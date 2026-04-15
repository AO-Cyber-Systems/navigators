-- name: CreateCallScript :one
-- Create a new call script.
INSERT INTO call_scripts (company_id, title, content, version, is_active, created_by)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetCallScript :one
-- Get a call script by ID and company.
SELECT * FROM call_scripts
WHERE id = $1 AND company_id = $2;

-- name: ListActiveCallScripts :many
-- List active call scripts for a company.
SELECT * FROM call_scripts
WHERE company_id = $1 AND is_active = true
ORDER BY created_at DESC;

-- name: UpdateCallScript :exec
-- Update call script fields.
UPDATE call_scripts
SET title = $3, content = $4, version = $5, is_active = $6, updated_at = now()
WHERE id = $1 AND company_id = $2;

-- name: DeactivateCallScript :exec
-- Soft-delete a call script by setting is_active=false.
-- Pull-sync propagates the row with updated_at bump so clients hide it.
UPDATE call_scripts
SET is_active = false, updated_at = now()
WHERE id = $1 AND company_id = $2;

-- name: GetCallScriptCurrentVersion :one
-- Fetch the current version number for optimistic increment on update.
SELECT version FROM call_scripts
WHERE id = $1 AND company_id = $2;

-- name: ListAllCallScripts :many
-- List ALL call scripts (active + inactive) for the admin management view.
SELECT * FROM call_scripts
WHERE company_id = $1
ORDER BY updated_at DESC;

-- name: PullCallScriptsUpdated :many
-- Pull call scripts updated since cursor for sync.
SELECT id, company_id, title, content, version, is_active, created_by, created_at, updated_at
FROM call_scripts
WHERE company_id = $1 AND updated_at > $2
ORDER BY updated_at ASC
LIMIT $3;
