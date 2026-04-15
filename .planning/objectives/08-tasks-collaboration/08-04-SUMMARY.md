---
objective: 08-tasks-collaboration
trd: "04"
subsystem: notifications
tags: [gap-closure, firebase-removal, local-notifications]
gap_closure: true
requirements: [PUSH-01, PUSH-02, PUSH-03]
dependency_graph:
  requires: []
  provides:
    - Local-only NotificationService (flutter_local_notifications)
  affects:
    - TaskService proto (RegisterDeviceToken removed)
    - TaskWorker / EventWorker (no dispatcher)
    - navigators-go module graph (firebase.google.com/go/v4 removed)
tech_stack:
  removed:
    - firebase.google.com/go/v4 (Go)
    - firebase_core ^3.12.1 (Flutter)
    - firebase_messaging ^15.2.5 (Flutter)
  kept:
    - flutter_local_notifications ^18.0.1
  patterns:
    - Local-only notifications (no remote push)
key_files:
  deleted:
    - navigators-go/internal/navigators/notification_service.go
  rewritten:
    - navigators-flutter/lib/src/services/notification_service.dart
  modified:
    - navigators-go/proto/navigators/v1/task.proto
    - navigators-go/internal/navigators/task_handler.go
    - navigators-go/internal/navigators/task_worker.go
    - navigators-go/internal/navigators/event_worker.go
    - navigators-go/internal/navigators/task_service.go
    - navigators-go/internal/navigators/event_service.go
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/cmd/server/main.go
    - navigators-go/go.mod
    - navigators-go/go.sum
    - navigators-flutter/pubspec.yaml
    - navigators-flutter/pubspec.lock
    - navigators-flutter/macos/Flutter/GeneratedPluginRegistrant.swift
    - navigators-flutter/windows/flutter/generated_plugin_registrant.cc
    - navigators-flutter/windows/flutter/generated_plugins.cmake
    - .planning/STATE.md
decisions:
  - Remote push descoped entirely; PUSH-01/02/03 reinterpreted as local-only notifications
  - device_tokens table in eden-platform-go is shared infra -- no navigators migration to drop it
  - RegisterDeviceToken RPC removed from proto contract (not kept as no-op) to match reality
  - EventWorker retained as a thin stub that only creates the JetStream stream; no consumers
metrics:
  duration: ~25 min
  completed: 2026-04-13
---

# Objective 08 TRD 04: Firebase/FCM Removal (Gap Closure) Summary

Remove Firebase/FCM entirely from Navigators (Go + Flutter) and replace with local-only notifications via `flutter_local_notifications`.

## What Changed

### Go backend (navigators-go)

- **Deleted** `internal/navigators/notification_service.go` (was 100% FCMDispatcher).
- **Proto:** removed `RegisterDeviceToken` RPC and its request/response messages from `task.proto`; regenerated via `buf generate` (re-wrote `task.pb.go` and `task.connect.go`).
- **TaskHandler:** dropped `fcmDispatcher` field, constructor param, and the `RegisterDeviceToken` method.
- **TaskWorker:** removed the `dispatcher` field, the notification consumer (`taskAssignedSubject` + `taskReminderSubject`), `reminderTicker` / `publishReminders`, `handleAssigned` / `handleReminder`, `getDeviceTokens`, and the `notification` eden import. **Preserved** `consumeProgress` and `processContactLogCreated` — task auto-progress from `contact_log.created` still works.
- **EventWorker:** stripped the dispatcher, reminder consumer, ticker, and helpers. Kept as a thin wrapper that creates the `NAVIGATORS_EVENTS` JetStream stream so future in-app consumers can attach cleanly.
- **TaskService.AssignTask / EventService.RSVPEvent:** removed the `task.assigned` and `event.rsvp` publish blocks (no consumer remained).
- **permissions.go:** dropped the `/navigators.v1.TaskService/RegisterDeviceToken` route.
- **main.go:** deleted the Firebase Admin SDK init block, the `firebase.google.com/go/v4` import, and the `notification` eden import. Updated `NewTaskHandler`, `NewTaskWorker`, `NewEventWorker` call sites to drop the dispatcher arg.
- **go.mod / go.sum:** `firebase.google.com/go/v4` no longer appears after `go mod tidy`.

### Flutter app (navigators-flutter)

