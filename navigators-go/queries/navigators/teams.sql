-- name: GetTeamTurfIDs :many
-- Returns all turf IDs for all navigators assigned to a super navigator.
SELECT DISTINCT ta.turf_id
FROM team_assignments tea
JOIN turf_assignments ta ON ta.user_id = tea.navigator_id
WHERE tea.super_navigator_id = $1;

-- name: GetTeamNavigators :many
SELECT tea.navigator_id, u.email, u.display_name
FROM team_assignments tea
JOIN users u ON u.id = tea.navigator_id
WHERE tea.super_navigator_id = $1;

-- name: AssignNavigatorToTeam :exec
INSERT INTO team_assignments (super_navigator_id, navigator_id, company_id, assigned_by)
VALUES ($1, $2, $3, $4)
ON CONFLICT (super_navigator_id, navigator_id) DO NOTHING;

-- name: RemoveNavigatorFromTeam :exec
DELETE FROM team_assignments WHERE super_navigator_id = $1 AND navigator_id = $2;
