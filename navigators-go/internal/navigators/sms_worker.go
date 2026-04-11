package navigators

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/nats-io/nats.go/jetstream"
	twilio "github.com/twilio/twilio-go"
	twilioApi "github.com/twilio/twilio-go/rest/api/v2010"
	"golang.org/x/time/rate"

	"navigators-go/internal/db"
)

const (
	smsStreamName        = "NAVIGATORS_SMS"
	smsInboundSubject    = "navigators.sms.inbound"
	smsStatusSubject     = "navigators.sms.status"
	smsCampaignSubject   = "navigators.sms.campaign.send"
	smsInboundConsumer   = "sms-inbound-worker"
	smsStatusConsumer    = "sms-status-worker"
	smsCampaignConsumer  = "sms-campaign-worker"
)

// SMSWorker processes SMS events from NATS JetStream.
type SMSWorker struct {
	js              jetstream.JetStream
	queries         *db.Queries
	pool            *pgxpool.Pool
	compliance      *SMSComplianceService
	templateService *SMSTemplateService
	twilioClient    *twilio.RestClient
	rateLimiter     *rate.Limiter
	cancel          context.CancelFunc
}

// NewSMSWorker creates a new SMSWorker.
func NewSMSWorker(
	js jetstream.JetStream,
	queries *db.Queries,
	pool *pgxpool.Pool,
	compliance *SMSComplianceService,
	templateService *SMSTemplateService,
	twilioClient *twilio.RestClient,
) *SMSWorker {
	return &SMSWorker{
		js:              js,
		queries:         queries,
		pool:            pool,
		compliance:      compliance,
		templateService: templateService,
		twilioClient:    twilioClient,
		rateLimiter:     rate.NewLimiter(rate.Limit(1), 1), // 1 msg/sec conservative default
	}
}

// Start initializes the JetStream stream and consumers, then starts processing goroutines.
func (w *SMSWorker) Start(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	w.cancel = cancel

	// Create or update the SMS stream
	_, err := w.js.CreateOrUpdateStream(ctx, jetstream.StreamConfig{
		Name:     smsStreamName,
		Subjects: []string{"navigators.sms.>"},
		Storage:  jetstream.FileStorage,
	})
	if err != nil {
		return fmt.Errorf("create SMS stream: %w", err)
	}
	slog.Info("NATS JetStream SMS stream ready", "stream", smsStreamName)

	// Create durable consumers
	inboundCons, err := w.js.CreateOrUpdateConsumer(ctx, smsStreamName, jetstream.ConsumerConfig{
		Durable:        smsInboundConsumer,
		FilterSubjects: []string{smsInboundSubject},
		AckPolicy:      jetstream.AckExplicitPolicy,
	})
	if err != nil {
		return fmt.Errorf("create inbound consumer: %w", err)
	}

	statusCons, err := w.js.CreateOrUpdateConsumer(ctx, smsStreamName, jetstream.ConsumerConfig{
		Durable:        smsStatusConsumer,
		FilterSubjects: []string{smsStatusSubject},
		AckPolicy:      jetstream.AckExplicitPolicy,
	})
	if err != nil {
		return fmt.Errorf("create status consumer: %w", err)
	}

	campaignCons, err := w.js.CreateOrUpdateConsumer(ctx, smsStreamName, jetstream.ConsumerConfig{
		Durable:        smsCampaignConsumer,
		FilterSubjects: []string{smsCampaignSubject},
		AckPolicy:      jetstream.AckExplicitPolicy,
	})
	if err != nil {
		return fmt.Errorf("create campaign consumer: %w", err)
	}

	// Start consuming in goroutines using the callback-based Consume API
	go w.consumeInbound(ctx, inboundCons)
	go w.consumeStatus(ctx, statusCons)
	go w.consumeCampaign(ctx, campaignCons)

	slog.Info("SMS NATS workers started", "consumers", 3)
	return nil
}

// Stop cancels the worker context.
func (w *SMSWorker) Stop() {
	if w.cancel != nil {
		w.cancel()
	}
}

