-- name: GetNavigatorProfile :one
-- Get a navigator profile by user_id and company_id.
SELECT * FROM navigator_profiles
WHERE user_id = $1 AND company_id = $2;

-- name: UpsertNavigatorProfile :one
-- Create or update a navigator profile (initial profile creation).
INSERT INTO navigator_profiles (user_id, company_id)
VALUES ($1, $2)
ON CONFLICT (user_id) DO UPDATE
SET updated_at = now()
RETURNING *;

-- name: UpdateLegalAcknowledgment :exec
-- Record a legal acknowledgment with version string for audit.
UPDATE navigator_profiles
SET legal_acknowledgment_at = now(),
    legal_acknowledgment_version = $2,
    updated_at = now()
WHERE user_id = $1;

-- name: CompleteOnboarding :one
-- Mark onboarding as complete, gating app access.
UPDATE navigator_profiles
SET onboarding_completed_at = now(),
    updated_at = now()
WHERE user_id = $1
RETURNING *;

-- name: UpdateLeaderboardOptIn :exec
-- Toggle leaderboard participation.
UPDATE navigator_profiles
SET leaderboard_opt_in = $2,
    updated_at = now()
WHERE user_id = $1;

-- name: GetLeaderboard :many
-- Aggregated leaderboard query for opted-in navigators within a company and time window.
SELECT
    np.user_id,
    u.display_name,
    COALESCE(SUM(CASE WHEN cl.contact_type = 'door_knock' THEN 1 ELSE 0 END), 0)::int AS doors_knocked,
    COALESCE(SUM(CASE WHEN cl.contact_type = 'text' THEN 1 ELSE 0 END), 0)::int AS texts_sent,
    COALESCE(SUM(CASE WHEN cl.contact_type = 'phone' THEN 1 ELSE 0 END), 0)::int AS calls_made,
    COALESCE(COUNT(cl.id), 0)::int AS total_actions,
    COALESCE((SELECT COUNT(*) FROM event_checkins ec
              JOIN events e ON e.id = ec.event_id
              WHERE ec.user_id = np.user_id
                AND e.company_id = $1
                AND ec.checked_in_at >= $2), 0)::int AS events_attended
FROM navigator_profiles np
JOIN users u ON u.id = np.user_id
LEFT JOIN contact_logs cl ON cl.user_id = np.user_id
    AND cl.company_id = $1
    AND cl.created_at >= $2
WHERE np.company_id = $1
  AND np.leaderboard_opt_in = true
GROUP BY np.user_id, u.display_name
ORDER BY total_actions DESC;

-- name: ListTrainingMaterials :many
-- List published training materials for a company, ordered by sort_order.
SELECT * FROM training_materials
WHERE company_id = $1 AND is_published = true
ORDER BY sort_order;

-- name: CreateTrainingMaterial :one
-- Create a new training material entry.
INSERT INTO training_materials (company_id, title, description, content_url, sort_order, created_by)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetTrainingMaterial :one
-- Get a training material by ID.
SELECT * FROM training_materials
WHERE id = $1;

-- name: UpdateTrainingMaterial :one
-- Update mutable fields on a training material scoped by company.
UPDATE training_materials
SET title = $3,
    description = $4,
    sort_order = $5,
    is_published = $6,
    updated_at = now()
WHERE id = $1 AND company_id = $2
RETURNING *;

-- name: SoftDeleteTrainingMaterial :exec
-- Soft-delete a training material by flipping is_published to false.
UPDATE training_materials
SET is_published = false,
    updated_at = now()
WHERE id = $1 AND company_id = $2;
