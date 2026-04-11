-- name: CreateTag :one
INSERT INTO voter_tags (company_id, name, color, created_by)
VALUES ($1, $2, $3, $4)
RETURNING *;

-- name: ListTags :many
SELECT * FROM voter_tags
WHERE company_id = $1
ORDER BY name;

-- name: GetTag :one
SELECT * FROM voter_tags WHERE id = $1;

-- name: DeleteTag :exec
DELETE FROM voter_tags WHERE id = $1 AND company_id = $2;

-- name: AssignTagToVoter :exec
INSERT INTO voter_tag_assignments (voter_id, tag_id, assigned_by)
VALUES ($1, $2, $3)
ON CONFLICT (voter_id, tag_id) DO NOTHING;

-- name: RemoveTagFromVoter :exec
DELETE FROM voter_tag_assignments
WHERE voter_id = $1 AND tag_id = $2;

-- name: GetVoterTags :many
SELECT vt.* FROM voter_tags vt
JOIN voter_tag_assignments vta ON vta.tag_id = vt.id
WHERE vta.voter_id = $1
ORDER BY vt.name;

-- name: ListVotersByTag :many
SELECT v.id, v.first_name, v.last_name, v.party, v.status,
       v.res_city, v.res_zip, v.municipality, v.year_of_birth
FROM voters v
JOIN voter_tag_assignments vta ON vta.voter_id = v.id
WHERE vta.tag_id = $1 AND v.company_id = $2
ORDER BY v.last_name, v.first_name
LIMIT $3 OFFSET $4;
