-- name: GetContactStats :one
-- Scoped contact metrics with date range.
SELECT
    COUNT(*) FILTER (WHERE contact_type = 'door_knock') AS doors_knocked,
    COUNT(*) FILTER (WHERE contact_type = 'phone') AS calls_made,
    COUNT(*) FILTER (WHERE contact_type = 'text') AS texts_sent,
    COUNT(DISTINCT CASE WHEN outcome NOT IN ('', 'not_home', 'refused') THEN voter_id END) AS successful_contacts,
    COUNT(DISTINCT voter_id) AS unique_voters,
    COUNT(*) FILTER (WHERE sentiment = 1) AS sentiment_1,
    COUNT(*) FILTER (WHERE sentiment = 2) AS sentiment_2,
    COUNT(*) FILTER (WHERE sentiment = 3) AS sentiment_3,
    COUNT(*) FILTER (WHERE sentiment = 4) AS sentiment_4,
    COUNT(*) FILTER (WHERE sentiment = 5) AS sentiment_5
FROM contact_logs
WHERE company_id = @company_id
  AND created_at >= @since
  AND created_at < @until
  AND (@user_id::uuid IS NULL OR user_id = @user_id)
  AND (@turf_ids::uuid[] IS NULL OR turf_id = ANY(@turf_ids));

-- name: GetContactTrendDay :many
-- Daily contact counts for trend charts.
SELECT
    date_trunc('day', created_at AT TIME ZONE 'America/New_York')::date AS day,
    COUNT(*) AS total_contacts,
    COUNT(*) FILTER (WHERE contact_type = 'door_knock') AS door_knocks,
    COUNT(*) FILTER (WHERE contact_type = 'phone') AS calls,
    COUNT(*) FILTER (WHERE contact_type = 'text') AS texts
FROM contact_logs
WHERE company_id = @company_id
  AND created_at >= @since
  AND created_at < @until
  AND (@user_id::uuid IS NULL OR user_id = @user_id)
  AND (@turf_ids::uuid[] IS NULL OR turf_id = ANY(@turf_ids))
GROUP BY day
ORDER BY day;

-- name: GetContactTrendWeek :many
-- Weekly contact counts for trend charts.
SELECT
    date_trunc('week', created_at AT TIME ZONE 'America/New_York')::date AS day,
    COUNT(*) AS total_contacts,
    COUNT(*) FILTER (WHERE contact_type = 'door_knock') AS door_knocks,
    COUNT(*) FILTER (WHERE contact_type = 'phone') AS calls,
    COUNT(*) FILTER (WHERE contact_type = 'text') AS texts
FROM contact_logs
WHERE company_id = @company_id
  AND created_at >= @since
  AND created_at < @until
  AND (@user_id::uuid IS NULL OR user_id = @user_id)
  AND (@turf_ids::uuid[] IS NULL OR turf_id = ANY(@turf_ids))
GROUP BY day
ORDER BY day;

-- name: GetNavigatorPerformance :many
-- Per-navigator metrics for team/admin performance view.
SELECT
    cl.user_id,
    COUNT(*) FILTER (WHERE cl.contact_type = 'door_knock') AS doors_knocked,
    COUNT(*) FILTER (WHERE cl.contact_type = 'phone') AS calls_made,
    COUNT(*) FILTER (WHERE cl.contact_type = 'text') AS texts_sent,
    COUNT(*) AS total_contacts,
    COUNT(DISTINCT CASE WHEN cl.outcome NOT IN ('', 'not_home', 'refused') THEN cl.voter_id END) AS successful_contacts,
    COUNT(DISTINCT cl.voter_id) AS unique_voters
FROM contact_logs cl
WHERE cl.company_id = @company_id
  AND cl.created_at >= @since
  AND cl.created_at < @until
  AND (@turf_ids::uuid[] IS NULL OR cl.turf_id = ANY(@turf_ids))
GROUP BY cl.user_id
ORDER BY total_contacts DESC;

-- name: GetTaskStats :one
-- Task completion summary.
SELECT
    COUNT(*) AS total_tasks,
    COUNT(*) FILTER (WHERE status = 'completed') AS completed_tasks
FROM tasks
WHERE company_id = @company_id
  AND (@user_id::uuid IS NULL OR created_by = @user_id);

-- name: GetAnalyticsTurfSummaries :many
-- Per-turf voter/contacted counts for dashboard.
SELECT
    t.id AS turf_id,
    t.name AS turf_name,
    COALESCE(s.total_voters, 0) AS voter_count,
    COALESCE(s.contacted_voters, 0) AS contacted_count
FROM turfs t
LEFT JOIN LATERAL (
    SELECT
        COUNT(DISTINCT v.id) AS total_voters,
        COUNT(DISTINCT cl.voter_id) AS contacted_voters
    FROM voters v
    LEFT JOIN contact_logs cl ON cl.voter_id = v.id AND cl.company_id = @company_id
    WHERE v.company_id = @company_id
      AND v.location IS NOT NULL
      AND ST_Contains(t.boundary, v.location)
) s ON true
WHERE t.company_id = @company_id
  AND t.is_active = true
  AND (@turf_ids::uuid[] IS NULL OR t.id = ANY(@turf_ids))
ORDER BY t.name;

-- name: GetDisplayNames :many
-- Lookup display names for users in a company.
SELECT u.id, u.display_name
FROM users u
JOIN company_memberships cm ON cm.user_id = u.id
WHERE cm.company_id = @company_id;

-- name: GetExportContacts :many
-- Export contact log rows with voter and turf names.
SELECT
    cl.created_at,
    v.first_name AS voter_first_name,
    v.last_name AS voter_last_name,
    cl.contact_type,
    cl.outcome,
    cl.sentiment,
    u.display_name AS navigator_name,
    t.name AS turf_name
FROM contact_logs cl
LEFT JOIN voters v ON v.id = cl.voter_id
LEFT JOIN users u ON u.id = cl.user_id
LEFT JOIN turfs t ON t.id = cl.turf_id
WHERE cl.company_id = @company_id
  AND cl.created_at >= @since
  AND cl.created_at < @until
  AND (@user_id::uuid IS NULL OR cl.user_id = @user_id)
  AND (@turf_ids::uuid[] IS NULL OR cl.turf_id = ANY(@turf_ids))
ORDER BY cl.created_at DESC;

-- name: GetExportVoters :many
-- Export voter data.
SELECT
    v.id,
    v.first_name,
    v.last_name,
    v.res_street_address,
    v.res_city,
    v.res_zip,
    v.party,
    v.status,
    v.registration_date
FROM voters v
WHERE v.company_id = @company_id
  AND (@turf_ids::uuid[] IS NULL OR EXISTS (
    SELECT 1 FROM turfs t
    WHERE t.id = ANY(@turf_ids)
      AND v.location IS NOT NULL
      AND ST_Contains(t.boundary, v.location)
  ))
ORDER BY v.last_name, v.first_name;

-- name: GetExportTasks :many
-- Export task data.
SELECT
    t.title,
    t.task_type,
    t.status,
    t.priority,
    t.progress_pct,
    t.due_date,
    u.display_name AS created_by_name,
    t.created_at
FROM tasks t
LEFT JOIN users u ON u.id = t.created_by
WHERE t.company_id = @company_id
  AND (@user_id::uuid IS NULL OR t.created_by = @user_id)
ORDER BY t.created_at DESC;
