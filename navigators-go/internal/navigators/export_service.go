package navigators

import (
	"bytes"
	"context"
	"encoding/csv"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuri/excelize/v2"

	"navigators-go/internal/db"
)

// ExportService generates CSV and Excel exports for contacts, voters, and tasks.
// All exports enforce role-based scoping via TurfScopedFilter.
type ExportService struct {
	queries *db.Queries
	pool    *pgxpool.Pool
	scope   *TurfScopedFilter
}

// NewExportService creates a new ExportService.
func NewExportService(queries *db.Queries, pool *pgxpool.Pool, scope *TurfScopedFilter) *ExportService {
	return &ExportService{queries: queries, pool: pool, scope: scope}
}

// Export dispatches to the appropriate export method based on type and format.
// Returns (data, filename, contentType, error).
func (s *ExportService) Export(ctx context.Context, companyID uuid.UUID, exportType, format string, since, until time.Time) ([]byte, string, string, error) {
	scope, err := s.scope.ResolveScope(ctx)
	if err != nil {
		return nil, "", "", fmt.Errorf("resolve scope: %w", err)
	}

	var userID pgtype.UUID
	var turfIDs []uuid.UUID
	if scope.Type == ScopeOwn {
		userID = pgtype.UUID{Bytes: scope.UserID, Valid: true}
		turfIDs = scope.TurfIDs
	} else if scope.Type == ScopeTeam {
		turfIDs = scope.TurfIDs
	}

	timestamp := time.Now().Format("20060102-150405")
	var data []byte
	var filename, contentType string

	switch exportType {
	case "contacts":
		if format == "csv" {
			data, err = s.exportContactsCSV(ctx, companyID, userID, turfIDs, since, until)
			filename = fmt.Sprintf("contacts-%s.csv", timestamp)
			contentType = "text/csv"
		} else {
			data, err = s.exportContactsExcel(ctx, companyID, userID, turfIDs, since, until)
			filename = fmt.Sprintf("contacts-%s.xlsx", timestamp)
			contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
		}
	case "voters":
		if format == "csv" {
			data, err = s.exportVotersCSV(ctx, companyID, turfIDs)
			filename = fmt.Sprintf("voters-%s.csv", timestamp)
			contentType = "text/csv"
		} else {
			data, err = s.exportVotersExcel(ctx, companyID, turfIDs)
			filename = fmt.Sprintf("voters-%s.xlsx", timestamp)
			contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
		}
	case "tasks":
		if format == "csv" {
			data, err = s.exportTasksCSV(ctx, companyID, userID)
			filename = fmt.Sprintf("tasks-%s.csv", timestamp)
			contentType = "text/csv"
		} else {
			data, err = s.exportTasksExcel(ctx, companyID, userID)
			filename = fmt.Sprintf("tasks-%s.xlsx", timestamp)
			contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
		}
	default:
		return nil, "", "", fmt.Errorf("unsupported export_type: %s", exportType)
	}

	if err != nil {
		return nil, "", "", err
	}
	return data, filename, contentType, nil
}

// --- Contacts export ---

func (s *ExportService) exportContactsCSV(ctx context.Context, companyID uuid.UUID, userID pgtype.UUID, turfIDs []uuid.UUID, since, until time.Time) ([]byte, error) {
	rows, err := s.queries.GetExportContacts(ctx, db.GetExportContactsParams{
		CompanyID: companyID,
		Since:     since,
		Until:     until,
		UserID:    userID,
		TurfIds:   turfIDs,
	})
	if err != nil {
		return nil, fmt.Errorf("get export contacts: %w", err)
	}

	var buf bytes.Buffer
	w := csv.NewWriter(&buf)

	// Header
	if err := w.Write([]string{"Date", "Voter Name", "Contact Type", "Outcome", "Sentiment", "Navigator", "Turf"}); err != nil {
		return nil, fmt.Errorf("write header: %w", err)
	}

	for _, r := range rows {
		voterName := derefStr(r.VoterFirstName) + " " + derefStr(r.VoterLastName)
		sentiment := ""
		if r.Sentiment != nil {
			sentiment = strconv.Itoa(int(*r.Sentiment))
		}
		if err := w.Write([]string{
			r.CreatedAt.Format(time.RFC3339),
			voterName,
			r.ContactType,
			r.Outcome,
			sentiment,
			derefStr(r.NavigatorName),
			derefStr(r.TurfName),
		}); err != nil {
			return nil, fmt.Errorf("write row: %w", err)
		}
	}

	w.Flush()
	if err := w.Error(); err != nil {
		return nil, fmt.Errorf("csv flush: %w", err)
	}
	return buf.Bytes(), nil
}

