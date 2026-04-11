package navigators

import (
	"bufio"
	"context"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/minio/minio-go/v7"

	"navigators-go/internal/db"
)

// ImportService provides voter file import operations.
type ImportService struct {
	queries      *db.Queries
	pool         *pgxpool.Pool
	minioClient  *minio.Client
	bucket       string
	auditService *AuditService
}

// NewImportService creates a new ImportService.
func NewImportService(
	queries *db.Queries,
	pool *pgxpool.Pool,
	minioClient *minio.Client,
	bucket string,
	auditService *AuditService,
) *ImportService {
	return &ImportService{
		queries:      queries,
		pool:         pool,
		minioClient:  minioClient,
		bucket:       bucket,
		auditService: auditService,
	}
}

// StagingRow represents a parsed voter row ready for staging.
type StagingRow struct {
	LineNumber            int32
	IsValid               bool
	ValidationError       string
	FirstName             string
	MiddleName            string
	LastName              string
	Suffix                string
	YearOfBirth           *int32
	ResStreetAddress      string
	ResStreetNumber       string
	ResStreetName         string
	ResUnit               string
	ResCity               string
	ResState              string
	ResZip                string
	MailStreetAddress     string
	MailCity              string
	MailState             string
	MailZip               string
	Party                 string
	Status                string
	RegistrationDate      string
	County                string
	Municipality          string
	Ward                  string
	Precinct              string
	CongressionalDistrict string
	StateSenateDistrict   string
	StateHouseDistrict    string
	SourceVoterID         string
	VotingHistory         json.RawMessage
	Phone                 string
	Email                 string
	DedupKey              string
	RawLine               string
}

// ParseError records a line-level parse error.
type ParseError struct {
	LineNumber int    `json:"line_number"`
	Error      string `json:"error"`
}

// knownHeaders are common CVR/L2 header field names used to detect header rows.
var knownHeaders = map[string]bool{
	"voter_id": true, "voterid": true, "first_name": true, "firstname": true,
	"last_name": true, "lastname": true, "name": true, "first": true,
	"last": true, "id": true, "registration": true,
}

// ParseCVRFile parses a pipe-delimited Maine CVR voter file using the provided field mapping.
// fieldMapping maps column index (0-based) to canonical field names.
func ParseCVRFile(reader io.Reader, fieldMapping map[int]string) ([]StagingRow, []ParseError) {
	var rows []StagingRow
	var errors []ParseError

	scanner := bufio.NewScanner(reader)
	// Increase buffer for potentially long lines
	scanner.Buffer(make([]byte, 0, 1024*1024), 1024*1024)

	lineNum := 0
	for scanner.Scan() {
		lineNum++
		line := scanner.Text()
		if line == "" {
			continue
		}

		fields := strings.Split(line, "|")

		// Skip header row
		if lineNum == 1 && len(fields) > 0 {
			firstField := strings.ToLower(strings.TrimSpace(fields[0]))
			if knownHeaders[firstField] {
				continue
			}
		}

		row, err := mapFieldsToRow(fields, fieldMapping, lineNum, line)
		if err != nil {
			errors = append(errors, ParseError{LineNumber: lineNum, Error: err.Error()})
			row.IsValid = false
			row.ValidationError = err.Error()
		}

		rows = append(rows, row)
	}

	if err := scanner.Err(); err != nil {
		errors = append(errors, ParseError{LineNumber: lineNum, Error: fmt.Sprintf("scanner error: %v", err)})
	}

	return rows, errors
}

// ParseL2File parses a tab-delimited L2 voter file using the provided field mapping.
func ParseL2File(reader io.Reader, fieldMapping map[int]string) ([]StagingRow, []ParseError) {
	var rows []StagingRow
	var errors []ParseError

	csvReader := csv.NewReader(reader)
	csvReader.Comma = '\t'
	csvReader.LazyQuotes = true
	csvReader.FieldsPerRecord = -1 // variable field count

	lineNum := 0
	for {
		fields, err := csvReader.Read()
		if err == io.EOF {
			break
		}
		lineNum++

		if err != nil {
			errors = append(errors, ParseError{LineNumber: lineNum, Error: fmt.Sprintf("csv parse: %v", err)})
			continue
		}

		// Skip header row
		if lineNum == 1 && len(fields) > 0 {
			firstField := strings.ToLower(strings.TrimSpace(fields[0]))
			if knownHeaders[firstField] {
				continue
			}
		}

		rawLine := strings.Join(fields, "\t")
		row, err2 := mapFieldsToRow(fields, fieldMapping, lineNum, rawLine)
		if err2 != nil {
			errors = append(errors, ParseError{LineNumber: lineNum, Error: err2.Error()})
			row.IsValid = false
			row.ValidationError = err2.Error()
		}

		rows = append(rows, row)
	}

	return rows, errors
}

