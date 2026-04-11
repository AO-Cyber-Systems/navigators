package navigators

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/nats-io/nats.go/jetstream"

	"github.com/aocybersystems/eden-platform-go/platform/notification"

	"navigators-go/internal/db"
)

const (
	eventStreamName        = "NAVIGATORS_EVENTS"
	eventReminderSubject   = "navigators.event.reminder"
	eventRSVPSubject       = "navigators.event.rsvp"
	eventReminderConsumer  = "event-reminder-worker"
)

// EventReminderEvent is published when an event reminder needs to be sent.
type EventReminderEvent struct {
	EventID    string `json:"event_id"`
	EventTitle string `json:"event_title"`
	StartsAt   string `json:"starts_at"`
	UserID     string `json:"user_id"`
}

// EventWorker consumes NATS JetStream events for event reminders.
type EventWorker struct {
	js         jetstream.JetStream
	queries    *db.Queries
	pool       *pgxpool.Pool
	dispatcher notification.Dispatcher // nil-safe, check IsEnabled()
	cancel     context.CancelFunc
}

// NewEventWorker creates a new EventWorker.
func NewEventWorker(js jetstream.JetStream, queries *db.Queries, pool *pgxpool.Pool, dispatcher notification.Dispatcher) *EventWorker {
	return &EventWorker{
		js:         js,
		queries:    queries,
		pool:       pool,
		dispatcher: dispatcher,
	}
}

// Start initializes the JetStream stream and consumers, then starts processing goroutines.
func (w *EventWorker) Start(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	w.cancel = cancel

	// Create or update the event stream
	_, err := w.js.CreateOrUpdateStream(ctx, jetstream.StreamConfig{
		Name:     eventStreamName,
		Subjects: []string{"navigators.event.>"},
		Storage:  jetstream.FileStorage,
	})
	if err != nil {
		return fmt.Errorf("create event stream: %w", err)
	}
	slog.Info("NATS JetStream event stream ready", "stream", eventStreamName)

	// Create durable consumer for event notifications (reminder + rsvp)
	notifCons, err := w.js.CreateOrUpdateConsumer(ctx, eventStreamName, jetstream.ConsumerConfig{
		Durable:        eventReminderConsumer,
		FilterSubjects: []string{eventReminderSubject, eventRSVPSubject},
		AckPolicy:      jetstream.AckExplicitPolicy,
	})
	if err != nil {
		return fmt.Errorf("create event notification consumer: %w", err)
	}

	// Start consuming goroutine
	go w.consumeNotifications(ctx, notifCons)

	// Start reminder ticker (every 1 hour)
	go w.reminderTicker(ctx)

	slog.Info("Event NATS workers started", "consumers", 1, "reminder_ticker", "1h")
	return nil
}

// Stop cancels the worker context.
func (w *EventWorker) Stop() {
	if w.cancel != nil {
		w.cancel()
	}
}

func (w *EventWorker) consumeNotifications(ctx context.Context, cons jetstream.Consumer) {
	cc, err := cons.Consume(func(msg jetstream.Msg) {
		subject := msg.Subject()
		var processErr error
		switch subject {
		case eventReminderSubject:
			processErr = w.handleReminder(ctx, msg)
		case eventRSVPSubject:
			// RSVP confirmation push (optional)
			processErr = w.handleRSVP(ctx, msg)
		default:
			slog.Warn("unknown event notification subject", "subject", subject)
			_ = msg.Ack()
			return
		}

		if processErr != nil {
			slog.Error("failed to process event notification", "subject", subject, "error", processErr)
			if nakErr := msg.Nak(); nakErr != nil {
				slog.Error("failed to NAK event notification message", "error", nakErr)
			}
			return
		}
		if err := msg.Ack(); err != nil {
			slog.Error("failed to ACK event notification message", "error", err)
		}
	})
	if err != nil {
		slog.Error("failed to start event notification consumer", "error", err)
		return
	}

	<-ctx.Done()
	cc.Stop()
}