- **pubspec.yaml:** removed `firebase_core` and `firebase_messaging`. Kept `flutter_local_notifications`.
- **notification_service.dart:** full rewrite as local-only. Preserved public API: `NotificationService` class name, `notificationServiceProvider` export, `showSyncAlert(int)` signature. Drops all FCM permission requests, token registration, foreground/background message handlers. Adds `showTaskNotification(id, title, body)` for future local triggers.
- **Plugin registrants:** `flutter pub get` regenerated linux/macos/windows registrant files — firebase plugins absent.
- **main.dart:** already contained no active Firebase code (Firebase.initializeApp was never wired).

### Why no DB migration

The `device_tokens` table lives in `eden-platform-go` (`migrations/platform/008_device_tokens.up.sql`), not in navigators-go. It is shared infrastructure potentially used by other eden apps. Intentionally left alone. No navigators migration created.

## PUSH-01/02/03 Reinterpretation

| Req    | Original intent              | New (local-only) behavior                                     |
| ------ | ---------------------------- | ------------------------------------------------------------- |
| PUSH-01| Task assignment remote push  | Surfaced in-app via `ListTasks` / pull sync. No remote push.  |
| PUSH-02| Task reminder remote push    | Surfaced in-app on Tasks tab. No reminder ticker, no push.    |
| PUSH-03| Sync-ready local alert       | **Unchanged** — `showSyncAlert(int)` via local notifications. |

If real-time remote push is ever required, a new objective (`11-push-notifications` or similar) will re-introduce Firebase cleanly. Do NOT re-add piecemeal.

## Task Evidence

| Task | Verify Command                                                    | Exit | Status |
| ---- | ----------------------------------------------------------------- | ---- | ------ |
| 1    | `go build ./... && go vet ./... && grep -rn firebase\|FCM\|fcm\|device_token\|RegisterDeviceToken` | 0 build, grep empty | PASS |
| 2    | `flutter pub get && flutter analyze && grep firebase lib/ pubspec.yaml` | 0 analyze (only pre-existing infos), grep empty | PASS |
| 3    | Repo-wide grep across .go/.dart/.proto/.yaml/go.mod/.cmake/.cc/.swift | empty | PASS |

## Validation Gate Results

| Gate  | Command                                    | Exit | Status |
| ----- | ------------------------------------------ | ---- | ------ |
| lint  | `flutter analyze`                          | 0    | PASS (15 pre-existing infos, 0 errors) |
| build | `go build ./...` + `flutter pub get`       | 0    | PASS   |

## Post-TRD Verification

- Auto-fix cycles used: 1 (removed orphaned publish blocks in task_service.go / event_service.go after worker rewrite; dropped unused imports).
- Must-haves verified: 5 / 5.
  - [x] No Firebase/FCM code or dep remains in Navigators.
  - [x] Local notifications via flutter_local_notifications.
  - [x] Server builds without Firebase Admin SDK and device_tokens code path.
  - [x] RegisterDeviceToken RPC removed from proto and Flutter call sites.
  - [x] PUSH-01/02/03 reinterpreted as local-only.
- Gate failures: None.

## Deviations from Plan

**1. [Rule 3 - blocking] Removed publish blocks in task_service.go / event_service.go**

- Found during: Task 1 (go build after worker rewrite).
- Issue: `task_service.AssignTask` and `event_service.RSVPEvent` referenced the deleted constants/types (`TaskAssignedEvent`, `taskAssignedSubject`, `EventRSVPEvent`, `eventRSVPSubject`).
- Fix: Removed the publish-to-NATS blocks entirely (no subscriber remained) and dropped now-unused `encoding/json` / `log/slog` imports. Added a comment explaining the descoping.

**2. [Rule 3 - blocking] Removed RegisterDeviceToken route from permissions.go**

- Found during: Task 1.
- Issue: `permissions.go` had a procedure permissions entry for the removed RPC.
- Fix: Deleted the one-line entry.

## Self-Check: PASSED

- `navigators-go/internal/navigators/notification_service.go`: MISSING (intentional — deleted).
- `navigators-flutter/lib/src/services/notification_service.dart`: FOUND (rewritten, 107 lines).
- Repo-wide grep (code only): empty — confirmed.
- `go build ./...`: exit 0.
- `go vet ./...`: exit 0.
- `flutter analyze`: exit 0 (no errors).

## Commits

- `refactor(08-04): strip Firebase/FCM from Go backend` (landed in HEAD alongside related Go changes)
- `refactor(08-04): strip Firebase from Flutter; rewrite NotificationService local-only`
- (This SUMMARY + STATE.md update as a final metadata commit.)
