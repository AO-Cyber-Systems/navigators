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

-- name: CreateTurfWithBoundary :one
INSERT INTO turfs (company_id, name, description, boundary)
VALUES (@company_id, @name, @description, ST_ForcePolygonCCW(ST_GeomFromGeoJSON(@boundary_geojson)))
RETURNING id, company_id, name, description, is_active,
    ST_AsGeoJSON(boundary) as boundary_geojson,
    ST_Y(ST_Centroid(boundary)) as center_lat,
    ST_X(ST_Centroid(boundary)) as center_lng,
    ST_Area(boundary::geography) as area_sq_meters,
    created_at, updated_at;

-- name: UpdateTurfBoundary :one
UPDATE turfs
SET boundary = ST_ForcePolygonCCW(ST_GeomFromGeoJSON(@boundary_geojson)),
    updated_at = now()
WHERE id = @turf_id AND company_id = @company_id
RETURNING id, company_id, name, description, is_active,
    ST_AsGeoJSON(boundary) as boundary_geojson,
    ST_Y(ST_Centroid(boundary)) as center_lat,
    ST_X(ST_Centroid(boundary)) as center_lng,
    ST_Area(boundary::geography) as area_sq_meters,
    created_at, updated_at;

-- name: GetTurfByID :one
SELECT t.id, t.company_id, t.name, t.description, t.is_active,
    ST_AsGeoJSON(t.boundary) as boundary_geojson,
    ST_Y(ST_Centroid(t.boundary)) as center_lat,
    ST_X(ST_Centroid(t.boundary)) as center_lng,
    ST_Area(t.boundary::geography) as area_sq_meters,
    (SELECT COUNT(*) FROM voters v
     WHERE v.company_id = t.company_id
       AND v.location IS NOT NULL
       AND v.geocode_status = 'success'
       AND ST_Contains(t.boundary, v.location))::bigint as voter_count,
    t.created_at, t.updated_at
FROM turfs t
WHERE t.id = @turf_id AND t.company_id = @company_id;

-- name: GetTurfsByCompanyWithBoundary :many
SELECT t.id, t.company_id, t.name, t.description, t.is_active,
    ST_AsGeoJSON(t.boundary) as boundary_geojson,
    ST_Y(ST_Centroid(t.boundary)) as center_lat,
    ST_X(ST_Centroid(t.boundary)) as center_lng,
    ST_Area(t.boundary::geography) as area_sq_meters,
    (SELECT COUNT(*) FROM voters v
     WHERE v.company_id = t.company_id
       AND v.location IS NOT NULL
       AND v.geocode_status = 'success'
       AND ST_Contains(t.boundary, v.location))::bigint as voter_count,
    t.created_at, t.updated_at
FROM turfs t
WHERE t.company_id = @company_id AND t.is_active = true;

-- name: CountVotersInTurf :one
SELECT COUNT(*) FROM voters v
JOIN turfs t ON t.id = @turf_id
WHERE v.company_id = @company_id
  AND v.location IS NOT NULL
  AND v.geocode_status = 'success'
  AND ST_Contains(t.boundary, v.location);

-- name: GetTurfCompletionStats :one
SELECT
    COUNT(DISTINCT v.id)::bigint as total_voters,
    COUNT(DISTINCT cl.voter_id)::bigint as contacted_voters
FROM voters v
JOIN turfs t ON t.id = @turf_id
LEFT JOIN contact_logs cl ON cl.voter_id = v.id AND cl.turf_id = @turf_id
WHERE v.company_id = @company_id
  AND v.location IS NOT NULL
  AND v.geocode_status = 'success'
  AND ST_Contains(t.boundary, v.location);
