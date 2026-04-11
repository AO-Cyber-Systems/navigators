---
objective: 10-volunteer-management-events
trd: "01"
subsystem: backend
tags: [volunteer, events, onboarding, leaderboard, training, nats, fcm]
dependency_graph:
  requires: [obj-08-tasks, obj-09-analytics]
  provides: [volunteer-backend, event-backend, training-backend]
  affects: [sync-service, permissions, main-wiring]
tech_stack:
  added: []
  patterns: [event-worker-ticker, minio-presigned-url, leaderboard-aggregation]
key_files:
  created:
    - navigators-go/migrations/navigators/016_volunteer_events.up.sql
    - navigators-go/migrations/navigators/016_volunteer_events.down.sql
    - navigators-go/proto/navigators/v1/volunteer.proto
    - navigators-go/proto/navigators/v1/event.proto
    - navigators-go/queries/navigators/volunteers.sql
    - navigators-go/queries/navigators/events.sql
    - navigators-go/internal/navigators/volunteer_service.go
    - navigators-go/internal/navigators/volunteer_handler.go
    - navigators-go/internal/navigators/event_service.go
    - navigators-go/internal/navigators/event_handler.go
    - navigators-go/internal/navigators/event_worker.go
  modified:
    - navigators-go/proto/navigators/v1/sync.proto
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/internal/navigators/sync_service.go
    - navigators-go/internal/navigators/sync_handler.go
    - navigators-go/cmd/server/main.go
decisions:
  - "Leaderboard uses aggregation over contact_logs + event_checkins with time window param (week/month/all_time)"
  - "Training materials use MinIO presigned URLs with 15-minute expiry"
  - "EventWorker uses separate NAVIGATORS_EVENTS NATS stream (not shared with tasks)"
  - "Event reminders dedup via last_reminder_sent_at on event_rsvps (2-hour threshold)"
  - "GetLeaderboard sqlc param named CheckedInAt (from subquery column name) -- works correctly"
metrics:
  duration: "12 min"
  completed: "2026-04-11"
  tasks: 2
  files: 25
---

# Objective 10 TRD 01: Volunteer Management & Events Backend Summary

Backend infrastructure for volunteer onboarding, event management, leaderboards, and training materials with NATS event reminders and sync endpoints.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | c376ba5 | Migration 016, proto definitions, sqlc queries for volunteer/event management |
| 2 | a892e5f | Go services, handlers, event worker, sync endpoints, and main.go wiring |

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|------|---------------|-----------|--------|
| 1: Migration/Proto/sqlc | `cd navigators-go && sqlc generate` | 0 | PASS |
| 1: Proto generation | `cd navigators-go && buf generate proto` | 0 | PASS |
| 2: Go build | `cd navigators-go && go build ./...` | 0 | PASS |
| 2: Go vet | `cd navigators-go && go vet ./...` | 0 | PASS |
| 2: Handler count | `grep -c "mux.Handle" cmd/server/main.go` = 17 | 0 | PASS |
| 2: Permission entries | grep confirms all 4 services in permissions.go | 0 | PASS |

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|------|---------|-----------|--------|
| lint | `cd navigators-go && go vet ./...` | 0 | PASS |
| build | `cd navigators-go && go build ./...` | 0 | PASS |

## What Was Built

### Migration 016 (5 tables)
- `navigator_profiles` -- user_id PK, onboarding_completed_at, legal_acknowledgment_at+version, leaderboard_opt_in
- `events` -- CRUD with event_type (canvass/phone_bank/meeting/other), status, location, linked_turf_id
- `event_rsvps` -- going/maybe/declined with last_reminder_sent_at for dedup
- `event_checkins` -- unique per event+user
- `training_materials` -- MinIO content_url, sort_order, is_published

### Proto Services (4 new)
- **OnboardingService** -- GetOnboardingStatus, AcknowledgeLegal (version string for audit), CompleteOnboarding, UpdateLeaderboardOptIn
- **LeaderboardService** -- GetLeaderboard with time_window (week/month/all_time) aggregating contact_logs + event_checkins
- **TrainingService** -- ListTrainingMaterials, CreateTrainingMaterial (role-gated), GetTrainingDownloadUrl (MinIO presigned)
- **EventService** -- Full CRUD, RSVPEvent, CheckInEvent, GetEventAttendance

### Sync Extensions
- PullEvents + PullTrainingMaterials added to SyncService proto and handler
- Cursor-based pagination following existing PullTasks pattern

### Event Worker
- NAVIGATORS_EVENTS NATS stream with navigators.event.> subjects
- 1-hour reminder ticker queries GetEventsStartingSoon (24h window)
- GetRSVPsNeedingReminder with 2-hour dedup threshold via last_reminder_sent_at
- FCM push via notification.Dispatcher with graceful degradation

### Permissions
- OnboardingService: all RPCs require authenticated (Member/40)
- LeaderboardService: view requires authenticated
- TrainingService: view for all, create requires Manager/60
- EventService: create/update/cancel require Manager/60, view/RSVP/check-in require Member/40

## Deviations from Plan

None -- TRD executed exactly as written.

## Post-TRD Verification

- Auto-fix cycles used: 0
- Must-haves verified: 9/9
- Gate failures: None
