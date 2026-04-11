package navigators

import (
	"context"
	"fmt"
	"time"

	connect "connectrpc.com/connect"
	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"

	"navigators-go/internal/db"

	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
)

// Compile-time check that TaskHandler implements the generated interface.
var _ navigatorsv1connect.TaskServiceHandler = (*TaskHandler)(nil)

// TaskHandler implements the navigators.v1.TaskService ConnectRPC handler.
type TaskHandler struct {
	taskService *TaskService
}

// NewTaskHandler creates a new TaskHandler.
func NewTaskHandler(taskService *TaskService) *TaskHandler {
	return &TaskHandler{taskService: taskService}
}

func (h *TaskHandler) CreateTask(ctx context.Context, req *connect.Request[navigatorsv1.CreateTaskRequest]) (*connect.Response[navigatorsv1.CreateTaskResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	claims := server.ClaimsFromContext(ctx)
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	title := req.Msg.GetTitle()
	if title == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("title is required"))
	}

	taskType := req.Msg.GetTaskType()
	if taskType == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("task_type is required"))
	}

	priority := req.Msg.GetPriority()
	if priority == "" {
		priority = "medium"
	}

	var dueDate *time.Time
	if req.Msg.GetDueDate() != "" {
		parsed, err := time.Parse(time.RFC3339, req.Msg.GetDueDate())
		if err != nil {
			return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid due_date: %w", err))
		}
		dueDate = &parsed
	}

	var linkedEntityType *string
	if req.Msg.GetLinkedEntityType() != "" {
		t := req.Msg.GetLinkedEntityType()
		linkedEntityType = &t
	}

	var linkedEntityID *uuid.UUID
	if req.Msg.GetLinkedEntityId() != "" {
		parsed, err := uuid.Parse(req.Msg.GetLinkedEntityId())
		if err != nil {
			return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid linked_entity_id: %w", err))
		}
		linkedEntityID = &parsed
	}

	task, err := h.taskService.CreateTask(ctx, companyID, userID, title, req.Msg.GetDescription(), taskType, priority, "", dueDate, linkedEntityType, linkedEntityID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("create task: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.CreateTaskResponse{
		Task: dbTaskToProto(task),
	}), nil
}

func (h *TaskHandler) GetTask(ctx context.Context, req *connect.Request[navigatorsv1.GetTaskRequest]) (*connect.Response[navigatorsv1.GetTaskResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	taskID, err := uuid.Parse(req.Msg.GetTaskId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid task_id: %w", err))
	}

	task, err := h.taskService.GetTask(ctx, companyID, taskID)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("task not found: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.GetTaskResponse{
		Task: dbTaskToProto(task),
	}), nil
}

func (h *TaskHandler) ListTasks(ctx context.Context, req *connect.Request[navigatorsv1.ListTasksRequest]) (*connect.Response[navigatorsv1.ListTasksResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	claims := server.ClaimsFromContext(ctx)
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	// Admin (80) and Manager (60) see all company tasks; Member (40) sees assigned only
	var dbTasks []db.Task
	if claims.RoleLevel >= 60 {
		dbTasks, err = h.taskService.ListTasksByCompany(ctx, companyID)
	} else {
		dbTasks, err = h.taskService.ListTasksByAssignee(ctx, companyID, userID)
	}
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("list tasks: %w", err))
	}

	pbTasks := make([]*navigatorsv1.Task, len(dbTasks))
	for i := range dbTasks {
		pbTasks[i] = dbTaskToProto(&dbTasks[i])
	}

	return connect.NewResponse(&navigatorsv1.ListTasksResponse{
		Tasks: pbTasks,
	}), nil
}

func (h *TaskHandler) UpdateTaskStatus(ctx context.Context, req *connect.Request[navigatorsv1.UpdateTaskStatusRequest]) (*connect.Response[navigatorsv1.UpdateTaskStatusResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	taskID, err := uuid.Parse(req.Msg.GetTaskId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid task_id: %w", err))
	}

	status := req.Msg.GetStatus()
	if status == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("status is required"))
	}

	if err := h.taskService.UpdateTaskStatus(ctx, companyID, taskID, status); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("update task status: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.UpdateTaskStatusResponse{}), nil
}

