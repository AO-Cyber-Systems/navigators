---
objective: 08-tasks-collaboration
trd: "02"
subsystem: task-notifications
tags: [nats, firebase, fcm, push-notifications, task-progress]
dependency_graph:
  requires: [08-01]
  provides: [task-worker, fcm-dispatcher, contact-log-events, device-token-registration]
  affects: [sync_service, task_service, task_handler, main.go]
tech_stack:
  added: [firebase.google.com/go/v4, firebase.google.com/go/v4/messaging]
  patterns: [nats-consumer, event-driven-progress, graceful-degradation, stale-token-cleanup]
key_files:
  created:
    - navigators-go/internal/navigators/task_worker.go
    - navigators-go/internal/navigators/notification_service.go
  modified:
    - navigators-go/internal/navigators/sync_service.go
    - navigators-go/internal/navigators/task_service.go
    - navigators-go/internal/navigators/task_handler.go
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/cmd/server/main.go
    - navigators-go/queries/navigators/tasks.sql
    - navigators-go/proto/navigators/v1/task.proto
decisions:
  - Firebase init moved before service wiring for dependency order (NATS, Firebase, then services)
  - FCMDispatcher uses raw pgxpool queries for device_tokens (eden pgstore.Backend has no NotificationStore)
  - TaskService.AssignTask signature expanded to include companyID for task title lookup in NATS event
metrics:
  duration: 8min
  completed: "2026-04-11"
---

# Objective 08 TRD 02: NATS Task Events + Firebase Push Notifications Summary

NATS event-driven task auto-progress with SQL recalculation, Firebase Admin SDK push via SendEachForMulticast, device token registration endpoint, and reminder ticker for due-date notifications.

## What was delivered

### Task 1: NATS contact_log event emission + TaskWorker
- SyncService.processContactLog now publishes `navigators.contact_log.created` to NATS after successful upsert
- SyncService constructor updated to accept `jetstream.JetStream` (nil-safe)
- ContactLogCreatedEvent struct carries companyID, voterID, turfID, userID
- TaskWorker with 2 durable consumers: `task-progress-worker` (contact_log.created) and `task-notification-worker` (task.assigned + task.reminder)
- Progress consumer: marks voter contacted, runs RecalculateTaskProgress (idempotent SQL subquery)
- Reminder ticker: every 1 hour queries GetTasksDueSoon, publishes `navigators.task.reminder` events
- Firebase Admin SDK initialized with graceful degradation (warn log if GOOGLE_APPLICATION_CREDENTIALS missing)
- NATS connection block moved before service wiring to resolve dependency order

### Task 2: FCM dispatcher + device token registration + assignment notifications
- FCMDispatcher implements `notification.Dispatcher` (SendPush + IsEnabled)
- Uses `SendEachForMulticast` (not deprecated `SendMulticast`)
- Stale token cleanup: checks `messaging.IsRegistrationTokenNotRegistered` in batch response
- `RegisterDeviceToken` RPC added to TaskService proto
- Handler validates token/platform, calls FCMDispatcher.RegisterDeviceToken (INSERT ON CONFLICT DO NOTHING)
- Permission: `tasks:view` (Member level) for RegisterDeviceToken
- TaskService.AssignTask publishes `navigators.task.assigned` NATS event with task title
- TaskService now accepts `jetstream.JetStream` for event publishing

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] FCMDispatcher created in Task 1 instead of Task 2**
- **Found during:** Task 1
- **Issue:** main.go references `navpkg.NewFCMDispatcher` which is defined in notification_service.go (Task 2 deliverable), but needed for Task 1 compilation
- **Fix:** Created notification_service.go in Task 1 to satisfy compile dependency
- **Files modified:** navigators-go/internal/navigators/notification_service.go
- **Commit:** 1cd51a8

**2. [Rule 3 - Blocking] NATS connection defined after SyncService usage**
- **Found during:** Task 1
- **Issue:** `js` variable used in NewSyncService call before `var js jetstream.JetStream` declaration
- **Fix:** Moved NATS connection block and Firebase init before service wiring in main.go
- **Files modified:** navigators-go/cmd/server/main.go
- **Commit:** 1cd51a8

**3. [Rule 1 - Bug] AssignTask missing companyID parameter**
- **Found during:** Task 2
- **Issue:** AssignTask needed companyID to look up task title for NATS event, but original signature only had taskID/userID/assignedBy
- **Fix:** Added companyID parameter to AssignTask, updated handler to extract from context
- **Files modified:** navigators-go/internal/navigators/task_service.go, task_handler.go
- **Commit:** 728b08a

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: NATS events + TaskWorker | `cd navigators-go && go build ./cmd/server/` | 0 | PASS |
| 2: FCM + device tokens + assignment | `cd navigators-go && go build ./cmd/server/` | 0 | PASS |

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-go && go vet ./...` | 0 | PASS |
| build | `cd navigators-go && go build ./cmd/server/` | 0 | PASS |

## Post-TRD Verification

- Auto-fix cycles used: 3
- Must-haves verified: 4/4 (task_worker.go 382 lines with TaskWorker, notification_service.go 123 lines with FCMDispatcher, sync_service.go has contact_log.created, key_links patterns verified)
- Gate failures: None

## Commits

| Commit | Description |
|---|---|
| 1cd51a8 | feat(08-02): NATS contact_log event emission, TaskWorker, Firebase SDK |
| 728b08a | feat(08-02): FCM dispatcher, device token registration, task assignment notifications |
