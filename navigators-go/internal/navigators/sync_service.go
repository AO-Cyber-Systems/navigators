package navigators

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"navigators-go/internal/db"
)

// SyncService provides sync query operations scoped to user's turfs.
type SyncService struct {
	queries           *db.Queries
	pool              *pgxpool.Pool
	turfFilter        *TurfScopedFilter
	surveyService     *SurveyService
	voterNotesService *VoterNotesService
}

// NewSyncService creates a new SyncService.
func NewSyncService(queries *db.Queries, pool *pgxpool.Pool, turfFilter *TurfScopedFilter, surveyService *SurveyService, voterNotesService *VoterNotesService) *SyncService {
	return &SyncService{
		queries:           queries,
		pool:              pool,
		turfFilter:        turfFilter,
		surveyService:     surveyService,
		voterNotesService: voterNotesService,
	}
}

// SyncVoterRow represents a voter row returned for sync pull.
type SyncVoterRow struct {
	ID               uuid.UUID
	TurfID           uuid.UUID
	FirstName        string
	LastName         string
	MiddleName       string
	Suffix           string
	YearOfBirth      int32
	ResStreetAddress string
	ResCity          string
	ResState         string
	ResZip           string
	Party            string
	Status           string
	Latitude         float64
	Longitude        float64
	VotingHistory    string
	Phone            string
	Email            string
	WalkSequence     int32
	UpdatedAt        time.Time
}

// SyncContactLogRow represents a contact log row returned for sync pull.
type SyncContactLogRow struct {
	ID          uuid.UUID
	VoterID     uuid.UUID
	TurfID      uuid.UUID
	UserID      uuid.UUID
	ContactType string
	Outcome     string
	Notes       string
	DoorStatus  string
	Sentiment   *int32
	CreatedAt   time.Time
}

