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
