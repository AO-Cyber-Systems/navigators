package navigators

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"navigators-go/internal/db"
)

// CallScriptService provides call script CRUD operations.
type CallScriptService struct {
	queries *db.Queries
	pool    *pgxpool.Pool
}

// NewCallScriptService creates a new CallScriptService.
func NewCallScriptService(queries *db.Queries, pool *pgxpool.Pool) *CallScriptService {
	return &CallScriptService{
		queries: queries,
		pool:    pool,
	}
}

// CreateCallScript creates a new call script.
func (s *CallScriptService) CreateCallScript(ctx context.Context, companyID, userID uuid.UUID, title, content string) (*db.CallScript, error) {
	script, err := s.queries.CreateCallScript(ctx, db.CreateCallScriptParams{
		CompanyID: companyID,
		Title:     title,
		Content:   content,
		Version:   1,
		IsActive:  true,
		CreatedBy: userID,
	})
	if err != nil {
		return nil, fmt.Errorf("create call script: %w", err)
	}
	return &script, nil
}

// ListActiveCallScripts returns active call scripts for a company.
func (s *CallScriptService) ListActiveCallScripts(ctx context.Context, companyID uuid.UUID) ([]db.CallScript, error) {
	scripts, err := s.queries.ListActiveCallScripts(ctx, companyID)
	if err != nil {
		return nil, fmt.Errorf("list active call scripts: %w", err)
	}
	return scripts, nil
}

// UpdateCallScript updates a call script's fields.
func (s *CallScriptService) UpdateCallScript(ctx context.Context, companyID, id uuid.UUID, title, content string, version int32, isActive bool) error {
	err := s.queries.UpdateCallScript(ctx, db.UpdateCallScriptParams{
		ID:        id,
		CompanyID: companyID,
		Title:     title,
		Content:   content,
		Version:   version,
		IsActive:  isActive,
	})
	if err != nil {
		return fmt.Errorf("update call script: %w", err)
	}
	return nil
}

// UpdateCallScriptFields fetches the current version, increments it, writes the
// new title/content/is_active, and returns the updated row. Optimistic
// concurrency control is out of scope for v1 -- version is incremented
// server-side on every admin edit.
func (s *CallScriptService) UpdateCallScriptFields(ctx context.Context, companyID, id uuid.UUID, title, content string, isActive bool) (*db.CallScript, error) {
	currentVersion, err := s.queries.GetCallScriptCurrentVersion(ctx, db.GetCallScriptCurrentVersionParams{
		ID:        id,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("get current version: %w", err)
	}
	if err := s.queries.UpdateCallScript(ctx, db.UpdateCallScriptParams{
		ID:        id,
		CompanyID: companyID,
		Title:     title,
		Content:   content,
		Version:   currentVersion + 1,
		IsActive:  isActive,
	}); err != nil {
		return nil, fmt.Errorf("update call script: %w", err)
	}
	script, err := s.queries.GetCallScript(ctx, db.GetCallScriptParams{
		ID:        id,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("re-fetch call script: %w", err)
	}
	return &script, nil
}

// DeactivateCallScript soft-deletes a call script by setting is_active=false.
// The updated_at bump is what propagates the change to offline clients via
// PullCallScriptsUpdated.
func (s *CallScriptService) DeactivateCallScript(ctx context.Context, companyID, id uuid.UUID) error {
	if err := s.queries.DeactivateCallScript(ctx, db.DeactivateCallScriptParams{
		ID:        id,
		CompanyID: companyID,
	}); err != nil {
		return fmt.Errorf("deactivate call script: %w", err)
	}
	return nil
}

// ListAllCallScripts returns every script for a company (active + inactive),
// ordered by most recently updated. Intended for the admin management UI.
func (s *CallScriptService) ListAllCallScripts(ctx context.Context, companyID uuid.UUID) ([]db.CallScript, error) {
	scripts, err := s.queries.ListAllCallScripts(ctx, companyID)
	if err != nil {
		return nil, fmt.Errorf("list all call scripts: %w", err)
	}
	return scripts, nil
}