// SyncSurveyFormRow represents a survey form row returned for sync pull.
type SyncSurveyFormRow struct {
	ID          uuid.UUID
	CompanyID   uuid.UUID
	Title       string
	Description string
	Schema      json.RawMessage
	Version     int32
	IsActive    bool
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// SyncSurveyResponseRow represents a survey response row returned for sync pull.
type SyncSurveyResponseRow struct {
	ID           uuid.UUID
	FormID       uuid.UUID
	FormVersion  int32
	VoterID      uuid.UUID
	UserID       uuid.UUID
	TurfID       uuid.UUID
	ContactLogID *uuid.UUID
	Responses    json.RawMessage
	CreatedAt    time.Time
}

// PullSurveyFormsResult contains the result of a survey form pull operation.
type PullSurveyFormsResult struct {
	SurveyForms []SyncSurveyFormRow
	NextCursor  string
	HasMore     bool
}

// PullSurveyResponsesResult contains the result of a survey response pull operation.
type PullSurveyResponsesResult struct {
	SurveyResponses []SyncSurveyResponseRow
	NextCursor      string
	HasMore         bool
}

// PullVoterUpdatesResult contains the result of a voter pull operation.
type PullVoterUpdatesResult struct {
	Voters     []SyncVoterRow
	NextCursor string
	HasMore    bool
}

// PullContactLogsResult contains the result of a contact log pull operation.
type PullContactLogsResult struct {
	ContactLogs []SyncContactLogRow
	NextCursor  string
	HasMore     bool
}

// TurfAssignmentResult contains turf info for the sync manifest.
type TurfAssignmentResult struct {
	TurfID          uuid.UUID
	TurfName        string
	BoundaryGeojson string
	VoterCount      int64
}

// --- Push Sync Types ---

// SyncOperationInput represents a single sync operation from the client.
type SyncOperationInput struct {
	ClientOperationID string
	EntityType        string
	EntityID          string
	OperationType     string
	Payload           []byte
	ClientTimestamp   string
}

// SyncError represents an error processing a specific sync operation.
type SyncError struct {
	OperationID string
	Code        string
	Message     string
}

// PushSyncBatchResult contains the result of processing a push sync batch.
type PushSyncBatchResult struct {
	ProcessedIDs []string
	Errors       []SyncError
}

// contactLogPayload is the JSON structure for contact log push operations.
type contactLogPayload struct {
	ID          string `json:"id"`
	VoterID     string `json:"voter_id"`
	TurfID      string `json:"turf_id"`
	UserID      string `json:"user_id"`
	ContactType string `json:"contact_type"`
	Outcome     string `json:"outcome"`
	Notes       string `json:"notes"`
	DoorStatus  string `json:"door_status"`
	Sentiment   *int32 `json:"sentiment"`
	CreatedAt   string `json:"created_at"`
}

// voterMetadataPayload is the JSON structure for voter metadata push operations.
type voterMetadataPayload struct {
	VoterID   string `json:"voter_id"`
	UpdatedAt string `json:"updated_at"`
}

// PushSyncBatch processes a batch of sync operations from the client.
// Each operation is processed idempotently: re-sending the same operation is a no-op.
// Contact logs are append-only (INSERT ON CONFLICT DO NOTHING).
// Voter metadata uses last-write-wins (UPDATE WHERE updated_at < client_timestamp).
func (s *SyncService) PushSyncBatch(ctx context.Context, userID, companyID uuid.UUID, ops []SyncOperationInput) (*PushSyncBatchResult, error) {
	var processed []string
	var syncErrors []SyncError

	for _, op := range ops {
		// 1. Check idempotency -- skip if already processed
		exists, err := s.queries.CheckSyncOperationProcessed(ctx, db.CheckSyncOperationProcessedParams{
			ClientOperationID: op.ClientOperationID,
			CompanyID:         companyID,
		})
		if err != nil {
			syncErrors = append(syncErrors, SyncError{
				OperationID: op.ClientOperationID,
				Code:        "internal_error",
				Message:     fmt.Sprintf("check idempotency: %v", err),
			})
			continue
		}
		if exists {
			// Already processed -- count as success
			processed = append(processed, op.ClientOperationID)
			continue
		}

		// 2. Process by entity type
		switch op.EntityType {
		case "contact_log":
			err = s.processContactLog(ctx, companyID, userID, op)
		case "voter_metadata":
			err = s.processVoterMetadata(ctx, companyID, op)
		case "survey_response":
			err = s.surveyService.ProcessSurveyResponse(ctx, companyID, userID, op)
		case "voter_note":
			err = s.voterNotesService.ProcessVoterNote(ctx, companyID, userID, op)
		default:
			syncErrors = append(syncErrors, SyncError{
				OperationID: op.ClientOperationID,
				Code:        "unknown_entity",
				Message:     fmt.Sprintf("unknown entity type: %s", op.EntityType),
			})
			continue
		}

		if err != nil {
			syncErrors = append(syncErrors, SyncError{
				OperationID: op.ClientOperationID,
				Code:        "processing_error",
				Message:     err.Error(),
			})
			continue
		}

		// 3. Record as processed for idempotency
		if recErr := s.queries.RecordSyncOperationProcessed(ctx, db.RecordSyncOperationProcessedParams{
			ClientOperationID: op.ClientOperationID,
			UserID:            userID,
			CompanyID:         companyID,
			EntityType:        op.EntityType,
			EntityID:          op.EntityID,
			OperationType:     op.OperationType,
		}); recErr != nil {
			// Non-fatal: operation was processed but idempotency record failed.
			// Next retry will re-process but ON CONFLICT clauses handle it.
			_ = recErr
		}

		processed = append(processed, op.ClientOperationID)
	}

	return &PushSyncBatchResult{
		ProcessedIDs: processed,
		Errors:       syncErrors,
	}, nil
}

// processContactLog inserts a contact log from a client push.
// Contact logs are append-only: ON CONFLICT (id) DO NOTHING.
func (s *SyncService) processContactLog(ctx context.Context, companyID, userID uuid.UUID, op SyncOperationInput) error {
	var payload contactLogPayload
	if err := json.Unmarshal(op.Payload, &payload); err != nil {
		return fmt.Errorf("unmarshal contact log payload: %w", err)
	}

	clID, err := uuid.Parse(payload.ID)
	if err != nil {
		clID, err = uuid.Parse(op.EntityID)
		if err != nil {
			return fmt.Errorf("parse contact log ID: %w", err)
		}
	}

	voterID, err := uuid.Parse(payload.VoterID)
	if err != nil {
		return fmt.Errorf("parse voter ID: %w", err)
	}

	var turfID pgtype.UUID
	if payload.TurfID != "" {
		parsed, err := uuid.Parse(payload.TurfID)
		if err != nil {
			return fmt.Errorf("parse turf ID: %w", err)
		}
		turfID = pgtype.UUID{Bytes: parsed, Valid: true}
	}

	createdAt := time.Now()
	if payload.CreatedAt != "" {
		if parsed, err := time.Parse(time.RFC3339, payload.CreatedAt); err == nil {
			createdAt = parsed
		}
	}

	return s.queries.UpsertContactLogFromSync(ctx, db.UpsertContactLogFromSyncParams{
		ID:          clID,
		CompanyID:   companyID,
		VoterID:     voterID,
		UserID:      userID,
		TurfID:      turfID,
		ContactType: payload.ContactType,
		Outcome:     payload.Outcome,
		Notes:       payload.Notes,
		DoorStatus:  payload.DoorStatus,
		Sentiment:   payload.Sentiment,
		CreatedAt:   createdAt,
	})
}

// processVoterMetadata updates voter metadata using LWW (last-write-wins).
// Only updates if the client's timestamp is newer than the server's current updated_at.
func (s *SyncService) processVoterMetadata(ctx context.Context, companyID uuid.UUID, op SyncOperationInput) error {
	var payload voterMetadataPayload
	if err := json.Unmarshal(op.Payload, &payload); err != nil {
		return fmt.Errorf("unmarshal voter metadata payload: %w", err)
	}

	voterID, err := uuid.Parse(payload.VoterID)
	if err != nil {
		voterID, err = uuid.Parse(op.EntityID)
		if err != nil {
			return fmt.Errorf("parse voter ID: %w", err)
		}
	}

	clientUpdatedAt := time.Now()
	if payload.UpdatedAt != "" {
		if parsed, err := time.Parse(time.RFC3339, payload.UpdatedAt); err == nil {
			clientUpdatedAt = parsed
		}
	}

	return s.queries.UpdateVoterUpdatedAtFromSync(ctx, db.UpdateVoterUpdatedAtFromSyncParams{
		ID:        voterID,
		CompanyID: companyID,
		UpdatedAt: clientUpdatedAt,
	})
}

// PullVoterUpdates returns voters updated since cursor, scoped to the user's turfs.
// Uses raw pgxpool for spatial JOIN (same pattern as turf_stats.go).
func (s *SyncService) PullVoterUpdates(ctx context.Context, companyID uuid.UUID, turfIDs []uuid.UUID, sinceCursor string, batchSize int32) (*PullVoterUpdatesResult, error) {
	if batchSize <= 0 || batchSize > 500 {
		batchSize = 500
	}

	if len(turfIDs) == 0 {
		return &PullVoterUpdatesResult{}, nil
	}

	// Parse cursor or use epoch for full sync
	var sinceTime time.Time
	if sinceCursor != "" {
		var err error
		sinceTime, err = time.Parse(time.RFC3339Nano, sinceCursor)
		if err != nil {
			return nil, fmt.Errorf("parse cursor: %w", err)
		}
	} else {
		sinceTime = time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC)
	}

	// Build turf ID array for ANY() clause
	turfIDStrings := make([]interface{}, len(turfIDs))
	for i, id := range turfIDs {
		turfIDStrings[i] = id
	}

	// Raw spatial query: get voters in turfs updated after cursor
	// Fetch batchSize+1 to detect has_more
	query := `
		SELECT DISTINCT v.id, t.id as turf_id,
			v.first_name, v.last_name, v.middle_name, v.suffix, v.year_of_birth,
			v.res_street_address, v.res_city, v.res_state, v.res_zip,
			v.party, v.status,
			COALESCE(ST_Y(v.location), 0) as latitude,
			COALESCE(ST_X(v.location), 0) as longitude,
			v.voting_history::text, COALESCE(v.phone, ''), COALESCE(v.email, ''),
			0 as walk_sequence,
			v.updated_at
		FROM voters v
		JOIN turfs t ON t.company_id = v.company_id
			AND t.id = ANY($1::uuid[])
			AND v.location IS NOT NULL
			AND v.geocode_status = 'success'
			AND ST_Contains(t.boundary, v.location)
		WHERE v.company_id = $2
			AND v.updated_at > $3
		ORDER BY v.updated_at ASC
		LIMIT $4`

	rows, err := s.pool.Query(ctx, query, turfIDs, companyID, sinceTime, batchSize+1)
	if err != nil {
		return nil, fmt.Errorf("pull voter updates: %w", err)
	}
	defer rows.Close()

	var voters []SyncVoterRow
	for rows.Next() {
		var v SyncVoterRow
		if err := rows.Scan(
			&v.ID, &v.TurfID,
			&v.FirstName, &v.LastName, &v.MiddleName, &v.Suffix, &v.YearOfBirth,
			&v.ResStreetAddress, &v.ResCity, &v.ResState, &v.ResZip,
			&v.Party, &v.Status,
			&v.Latitude, &v.Longitude,
			&v.VotingHistory, &v.Phone, &v.Email,
			&v.WalkSequence,
			&v.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan voter row: %w", err)
		}
		voters = append(voters, v)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate voter rows: %w", err)
	}

	hasMore := len(voters) > int(batchSize)
	if hasMore {
		voters = voters[:batchSize]
	}

	var nextCursor string
	if len(voters) > 0 {
		nextCursor = voters[len(voters)-1].UpdatedAt.Format(time.RFC3339Nano)
	}

	return &PullVoterUpdatesResult{
		Voters:     voters,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}, nil
}

