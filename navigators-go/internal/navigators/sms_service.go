package navigators

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	twilio "github.com/twilio/twilio-go"
	twilioApi "github.com/twilio/twilio-go/rest/api/v2010"

	"navigators-go/internal/db"
)

// SMSService provides core SMS operations: sending, conversation retrieval, and config management.
type SMSService struct {
	queries      *db.Queries
	pool         *pgxpool.Pool
	twilioClient *twilio.RestClient
	compliance   *SMSComplianceService
	auditService *AuditService
}

// NewSMSService creates a new SMSService with a Twilio client.
func NewSMSService(
	queries *db.Queries,
	pool *pgxpool.Pool,
	twilioAccountSid, twilioAuthToken string,
	compliance *SMSComplianceService,
	auditService *AuditService,
) *SMSService {
	var client *twilio.RestClient
	if twilioAccountSid != "" && twilioAuthToken != "" {
		client = twilio.NewRestClientWithParams(twilio.ClientParams{
			Username:   twilioAccountSid,
			Password:   twilioAuthToken,
			AccountSid: twilioAccountSid,
		})
	}

	return &SMSService{
		queries:      queries,
		pool:         pool,
		twilioClient: client,
		compliance:   compliance,
		auditService: auditService,
	}
}

// TwilioClient returns the underlying Twilio REST client for shared use (e.g., campaign worker).
func (s *SMSService) TwilioClient() *twilio.RestClient {
	return s.twilioClient
}

// SendP2P sends a human-initiated P2P text message to a voter.
func (s *SMSService) SendP2P(ctx context.Context, voterID uuid.UUID, body string) (*db.SmsMessage, error) {
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

	// Load SMS config
	config, err := s.queries.GetSMSConfig(ctx, companyID)
	if err != nil {
		return nil, fmt.Errorf("SMS not configured: %w", err)
	}
	if config.P2pMessagingServiceSid == "" {
		return nil, fmt.Errorf("P2P Messaging Service SID not configured")
	}

	// Compliance check (suppression + quiet hours)
	if err := s.compliance.CheckSendAllowed(ctx, voterID, companyID); err != nil {
		return nil, fmt.Errorf("compliance check: %w", err)
	}

	// Look up voter phone number
	phone, err := s.queries.GetVoterPhone(ctx, db.GetVoterPhoneParams{
		ID:        voterID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("get voter phone: %w", err)
	}
	if phone == "" {
		return nil, fmt.Errorf("voter has no phone number")
	}

	// Send via Twilio
	if s.twilioClient == nil {
		return nil, fmt.Errorf("Twilio client not configured")
	}

	statusCallbackURL := config.StatusWebhookUrl
	params := &twilioApi.CreateMessageParams{}
	params.SetMessagingServiceSid(config.P2pMessagingServiceSid)
	params.SetTo(phone)
	params.SetBody(body)
	if statusCallbackURL != "" {
		params.SetStatusCallback(statusCallbackURL)
	}

	resp, err := s.twilioClient.Api.CreateMessage(params)
	if err != nil {
		return nil, fmt.Errorf("twilio send: %w", err)
	}

	twilioSid := ""
	if resp.Sid != nil {
		twilioSid = *resp.Sid
	}

	// Insert message record
	row, err := s.queries.InsertSMSMessage(ctx, db.InsertSMSMessageParams{
		CompanyID:   companyID,
		VoterID:     voterID,
		UserID:      pgtype.UUID{Bytes: userID, Valid: true},
		CampaignID:  pgtype.UUID{Valid: false},
		Direction:   "outbound",
		MessageType: "p2p",
		FromNumber:  "", // Twilio assigns via MessagingService
		ToNumber:    phone,
		Body:        body,
		TwilioMessageSid: &twilioSid,
		Status:      "queued",
		Segments:    1,
	})
	if err != nil {
		return nil, fmt.Errorf("insert message: %w", err)
	}

	// Insert contact log for unified timeline
	if err := s.queries.InsertContactLog(ctx, db.InsertContactLogParams{
		CompanyID:   companyID,
		VoterID:     voterID,
		UserID:      userID,
		ContactType: "text",
		Notes:       fmt.Sprintf("P2P SMS: %s", truncate(body, 100)),
	}); err != nil {
		slog.Warn("failed to insert contact log for SMS", "error", err)
	}

	// Audit log
	if err := s.auditService.LogVoterAccess(ctx, voterID.String(), "sms_send", nil, map[string]any{
		"message_id":  row.ID.String(),
		"twilio_sid":  twilioSid,
		"direction":   "outbound",
		"body_length": len(body),
	}); err != nil {
		slog.Warn("failed to log SMS send audit", "error", err)
	}

	msg := &db.SmsMessage{
		ID:               row.ID,
		CompanyID:        companyID,
		VoterID:          voterID,
		UserID:           pgtype.UUID{Bytes: userID, Valid: true},
		Direction:        "outbound",
		MessageType:      "p2p",
		ToNumber:         phone,
		Body:             body,
		TwilioMessageSid: &twilioSid,
		Status:           "queued",
		Segments:         1,
		CreatedAt:        row.CreatedAt,
		UpdatedAt:        row.CreatedAt,
	}

	return msg, nil
}

// GetConversation returns the message thread for a specific voter.
func (s *SMSService) GetConversation(ctx context.Context, voterID uuid.UUID, limit, offset int32) ([]db.SmsMessage, int64, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, 0, fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, 0, fmt.Errorf("parse company ID: %w", err)
	}

	messages, err := s.queries.ListConversation(ctx, db.ListConversationParams{
		CompanyID: companyID,
		VoterID:   voterID,
		Limit:     limit,
		Offset:    offset,
	})
	if err != nil {
		return nil, 0, fmt.Errorf("list conversation: %w", err)
	}

	count, err := s.queries.CountConversationMessages(ctx, db.CountConversationMessagesParams{
		CompanyID: companyID,
		VoterID:   voterID,
	})
	if err != nil {
		return nil, 0, fmt.Errorf("count conversation: %w", err)
	}

	return messages, count, nil
}

// ListConversations returns voter summaries with the last message for the conversation list.
func (s *SMSService) ListConversations(ctx context.Context, limit, offset int32) ([]db.ListConversationVotersRow, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("parse company ID: %w", err)
	}

	rows, err := s.queries.ListConversationVoters(ctx, db.ListConversationVotersParams{
		CompanyID: companyID,
		Limit:     limit,
		Offset:    offset,
	})
	if err != nil {
		return nil, fmt.Errorf("list conversation voters: %w", err)
	}

	return rows, nil
}

// GetConfig returns the SMS configuration for the company.
func (s *SMSService) GetConfig(ctx context.Context) (*db.SmsConfig, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("parse company ID: %w", err)
	}

	config, err := s.queries.GetSMSConfig(ctx, companyID)
	if err != nil {
		return nil, fmt.Errorf("get SMS config: %w", err)
	}

	return &config, nil
}

// UpdateConfig updates the SMS configuration for the company.
func (s *SMSService) UpdateConfig(ctx context.Context, params db.UpsertSMSConfigParams) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return fmt.Errorf("parse company ID: %w", err)
	}

	params.CompanyID = companyID
	if err := s.queries.UpsertSMSConfig(ctx, params); err != nil {
		return fmt.Errorf("upsert SMS config: %w", err)
	}

	return nil
}

// truncate returns the first n characters of s, appending "..." if truncated.
func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