// handleReminder sends push notification for an event reminder.
func (w *EventWorker) handleReminder(ctx context.Context, msg jetstream.Msg) error {
	var event EventReminderEvent
	if err := json.Unmarshal(msg.Data(), &event); err != nil {
		return fmt.Errorf("unmarshal event.reminder: %w", err)
	}

	if w.dispatcher == nil || !w.dispatcher.IsEnabled() {
		return nil
	}

	userID, err := uuid.Parse(event.UserID)
	if err != nil {
		return fmt.Errorf("parse user_id: %w", err)
	}

	tokens, err := w.getDeviceTokens(ctx, userID)
	if err != nil {
		slog.Warn("failed to get device tokens for event reminder", "error", err, "user_id", userID)
		return nil // Non-fatal: user may not have tokens registered
	}
	if len(tokens) == 0 {
		return nil
	}

	data := map[string]string{
		"type":      "event_reminder",
		"event_id":  event.EventID,
		"starts_at": event.StartsAt,
	}
	body := fmt.Sprintf("%s starts at %s", event.EventTitle, event.StartsAt)
	if err := w.dispatcher.SendPush(ctx, tokens, "Event Reminder", body, data); err != nil {
		slog.Warn("failed to send event reminder push notification", "error", err, "user_id", userID)
	}

	return nil
}

// handleRSVP sends push confirmation for an RSVP.
func (w *EventWorker) handleRSVP(ctx context.Context, msg jetstream.Msg) error {
	// RSVP confirmation is optional; just acknowledge
	return nil
}

// reminderTicker periodically queries events starting soon and publishes reminder events.
func (w *EventWorker) reminderTicker(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			w.publishReminders(ctx)
		}
	}
}

func (w *EventWorker) publishReminders(ctx context.Context) {
	events, err := w.queries.GetEventsStartingSoon(ctx)
	if err != nil {
		slog.Warn("failed to query events starting soon", "error", err)
		return
	}

	// For each upcoming event, find RSVPs that need reminders
	reminderThreshold := time.Now().UTC().Add(-2 * time.Hour)

	for _, event := range events {
		rsvps, err := w.queries.GetRSVPsNeedingReminder(ctx, db.GetRSVPsNeedingReminderParams{
			EventID:            event.ID,
			LastReminderSentAt: pgtype.Timestamptz{Time: reminderThreshold, Valid: true},
		})
		if err != nil {
			slog.Warn("failed to get rsvps needing reminder", "error", err, "event_id", event.ID)
			continue
		}

		for _, rsvp := range rsvps {
			reminder := EventReminderEvent{
				EventID:    event.ID.String(),
				EventTitle: event.Title,
				StartsAt:   event.StartsAt.Format(time.RFC3339),
				UserID:     rsvp.UserID.String(),
			}
			data, _ := json.Marshal(reminder)
			if _, err := w.js.Publish(ctx, eventReminderSubject, data); err != nil {
				slog.Warn("failed to publish event reminder", "error", err, "event_id", event.ID, "user_id", rsvp.UserID)
				continue
			}

			// Mark reminder as sent (dedup)
			if err := w.queries.UpdateRSVPReminderSent(ctx, rsvp.ID); err != nil {
				slog.Warn("failed to update rsvp reminder sent", "error", err, "rsvp_id", rsvp.ID)
			}
		}

		if len(rsvps) > 0 {
			slog.Info("published event reminders", "event_id", event.ID, "count", len(rsvps))
		}
	}
}

// getDeviceTokens queries device tokens for a user from the shared database.
func (w *EventWorker) getDeviceTokens(ctx context.Context, userID uuid.UUID) ([]notification.DeviceTokenRecord, error) {
	rows, err := w.pool.Query(ctx, "SELECT token, platform, user_id FROM device_tokens WHERE user_id = $1", userID)
	if err != nil {
		return nil, fmt.Errorf("query device tokens: %w", err)
	}
	defer rows.Close()

	var tokens []notification.DeviceTokenRecord
	for rows.Next() {
		var t notification.DeviceTokenRecord
		if err := rows.Scan(&t.Token, &t.Platform, &t.UserID); err != nil {
			return nil, fmt.Errorf("scan device token: %w", err)
		}
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}