// PullContactLogs returns contact logs created since cursor, scoped to the user's turfs.
func (s *SyncService) PullContactLogs(ctx context.Context, companyID uuid.UUID, turfIDs []uuid.UUID, sinceCursor string, batchSize int32) (*PullContactLogsResult, error) {
	if batchSize <= 0 || batchSize > 500 {
		batchSize = 500
	}

	if len(turfIDs) == 0 {
		return &PullContactLogsResult{}, nil
	}

	var sinceTime time.Time
	if sinceCursor != "" {
		var err error
		sinceTime, err = time.Parse(time.RFC3339Nano, sinceCursor)
		if err != nil {
			return nil, fmt.Errorf("parse cursor: %w", err)
		}
	} else {
		sinceTime = time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC)
	}

	query := `
		SELECT cl.id, cl.voter_id, cl.turf_id, cl.user_id,
			cl.contact_type, cl.outcome, cl.notes,
			cl.door_status, cl.sentiment, cl.created_at
		FROM contact_logs cl
		WHERE cl.company_id = $1
			AND cl.turf_id = ANY($2::uuid[])
			AND cl.created_at > $3
		ORDER BY cl.created_at ASC
		LIMIT $4`

	rows, err := s.pool.Query(ctx, query, companyID, turfIDs, sinceTime, batchSize+1)
	if err != nil {
		return nil, fmt.Errorf("pull contact logs: %w", err)
	}
	defer rows.Close()

	var logs []SyncContactLogRow
	for rows.Next() {
		var cl SyncContactLogRow
		if err := rows.Scan(
			&cl.ID, &cl.VoterID, &cl.TurfID, &cl.UserID,
			&cl.ContactType, &cl.Outcome, &cl.Notes,
			&cl.DoorStatus, &cl.Sentiment, &cl.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan contact log row: %w", err)
		}
		logs = append(logs, cl)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate contact log rows: %w", err)
	}

	hasMore := len(logs) > int(batchSize)
	if hasMore {
		logs = logs[:batchSize]
	}

	var nextCursor string
	if len(logs) > 0 {
		nextCursor = logs[len(logs)-1].CreatedAt.Format(time.RFC3339Nano)
	}

	return &PullContactLogsResult{
		ContactLogs: logs,
		NextCursor:  nextCursor,
		HasMore:     hasMore,
	}, nil
}