// mapFieldsToRow maps raw string fields to a StagingRow using the field mapping.
func mapFieldsToRow(fields []string, fieldMapping map[int]string, lineNum int, rawLine string) (StagingRow, error) {
	row := StagingRow{
		LineNumber:    int32(lineNum),
		IsValid:       true,
		VotingHistory: json.RawMessage("[]"),
		RawLine:       rawLine,
		ResState:      "ME",
	}

	for idx, fieldName := range fieldMapping {
		if idx >= len(fields) {
			continue
		}
		value := strings.TrimSpace(fields[idx])

		switch strings.ToLower(fieldName) {
		case "first_name":
			row.FirstName = value
		case "middle_name":
			row.MiddleName = value
		case "last_name":
			row.LastName = value
		case "suffix":
			row.Suffix = value
		case "year_of_birth":
			if value != "" {
				yob, err := strconv.Atoi(value)
				if err == nil {
					y := int32(yob)
					row.YearOfBirth = &y
				}
			}
		case "date_of_birth":
			// Extract year only -- NEVER store full DOB per Maine 21-A s196-A
			if value != "" {
				if y := extractYear(value); y > 0 {
					yr := int32(y)
					row.YearOfBirth = &yr
				}
			}
		case "res_street_address":
			row.ResStreetAddress = value
			num, name := parseStreetAddress(value)
			row.ResStreetNumber = num
			row.ResStreetName = name
		case "res_street_number":
			row.ResStreetNumber = value
		case "res_street_name":
			row.ResStreetName = value
		case "res_unit":
			row.ResUnit = value
		case "res_city":
			row.ResCity = value
		case "res_state":
			row.ResState = value
		case "res_zip":
			row.ResZip = truncateZip5(value)
		case "mail_street_address":
			row.MailStreetAddress = value
		case "mail_city":
			row.MailCity = value
		case "mail_state":
			row.MailState = value
		case "mail_zip":
			row.MailZip = value
		case "party":
			row.Party = normalizeParty(value)
		case "status":
			row.Status = value
		case "registration_date":
			row.RegistrationDate = value
		case "county":
			row.County = value
		case "municipality":
			row.Municipality = value
		case "ward":
			row.Ward = value
		case "precinct":
			row.Precinct = value
		case "congressional_district":
			row.CongressionalDistrict = value
		case "state_senate_district":
			row.StateSenateDistrict = value
		case "state_house_district":
			row.StateHouseDistrict = value
		case "source_voter_id", "voter_id":
			row.SourceVoterID = value
		case "phone":
			row.Phone = value
		case "email":
			row.Email = value
		// Explicitly skip prohibited fields
		case "ssn", "social_security", "drivers_license", "driver_license",
			"felony_status", "criminal_history":
			// DO NOT store these fields
		}
	}

	// Validate required fields
	if row.LastName == "" {
		return row, fmt.Errorf("missing required field: last_name")
	}

	// Generate dedup key
	row.DedupKey = GenerateDedupKey(row.LastName, row.ResStreetNumber, row.ResStreetName, row.ResZip, row.YearOfBirth)
	if row.DedupKey == "" {
		return row, fmt.Errorf("unable to generate dedup key: insufficient data")
	}

	return row, nil
}

// streetAbbrevsRegexp matches common street suffixes for normalization.
var streetAbbrevs = map[string]string{
	"STREET": "ST", "AVENUE": "AVE", "BOULEVARD": "BLVD", "DRIVE": "DR",
	"LANE": "LN", "ROAD": "RD", "COURT": "CT", "PLACE": "PL",
	"CIRCLE": "CIR", "TERRACE": "TER", "WAY": "WAY", "HIGHWAY": "HWY",
	"PARKWAY": "PKWY", "TRAIL": "TRL",
}

// nonAlphaRegexp strips non-alpha characters for name normalization.
var nonAlphaRegexp = regexp.MustCompile(`[^A-Z]`)

