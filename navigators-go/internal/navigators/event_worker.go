package navigators

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/nats-io/nats.go/jetstream"

	"navigators-go/internal/db"
)

const (
	eventStreamName = "NAVIGATORS_EVENTS"
)

// EventWorker owns the NAVIGATORS_EVENTS JetStream stream.
//
// Remote push was descoped; see .planning/objectives/08-tasks-collaboration/08-04-TRD.md.
// Event reminder / RSVP push consumers and the reminder ticker were removed.
// The stream is still created here so future local or in-app consumers can attach.
type EventWorker struct {
	js      jetstream.JetStream
	queries *db.Queries
	pool    *pgxpool.Pool
	cancel  context.CancelFunc
}

// NewEventWorker creates a new EventWorker.
func NewEventWorker(js jetstream.JetStream, queries *db.Queries, pool *pgxpool.Pool) *EventWorker {
	return &EventWorker{
		js:      js,
		queries: queries,
		pool:    pool,
	}
}

// Start ensures the JetStream event stream exists.
func (w *EventWorker) Start(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	w.cancel = cancel

	_, err := w.js.CreateOrUpdateStream(ctx, jetstream.StreamConfig{
		Name:     eventStreamName,
		Subjects: []string{"navigators.event.>"},
		Storage:  jetstream.FileStorage,
	})
	if err != nil {
		return fmt.Errorf("create event stream: %w", err)
	}
	slog.Info("NATS JetStream event stream ready", "stream", eventStreamName)
	slog.Info("Event NATS worker started", "consumers", 0, "note", "push descoped (local-only notifications)")
	return nil
}

// Stop cancels the worker context.
func (w *EventWorker) Stop() {
	if w.cancel != nil {
		w.cancel()
	}
}