// PullSurveyForms returns survey forms updated since cursor for a company.
func (s *SyncService) PullSurveyForms(ctx context.Context, companyID uuid.UUID, sinceCursor string, batchSize int32) (*PullSurveyFormsResult, error) {
	if batchSize <= 0 || batchSize > 500 {
		batchSize = 500
	}

	var sinceTime time.Time
	if sinceCursor != "" {
		var err error
		sinceTime, err = time.Parse(time.RFC3339Nano, sinceCursor)
		if err != nil {
			return nil, fmt.Errorf("parse cursor: %w", err)
		}
	} else {
		sinceTime = time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC)
	}

	dbForms, err := s.queries.PullSurveyForms(ctx, db.PullSurveyFormsParams{
		CompanyID: companyID,
		UpdatedAt: sinceTime,
		Limit:     batchSize + 1,
	})
	if err != nil {
		return nil, fmt.Errorf("pull survey forms: %w", err)
	}

	hasMore := len(dbForms) > int(batchSize)
	if hasMore {
		dbForms = dbForms[:batchSize]
	}

	forms := make([]SyncSurveyFormRow, len(dbForms))
	for i, f := range dbForms {
		forms[i] = SyncSurveyFormRow{
			ID:          f.ID,
			CompanyID:   f.CompanyID,
			Title:       f.Title,
			Description: f.Description,
			Schema:      f.Schema,
			Version:     f.Version,
			IsActive:    f.IsActive,
			CreatedAt:   f.CreatedAt,
			UpdatedAt:   f.UpdatedAt,
		}
	}

	var nextCursor string
	if len(forms) > 0 {
		nextCursor = forms[len(forms)-1].UpdatedAt.Format(time.RFC3339Nano)
	}

	return &PullSurveyFormsResult{
		SurveyForms: forms,
		NextCursor:  nextCursor,
		HasMore:     hasMore,
	}, nil
}

