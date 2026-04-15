-- name: CreateEvent :one
-- Create a new event.
INSERT INTO events (company_id, title, description, event_type, starts_at, ends_at,
                    location_name, location_lat, location_lng, linked_turf_id, max_attendees, created_by)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
RETURNING *;

-- name: GetEvent :one
-- Get an event by ID and company.
SELECT * FROM events
WHERE id = $1 AND company_id = $2;

-- name: ListEventsByCompany :many
-- List events for a company, ordered by starts_at DESC.
SELECT * FROM events
WHERE company_id = $1
ORDER BY starts_at DESC;

-- name: UpdateEvent :one
-- Update an existing event.
UPDATE events
SET title = $3, description = $4, event_type = $5,
    starts_at = $6, ends_at = $7,
    location_name = $8, location_lat = $9, location_lng = $10,
    linked_turf_id = $11, max_attendees = $12,
    updated_at = now()
WHERE id = $1 AND company_id = $2
RETURNING *;

-- name: CancelEvent :exec
-- Cancel an event.
UPDATE events
SET status = 'cancelled', updated_at = now()
WHERE id = $1 AND company_id = $2;

-- name: RSVPEvent :one
-- Create or update an RSVP for an event.
INSERT INTO event_rsvps (event_id, user_id, status)
VALUES ($1, $2, $3)
ON CONFLICT (event_id, user_id) DO UPDATE
SET status = EXCLUDED.status
RETURNING *;

-- name: DeleteRSVP :exec
-- Delete an RSVP.
DELETE FROM event_rsvps
WHERE event_id = $1 AND user_id = $2;

-- name: CheckInEvent :one
-- Record a check-in at an event.
INSERT INTO event_checkins (event_id, user_id)
VALUES ($1, $2)
ON CONFLICT (event_id, user_id) DO NOTHING
RETURNING *;

-- name: GetEventRSVPs :many
-- Get RSVPs for an event with user display names.
SELECT er.id, er.event_id, er.user_id, er.status, er.created_at,
       u.display_name
FROM event_rsvps er
JOIN users u ON u.id = er.user_id
WHERE er.event_id = $1;

-- name: GetEventCheckins :many
-- Get check-ins for an event with user display names.
SELECT ec.id, ec.event_id, ec.user_id, ec.checked_in_at,
       u.display_name
FROM event_checkins ec
JOIN users u ON u.id = ec.user_id
WHERE ec.event_id = $1;

-- name: GetEventRSVPCount :one
-- Count RSVPs with status 'going' for an event.
SELECT COUNT(*)::int AS count FROM event_rsvps
WHERE event_id = $1 AND status = 'going';

-- name: GetEventsStartingSoon :many
-- Get events starting within the next 24 hours that are still scheduled.
SELECT * FROM events
WHERE starts_at BETWEEN now() AND now() + interval '24 hours'
  AND status = 'scheduled';

-- name: GetRSVPsNeedingReminder :many
-- Get RSVPs that need a reminder (going, not reminded within threshold).
SELECT * FROM event_rsvps
WHERE event_id = $1
  AND status = 'going'
  AND (last_reminder_sent_at IS NULL OR last_reminder_sent_at < $2);

-- name: UpdateRSVPReminderSent :exec
-- Mark an RSVP as having been sent a reminder.
UPDATE event_rsvps
SET last_reminder_sent_at = now()
WHERE id = $1;

-- name: PullEventsUpdated :many
-- Pull events updated since cursor for sync.
SELECT * FROM events
WHERE company_id = $1 AND updated_at > $2
ORDER BY updated_at ASC
LIMIT $3;

-- name: PullEventRSVPsForEvents :many
-- Pull RSVPs for a set of events (used after PullEventsUpdated).
SELECT er.* FROM event_rsvps er
JOIN events e ON e.id = er.event_id
WHERE e.company_id = $1 AND er.created_at > $2
ORDER BY er.created_at ASC
LIMIT $3;

-- name: PullTrainingMaterialsUpdated :many
-- Pull training materials updated since cursor for sync.
-- NOTE: does not filter is_published so clients see soft-deleted rows and can
-- reconcile local state (Drift DAO filters isPublished=true on the read side).
SELECT * FROM training_materials
WHERE company_id = $1 AND updated_at > $2
ORDER BY updated_at ASC
LIMIT $3;
