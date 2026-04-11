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