// GenerateDedupKey creates a deterministic dedup key from voter identity components.
// Format: "LASTNAME|STREETNUM|STREETNAME|ZIP5|YOB"
func GenerateDedupKey(lastName, streetNumber, streetName, zip string, yearOfBirth *int32) string {
	// Normalize last name: uppercase, remove non-alpha
	normLast := nonAlphaRegexp.ReplaceAllString(strings.ToUpper(lastName), "")
	if normLast == "" {
		return ""
	}

	// Normalize street number
	normNum := strings.TrimSpace(streetNumber)

	// Normalize street name: uppercase, abbreviate suffixes
	normStreet := strings.ToUpper(strings.TrimSpace(streetName))
	for full, abbrev := range streetAbbrevs {
		normStreet = strings.ReplaceAll(normStreet, full, abbrev)
	}
	normStreet = nonAlphaRegexp.ReplaceAllString(normStreet, "")

	// Zip5
	zip5 := truncateZip5(zip)

	// Year of birth
	yobStr := ""
	if yearOfBirth != nil {
		yobStr = strconv.Itoa(int(*yearOfBirth))
	}

	return normLast + "|" + normNum + "|" + normStreet + "|" + zip5 + "|" + yobStr
}

// extractYear tries to parse a year from various date formats.
func extractYear(dateStr string) int {
	dateStr = strings.TrimSpace(dateStr)

	// Try YYYY-MM-DD
	for _, layout := range []string{"2006-01-02", "01/02/2006", "1/2/2006", "01-02-2006"} {
		if t, err := time.Parse(layout, dateStr); err == nil {
			return t.Year()
		}
	}

	// Try just a 4-digit year
	if len(dateStr) == 4 {
		if y, err := strconv.Atoi(dateStr); err == nil && y > 1900 && y < 2100 {
			return y
		}
	}

	return 0
}

// truncateZip5 returns the first 5 characters of a ZIP code.
func truncateZip5(zip string) string {
	zip = strings.TrimSpace(zip)
	if len(zip) > 5 {
		return zip[:5]
	}
	return zip
}

// parseStreetAddress splits a full address into number and street name.
func parseStreetAddress(addr string) (number, street string) {
	addr = strings.TrimSpace(addr)
	parts := strings.SplitN(addr, " ", 2)
	if len(parts) < 2 {
		return "", addr
	}
	// Check if first part looks like a number
	if _, err := strconv.Atoi(parts[0]); err == nil {
		return parts[0], parts[1]
	}
	return "", addr
}

// normalizeParty normalizes Maine party codes.
func normalizeParty(party string) string {
	party = strings.ToUpper(strings.TrimSpace(party))
	switch party {
	case "D", "DEM", "DEMOCRAT", "DEMOCRATIC":
		return "D"
	case "R", "REP", "REPUBLICAN":
		return "R"
	case "G", "GRN", "GREEN":
		return "G"
	case "L", "LIB", "LIBERTARIAN":
		return "L"
	case "NL":
		return "NL"
	case "", "U", "UNENROLLED":
		return "U"
	default:
		return party
	}
}

// StartImport creates a new import job and returns a presigned upload URL.
func (s *ImportService) StartImport(ctx context.Context, companyID, userID uuid.UUID, fileName, sourceType string, fieldMapping json.RawMessage) (uuid.UUID, string, error) {
	jobID := uuid.New()
	storageKey := fmt.Sprintf("voter-imports/%s/%s/%s", companyID, jobID, fileName)

	// Create presigned PUT URL for direct upload to MinIO
	presignedURL, err := s.minioClient.PresignedPutObject(ctx, s.bucket, storageKey, 30*time.Minute)
	if err != nil {
		return uuid.Nil, "", fmt.Errorf("create presigned URL: %w", err)
	}

	// Create import job record
	job, err := s.queries.CreateImportJob(ctx, db.CreateImportJobParams{
		CompanyID:      companyID,
		UploadedBy:     userID,
		FileName:       fileName,
		FileStorageKey: storageKey,
		SourceType:     sourceType,
		FieldMapping:   fieldMapping,
	})
	if err != nil {
		return uuid.Nil, "", fmt.Errorf("create import job: %w", err)
	}

	slog.Info("import job created", "job_id", job.ID, "file", fileName, "source_type", sourceType)
	return job.ID, presignedURL.String(), nil
}

