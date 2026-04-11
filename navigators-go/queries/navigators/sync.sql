-- name: GetSyncTurfAssignments :many
-- Returns turf info with boundary and voter count for a user's assigned turfs.
SELECT
    t.id as turf_id,
    t.name as turf_name,
    ST_AsGeoJSON(t.boundary) as boundary_geojson,
    (SELECT COUNT(*) FROM voters v
     WHERE v.company_id = t.company_id
       AND v.location IS NOT NULL
       AND v.geocode_status = 'success'
       AND ST_Contains(t.boundary, v.location))::bigint as voter_count
FROM turf_assignments ta
JOIN turfs t ON t.id = ta.turf_id
WHERE ta.user_id = $1
  AND t.is_active = true;

-- name: UpsertSyncServerCursor :exec
INSERT INTO sync_server_cursors (user_id, entity_type, last_cursor)
VALUES ($1, $2, $3)
ON CONFLICT (user_id, entity_type) DO UPDATE
SET last_cursor = EXCLUDED.last_cursor;

-- name: GetSyncServerCursor :one
SELECT last_cursor FROM sync_server_cursors
WHERE user_id = $1 AND entity_type = $2;

-- name: CheckSyncOperationProcessed :one
-- Check if a client sync operation has already been processed (idempotency).
SELECT EXISTS(
  SELECT 1 FROM sync_received_operations
  WHERE client_operation_id = $1 AND company_id = $2
);

-- name: RecordSyncOperationProcessed :exec
-- Record a processed sync operation for idempotency tracking.
INSERT INTO sync_received_operations (client_operation_id, user_id, company_id, entity_type, entity_id, operation_type)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT DO NOTHING;

-- name: UpsertContactLogFromSync :exec
-- Insert a contact log from a client sync push. Append-only: skip if already exists.
INSERT INTO contact_logs (id, company_id, voter_id, user_id, turf_id, contact_type, outcome, notes, door_status, sentiment, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
ON CONFLICT (id) DO NOTHING;

-- name: UpdateVoterUpdatedAtFromSync :exec
-- Update voter updated_at timestamp from a client sync push using LWW (last-write-wins).
-- Only updates if the client's timestamp is newer than the server's current updated_at.
-- Actual field updates are handled in Go code via raw pgxpool for flexibility.
UPDATE voters
SET updated_at = now()
WHERE id = $1 AND company_id = $2
  AND updated_at < $3;

-- name: PullSurveyForms :many
-- Pull active survey forms updated since cursor.
SELECT id, company_id, title, description, schema, version, is_active, created_by, created_at, updated_at
FROM survey_forms
WHERE company_id = $1 AND is_active = true AND updated_at > $2
ORDER BY updated_at ASC
LIMIT $3;

-- name: PullSurveyResponses :many
-- Pull survey responses created since cursor, scoped to turfs.
SELECT id, company_id, form_id, form_version, voter_id, user_id, turf_id, contact_log_id, responses, created_at
FROM survey_responses
WHERE company_id = $1 AND turf_id = ANY($2::uuid[]) AND created_at > $3
ORDER BY created_at ASC
LIMIT $4;