func (w *SMSWorker) consumeInbound(ctx context.Context, cons jetstream.Consumer) {
	cc, err := cons.Consume(func(msg jetstream.Msg) {
		if err := w.processInbound(ctx, msg); err != nil {
			slog.Error("failed to process inbound SMS", "error", err)
			// NAK to trigger redelivery
			if nakErr := msg.Nak(); nakErr != nil {
				slog.Error("failed to NAK inbound message", "error", nakErr)
			}
			return
		}
		if err := msg.Ack(); err != nil {
			slog.Error("failed to ACK inbound message", "error", err)
		}
	})
	if err != nil {
		slog.Error("failed to start inbound consumer", "error", err)
		return
	}

	<-ctx.Done()
	cc.Stop()
}

func (w *SMSWorker) consumeStatus(ctx context.Context, cons jetstream.Consumer) {
	cc, err := cons.Consume(func(msg jetstream.Msg) {
		if err := w.processStatus(ctx, msg); err != nil {
			slog.Error("failed to process status update", "error", err)
			if nakErr := msg.Nak(); nakErr != nil {
				slog.Error("failed to NAK status message", "error", nakErr)
			}
			return
		}
		if err := msg.Ack(); err != nil {
			slog.Error("failed to ACK status message", "error", err)
		}
	})
	if err != nil {
		slog.Error("failed to start status consumer", "error", err)
		return
	}

	<-ctx.Done()
	cc.Stop()
}

func (w *SMSWorker) consumeCampaign(ctx context.Context, cons jetstream.Consumer) {
	cc, err := cons.Consume(func(msg jetstream.Msg) {
		if err := w.processCampaignSend(ctx, msg); err != nil {
			slog.Error("failed to process campaign send", "error", err)
			if nakErr := msg.Nak(); nakErr != nil {
				slog.Error("failed to NAK campaign message", "error", nakErr)
			}
			return
		}
		if err := msg.Ack(); err != nil {
			slog.Error("failed to ACK campaign message", "error", err)
		}
	})
	if err != nil {
		slog.Error("failed to start campaign consumer", "error", err)
		return
	}

	<-ctx.Done()
	cc.Stop()
}

func (w *SMSWorker) processInbound(ctx context.Context, msg jetstream.Msg) error {
	var event InboundSMSEvent
	if err := json.Unmarshal(msg.Data(), &event); err != nil {
		return fmt.Errorf("unmarshal inbound event: %w", err)
	}

	slog.Info("processing inbound SMS", "message_sid", event.MessageSid, "from", event.From, "opt_out_type", event.OptOutType)

	// Normalize phone number for lookup (strip leading +1 for US numbers)
	phone := normalizePhone(event.From)

	// We need to find the company and voter by phone number.
	// For v1 with single company (MaineGOP), we use the known company ID.
	// In a multi-tenant setup, we'd look up by MessagingServiceSid -> company mapping.
	companyID := MaineGOPCompanyID

	// Look up voter by phone number
	voterRow, err := w.queries.GetVoterByPhone(ctx, db.GetVoterByPhoneParams{
		Phone:     phone,
		CompanyID: companyID,
	})
	if err != nil {
		// Try with original format
		voterRow, err = w.queries.GetVoterByPhone(ctx, db.GetVoterByPhoneParams{
			Phone:     event.From,
			CompanyID: companyID,
		})
		if err != nil {
			slog.Warn("inbound SMS from unknown number", "from", event.From, "message_sid", event.MessageSid)
			// Still process opt-out even if voter not found in our DB
			// (Twilio handles carrier-level STOP; we log the attempt)
			return nil
		}
	}

	// Insert message (idempotent on twilio_message_sid)
	sid := event.MessageSid
	err = w.queries.InsertSMSMessageIdempotent(ctx, db.InsertSMSMessageIdempotentParams{
		CompanyID:        companyID,
		VoterID:          voterRow.ID,
		UserID:           pgtype.UUID{Valid: false},
		CampaignID:       pgtype.UUID{Valid: false},
		Direction:        "inbound",
		MessageType:      "p2p",
		FromNumber:       event.From,
		ToNumber:         event.To,
		Body:             event.Body,
		TwilioMessageSid: &sid,
		Status:           "received",
		Segments:         1,
	})
	if err != nil {
		return fmt.Errorf("insert inbound message: %w", err)
	}

	// Process opt-out/opt-in keywords
	if event.OptOutType == "STOP" || event.OptOutType == "START" {
		if err := w.compliance.ProcessOptOut(ctx, companyID, voterRow.ID, event.OptOutType); err != nil {
			slog.Error("failed to process opt-out", "error", err, "voter_id", voterRow.ID, "opt_out_type", event.OptOutType)
			// Don't fail the message processing -- suppression update failed but message was stored
		}
	}

	return nil
}

