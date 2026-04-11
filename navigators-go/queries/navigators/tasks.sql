-- name: CreateTask :one
-- Create a new task.
INSERT INTO tasks (company_id, title, description, task_type, priority, status, due_date, linked_entity_type, linked_entity_id, total_count, created_by)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
RETURNING *;

-- name: GetTask :one
-- Get a task by ID and company.
SELECT * FROM tasks
WHERE id = $1 AND company_id = $2;

-- name: ListTasksByCompany :many
-- List tasks for a company, ordered by created_at DESC.
SELECT * FROM tasks
WHERE company_id = $1
ORDER BY created_at DESC;

-- name: ListTasksByAssignee :many
-- List tasks assigned to a specific user.
SELECT t.* FROM tasks t
JOIN task_assignments ta ON ta.task_id = t.id
WHERE ta.user_id = $1 AND t.company_id = $2
ORDER BY t.created_at DESC;

-- name: UpdateTaskStatus :exec
-- Update a task's status.
UPDATE tasks
SET status = $3, updated_at = now()
WHERE id = $1 AND company_id = $2;

-- name: UpdateTaskProgress :exec
-- Update a task's progress percentage and completed count.
UPDATE tasks
SET progress_pct = $3, completed_count = $4, updated_at = now()
WHERE id = $1 AND company_id = $2;

-- name: DeleteTask :exec
-- Delete a task by ID and company.
DELETE FROM tasks
WHERE id = $1 AND company_id = $2;

-- name: CreateTaskAssignment :exec
-- Assign a user to a task.
INSERT INTO task_assignments (task_id, user_id, assigned_by)
VALUES ($1, $2, $3)
ON CONFLICT (task_id, user_id) DO NOTHING;

-- name: DeleteTaskAssignment :exec
-- Remove a user assignment from a task.
DELETE FROM task_assignments
WHERE task_id = $1 AND user_id = $2;

-- name: GetTaskAssignments :many
-- Get all assignments for a task with user names.
SELECT ta.id, ta.task_id, ta.user_id, ta.assigned_by, ta.assigned_at,
       u.display_name as user_display_name
FROM task_assignments ta
JOIN users u ON u.id = ta.user_id
WHERE ta.task_id = $1;

-- name: InsertTaskVoters :copyfrom
-- Bulk insert task voters for contact_list tasks.
INSERT INTO task_voters (task_id, voter_id) VALUES ($1, $2);

-- name: GetTaskVoterCount :one
-- Get total and contacted count for a task's voters.
SELECT count(*) AS total, count(*) FILTER (WHERE is_contacted) AS contacted
FROM task_voters
WHERE task_id = $1;

-- name: MarkTaskVoterContacted :exec
-- Mark a voter as contacted on a task.
UPDATE task_voters
SET is_contacted = true, contacted_at = now()
WHERE task_id = $1 AND voter_id = $2;

-- name: RecalculateTaskProgress :exec
-- Recalculate task progress from task_voters counts.
UPDATE tasks SET
    completed_count = sub.contacted,
    progress_pct = CASE WHEN sub.total = 0 THEN 0 ELSE (sub.contacted * 100 / sub.total) END,
    status = CASE WHEN sub.contacted >= sub.total AND sub.total > 0 THEN 'completed' ELSE status END,
    updated_at = now()
FROM (
    SELECT task_id, count(*)::int AS total, count(*) FILTER (WHERE is_contacted)::int AS contacted
    FROM task_voters WHERE task_id = $1 GROUP BY task_id
) sub
WHERE tasks.id = sub.task_id AND tasks.id = $1;

-- name: GetTasksLinkedToVoter :many
-- Find active tasks linked to a voter (via task_voters or linked_entity).
SELECT DISTINCT t.* FROM tasks t
LEFT JOIN task_voters tv ON tv.task_id = t.id AND tv.voter_id = @voter_id
WHERE t.company_id = @company_id
  AND t.status IN ('open', 'in_progress')
  AND (
    tv.voter_id IS NOT NULL
    OR (t.linked_entity_type = 'voter' AND t.linked_entity_id = @voter_id)
    OR (t.linked_entity_type = 'turf' AND t.linked_entity_id = @turf_id)
  );

-- name: CreateTaskNote :one
-- Create a task note.
INSERT INTO task_notes (company_id, task_id, user_id, content, visibility)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: ListTaskNotes :many
-- List notes for a task, ordered by created_at.
SELECT * FROM task_notes
WHERE task_id = $1
ORDER BY created_at ASC;

-- name: PullTasksUpdated :many
-- Pull tasks updated since cursor for sync.
SELECT id, company_id, title, description, task_type, priority, status,
       due_date, linked_entity_type, linked_entity_id,
       progress_pct, total_count, completed_count,
       created_by, created_at, updated_at
FROM tasks
WHERE company_id = $1 AND updated_at > $2
ORDER BY updated_at ASC
LIMIT $3;

-- name: PullTaskAssignmentsUpdated :many
-- Pull task assignments for a company's tasks since cursor.
SELECT ta.id, ta.task_id, ta.user_id, ta.assigned_by, ta.assigned_at
FROM task_assignments ta
JOIN tasks t ON t.id = ta.task_id
WHERE t.company_id = $1 AND ta.assigned_at > $2
ORDER BY ta.assigned_at ASC
LIMIT $3;

-- name: PullTaskNotesUpdated :many
-- Pull task notes updated since cursor for sync.
SELECT id, company_id, task_id, user_id, content, visibility, created_at
FROM task_notes
WHERE company_id = $1 AND created_at > $2
ORDER BY created_at ASC
LIMIT $3;