// ConfirmUploadAndProcess starts background processing of an uploaded file.
func (s *ImportService) ConfirmUploadAndProcess(ctx context.Context, jobID uuid.UUID) error {
	job, err := s.queries.GetImportJob(ctx, jobID)
	if err != nil {
		return fmt.Errorf("get import job: %w", err)
	}

	if job.Status != "pending" {
		return fmt.Errorf("import job status is %q, expected 'pending'", job.Status)
	}

	// Update status to parsing
	if err := s.queries.UpdateImportJobStatus(ctx, db.UpdateImportJobStatusParams{
		ID:     jobID,
		Status: "parsing",
		Errors: json.RawMessage("[]"),
	}); err != nil {
		return fmt.Errorf("update job status: %w", err)
	}

	// Parse field mapping
	var fieldMapping map[int]string
	if err := json.Unmarshal(job.FieldMapping, &fieldMapping); err != nil {
		// Try string-keyed format and convert
		var strMapping map[string]string
		if err2 := json.Unmarshal(job.FieldMapping, &strMapping); err2 != nil {
			return fmt.Errorf("parse field mapping: %w (also tried string keys: %w)", err, err2)
		}
		fieldMapping = make(map[int]string, len(strMapping))
		for k, v := range strMapping {
			idx, err3 := strconv.Atoi(k)
			if err3 != nil {
				return fmt.Errorf("invalid field mapping key %q: %w", k, err3)
			}
			fieldMapping[idx] = v
		}
	}

	// Launch background goroutine with fresh context (HTTP request context will be cancelled)
	go s.processImport(context.Background(), job, fieldMapping)

	return nil
}

// processImport runs the full import pipeline: download, parse, stage, merge.
func (s *ImportService) processImport(ctx context.Context, job db.ImportJob, fieldMapping map[int]string) {
	logger := slog.With("job_id", job.ID, "file", job.FileName)

	// Helper to fail the job
	failJob := func(errMsg string) {
		logger.Error("import failed", "error", errMsg)
		errJSON, _ := json.Marshal([]ParseError{{Error: errMsg}})
		_ = s.queries.UpdateImportJobStatus(ctx, db.UpdateImportJobStatusParams{
			ID:     job.ID,
			Status: "failed",
			Errors: errJSON,
		})
	}

	// 1. Download file from MinIO
	obj, err := s.minioClient.GetObject(ctx, s.bucket, job.FileStorageKey, minio.GetObjectOptions{})
	if err != nil {
		failJob(fmt.Sprintf("download file: %v", err))
		return
	}
	defer obj.Close()

	// 2. Parse file based on source type
	var stagingRows []StagingRow
	var parseErrors []ParseError

	switch job.SourceType {
	case "cvr":
		stagingRows, parseErrors = ParseCVRFile(obj, fieldMapping)
	case "l2":
		stagingRows, parseErrors = ParseL2File(obj, fieldMapping)
	default:
		failJob(fmt.Sprintf("unsupported source type: %s", job.SourceType))
		return
	}

	totalRows := int32(len(stagingRows))
	errorRows := int32(len(parseErrors))
	parsedRows := totalRows - errorRows

	logger.Info("file parsed", "total", totalRows, "parsed", parsedRows, "errors", errorRows)

	// Update status to staging
	if err := s.queries.UpdateImportJobStatus(ctx, db.UpdateImportJobStatusParams{
		ID:         job.ID,
		Status:     "staging",
		TotalRows:  totalRows,
		ParsedRows: parsedRows,
		ErrorRows:  errorRows,
		Errors:     marshalErrors(parseErrors),
	}); err != nil {
		failJob(fmt.Sprintf("update status to staging: %v", err))
		return
	}

	// 3. Bulk copy staging rows using pgx CopyFrom
	if len(stagingRows) > 0 {
		if err := s.bulkCopyStaging(ctx, job.ID, stagingRows); err != nil {
			// Cleanup partial staging data
			_ = s.queries.CleanupStaging(ctx, job.ID)
			failJob(fmt.Sprintf("copy to staging: %v", err))
			return
		}
	}

	// 4. Merge staging to voters
	if err := s.queries.UpdateImportJobStatus(ctx, db.UpdateImportJobStatusParams{
		ID:         job.ID,
		Status:     "merging",
		TotalRows:  totalRows,
		ParsedRows: parsedRows,
		ErrorRows:  errorRows,
		Errors:     marshalErrors(parseErrors),
	}); err != nil {
		failJob(fmt.Sprintf("update status to merging: %v", err))
		return
	}

	if err := s.queries.MergeStagingToVoters(ctx, db.MergeStagingToVotersParams{
		ImportJobID: job.ID,
		CompanyID:   job.CompanyID,
		Source:      job.SourceType,
	}); err != nil {
		failJob(fmt.Sprintf("merge staging to voters: %v", err))
		return
	}

	// 5. Count results
	counts, err := s.queries.CountStagingRows(ctx, job.ID)
	if err != nil {
		failJob(fmt.Sprintf("count staging rows: %v", err))
		return
	}

	mergedRows := int32(counts.Valid)
	skippedRows := int32(counts.Invalid)

	// 6. Complete the job
	if err := s.queries.UpdateImportJobStatus(ctx, db.UpdateImportJobStatusParams{
		ID:          job.ID,
		Status:      "complete",
		TotalRows:   totalRows,
		ParsedRows:  parsedRows,
		MergedRows:  mergedRows,
		SkippedRows: skippedRows,
		ErrorRows:   errorRows,
		Errors:      marshalErrors(parseErrors),
	}); err != nil {
		failJob(fmt.Sprintf("update status to complete: %v", err))
		return
	}

	// 7. Cleanup staging data
	_ = s.queries.CleanupStaging(ctx, job.ID)

	logger.Info("import complete", "merged", mergedRows, "skipped", skippedRows, "errors", errorRows)
}

