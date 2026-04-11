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

	"navigators-go/internal/db"

	"github.com/aocybersystems/eden-platform-go/platform/notification"
)

const (
	taskStreamName           = "NAVIGATORS_TASKS"
	contactLogCreatedSubject = "navigators.contact_log.created"
	taskAssignedSubject      = "navigators.task.assigned"
	taskReminderSubject      = "navigators.task.reminder"
	progressConsumer         = "task-progress-worker"
	notificationConsumer     = "task-notification-worker"
)

// TaskAssignedEvent is published when a user is assigned to a task.
type TaskAssignedEvent struct {
	TaskID    string `json:"task_id"`
	UserID    string `json:"user_id"`
	TaskTitle string `json:"task_title"`
}

// TaskReminderEvent is published for tasks approaching due date.
type TaskReminderEvent struct {
	TaskID      string   `json:"task_id"`
	UserIDs     []string `json:"user_ids"`
	TaskTitle   string   `json:"task_title"`
	DueDate     string   `json:"due_date"`
}

// TaskWorker consumes NATS JetStream events for task progress and notifications.
type TaskWorker struct {
	js         jetstream.JetStream
	queries    *db.Queries
	pool       *pgxpool.Pool
	dispatcher notification.Dispatcher // nil-safe, check IsEnabled()
	cancel     context.CancelFunc
}

// NewTaskWorker creates a new TaskWorker.
func NewTaskWorker(js jetstream.JetStream, queries *db.Queries, pool *pgxpool.Pool, dispatcher notification.Dispatcher) *TaskWorker {
	return &TaskWorker{
		js:         js,
		queries:    queries,
		pool:       pool,
		dispatcher: dispatcher,
	}
}

// Start initializes the JetStream stream and consumers, then starts processing goroutines.
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

	// Create durable consumer for task notifications (assigned + reminder)
	notifCons, err := w.js.CreateOrUpdateConsumer(ctx, taskStreamName, jetstream.ConsumerConfig{
		Durable:        notificationConsumer,
		FilterSubjects: []string{taskAssignedSubject, taskReminderSubject},
		AckPolicy:      jetstream.AckExplicitPolicy,
	})
	if err != nil {
		return fmt.Errorf("create notification consumer: %w", err)
	}

	// Start consuming goroutines
	go w.consumeProgress(ctx, progressCons)
	go w.consumeNotifications(ctx, notifCons)

	// Start reminder ticker (every 1 hour)
	go w.reminderTicker(ctx)

	slog.Info("Task NATS workers started", "consumers", 2, "reminder_ticker", "1h")
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

func (w *TaskWorker) consumeNotifications(ctx context.Context, cons jetstream.Consumer) {
	cc, err := cons.Consume(func(msg jetstream.Msg) {
		subject := msg.Subject()
		var processErr error
		switch subject {
		case taskAssignedSubject:
			processErr = w.handleAssigned(ctx, msg)
		case taskReminderSubject:
			processErr = w.handleReminder(ctx, msg)
		default:
			slog.Warn("unknown task notification subject", "subject", subject)
			_ = msg.Ack()
			return
		}

		if processErr != nil {
			slog.Error("failed to process task notification", "subject", subject, "error", processErr)
			if nakErr := msg.Nak(); nakErr != nil {
				slog.Error("failed to NAK notification message", "error", nakErr)
			}
			return
		}
		if err := msg.Ack(); err != nil {
			slog.Error("failed to ACK notification message", "error", err)
		}
	})
	if err != nil {
		slog.Error("failed to start notification consumer", "error", err)
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

// handleAssigned sends push notification when a user is assigned to a task.
func (w *TaskWorker) handleAssigned(ctx context.Context, msg jetstream.Msg) error {
	var event TaskAssignedEvent
	if err := json.Unmarshal(msg.Data(), &event); err != nil {
		return fmt.Errorf("unmarshal task.assigned: %w", err)
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
		slog.Warn("failed to get device tokens for assignment notification", "error", err, "user_id", userID)
		return nil // Non-fatal: user may not have tokens registered
	}
	if len(tokens) == 0 {
		return nil
	}

	data := map[string]string{
		"type":    "task_assigned",
		"task_id": event.TaskID,
	}
	if err := w.dispatcher.SendPush(ctx, tokens, "New Task Assigned", event.TaskTitle, data); err != nil {
		slog.Warn("failed to send assignment push notification", "error", err, "user_id", userID)
	}

	return nil
}

// handleReminder sends push notifications for tasks approaching due date.
func (w *TaskWorker) handleReminder(ctx context.Context, msg jetstream.Msg) error {
	var event TaskReminderEvent
	if err := json.Unmarshal(msg.Data(), &event); err != nil {
		return fmt.Errorf("unmarshal task.reminder: %w", err)
	}

	if w.dispatcher == nil || !w.dispatcher.IsEnabled() {
		return nil
	}

	data := map[string]string{
		"type":     "task_reminder",
		"task_id":  event.TaskID,
		"due_date": event.DueDate,
	}

	for _, uid := range event.UserIDs {
		userID, err := uuid.Parse(uid)
		if err != nil {
			slog.Warn("invalid user_id in reminder event", "user_id", uid)
			continue
		}

		tokens, err := w.getDeviceTokens(ctx, userID)
		if err != nil || len(tokens) == 0 {
			continue
		}

		body := fmt.Sprintf("%s - Due: %s", event.TaskTitle, event.DueDate)
		if err := w.dispatcher.SendPush(ctx, tokens, "Task Due Soon", body, data); err != nil {
			slog.Warn("failed to send reminder push notification", "error", err, "user_id", userID)
		}
	}

	return nil
}

// reminderTicker periodically queries tasks due soon and publishes reminder events.
func (w *TaskWorker) reminderTicker(ctx context.Context) {
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

func (w *TaskWorker) publishReminders(ctx context.Context) {
	tasks, err := w.queries.GetTasksDueSoon(ctx)
	if err != nil {
		slog.Warn("failed to query tasks due soon", "error", err)
		return
	}

	for _, task := range tasks {
		var assigneeIDs []string
		for _, uid := range task.AssigneeIds {
			assigneeIDs = append(assigneeIDs, uid.String())
		}

		dueDate := ""
		if task.DueDate.Valid {
			dueDate = task.DueDate.Time.Format(time.RFC3339)
		}

		event := TaskReminderEvent{
			TaskID:    task.ID.String(),
			UserIDs:   assigneeIDs,
			TaskTitle: task.Title,
			DueDate:   dueDate,
		}
		data, _ := json.Marshal(event)
		if _, err := w.js.Publish(ctx, taskReminderSubject, data); err != nil {
			slog.Warn("failed to publish task reminder", "error", err, "task_id", task.ID)
		}
	}

	if len(tasks) > 0 {
		slog.Info("published task reminders", "count", len(tasks))
	}
}

// getDeviceTokens queries device tokens for a user from the shared database.
func (w *TaskWorker) getDeviceTokens(ctx context.Context, userID uuid.UUID) ([]notification.DeviceTokenRecord, error) {
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
