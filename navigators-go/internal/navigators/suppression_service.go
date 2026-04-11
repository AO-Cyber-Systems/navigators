package navigators

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"

	"navigators-go/internal/db"
)

// SuppressionService manages the global voter suppression list.
// Suppressed voters are excluded from outreach operations.
type SuppressionService struct {
	queries      *db.Queries
	auditService *AuditService
}

// NewSuppressionService creates a new SuppressionService.
func NewSuppressionService(queries *db.Queries, auditService *AuditService) *SuppressionService {
	return &SuppressionService{
		queries:      queries,
		auditService: auditService,
	}
}

// AddToSuppressionList adds a voter to the suppression list.
// Requires admin permission (enforced at handler level via RBAC).
func (s *SuppressionService) AddToSuppressionList(ctx context.Context, voterID uuid.UUID, reason string) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return fmt.Errorf("parse company ID: %w", err)
	}
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return fmt.Errorf("parse user ID: %w", err)
	}

	err = s.queries.AddToSuppressionList(ctx, db.AddToSuppressionListParams{
		CompanyID: companyID,
		VoterID:   voterID,
		Reason:    reason,
		AddedBy:   userID,
	})
	if err != nil {
		return fmt.Errorf("add to suppression list: %w", err)
	}

	// Audit log
	if err := s.auditService.LogVoterAccess(ctx, voterID.String(), "suppress", nil, map[string]any{
		"reason": reason,
	}); err != nil {
		slog.Warn("failed to log suppression audit", "error", err)
	}

	return nil
}

// RemoveFromSuppressionList removes a voter from the suppression list.
// Requires admin permission (enforced at handler level via RBAC).
func (s *SuppressionService) RemoveFromSuppressionList(ctx context.Context, voterID uuid.UUID) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return fmt.Errorf("parse company ID: %w", err)
	}

	err = s.queries.RemoveFromSuppressionList(ctx, db.RemoveFromSuppressionListParams{
		CompanyID: companyID,
		VoterID:   voterID,
	})
	if err != nil {
		return fmt.Errorf("remove from suppression list: %w", err)
	}

	// Audit log
	if err := s.auditService.LogVoterAccess(ctx, voterID.String(), "unsuppress", nil, nil); err != nil {
		slog.Warn("failed to log unsuppression audit", "error", err)
	}

	return nil
}

// IsVoterSuppressed checks if a voter is on the suppression list.
// This is the gating function used before any outreach operation.
// FAIL-CLOSED: if the check errors, returns true (suppressed) to prevent outreach.
func (s *SuppressionService) IsVoterSuppressed(ctx context.Context, voterID uuid.UUID) (bool, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return true, fmt.Errorf("no claims in context")
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return true, fmt.Errorf("parse company ID: %w", err)
	}

	suppressed, err := s.queries.IsVoterSuppressed(ctx, db.IsVoterSuppressedParams{
		CompanyID: companyID,
		VoterID:   voterID,
	})
	if err != nil {
		// FAIL CLOSED: if we can't check, assume suppressed
		slog.Error("suppression check failed, failing closed", "voter_id", voterID, "error", err)
		return true, fmt.Errorf("suppression check: %w", err)
	}

	return suppressed, nil
}

// ListSuppressedVoters returns a paginated list of suppressed voters with voter details.
func (s *SuppressionService) ListSuppressedVoters(ctx context.Context, limit, offset int32) ([]db.ListSuppressedVotersRow, int64, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, 0, fmt.Errorf("no claims in context")
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, 0, fmt.Errorf("parse company ID: %w", err)
	}

	rows, err := s.queries.ListSuppressedVoters(ctx, db.ListSuppressedVotersParams{
		CompanyID: companyID,
		Limit:     limit,
		Offset:    offset,
	})
	if err != nil {
		return nil, 0, fmt.Errorf("list suppressed voters: %w", err)
	}

	count, err := s.queries.CountSuppressedVoters(ctx, companyID)
	if err != nil {
		return nil, 0, fmt.Errorf("count suppressed voters: %w", err)
	}

	return rows, count, nil
}
