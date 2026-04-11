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
)

// TaskService provides task CRUD, assignment, linking, and notes operations.
type TaskService struct {
	queries *db.Queries
	pool    *pgxpool.Pool
	js      jetstream.JetStream // nil if NATS unavailable
}

// NewTaskService creates a new TaskService.
func NewTaskService(queries *db.Queries, pool *pgxpool.Pool, js jetstream.JetStream) *TaskService {
	return &TaskService{
		queries: queries,
		pool:    pool,
		js:      js,
	}
}

// CreateTask creates a new task.
func (s *TaskService) CreateTask(ctx context.Context, companyID, userID uuid.UUID, title, description, taskType, priority, status string, dueDate *time.Time, linkedEntityType *string, linkedEntityID *uuid.UUID) (*db.Task, error) {
	// Validate task_type
	switch taskType {
	case "contact_list", "event", "data_entry", "custom":
	default:
		return nil, fmt.Errorf("invalid task_type: %s", taskType)
	}

	// Validate priority
	switch priority {
	case "low", "medium", "high", "urgent":
	default:
		return nil, fmt.Errorf("invalid priority: %s", priority)
	}

	// Validate status
	if status == "" {
		status = "open"
	}
	switch status {
	case "open", "in_progress", "completed", "cancelled":
	default:
		return nil, fmt.Errorf("invalid status: %s", status)
	}

	// Convert dueDate to pgtype.Timestamptz
	var pgDueDate pgtype.Timestamptz
	if dueDate != nil {
		pgDueDate = pgtype.Timestamptz{Time: *dueDate, Valid: true}
	}

	// Convert linkedEntityID to pgtype.UUID
	var pgLinkedEntityID pgtype.UUID
	if linkedEntityID != nil {
		pgLinkedEntityID = pgtype.UUID{Bytes: *linkedEntityID, Valid: true}
	}

	task, err := s.queries.CreateTask(ctx, db.CreateTaskParams{
		CompanyID:        companyID,
		Title:            title,
		Description:      description,
		TaskType:         taskType,
		Priority:         priority,
		Status:           status,
		DueDate:          pgDueDate,
		LinkedEntityType: linkedEntityType,
		LinkedEntityID:   pgLinkedEntityID,
		TotalCount:       0,
		CreatedBy:        userID,
	})
	if err != nil {
		return nil, fmt.Errorf("create task: %w", err)
	}

	return &task, nil
}

