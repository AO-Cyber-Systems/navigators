package navigators

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/nats-io/nats.go/jetstream"

	"navigators-go/internal/db"
)

const (
	// smsCampaignSendSubject is the NATS subject for campaign send jobs.
	smsCampaignSendSubject = "navigators.sms.campaign.send"
	// campaignPublishBatchSize is the number of send jobs published per NATS batch.
	campaignPublishBatchSize = 100
)

// CampaignSendJob represents a single voter send job published to NATS for async processing.
type CampaignSendJob struct {
	CampaignID uuid.UUID `json:"campaign_id"`
	VoterID    uuid.UUID `json:"voter_id"`
	CompanyID  uuid.UUID `json:"company_id"`
	TemplateID uuid.UUID `json:"template_id"`
}

// SMSCampaignService manages SMS broadcast campaigns with A2P sending.
type SMSCampaignService struct {
	queries         *db.Queries
	pool            *pgxpool.Pool
	js              jetstream.JetStream
	templateService *SMSTemplateService
	compliance      *SMSComplianceService
}

// NewSMSCampaignService creates a new SMSCampaignService.
func NewSMSCampaignService(
	queries *db.Queries,
	pool *pgxpool.Pool,
	js jetstream.JetStream,
	templateService *SMSTemplateService,
	compliance *SMSComplianceService,
) *SMSCampaignService {
	return &SMSCampaignService{
		queries:         queries,
		pool:            pool,
		js:              js,
		templateService: templateService,
		compliance:      compliance,
	}
}

// CreateCampaign creates a new campaign in 'draft' status.
func (s *SMSCampaignService) CreateCampaign(ctx context.Context, name string, templateID uuid.UUID, segmentFilters json.RawMessage) (*db.SmsCampaign, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("parse company ID: %w", err)
	}
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, fmt.Errorf("parse user ID: %w", err)
	}

	// Validate template exists and is active
	tmpl, err := s.queries.GetSMSTemplate(ctx, db.GetSMSTemplateParams{
		ID:        templateID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("template not found: %w", err)
	}
	if !tmpl.IsActive {
		return nil, fmt.Errorf("template is not active")
	}

	// Default segment filters to empty JSON object if nil
	if segmentFilters == nil {
		segmentFilters = json.RawMessage(`{}`)
	}

	row, err := s.queries.CreateSMSCampaign(ctx, db.CreateSMSCampaignParams{
		CompanyID:      companyID,
		Name:           name,
		TemplateID:     pgtype.UUID{Bytes: templateID, Valid: true},
		SegmentFilters: segmentFilters,
		CreatedBy:      userID,
	})
	if err != nil {
		return nil, fmt.Errorf("create campaign: %w", err)
	}

	return &db.SmsCampaign{
		ID:             row.ID,
		CompanyID:      companyID,
		Name:           name,
		TemplateID:     pgtype.UUID{Bytes: templateID, Valid: true},
		SegmentFilters: segmentFilters,
		Status:         "draft",
		CreatedBy:      userID,
		CreatedAt:      row.CreatedAt,
		UpdatedAt:      row.CreatedAt,
	}, nil
}

// LaunchCampaign launches a draft campaign by checking 10DLC status,
// counting target voters, updating the campaign status, and publishing send jobs to NATS.
func (s *SMSCampaignService) LaunchCampaign(ctx context.Context, campaignID uuid.UUID) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return fmt.Errorf("parse company ID: %w", err)
	}

	// Load campaign, verify status == 'draft'
	campaign, err := s.queries.GetSMSCampaign(ctx, db.GetSMSCampaignParams{
		ID:        campaignID,
		CompanyID: companyID,
	})
	if err != nil {
		return fmt.Errorf("get campaign: %w", err)
	}
	if campaign.Status != "draft" {
		return fmt.Errorf("campaign status must be 'draft' to launch, currently '%s'", campaign.Status)
	}

	// Load SMS config, CHECK ten_dlc_status == 'approved'
	config, err := s.queries.GetSMSConfig(ctx, companyID)
	if err != nil {
		return fmt.Errorf("SMS not configured: %w", err)
	}
	if config.TenDlcStatus != "approved" {
		return fmt.Errorf("A2P messaging requires 10DLC approval (current status: %s)", config.TenDlcStatus)
	}
	if config.A2pMessagingServiceSid == "" {
		return fmt.Errorf("A2P Messaging Service SID not configured")
	}

	// Get template ID
	templateID := uuid.UUID(campaign.TemplateID.Bytes)

	// Count voters matching segment (simplified: all voters with phones in company).
	// Full segment filtering by district/party/tags will use segment_filters JSONB
	// with raw SQL in a future iteration. For v1, we use a simplified approach.
	voterCount, err := s.queries.CountCampaignVoterTargets(ctx, companyID)
	if err != nil {
		return fmt.Errorf("count target voters: %w", err)
	}
	if voterCount == 0 {
		return fmt.Errorf("no voters match the target segment")
	}

	// Update campaign: total_recipients, status='sending', launched_at=now()
	if err := s.queries.UpdateCampaignTotalRecipients(ctx, db.UpdateCampaignTotalRecipientsParams{
		ID:              campaignID,
		TotalRecipients: int32(voterCount),
	}); err != nil {
		return fmt.Errorf("update total recipients: %w", err)
	}

	if err := s.queries.UpdateCampaignStatus(ctx, db.UpdateCampaignStatusParams{
		ID:        campaignID,
		CompanyID: companyID,
		Status:    "sending",
	}); err != nil {
		return fmt.Errorf("update campaign status: %w", err)
	}

	// Publish send jobs to NATS in batches
	var offset int32
	batchSize := int32(campaignPublishBatchSize)
	totalPublished := 0

	for {
		voters, err := s.queries.GetCampaignVoterTargets(ctx, db.GetCampaignVoterTargetsParams{
			CompanyID: companyID,
			Limit:     batchSize,
			Offset:    offset,
		})
		if err != nil {
			return fmt.Errorf("get voter targets batch: %w", err)
		}
		if len(voters) == 0 {
			break
		}

		for _, voter := range voters {
			job := CampaignSendJob{
				CampaignID: campaignID,
				VoterID:    voter.ID,
				CompanyID:  companyID,
				TemplateID: templateID,
			}

			data, err := json.Marshal(job)
			if err != nil {
				slog.Error("failed to marshal campaign send job", "error", err, "voter_id", voter.ID)
				continue
			}

			if _, err := s.js.Publish(ctx, smsCampaignSendSubject, data); err != nil {
				slog.Error("failed to publish campaign send job", "error", err, "voter_id", voter.ID)
				// Continue publishing remaining jobs; individual failures are tracked
				continue
			}
			totalPublished++
		}

		offset += int32(len(voters))
		if len(voters) < int(batchSize) {
			break
		}
	}

	slog.Info("campaign launched", "campaign_id", campaignID, "total_published", totalPublished)
	return nil
}