func (w *SMSWorker) processStatus(ctx context.Context, msg jetstream.Msg) error {
	var event StatusUpdateEvent
	if err := json.Unmarshal(msg.Data(), &event); err != nil {
		return fmt.Errorf("unmarshal status event: %w", err)
	}

	slog.Info("processing status update", "message_sid", event.MessageSid, "status", event.MessageStatus)

	// Update message status
	sid := event.MessageSid
	err := w.queries.UpdateSMSMessageStatus(ctx, db.UpdateSMSMessageStatusParams{
		TwilioMessageSid: &sid,
		Status:           event.MessageStatus,
		ErrorCode:        event.ErrorCode,
	})
	if err != nil {
		return fmt.Errorf("update message status: %w", err)
	}

	// If message has a campaign_id, increment the appropriate counter
	campaignID, err := w.queries.GetSMSMessageCampaignID(ctx, &sid)
	if err != nil {
		// Message might not exist yet or has no campaign -- not an error
		return nil
	}
	if campaignID.Valid {
		cid := uuid.UUID(campaignID.Bytes)
		switch event.MessageStatus {
		case "delivered":
			if err := w.queries.IncrementCampaignDeliveredCount(ctx, cid); err != nil {
				slog.Warn("failed to increment campaign delivered count", "error", err, "campaign_id", cid)
			}
		case "failed", "undelivered":
			if err := w.queries.IncrementCampaignFailedCount(ctx, cid); err != nil {
				slog.Warn("failed to increment campaign failed count", "error", err, "campaign_id", cid)
			}
		}
	}

	return nil
}