// bulkCopyStaging uses pgx CopyFrom to insert staging rows efficiently.
func (s *ImportService) bulkCopyStaging(ctx context.Context, jobID uuid.UUID, rows []StagingRow) error {
	columns := []string{
		"import_job_id", "line_number", "is_valid", "validation_error",
		"first_name", "middle_name", "last_name", "suffix", "year_of_birth",
		"res_street_address", "res_street_number", "res_street_name", "res_unit",
		"res_city", "res_state", "res_zip",
		"mail_street_address", "mail_city", "mail_state", "mail_zip",
		"party", "status", "registration_date",
		"county", "municipality", "ward", "precinct",
		"congressional_district", "state_senate_district", "state_house_district",
		"source_voter_id", "voting_history", "phone", "email",
		"dedup_key", "raw_line",
	}

	copyRows := make([][]interface{}, len(rows))
	for i, r := range rows {
		copyRows[i] = []interface{}{
			jobID, r.LineNumber, r.IsValid, r.ValidationError,
			r.FirstName, r.MiddleName, r.LastName, r.Suffix, r.YearOfBirth,
			r.ResStreetAddress, r.ResStreetNumber, r.ResStreetName, r.ResUnit,
			r.ResCity, r.ResState, r.ResZip,
			r.MailStreetAddress, r.MailCity, r.MailState, r.MailZip,
			r.Party, r.Status, r.RegistrationDate,
			r.County, r.Municipality, r.Ward, r.Precinct,
			r.CongressionalDistrict, r.StateSenateDistrict, r.StateHouseDistrict,
			r.SourceVoterID, r.VotingHistory, r.Phone, r.Email,
			r.DedupKey, r.RawLine,
		}
	}

	_, err := s.pool.CopyFrom(
		ctx,
		pgx.Identifier{"import_staging"},
		columns,
		pgx.CopyFromRows(copyRows),
	)
	return err
}

// GetImportStatus returns the current state of an import job.
func (s *ImportService) GetImportStatus(ctx context.Context, jobID uuid.UUID) (db.ImportJob, error) {
	return s.queries.GetImportJob(ctx, jobID)
}

// ListImportJobs returns a paginated list of import jobs for a company.
func (s *ImportService) ListImportJobs(ctx context.Context, companyID uuid.UUID, limit, offset int32) ([]db.ImportJob, int64, error) {
	jobs, err := s.queries.ListImportJobs(ctx, db.ListImportJobsParams{
		CompanyID: companyID,
		Limit:     limit,
		Offset:    offset,
	})
	if err != nil {
		return nil, 0, fmt.Errorf("list import jobs: %w", err)
	}

	count, err := s.queries.CountImportJobs(ctx, companyID)
	if err != nil {
		return nil, 0, fmt.Errorf("count import jobs: %w", err)
	}

	return jobs, count, nil
}

// marshalErrors converts parse errors to JSON.
func marshalErrors(errors []ParseError) json.RawMessage {
	if len(errors) == 0 {
		return json.RawMessage("[]")
	}
	data, err := json.Marshal(errors)
	if err != nil {
		return json.RawMessage("[]")
	}
	return data
}