func (h *TaskHandler) DeleteTask(ctx context.Context, req *connect.Request[navigatorsv1.DeleteTaskRequest]) (*connect.Response[navigatorsv1.DeleteTaskResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	taskID, err := uuid.Parse(req.Msg.GetTaskId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid task_id: %w", err))
	}

	if err := h.taskService.DeleteTask(ctx, companyID, taskID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("delete task: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.DeleteTaskResponse{}), nil
}

func (h *TaskHandler) AssignTask(ctx context.Context, req *connect.Request[navigatorsv1.AssignTaskRequest]) (*connect.Response[navigatorsv1.AssignTaskResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	assignedBy, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	taskID, err := uuid.Parse(req.Msg.GetTaskId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid task_id: %w", err))
	}

	userID, err := uuid.Parse(req.Msg.GetUserId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid user_id: %w", err))
	}

	if err := h.taskService.AssignTask(ctx, taskID, userID, assignedBy); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("assign task: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.AssignTaskResponse{}), nil
}

func (h *TaskHandler) UnassignTask(ctx context.Context, req *connect.Request[navigatorsv1.UnassignTaskRequest]) (*connect.Response[navigatorsv1.UnassignTaskResponse], error) {
	taskID, err := uuid.Parse(req.Msg.GetTaskId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid task_id: %w", err))
	}

	userID, err := uuid.Parse(req.Msg.GetUserId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid user_id: %w", err))
	}

	if err := h.taskService.UnassignTask(ctx, taskID, userID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("unassign task: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.UnassignTaskResponse{}), nil
}

func (h *TaskHandler) GetTaskAssignments(ctx context.Context, req *connect.Request[navigatorsv1.GetTaskAssignmentsRequest]) (*connect.Response[navigatorsv1.GetTaskAssignmentsResponse], error) {
	taskID, err := uuid.Parse(req.Msg.GetTaskId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid task_id: %w", err))
	}

	assignments, err := h.taskService.GetTaskAssignments(ctx, taskID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get task assignments: %w", err))
	}

	pbAssignments := make([]*navigatorsv1.TaskAssignment, len(assignments))
	for i, a := range assignments {
		pbAssignments[i] = &navigatorsv1.TaskAssignment{
			Id:              a.ID.String(),
			TaskId:          a.TaskID.String(),
			UserId:          a.UserID.String(),
			AssignedBy:      a.AssignedBy.String(),
			AssignedAt:      a.AssignedAt.Format(time.RFC3339),
			UserDisplayName: a.UserDisplayName,
		}
	}

	return connect.NewResponse(&navigatorsv1.GetTaskAssignmentsResponse{
		Assignments: pbAssignments,
	}), nil
}

func (h *TaskHandler) LinkTaskVoters(ctx context.Context, req *connect.Request[navigatorsv1.LinkTaskVotersRequest]) (*connect.Response[navigatorsv1.LinkTaskVotersResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	taskID, err := uuid.Parse(req.Msg.GetTaskId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid task_id: %w", err))
	}

	voterIDs := make([]uuid.UUID, len(req.Msg.GetVoterIds()))
	for i, vid := range req.Msg.GetVoterIds() {
		parsed, err := uuid.Parse(vid)
		if err != nil {
			return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid voter_id at index %d: %w", i, err))
		}
		voterIDs[i] = parsed
	}

	count, err := h.taskService.LinkTaskVoters(ctx, companyID, taskID, voterIDs)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("link task voters: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.LinkTaskVotersResponse{
		LinkedCount: count,
	}), nil
}

func (h *TaskHandler) CreateTaskNote(ctx context.Context, req *connect.Request[navigatorsv1.CreateTaskNoteRequest]) (*connect.Response[navigatorsv1.CreateTaskNoteResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	claims := server.ClaimsFromContext(ctx)
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	taskID, err := uuid.Parse(req.Msg.GetTaskId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid task_id: %w", err))
	}

	content := req.Msg.GetContent()
	if content == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("content is required"))
	}

	visibility := req.Msg.GetVisibility()
	if visibility == "" {
		visibility = "team"
	}

	note, err := h.taskService.CreateTaskNote(ctx, companyID, taskID, userID, content, visibility)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("create task note: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.CreateTaskNoteResponse{
		Note: dbTaskNoteToProto(note),
	}), nil
}

func (h *TaskHandler) ListTaskNotes(ctx context.Context, req *connect.Request[navigatorsv1.ListTaskNotesRequest]) (*connect.Response[navigatorsv1.ListTaskNotesResponse], error) {
	taskID, err := uuid.Parse(req.Msg.GetTaskId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid task_id: %w", err))
	}

	notes, err := h.taskService.ListTaskNotes(ctx, taskID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("list task notes: %w", err))
	}

	pbNotes := make([]*navigatorsv1.TaskNote, len(notes))
	for i := range notes {
		pbNotes[i] = dbTaskNoteToProto(&notes[i])
	}

	return connect.NewResponse(&navigatorsv1.ListTaskNotesResponse{
		Notes: pbNotes,
	}), nil
}

// --- Proto conversion helpers ---

// dbTaskToProto converts a db.Task to a proto Task message.
func dbTaskToProto(t *db.Task) *navigatorsv1.Task {
	var dueDate string
	if t.DueDate.Valid {
		dueDate = t.DueDate.Time.Format(time.RFC3339)
	}
	var linkedEntityType string
	if t.LinkedEntityType != nil {
		linkedEntityType = *t.LinkedEntityType
	}
	var linkedEntityID string
	if t.LinkedEntityID.Valid {
		linkedEntityID = uuid.UUID(t.LinkedEntityID.Bytes).String()
	}

	return &navigatorsv1.Task{
		Id:               t.ID.String(),
		CompanyId:        t.CompanyID.String(),
		Title:            t.Title,
		Description:      t.Description,
		TaskType:         t.TaskType,
		Priority:         t.Priority,
		Status:           t.Status,
		DueDate:          dueDate,
		LinkedEntityType: linkedEntityType,
		LinkedEntityId:   linkedEntityID,
		ProgressPct:      t.ProgressPct,
		TotalCount:       t.TotalCount,
		CompletedCount:   t.CompletedCount,
		CreatedBy:        t.CreatedBy.String(),
		CreatedAt:        t.CreatedAt.Format(time.RFC3339),
		UpdatedAt:        t.UpdatedAt.Format(time.RFC3339),
	}
}

// dbTaskNoteToProto converts a db.TaskNote to a proto TaskNote message.
func dbTaskNoteToProto(n *db.TaskNote) *navigatorsv1.TaskNote {
	return &navigatorsv1.TaskNote{
		Id:         n.ID.String(),
		CompanyId:  n.CompanyID.String(),
		TaskId:     n.TaskID.String(),
		UserId:     n.UserID.String(),
		Content:    n.Content,
		Visibility: n.Visibility,
		CreatedAt:  n.CreatedAt.Format(time.RFC3339),
	}
}
