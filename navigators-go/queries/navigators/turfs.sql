-- name: GetUserTurfIDs :many
SELECT turf_id FROM turf_assignments WHERE user_id = $1;

-- name: GetTurfsByCompany :many
SELECT id, company_id, name, description, is_active, created_at, updated_at
FROM turfs WHERE company_id = $1 AND is_active = true;

-- name: CreateTurf :one
INSERT INTO turfs (company_id, name, description)
VALUES ($1, $2, $3)
RETURNING id, company_id, name, description, is_active, created_at, updated_at;

-- name: AssignUserToTurf :exec
INSERT INTO turf_assignments (turf_id, user_id, assigned_by)
VALUES ($1, $2, $3)
ON CONFLICT (turf_id, user_id) DO NOTHING;

-- name: RemoveUserFromTurf :exec
DELETE FROM turf_assignments WHERE turf_id = $1 AND user_id = $2;

-- name: GetTurfAssignmentsForUser :many
SELECT ta.turf_id, t.name as turf_name
FROM turf_assignments ta
JOIN turfs t ON t.id = ta.turf_id
WHERE ta.user_id = $1;
