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

// SurveyService provides survey form CRUD and response processing.
type SurveyService struct {
	queries *db.Queries
	pool    *pgxpool.Pool
}

// NewSurveyService creates a new SurveyService.
func NewSurveyService(queries *db.Queries, pool *pgxpool.Pool) *SurveyService {
	return &SurveyService{
		queries: queries,
		pool:    pool,
	}
}

// CreateSurveyForm creates a new survey form.
func (s *SurveyService) CreateSurveyForm(ctx context.Context, companyID, userID uuid.UUID, title, description string, schema json.RawMessage) (*db.SurveyForm, error) {
	form, err := s.queries.CreateSurveyForm(ctx, db.CreateSurveyFormParams{
		CompanyID:   companyID,
		Title:       title,
		Description: description,
		Schema:      schema,
		Version:     1,
		IsActive:    true,
		CreatedBy:   userID,
	})
	if err != nil {
		return nil, fmt.Errorf("create survey form: %w", err)
	}
	return &form, nil
}

// ListActiveForms returns active survey forms for a company.
func (s *SurveyService) ListActiveForms(ctx context.Context, companyID uuid.UUID) ([]db.SurveyForm, error) {
	forms, err := s.queries.ListActiveSurveyForms(ctx, companyID)
	if err != nil {
		return nil, fmt.Errorf("list active survey forms: %w", err)
	}
	return forms, nil
}

// surveyResponsePayload is the JSON structure for survey response push operations.
type surveyResponsePayload struct {
	ID           string `json:"id"`
	FormID       string `json:"form_id"`
	FormVersion  int32  `json:"form_version"`
	VoterID      string `json:"voter_id"`
	UserID       string `json:"user_id"`
	TurfID       string `json:"turf_id"`
	ContactLogID string `json:"contact_log_id"`
	Responses    string `json:"responses"`
	CreatedAt    string `json:"created_at"`
}

// ProcessSurveyResponse processes a survey response from a client push.
func (s *SurveyService) ProcessSurveyResponse(ctx context.Context, companyID, userID uuid.UUID, op SyncOperationInput) error {
	var payload surveyResponsePayload
	if err := json.Unmarshal(op.Payload, &payload); err != nil {
		return fmt.Errorf("unmarshal survey response payload: %w", err)
	}

	srID, err := uuid.Parse(payload.ID)
	if err != nil {
		srID, err = uuid.Parse(op.EntityID)
		if err != nil {
			return fmt.Errorf("parse survey response ID: %w", err)
		}
	}

	formID, err := uuid.Parse(payload.FormID)
	if err != nil {
		return fmt.Errorf("parse form ID: %w", err)
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

	var contactLogID pgtype.UUID
	if payload.ContactLogID != "" {
		parsed, err := uuid.Parse(payload.ContactLogID)
		if err != nil {
			return fmt.Errorf("parse contact log ID: %w", err)
		}
		contactLogID = pgtype.UUID{Bytes: parsed, Valid: true}
	}

	// Parse responses JSON into json.RawMessage
	var responses json.RawMessage
	if payload.Responses != "" {
		responses = json.RawMessage(payload.Responses)
	} else {
		responses = json.RawMessage("{}")
	}

	createdAt := time.Now()
	if payload.CreatedAt != "" {
		if parsed, err := time.Parse(time.RFC3339, payload.CreatedAt); err == nil {
			createdAt = parsed
		}
	}

	return s.queries.UpsertSurveyResponseFromSync(ctx, db.UpsertSurveyResponseFromSyncParams{
		ID:           srID,
		CompanyID:    companyID,
		FormID:       formID,
		FormVersion:  payload.FormVersion,
		VoterID:      voterID,
		UserID:       userID,
		TurfID:       turfID,
		ContactLogID: contactLogID,
		Responses:    responses,
		CreatedAt:    createdAt,
	})
}
