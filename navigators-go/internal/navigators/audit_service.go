package navigators

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aocybersystems/eden-platform-go/platform/audit"
	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"

	"navigators-go/internal/db"
)

// AuditService provides voter access audit logging and query capabilities.
type AuditService struct {
	queries     *db.Queries
	auditLogger *audit.Logger
}

// NewAuditService creates a new AuditService.
func NewAuditService(queries *db.Queries, auditLogger *audit.Logger) *AuditService {
	return &AuditService{
		queries:     queries,
		auditLogger: auditLogger,
	}
}

// LogVoterAccess records a voter data access event.
// Call this from every voter data handler/service method.
// It writes to both the domain-specific voter_access_log table and eden's general audit logger.
func (s *AuditService) LogVoterAccess(ctx context.Context, voterID, accessType string, turfID *uuid.UUID, details map[string]any) error {
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

	detailsJSON, err := json.Marshal(details)
	if err != nil {
		detailsJSON = []byte("{}")
	}

	// Build nullable turf_id
	var pgTurfID pgtype.UUID
	if turfID != nil {
		pgTurfID = pgtype.UUID{Bytes: *turfID, Valid: true}
	}

	// Write to voter_access_log table (detailed, domain-specific)
	err = s.queries.LogVoterAccess(ctx, db.LogVoterAccessParams{
		CompanyID:  companyID,
		UserID:     userID,
		VoterID:    voterID,
		AccessType: accessType,
		TurfID:     pgTurfID,
		Details:    detailsJSON,
		IpAddress:  extractIPFromContext(ctx),
	})
	if err != nil {
		return fmt.Errorf("log voter access: %w", err)
	}

	// Also log to eden's audit logger (general audit trail)
	auditDetails := details
	if auditDetails == nil {
		auditDetails = map[string]any{}
	}
	if turfID != nil {
		auditDetails["turf_id"] = turfID.String()
	}
	auditDetails["access_type"] = accessType

	s.auditLogger.Log(audit.Event{
		CompanyID:  claims.CompanyID,
		ActorID:    claims.UserID,
		Action:     "voter." + accessType,
		Resource:   "voter",
		ResourceID: voterID,
		Details:    auditDetails,
		IPAddress:  extractIPFromContext(ctx),
	})

	return nil
}

// ListAuditLogs returns paginated voter access audit logs for admin viewing.
func (s *AuditService) ListAuditLogs(ctx context.Context, limit, offset int32) ([]db.ListVoterAccessLogsRow, int64, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, 0, fmt.Errorf("no claims in context")
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, 0, fmt.Errorf("parse company ID: %w", err)
	}

	logs, err := s.queries.ListVoterAccessLogs(ctx, db.ListVoterAccessLogsParams{
		CompanyID: companyID,
		Limit:     limit,
		Offset:    offset,
	})
	if err != nil {
		return nil, 0, fmt.Errorf("list voter access logs: %w", err)
	}

	count, err := s.queries.CountVoterAccessLogs(ctx, companyID)
	if err != nil {
		return nil, 0, fmt.Errorf("count voter access logs: %w", err)
	}

	return logs, count, nil
}

// extractIPFromContext extracts the client IP address from request headers in context.
func extractIPFromContext(ctx context.Context) string {
	// ConnectRPC doesn't directly expose headers in context the same way;
	// the audit interceptor uses req.Header().Get("X-Forwarded-For").
	// For service-level calls, we return empty and let the interceptor handle it.
	return ""
}
