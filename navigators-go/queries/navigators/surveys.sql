-- name: CreateSurveyForm :one
-- Create a new survey form.
INSERT INTO survey_forms (company_id, title, description, schema, version, is_active, created_by)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: GetSurveyForm :one
-- Get a survey form by ID and company.
SELECT * FROM survey_forms
WHERE id = $1 AND company_id = $2;

-- name: ListActiveSurveyForms :many
-- List active survey forms for a company.
SELECT * FROM survey_forms
WHERE company_id = $1 AND is_active = true
ORDER BY created_at DESC;

-- name: UpdateSurveyForm :exec
-- Update survey form fields.
UPDATE survey_forms
SET title = $3, description = $4, schema = $5, version = $6, is_active = $7, updated_at = now()
WHERE id = $1 AND company_id = $2;

-- name: UpsertSurveyResponseFromSync :exec
-- Insert a survey response from a client sync push. Append-only: skip if already exists.
INSERT INTO survey_responses (id, company_id, form_id, form_version, voter_id, user_id, turf_id, contact_log_id, responses, created_at)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
ON CONFLICT (id) DO NOTHING;

-- name: GetSurveyResponsesForVoter :many
-- Get survey responses for a voter.
SELECT * FROM survey_responses
WHERE voter_id = $1 AND company_id = $2
ORDER BY created_at DESC;
