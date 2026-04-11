-- name: UpsertVoterNoteFromSync :exec
-- Insert a voter note from a client sync push. Append-only: skip if already exists.
INSERT INTO voter_notes (id, company_id, voter_id, user_id, turf_id, content, visibility, created_at, updated_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
ON CONFLICT (id) DO NOTHING;

-- name: GetVoterNotesForVoterByRole :many
-- Get voter notes for a voter, scoped by role level.
-- $3 = role_level (int), $4 = requesting user_id
-- Admin (>=80) sees all notes for the voter.
-- SuperNav (>=60) sees 'org' + 'team' notes for the voter.
-- Navigator (<60) sees 'org' notes + own notes.
SELECT * FROM voter_notes
WHERE voter_id = $1 AND company_id = $2
  AND (
    -- Admin sees all
    $3 >= 80
    -- SuperNav sees org + team
    OR ($3 >= 60 AND visibility IN ('org', 'team'))
    -- Navigator sees org + own
    OR (visibility = 'org')
    OR (user_id = $4)
  )
ORDER BY created_at DESC;
