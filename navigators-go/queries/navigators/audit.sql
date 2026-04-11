-- name: LogVoterAccess :exec
INSERT INTO voter_access_log (company_id, user_id, voter_id, access_type, turf_id, details, ip_address)
VALUES ($1, $2, $3, $4, $5, $6, $7);

-- name: ListVoterAccessLogs :many
SELECT val.id, val.user_id, u.email as user_email, val.voter_id,
       val.access_type, val.turf_id, t.name as turf_name,
       val.details, val.ip_address, val.created_at
FROM voter_access_log val
JOIN users u ON u.id = val.user_id
LEFT JOIN turfs t ON t.id = val.turf_id
WHERE val.company_id = $1
ORDER BY val.created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListVoterAccessLogsByUser :many
SELECT val.id, val.voter_id, val.access_type, val.turf_id,
       val.details, val.ip_address, val.created_at
FROM voter_access_log val
WHERE val.company_id = $1 AND val.user_id = $2
ORDER BY val.created_at DESC
LIMIT $3 OFFSET $4;

-- name: CountVoterAccessLogs :one
SELECT COUNT(*) FROM voter_access_log WHERE company_id = $1;
