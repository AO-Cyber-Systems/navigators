package navigators

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"

	"navigators-go/internal/db"
)

// SMSComplianceService enforces SMS sending rules: suppression checks,
// quiet hours, and opt-out processing.
type SMSComplianceService struct {
	queries            *db.Queries
	suppressionService *SuppressionService
}

// NewSMSComplianceService creates a new SMSComplianceService.
func NewSMSComplianceService(queries *db.Queries, suppressionService *SuppressionService) *SMSComplianceService {
	return &SMSComplianceService{
		queries:            queries,
		suppressionService: suppressionService,
	}
}

// CheckSendAllowed verifies that an SMS can be sent to the voter.
// Checks suppression list (fail-closed) and quiet hours.
func (c *SMSComplianceService) CheckSendAllowed(ctx context.Context, voterID, companyID uuid.UUID) error {
	// Check suppression list (fail-closed: returns true on error)
	suppressed, err := c.suppressionService.IsVoterSuppressed(ctx, voterID)
	if err != nil {
		return fmt.Errorf("suppression check failed (fail-closed): %w", err)
	}
	if suppressed {
		return fmt.Errorf("voter is on suppression list")
	}

	// Check quiet hours using company config
	config, err := c.queries.GetSMSConfig(ctx, companyID)
	if err != nil {
		// If no config, can't send
		return fmt.Errorf("SMS not configured for company: %w", err)
	}

	if c.checkQuietHours(config.QuietHoursStart, config.QuietHoursEnd) {
		return fmt.Errorf("quiet hours: SMS cannot be sent between %d:00 and %d:00 Eastern", config.QuietHoursStart, config.QuietHoursEnd)
	}

	return nil
}

// checkQuietHours returns true if the current time (Eastern) is within quiet hours.
// All Maine recipients are Eastern Time, simplifying timezone logic for v1.
func (c *SMSComplianceService) checkQuietHours(start, end int32) bool {
	loc, err := time.LoadLocation("America/New_York")
	if err != nil {
		// If we can't load timezone, fail closed (block sending)
		slog.Error("failed to load America/New_York timezone, blocking send", "error", err)
		return true
	}

	now := time.Now().In(loc)
	return isQuietHours(now, int(start), int(end))
}

// isQuietHours checks if the given time falls within quiet hours.
// start=21 means 9PM, end=8 means 8AM. Quiet if hour >= start OR hour < end (wrapping midnight).
func isQuietHours(now time.Time, start, end int) bool {
	hour := now.Hour()
	// Wrapping midnight: quiet if hour >= start (e.g., 21) OR hour < end (e.g., 8)
	if start > end {
		return hour >= start || hour < end
	}
	// Non-wrapping: quiet if hour >= start AND hour < end
	return hour >= start && hour < end
}

// ProcessOptOut handles opt-out (STOP) and opt-in (START) keyword processing.
// Called from the NATS worker (no authenticated user context), so we call
// the query directly rather than going through SuppressionService which requires claims.
func (c *SMSComplianceService) ProcessOptOut(ctx context.Context, companyID, voterID uuid.UUID, optOutType string) error {
	switch optOutType {
	case "STOP":
		// Look up a company admin user for the added_by FK (suppression_list requires a valid user reference).
		adminUserID, err := c.queries.GetCompanyAdminUserID(ctx, companyID)
		if err != nil {
			return fmt.Errorf("find admin user for opt-out processing: %w", err)
		}
		err = c.queries.AddToSuppressionList(ctx, db.AddToSuppressionListParams{
			CompanyID: companyID,
			VoterID:   voterID,
			Reason:    "SMS opt-out (STOP keyword)",
			AddedBy:   adminUserID,
		})
		if err != nil {
			return fmt.Errorf("add to suppression list: %w", err)
		}
		slog.Info("voter opted out via STOP", "voter_id", voterID, "company_id", companyID)

	case "START":
		err := c.queries.RemoveFromSuppressionList(ctx, db.RemoveFromSuppressionListParams{
			CompanyID: companyID,
			VoterID:   voterID,
		})
		if err != nil {
			return fmt.Errorf("remove from suppression list: %w", err)
		}
		slog.Info("voter opted in via START", "voter_id", voterID, "company_id", companyID)

	default:
		// HELP or empty -- no action needed
	}

	return nil
}
