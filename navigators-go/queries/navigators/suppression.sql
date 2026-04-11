-- name: AddToSuppressionList :exec
INSERT INTO suppression_list (company_id, voter_id, reason, added_by)
VALUES ($1, $2, $3, $4)
ON CONFLICT (company_id, voter_id) DO UPDATE SET
    reason = EXCLUDED.reason,
    added_by = EXCLUDED.added_by,
    added_at = now();

-- name: RemoveFromSuppressionList :exec
DELETE FROM suppression_list
WHERE company_id = $1 AND voter_id = $2;

-- name: IsVoterSuppressed :one
SELECT EXISTS(
    SELECT 1 FROM suppression_list WHERE company_id = $1 AND voter_id = $2
) AS is_suppressed;

-- name: ListSuppressedVoters :many
SELECT s.id, s.voter_id, s.reason, s.added_by, s.added_at,
       v.first_name, v.last_name, v.res_street_address, v.res_city, v.res_state, v.res_zip
FROM suppression_list s
JOIN voters v ON v.id = s.voter_id
WHERE s.company_id = $1
ORDER BY s.added_at DESC
LIMIT $2 OFFSET $3;

-- name: CountSuppressedVoters :one
SELECT COUNT(*) FROM suppression_list WHERE company_id = $1;