// PauseCampaign sets campaign status to 'paused'. Worker checks status before each send.
func (s *SMSCampaignService) PauseCampaign(ctx context.Context, campaignID uuid.UUID) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return fmt.Errorf("parse company ID: %w", err)
	}

	campaign, err := s.queries.GetSMSCampaign(ctx, db.GetSMSCampaignParams{
		ID:        campaignID,
		CompanyID: companyID,
	})
	if err != nil {
		return fmt.Errorf("get campaign: %w", err)
	}
	if campaign.Status != "sending" {
		return fmt.Errorf("can only pause a campaign that is 'sending', currently '%s'", campaign.Status)
	}

	return s.queries.UpdateCampaignStatus(ctx, db.UpdateCampaignStatusParams{
		ID:        campaignID,
		CompanyID: companyID,
		Status:    "paused",
	})
}

// CancelCampaign sets campaign status to 'cancelled'.
func (s *SMSCampaignService) CancelCampaign(ctx context.Context, campaignID uuid.UUID) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return fmt.Errorf("parse company ID: %w", err)
	}

	return s.queries.UpdateCampaignStatus(ctx, db.UpdateCampaignStatusParams{
		ID:        campaignID,
		CompanyID: companyID,
		Status:    "cancelled",
	})
}

// GetCampaign returns a campaign by ID.
func (s *SMSCampaignService) GetCampaign(ctx context.Context, campaignID uuid.UUID) (*db.SmsCampaign, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("parse company ID: %w", err)
	}

	campaign, err := s.queries.GetSMSCampaign(ctx, db.GetSMSCampaignParams{
		ID:        campaignID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("get campaign: %w", err)
	}
	return &campaign, nil
}

// ListCampaigns returns campaigns for the company with pagination.
func (s *SMSCampaignService) ListCampaigns(ctx context.Context, limit, offset int32) ([]db.SmsCampaign, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("parse company ID: %w", err)
	}

	return s.queries.ListSMSCampaigns(ctx, db.ListSMSCampaignsParams{
		CompanyID: companyID,
		Limit:     limit,
		Offset:    offset,
	})
}

// Get10DLCStatus returns the 10DLC registration status from sms_config.
func (s *SMSCampaignService) Get10DLCStatus(ctx context.Context) (string, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return "", fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return "", fmt.Errorf("parse company ID: %w", err)
	}

	config, err := s.queries.GetSMSConfig(ctx, companyID)
	if err != nil {
		return "", fmt.Errorf("get SMS config: %w", err)
	}

	return config.TenDlcStatus, nil
}

// Update10DLCStatus updates the 10DLC registration status (admin updates after checking Twilio dashboard).
func (s *SMSCampaignService) Update10DLCStatus(ctx context.Context, brandSid, campaignSid, status string) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return fmt.Errorf("parse company ID: %w", err)
	}

	// Load existing config, update the 10DLC fields
	config, err := s.queries.GetSMSConfig(ctx, companyID)
	if err != nil {
		return fmt.Errorf("get SMS config: %w", err)
	}

	return s.queries.UpsertSMSConfig(ctx, db.UpsertSMSConfigParams{
		CompanyID:                companyID,
		TwilioAccountSid:         config.TwilioAccountSid,
		TwilioAuthTokenEncrypted: config.TwilioAuthTokenEncrypted,
		P2pMessagingServiceSid:   config.P2pMessagingServiceSid,
		A2pMessagingServiceSid:   config.A2pMessagingServiceSid,
		InboundWebhookUrl:        config.InboundWebhookUrl,
		StatusWebhookUrl:         config.StatusWebhookUrl,
		QuietHoursStart:          config.QuietHoursStart,
		QuietHoursEnd:            config.QuietHoursEnd,
		TenDlcBrandSid:           brandSid,
		TenDlcCampaignSid:        campaignSid,
		TenDlcStatus:             status,
	})
}
