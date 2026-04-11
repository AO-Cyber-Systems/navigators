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

	"navigators-go/internal/db"
)

const (
	smsStreamName       = "NAVIGATORS_SMS"
	smsInboundSubject   = "navigators.sms.inbound"
	smsStatusSubject    = "navigators.sms.status"
	smsInboundConsumer  = "sms-inbound-worker"
	smsStatusConsumer   = "sms-status-worker"
)

// SMSWorker processes SMS events from NATS JetStream.
type SMSWorker struct {
	js         jetstream.JetStream
	queries    *db.Queries
	pool       *pgxpool.Pool
	compliance *SMSComplianceService
	cancel     context.CancelFunc
}

// NewSMSWorker creates a new SMSWorker.
func NewSMSWorker(js jetstream.JetStream, queries *db.Queries, pool *pgxpool.Pool, compliance *SMSComplianceService) *SMSWorker {
	return &SMSWorker{
		js:         js,
		queries:    queries,
		pool:       pool,
		compliance: compliance,
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
		Durable:       smsInboundConsumer,
		FilterSubjects: []string{smsInboundSubject},
		AckPolicy:     jetstream.AckExplicitPolicy,
	})
	if err != nil {
		return fmt.Errorf("create inbound consumer: %w", err)
	}

	statusCons, err := w.js.CreateOrUpdateConsumer(ctx, smsStreamName, jetstream.ConsumerConfig{
		Durable:       smsStatusConsumer,
		FilterSubjects: []string{smsStatusSubject},
		AckPolicy:     jetstream.AckExplicitPolicy,
	})
	if err != nil {
		return fmt.Errorf("create status consumer: %w", err)
	}

	// Start consuming in goroutines using the callback-based Consume API
	go w.consumeInbound(ctx, inboundCons)
	go w.consumeStatus(ctx, statusCons)

	slog.Info("SMS NATS workers started")
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