func (s *ExportService) exportContactsExcel(ctx context.Context, companyID uuid.UUID, userID pgtype.UUID, turfIDs []uuid.UUID, since, until time.Time) ([]byte, error) {
	rows, err := s.queries.GetExportContacts(ctx, db.GetExportContactsParams{
		CompanyID: companyID,
		Since:     since,
		Until:     until,
		UserID:    userID,
		TurfIds:   turfIDs,
	})
	if err != nil {
		return nil, fmt.Errorf("get export contacts: %w", err)
	}

	f := excelize.NewFile()
	defer f.Close()

	sw, err := f.NewStreamWriter("Sheet1")
	if err != nil {
		return nil, fmt.Errorf("new stream writer: %w", err)
	}

	// Header row
	if err := sw.SetRow("A1", []interface{}{
		excelize.Cell{Value: "Date"},
		excelize.Cell{Value: "Voter Name"},
		excelize.Cell{Value: "Contact Type"},
		excelize.Cell{Value: "Outcome"},
		excelize.Cell{Value: "Sentiment"},
		excelize.Cell{Value: "Navigator"},
		excelize.Cell{Value: "Turf"},
	}); err != nil {
		return nil, fmt.Errorf("write header: %w", err)
	}

	for i, r := range rows {
		voterName := derefStr(r.VoterFirstName) + " " + derefStr(r.VoterLastName)
		sentiment := ""
		if r.Sentiment != nil {
			sentiment = strconv.Itoa(int(*r.Sentiment))
		}
		cell, _ := excelize.CoordinatesToCellName(1, i+2)
		if err := sw.SetRow(cell, []interface{}{
			excelize.Cell{Value: r.CreatedAt.Format(time.RFC3339)},
			excelize.Cell{Value: voterName},
			excelize.Cell{Value: r.ContactType},
			excelize.Cell{Value: r.Outcome},
			excelize.Cell{Value: sentiment},
			excelize.Cell{Value: derefStr(r.NavigatorName)},
			excelize.Cell{Value: derefStr(r.TurfName)},
		}); err != nil {
			return nil, fmt.Errorf("write row %d: %w", i, err)
		}
	}

	if err := sw.Flush(); err != nil {
		return nil, fmt.Errorf("flush stream writer: %w", err)
	}

	var buf bytes.Buffer
	if _, err := f.WriteTo(&buf); err != nil {
		return nil, fmt.Errorf("write excel: %w", err)
	}
	return buf.Bytes(), nil
}

// --- Voters export ---

func (s *ExportService) exportVotersCSV(ctx context.Context, companyID uuid.UUID, turfIDs []uuid.UUID) ([]byte, error) {
	rows, err := s.queries.GetExportVoters(ctx, db.GetExportVotersParams{
		CompanyID: companyID,
		TurfIds:   turfIDs,
	})
	if err != nil {
		return nil, fmt.Errorf("get export voters: %w", err)
	}

	var buf bytes.Buffer
	w := csv.NewWriter(&buf)

	if err := w.Write([]string{"Voter ID", "First Name", "Last Name", "Address", "City", "Zip", "Party", "Status", "Registration Date"}); err != nil {
		return nil, fmt.Errorf("write header: %w", err)
	}

	for _, r := range rows {
		if err := w.Write([]string{
			r.ID.String(),
			r.FirstName,
			r.LastName,
			r.ResStreetAddress,
			r.ResCity,
			r.ResZip,
			r.Party,
			r.Status,
			r.RegistrationDate,
		}); err != nil {
			return nil, fmt.Errorf("write row: %w", err)
		}
	}

	w.Flush()
	if err := w.Error(); err != nil {
		return nil, fmt.Errorf("csv flush: %w", err)
	}
	return buf.Bytes(), nil
}

func (s *ExportService) exportVotersExcel(ctx context.Context, companyID uuid.UUID, turfIDs []uuid.UUID) ([]byte, error) {
	rows, err := s.queries.GetExportVoters(ctx, db.GetExportVotersParams{
		CompanyID: companyID,
		TurfIds:   turfIDs,
	})
	if err != nil {
		return nil, fmt.Errorf("get export voters: %w", err)
	}

	f := excelize.NewFile()
	defer f.Close()

	sw, err := f.NewStreamWriter("Sheet1")
	if err != nil {
		return nil, fmt.Errorf("new stream writer: %w", err)
	}

	if err := sw.SetRow("A1", []interface{}{
		excelize.Cell{Value: "Voter ID"},
		excelize.Cell{Value: "First Name"},
		excelize.Cell{Value: "Last Name"},
		excelize.Cell{Value: "Address"},
		excelize.Cell{Value: "City"},
		excelize.Cell{Value: "Zip"},
		excelize.Cell{Value: "Party"},
		excelize.Cell{Value: "Status"},
		excelize.Cell{Value: "Registration Date"},
	}); err != nil {
		return nil, fmt.Errorf("write header: %w", err)
	}

	for i, r := range rows {
		cell, _ := excelize.CoordinatesToCellName(1, i+2)
		if err := sw.SetRow(cell, []interface{}{
			excelize.Cell{Value: r.ID.String()},
			excelize.Cell{Value: r.FirstName},
			excelize.Cell{Value: r.LastName},
			excelize.Cell{Value: r.ResStreetAddress},
			excelize.Cell{Value: r.ResCity},
			excelize.Cell{Value: r.ResZip},
			excelize.Cell{Value: r.Party},
			excelize.Cell{Value: r.Status},
			excelize.Cell{Value: r.RegistrationDate},
		}); err != nil {
			return nil, fmt.Errorf("write row %d: %w", i, err)
		}
	}

	if err := sw.Flush(); err != nil {
		return nil, fmt.Errorf("flush stream writer: %w", err)
	}

	var buf bytes.Buffer
	if _, err := f.WriteTo(&buf); err != nil {
		return nil, fmt.Errorf("write excel: %w", err)
	}
	return buf.Bytes(), nil
}