// processCampaignSend processes a single campaign send job from NATS.
// Checks campaign status, compliance (suppression + quiet hours) at SEND TIME,
// renders the template, sends via Twilio A2P, and tracks progress.
func (w *SMSWorker) processCampaignSend(ctx context.Context, msg jetstream.Msg) error {
	var job CampaignSendJob
	if err := json.Unmarshal(msg.Data(), &job); err != nil {
		return fmt.Errorf("unmarshal campaign send job: %w", err)
	}

	slog.Info("processing campaign send", "campaign_id", job.CampaignID, "voter_id", job.VoterID)

	// Rate limit: wait until rate limiter allows (1 msg/sec default)
	if err := w.rateLimiter.Wait(ctx); err != nil {
		return fmt.Errorf("rate limiter: %w", err)
	}

	// Load campaign, check status is still 'sending' (support pause/cancel mid-batch)
	campaign, err := w.queries.GetSMSCampaign(ctx, db.GetSMSCampaignParams{
		ID:        job.CampaignID,
		CompanyID: job.CompanyID,
	})
	if err != nil {
		return fmt.Errorf("get campaign: %w", err)
	}
	if campaign.Status != "sending" {
		slog.Info("campaign no longer sending, skipping", "campaign_id", job.CampaignID, "status", campaign.Status)
		return nil // Ack the message, campaign was paused/cancelled
	}

	// Load SMS config for the company
	config, err := w.queries.GetSMSConfig(ctx, job.CompanyID)
	if err != nil {
		return fmt.Errorf("get SMS config: %w", err)
	}

	// Compliance check at SEND TIME (not queue time): suppression + quiet hours
	if err := w.compliance.CheckSendAllowed(ctx, job.VoterID, job.CompanyID); err != nil {
		slog.Info("campaign send blocked by compliance", "campaign_id", job.CampaignID, "voter_id", job.VoterID, "reason", err.Error())
		// Increment failed count for blocked sends
		if incrErr := w.queries.IncrementCampaignFailedCount(ctx, job.CampaignID); incrErr != nil {
			slog.Warn("failed to increment campaign failed count", "error", incrErr)
		}
		w.checkCampaignCompletion(ctx, job.CampaignID, job.CompanyID)
		return nil // Ack -- don't retry compliance-blocked sends
	}

	// Load template
	tmpl, err := w.queries.GetSMSTemplate(ctx, db.GetSMSTemplateParams{
		ID:        job.TemplateID,
		CompanyID: job.CompanyID,
	})
	if err != nil {
		slog.Error("failed to load template for campaign send", "error", err, "template_id", job.TemplateID)
		if incrErr := w.queries.IncrementCampaignFailedCount(ctx, job.CampaignID); incrErr != nil {
			slog.Warn("failed to increment campaign failed count", "error", incrErr)
		}
		w.checkCampaignCompletion(ctx, job.CampaignID, job.CompanyID)
		return nil
	}

	// Load voter data for template rendering
	voterRow, err := w.queries.GetCampaignVoterTargets(ctx, db.GetCampaignVoterTargetsParams{
		CompanyID: job.CompanyID,
		Limit:     1,
		Offset:    0,
	})
	// Use raw query to get single voter by ID for rendering
	var voterCtx VoterContext
	var voterPhone string
	err = w.pool.QueryRow(ctx,
		`SELECT first_name, last_name, res_city, state_house_district, party, phone
		 FROM voters WHERE id = $1 AND company_id = $2`,
		job.VoterID, job.CompanyID,
	).Scan(&voterCtx.FirstName, &voterCtx.LastName, &voterCtx.City, &voterCtx.District, &voterCtx.Party, &voterPhone)
	if err != nil {
		slog.Error("failed to load voter for campaign send", "error", err, "voter_id", job.VoterID)
		if incrErr := w.queries.IncrementCampaignFailedCount(ctx, job.CampaignID); incrErr != nil {
			slog.Warn("failed to increment campaign failed count", "error", incrErr)
		}
		w.checkCampaignCompletion(ctx, job.CampaignID, job.CompanyID)
		return nil
	}
	_ = voterRow // satisfied by raw query above

	if voterPhone == "" {
		slog.Warn("voter has no phone number", "voter_id", job.VoterID)
		if incrErr := w.queries.IncrementCampaignFailedCount(ctx, job.CampaignID); incrErr != nil {
			slog.Warn("failed to increment campaign failed count", "error", incrErr)
		}
		w.checkCampaignCompletion(ctx, job.CampaignID, job.CompanyID)
		return nil
	}

	// Render template with voter data
	rendered, err := w.templateService.RenderTemplate(tmpl.Body, voterCtx)
	if err != nil {
		slog.Error("template rendering failed", "error", err, "voter_id", job.VoterID, "template_id", job.TemplateID)
		if incrErr := w.queries.IncrementCampaignFailedCount(ctx, job.CampaignID); incrErr != nil {
			slog.Warn("failed to increment campaign failed count", "error", incrErr)
		}
		w.checkCampaignCompletion(ctx, job.CampaignID, job.CompanyID)
		return nil
	}

	// Send via Twilio using A2P Messaging Service SID
	if w.twilioClient == nil {
		return fmt.Errorf("Twilio client not configured")
	}

	statusCallbackURL := config.StatusWebhookUrl
	params := &twilioApi.CreateMessageParams{}
	params.SetMessagingServiceSid(config.A2pMessagingServiceSid)
	params.SetTo(voterPhone)
	params.SetBody(rendered)
	if statusCallbackURL != "" {
		params.SetStatusCallback(statusCallbackURL)
	}

	resp, err := w.twilioClient.Api.CreateMessage(params)
	if err != nil {
		slog.Error("Twilio A2P send failed", "error", err, "voter_id", job.VoterID, "campaign_id", job.CampaignID)
		if incrErr := w.queries.IncrementCampaignFailedCount(ctx, job.CampaignID); incrErr != nil {
			slog.Warn("failed to increment campaign failed count", "error", incrErr)
		}
		w.checkCampaignCompletion(ctx, job.CampaignID, job.CompanyID)
		return nil // Ack -- don't retry failed Twilio sends
	}

	twilioSid := ""
	if resp.Sid != nil {
		twilioSid = *resp.Sid
	}

	// Insert message record
	_, insertErr := w.queries.InsertSMSMessage(ctx, db.InsertSMSMessageParams{
		CompanyID:        job.CompanyID,
		VoterID:          job.VoterID,
		UserID:           pgtype.UUID{Valid: false}, // System-initiated (campaign)
		CampaignID:       pgtype.UUID{Bytes: job.CampaignID, Valid: true},
		Direction:        "outbound",
		MessageType:      "a2p",
		FromNumber:       "", // Twilio assigns via MessagingService
		ToNumber:         voterPhone,
		Body:             rendered,
		TwilioMessageSid: &twilioSid,
		Status:           "queued",
		Segments:         1,
	})
	if insertErr != nil {
		slog.Error("failed to insert campaign message", "error", insertErr, "twilio_sid", twilioSid)
	}

	// Insert contact log
	adminUserID, adminErr := w.queries.GetCompanyAdminUserID(ctx, job.CompanyID)
	if adminErr == nil {
		if clErr := w.queries.InsertContactLog(ctx, db.InsertContactLogParams{
			CompanyID:   job.CompanyID,
			VoterID:     job.VoterID,
			UserID:      adminUserID,
			ContactType: "text",
			Notes:       fmt.Sprintf("A2P Campaign: %s", truncate(rendered, 100)),
		}); clErr != nil {
			slog.Warn("failed to insert contact log for campaign send", "error", clErr)
		}
	}

	// Increment campaign sent count
	if incrErr := w.queries.IncrementCampaignSentCount(ctx, job.CampaignID); incrErr != nil {
		slog.Warn("failed to increment campaign sent count", "error", incrErr)
	}

	// Check if campaign is complete
	w.checkCampaignCompletion(ctx, job.CampaignID, job.CompanyID)

	return nil
}

