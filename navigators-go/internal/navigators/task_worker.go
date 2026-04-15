package navigators

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/nats-io/nats.go/jetstream"

	"navigators-go/internal/db"
)

const (
	taskStreamName           = "NAVIGATORS_TASKS"
	contactLogCreatedSubject = "navigators.contact_log.created"
	progressConsumer         = "task-progress-worker"
)

// TaskWorker consumes NATS JetStream events for task progress.
//
// Remote push was descoped; see .planning/objectives/08-tasks-collaboration/08-04-TRD.md.
// This worker now only handles contact_log.created -> task auto-progress.
type TaskWorker struct {
	js      jetstream.JetStream
	queries *db.Queries
	pool    *pgxpool.Pool
	cancel  context.CancelFunc
}

// NewTaskWorker creates a new TaskWorker.
func NewTaskWorker(js jetstream.JetStream, queries *db.Queries, pool *pgxpool.Pool) *TaskWorker {
	return &TaskWorker{
		js:      js,
		queries: queries,
		pool:    pool,
	}
}

// Start initializes the JetStream stream and the progress consumer, then starts processing.
func (w *TaskWorker) Start(ctx context.Context) error {
	ctx, cancel := context.WithCancel(ctx)
	w.cancel = cancel

	// Create or update the task stream
	_, err := w.js.CreateOrUpdateStream(ctx, jetstream.StreamConfig{
		Name:     taskStreamName,
		Subjects: []string{"navigators.task.>", "navigators.contact_log.>"},
		Storage:  jetstream.FileStorage,
	})
	if err != nil {
		return fmt.Errorf("create task stream: %w", err)
	}
	slog.Info("NATS JetStream task stream ready", "stream", taskStreamName)

	// Create durable consumer for contact_log.created -> task progress
	progressCons, err := w.js.CreateOrUpdateConsumer(ctx, taskStreamName, jetstream.ConsumerConfig{
		Durable:        progressConsumer,
		FilterSubjects: []string{contactLogCreatedSubject},
		AckPolicy:      jetstream.AckExplicitPolicy,
	})
	if err != nil {
		return fmt.Errorf("create progress consumer: %w", err)
	}

	go w.consumeProgress(ctx, progressCons)

	slog.Info("Task NATS worker started", "consumers", 1)
	return nil
}

// Stop cancels the worker context.
func (w *TaskWorker) Stop() {
	if w.cancel != nil {
		w.cancel()
	}
}

func (w *TaskWorker) consumeProgress(ctx context.Context, cons jetstream.Consumer) {
	cc, err := cons.Consume(func(msg jetstream.Msg) {
		if err := w.processContactLogCreated(ctx, msg); err != nil {
			slog.Error("failed to process contact_log.created", "error", err)
			if nakErr := msg.Nak(); nakErr != nil {
				slog.Error("failed to NAK progress message", "error", nakErr)
			}
			return
		}
		if err := msg.Ack(); err != nil {
			slog.Error("failed to ACK progress message", "error", err)
		}
	})
	if err != nil {
		slog.Error("failed to start progress consumer", "error", err)
		return
	}

	<-ctx.Done()
	cc.Stop()
}

// processContactLogCreated handles contact_log.created events for task auto-progress.
func (w *TaskWorker) processContactLogCreated(ctx context.Context, msg jetstream.Msg) error {
	var event ContactLogCreatedEvent
	if err := json.Unmarshal(msg.Data(), &event); err != nil {
		return fmt.Errorf("unmarshal contact_log.created: %w", err)
	}

	companyID, err := uuid.Parse(event.CompanyID)
	if err != nil {
		return fmt.Errorf("parse company_id: %w", err)
	}

	voterID, err := uuid.Parse(event.VoterID)
	if err != nil {
		return fmt.Errorf("parse voter_id: %w", err)
	}

	var turfID uuid.UUID
	if event.TurfID != "" {
		turfID, err = uuid.Parse(event.TurfID)
		if err != nil {
			return fmt.Errorf("parse turf_id: %w", err)
		}
	}

	slog.Debug("processing contact_log.created for task progress", "company_id", companyID, "voter_id", voterID)

	// Find active tasks linked to this voter
	var pgTurfID pgtype.UUID
	if event.TurfID != "" {
		pgTurfID = pgtype.UUID{Bytes: turfID, Valid: true}
	}
	tasks, err := w.queries.GetTasksLinkedToVoter(ctx, db.GetTasksLinkedToVoterParams{
		CompanyID: companyID,
		VoterID:   voterID,
		TurfID:    pgTurfID,
	})
	if err != nil {
		return fmt.Errorf("get tasks linked to voter: %w", err)
	}

	if len(tasks) == 0 {
		return nil
	}

	// For each linked task: mark voter contacted, recalculate progress
	for _, task := range tasks {
		// Mark the voter as contacted on the task
		if err := w.queries.MarkTaskVoterContacted(ctx, db.MarkTaskVoterContactedParams{
			TaskID:  task.ID,
			VoterID: voterID,
		}); err != nil {
			slog.Warn("failed to mark task voter contacted", "error", err, "task_id", task.ID, "voter_id", voterID)
			continue
		}

		// Recalculate task progress from SQL (idempotent, race-safe)
		if err := w.queries.RecalculateTaskProgress(ctx, task.ID); err != nil {
			slog.Warn("failed to recalculate task progress", "error", err, "task_id", task.ID)
		}

		slog.Debug("updated task progress", "task_id", task.ID, "voter_id", voterID)
	}

	return nil
}