// PullSurveyResponses returns survey responses created since cursor, scoped to turfs.
func (s *SyncService) PullSurveyResponses(ctx context.Context, companyID uuid.UUID, turfIDs []uuid.UUID, sinceCursor string, batchSize int32) (*PullSurveyResponsesResult, error) {
	if batchSize <= 0 || batchSize > 500 {
		batchSize = 500
	}

	if len(turfIDs) == 0 {
		return &PullSurveyResponsesResult{}, nil
	}

	var sinceTime time.Time
	if sinceCursor != "" {
		var err error
		sinceTime, err = time.Parse(time.RFC3339Nano, sinceCursor)
		if err != nil {
			return nil, fmt.Errorf("parse cursor: %w", err)
		}
	} else {
		sinceTime = time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC)
	}

	dbResponses, err := s.queries.PullSurveyResponses(ctx, db.PullSurveyResponsesParams{
		CompanyID: companyID,
		Column2:   turfIDs,
		CreatedAt: sinceTime,
		Limit:     batchSize + 1,
	})
	if err != nil {
		return nil, fmt.Errorf("pull survey responses: %w", err)
	}

	hasMore := len(dbResponses) > int(batchSize)
	if hasMore {
		dbResponses = dbResponses[:batchSize]
	}

	responses := make([]SyncSurveyResponseRow, len(dbResponses))
	for i, r := range dbResponses {
		row := SyncSurveyResponseRow{
			ID:          r.ID,
			FormID:      r.FormID,
			FormVersion: r.FormVersion,
			VoterID:     r.VoterID,
			UserID:      r.UserID,
			Responses:   r.Responses,
			CreatedAt:   r.CreatedAt,
		}
		if r.TurfID.Valid {
			row.TurfID = uuid.UUID(r.TurfID.Bytes)
		}
		if r.ContactLogID.Valid {
			clID := uuid.UUID(r.ContactLogID.Bytes)
			row.ContactLogID = &clID
		}
		responses[i] = row
	}

	var nextCursor string
	if len(responses) > 0 {
		nextCursor = responses[len(responses)-1].CreatedAt.Format(time.RFC3339Nano)
	}

	return &PullSurveyResponsesResult{
		SurveyResponses: responses,
		NextCursor:      nextCursor,
		HasMore:         hasMore,
	}, nil
}

// GetSyncManifest returns the user's turf assignments with boundary and voter count.
func (s *SyncService) GetSyncManifest(ctx context.Context, userID uuid.UUID) ([]TurfAssignmentResult, error) {
	sqlcRows, err := s.queries.GetSyncTurfAssignments(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get sync turf assignments: %w", err)
	}

	results := make([]TurfAssignmentResult, len(sqlcRows))
	for i, row := range sqlcRows {
		var geojson string
		if s, ok := row.BoundaryGeojson.(string); ok {
			geojson = s
		}
		results[i] = TurfAssignmentResult{
			TurfID:          row.TurfID,
			TurfName:        row.TurfName,
			BoundaryGeojson: geojson,
			VoterCount:      row.VoterCount,
		}
	}

	return results, nil
}