// checkCampaignCompletion checks if sent_count + failed_count >= total_recipients
// and updates campaign status to 'completed' if so.
func (w *SMSWorker) checkCampaignCompletion(ctx context.Context, campaignID, companyID uuid.UUID) {
	campaign, err := w.queries.GetSMSCampaign(ctx, db.GetSMSCampaignParams{
		ID:        campaignID,
		CompanyID: companyID,
	})
	if err != nil {
		slog.Warn("failed to check campaign completion", "error", err, "campaign_id", campaignID)
		return
	}

	if campaign.SentCount+campaign.FailedCount >= campaign.TotalRecipients && campaign.TotalRecipients > 0 {
		if err := w.queries.UpdateCampaignStatus(ctx, db.UpdateCampaignStatusParams{
			ID:        campaignID,
			CompanyID: companyID,
			Status:    "completed",
		}); err != nil {
			slog.Warn("failed to mark campaign completed", "error", err, "campaign_id", campaignID)
		} else {
			slog.Info("campaign completed", "campaign_id", campaignID,
				"sent", campaign.SentCount, "failed", campaign.FailedCount, "total", campaign.TotalRecipients)
		}
	}
}

// normalizePhone strips common US phone prefixes for consistent lookup.
func normalizePhone(phone string) string {
	// Remove +1 prefix for US numbers
	phone = strings.TrimPrefix(phone, "+1")
	phone = strings.TrimPrefix(phone, "1")
	// Remove non-digit characters
	var digits strings.Builder
	for _, ch := range phone {
		if ch >= '0' && ch <= '9' {
			digits.WriteRune(ch)
		}
	}
	return digits.String()
}