// GetTask returns a task by ID.
func (s *TaskService) GetTask(ctx context.Context, companyID, taskID uuid.UUID) (*db.Task, error) {
	task, err := s.queries.GetTask(ctx, db.GetTaskParams{
		ID:        taskID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("get task: %w", err)
	}
	return &task, nil
}

// ListTasksByCompany returns all tasks for a company.
func (s *TaskService) ListTasksByCompany(ctx context.Context, companyID uuid.UUID) ([]db.Task, error) {
	tasks, err := s.queries.ListTasksByCompany(ctx, companyID)
	if err != nil {
		return nil, fmt.Errorf("list tasks by company: %w", err)
	}
	return tasks, nil
}

// ListTasksByAssignee returns tasks assigned to a specific user.
func (s *TaskService) ListTasksByAssignee(ctx context.Context, companyID, userID uuid.UUID) ([]db.Task, error) {
	tasks, err := s.queries.ListTasksByAssignee(ctx, db.ListTasksByAssigneeParams{
		UserID:    userID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("list tasks by assignee: %w", err)
	}
	return tasks, nil
}

// UpdateTaskStatus updates the status of a task.
func (s *TaskService) UpdateTaskStatus(ctx context.Context, companyID, taskID uuid.UUID, status string) error {
	switch status {
	case "open", "in_progress", "completed", "cancelled":
	default:
		return fmt.Errorf("invalid status: %s", status)
	}

	err := s.queries.UpdateTaskStatus(ctx, db.UpdateTaskStatusParams{
		ID:        taskID,
		CompanyID: companyID,
		Status:    status,
	})
	if err != nil {
		return fmt.Errorf("update task status: %w", err)
	}
	return nil
}

// DeleteTask deletes a task.
func (s *TaskService) DeleteTask(ctx context.Context, companyID, taskID uuid.UUID) error {
	err := s.queries.DeleteTask(ctx, db.DeleteTaskParams{
		ID:        taskID,
		CompanyID: companyID,
	})
	if err != nil {
		return fmt.Errorf("delete task: %w", err)
	}
	return nil
}

// AssignTask assigns a user to a task and publishes a NATS event for push notification.
func (s *TaskService) AssignTask(ctx context.Context, companyID, taskID, userID, assignedBy uuid.UUID) error {
	err := s.queries.CreateTaskAssignment(ctx, db.CreateTaskAssignmentParams{
		TaskID:     taskID,
		UserID:     userID,
		AssignedBy: assignedBy,
	})
	if err != nil {
		return fmt.Errorf("assign task: %w", err)
	}

	// Publish task.assigned event for push notification
	if s.js != nil {
		// Get task title for the notification
		task, taskErr := s.queries.GetTask(ctx, db.GetTaskParams{
			ID:        taskID,
			CompanyID: companyID,
		})
		taskTitle := "New Task"
		if taskErr == nil {
			taskTitle = task.Title
		}

		event := TaskAssignedEvent{
			TaskID:    taskID.String(),
			UserID:    userID.String(),
			TaskTitle: taskTitle,
		}
		data, _ := json.Marshal(event)
		if _, pubErr := s.js.Publish(ctx, taskAssignedSubject, data); pubErr != nil {
			slog.Warn("failed to publish task.assigned event", "error", pubErr, "task_id", taskID, "user_id", userID)
		}
	}

	return nil
}

// UnassignTask removes a user from a task.
func (s *TaskService) UnassignTask(ctx context.Context, taskID, userID uuid.UUID) error {
	err := s.queries.DeleteTaskAssignment(ctx, db.DeleteTaskAssignmentParams{
		TaskID: taskID,
		UserID: userID,
	})
	if err != nil {
		return fmt.Errorf("unassign task: %w", err)
	}
	return nil
}

// GetTaskAssignments returns all assignments for a task.
func (s *TaskService) GetTaskAssignments(ctx context.Context, taskID uuid.UUID) ([]db.GetTaskAssignmentsRow, error) {
	assignments, err := s.queries.GetTaskAssignments(ctx, taskID)
	if err != nil {
		return nil, fmt.Errorf("get task assignments: %w", err)
	}
	return assignments, nil
}

// LinkTaskVoters bulk-inserts voter IDs into task_voters and updates total_count.
func (s *TaskService) LinkTaskVoters(ctx context.Context, companyID, taskID uuid.UUID, voterIDs []uuid.UUID) (int32, error) {
	// Insert task_voters
	rows := make([]db.InsertTaskVotersParams, len(voterIDs))
	for i, vid := range voterIDs {
		rows[i] = db.InsertTaskVotersParams{
			TaskID:  taskID,
			VoterID: vid,
		}
	}

	count, err := s.queries.InsertTaskVoters(ctx, rows)
	if err != nil {
		return 0, fmt.Errorf("link task voters: %w", err)
	}

	// Update total_count on the task
	if err := s.queries.UpdateTaskProgress(ctx, db.UpdateTaskProgressParams{
		ID:             taskID,
		CompanyID:      companyID,
		ProgressPct:    0,
		CompletedCount: 0,
	}); err != nil {
		return 0, fmt.Errorf("update task total_count: %w", err)
	}

	return int32(count), nil
}

// CreateTaskNote creates a note on a task.
func (s *TaskService) CreateTaskNote(ctx context.Context, companyID, taskID, userID uuid.UUID, content, visibility string) (*db.TaskNote, error) {
	if visibility == "" {
		visibility = "team"
	}
	switch visibility {
	case "team", "org":
	default:
		return nil, fmt.Errorf("invalid visibility: %s", visibility)
	}

	note, err := s.queries.CreateTaskNote(ctx, db.CreateTaskNoteParams{
		CompanyID:  companyID,
		TaskID:     taskID,
		UserID:     userID,
		Content:    content,
		Visibility: visibility,
	})
	if err != nil {
		return nil, fmt.Errorf("create task note: %w", err)
	}
	return &note, nil
}

// ListTaskNotes returns notes for a task.
func (s *TaskService) ListTaskNotes(ctx context.Context, taskID uuid.UUID) ([]db.TaskNote, error) {
	notes, err := s.queries.ListTaskNotes(ctx, taskID)
	if err != nil {
		return nil, fmt.Errorf("list task notes: %w", err)
	}
	return notes, nil
}