// --- Tasks export ---

func (s *ExportService) exportTasksCSV(ctx context.Context, companyID uuid.UUID, userID pgtype.UUID) ([]byte, error) {
	rows, err := s.queries.GetExportTasks(ctx, db.GetExportTasksParams{
		CompanyID: companyID,
		UserID:    userID,
	})
	if err != nil {
		return nil, fmt.Errorf("get export tasks: %w", err)
	}

	var buf bytes.Buffer
	w := csv.NewWriter(&buf)

	if err := w.Write([]string{"Title", "Type", "Status", "Priority", "Progress %", "Due Date", "Created By", "Created At"}); err != nil {
		return nil, fmt.Errorf("write header: %w", err)
	}

	for _, r := range rows {
		dueDate := ""
		if r.DueDate.Valid {
			dueDate = r.DueDate.Time.Format(time.RFC3339)
		}
		if err := w.Write([]string{
			r.Title,
			r.TaskType,
			r.Status,
			r.Priority,
			strconv.Itoa(int(r.ProgressPct)),
			dueDate,
			derefStr(r.CreatedByName),
			r.CreatedAt.Format(time.RFC3339),
		}); err != nil {
			return nil, fmt.Errorf("write row: %w", err)
		}
	}

	w.Flush()
	if err := w.Error(); err != nil {
		return nil, fmt.Errorf("csv flush: %w", err)
	}
	return buf.Bytes(), nil
}

func (s *ExportService) exportTasksExcel(ctx context.Context, companyID uuid.UUID, userID pgtype.UUID) ([]byte, error) {
	rows, err := s.queries.GetExportTasks(ctx, db.GetExportTasksParams{
		CompanyID: companyID,
		UserID:    userID,
	})
	if err != nil {
		return nil, fmt.Errorf("get export tasks: %w", err)
	}

	f := excelize.NewFile()
	defer f.Close()

	sw, err := f.NewStreamWriter("Sheet1")
	if err != nil {
		return nil, fmt.Errorf("new stream writer: %w", err)
	}

	if err := sw.SetRow("A1", []interface{}{
		excelize.Cell{Value: "Title"},
		excelize.Cell{Value: "Type"},
		excelize.Cell{Value: "Status"},
		excelize.Cell{Value: "Priority"},
		excelize.Cell{Value: "Progress %"},
		excelize.Cell{Value: "Due Date"},
		excelize.Cell{Value: "Created By"},
		excelize.Cell{Value: "Created At"},
	}); err != nil {
		return nil, fmt.Errorf("write header: %w", err)
	}

	for i, r := range rows {
		dueDate := ""
		if r.DueDate.Valid {
			dueDate = r.DueDate.Time.Format(time.RFC3339)
		}
		cell, _ := excelize.CoordinatesToCellName(1, i+2)
		if err := sw.SetRow(cell, []interface{}{
			excelize.Cell{Value: r.Title},
			excelize.Cell{Value: r.TaskType},
			excelize.Cell{Value: r.Status},
			excelize.Cell{Value: r.Priority},
			excelize.Cell{Value: r.ProgressPct},
			excelize.Cell{Value: dueDate},
			excelize.Cell{Value: derefStr(r.CreatedByName)},
			excelize.Cell{Value: r.CreatedAt.Format(time.RFC3339)},
		}); err != nil {
			return nil, fmt.Errorf("write row %d: %w", i, err)
		}
	}

	if err := sw.Flush(); err != nil {
		return nil, fmt.Errorf("flush stream writer: %w", err)
	}

	var buf bytes.Buffer
	if _, err := f.WriteTo(&buf); err != nil {
		return nil, fmt.Errorf("write excel: %w", err)
	}
	return buf.Bytes(), nil
}

// derefStr safely dereferences a string pointer, returning empty string if nil.
func derefStr(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
