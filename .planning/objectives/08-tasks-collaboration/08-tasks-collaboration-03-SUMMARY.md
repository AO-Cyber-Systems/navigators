---
objective: 08-tasks-collaboration
job: "03"
subsystem: ui
tags: [flutter, firebase-messaging, fcm, push-notifications, flutter-local-notifications, riverpod, drift, tasks]

# Dependency graph
requires:
  - objective: 08-tasks-collaboration-01
    provides: "Drift task/task_assignment/task_note tables and TaskDao"
  - objective: 08-tasks-collaboration-02
    provides: "Server-side task CRUD, auto-progress, FCM push notifications, RegisterDeviceToken RPC"
provides:
  - "TaskListScreen with filters and offline-first Drift streams"
  - "TaskDetailScreen with progress, notes, linked items"
  - "TaskCreateScreen with full form for Admin/Super Nav"
  - "NotificationService for FCM init, token registration, foreground/background messages"
  - "TaskService API client for task CRUD"
  - "PUSH-03 local sync alert on reconnect with pending outbox data"
  - "Tasks tab in bottom navigation"
affects: [09-analytics-reporting]

# Tech tracking
tech-stack:
  added: [firebase_core ^3.12.1, firebase_messaging ^15.2.5, flutter_local_notifications ^18.0.1]
  patterns: [graceful-firebase-degradation, push03-local-notification, top-level-background-handler]

key-files:
  created:
    - navigators-flutter/lib/src/features/tasks/task_list_screen.dart
    - navigators-flutter/lib/src/features/tasks/task_detail_screen.dart
    - navigators-flutter/lib/src/features/tasks/task_create_screen.dart
    - navigators-flutter/lib/src/services/notification_service.dart
    - navigators-flutter/lib/src/services/task_service.dart
  modified:
    - navigators-flutter/lib/src/app.dart
    - navigators-flutter/lib/main.dart
    - navigators-flutter/pubspec.yaml
    - navigators-flutter/lib/src/sync/sync_engine.dart
    - navigators-flutter/lib/src/sync/sync_scheduler.dart
    - navigators-flutter/lib/src/database/daos/sync_dao.dart

key-decisions:
  - "Firebase init commented out pending flutterfire configure -- graceful degradation pattern"
  - "SyncEngine.db made public (was _db) for SyncScheduler PUSH-03 access"
  - "SyncDao.getPendingCount added as one-shot Future for PUSH-03 (vs countPending stream)"
  - "Tasks tab visible for all roles; FAB for create visible only for Manager/60+ roles"

patterns-established:
  - "Firebase graceful degradation: wrap init in try-catch, disable push features if not configured, app continues"
  - "PUSH-03 pattern: check outbox count on connectivity reconnect, show flutter_local_notifications alert"
  - "Top-level FCM background handler with @pragma('vm:entry-point')"

requirements-completed: [PUSH-03]

# Verification evidence
verification:
  gates_defined: 1
  gates_passed: 1
  auto_fix_cycles: 1
  tdd_evidence: false
  test_pairing: false

# Metrics
duration: 8min
completed: 2026-04-11
---

# Objective 8 TRD 03: Flutter Task UI, Push Notifications, and PUSH-03 Summary

**Task list/detail/create screens with Drift offline streams, FCM push notification service with graceful degradation, local sync alert (PUSH-03) on reconnect, and Tasks tab in bottom navigation**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-11T18:42:02Z
- **Completed:** 2026-04-11T18:49:57Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- TaskListScreen with filter chips (All/Open/In Progress/Completed), priority badges, progress bars, and offline-first Drift streams
- TaskDetailScreen with progress bar, due date highlighting, linked items, assignments, notes section with offline-capable add-note
- TaskCreateScreen with full form (title, description, type, priority, due date, entity linking, multi-select assignees)
- NotificationService handling FCM init, token registration, foreground/background messages, graceful degradation if Firebase not configured
- TaskService API client for task CRUD via ConnectRPC JSON protocol
- PUSH-03: SyncScheduler checks outbox pending count on reconnect, shows local notification via flutter_local_notifications
- Tasks tab added to bottom navigation for all authenticated roles

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Firebase setup, NotificationService, TaskService, PUSH-03 | `cd navigators-flutter && flutter pub get && dart analyze` | 0 | PASS |
| 2: Task UI screens and Tasks tab | `cd navigators-flutter && dart analyze` | 0 | PASS |

## Task Commits

Each task was committed atomically:

1. **Task 1: Firebase setup, NotificationService, TaskService, PUSH-03** - `b89e5f6` (feat)
2. **Task 2: Task UI screens and Tasks tab** - `b7c622d` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| build | `cd navigators-flutter && flutter pub get && dart run build_runner build --delete-conflicting-outputs && dart analyze` | 0 | PASS |

## Post-TRD Verification

- **Auto-fix cycles used:** 1 (SyncEngine._db renamed to public db for SyncScheduler PUSH-03 access)
- **Must-haves verified:** 6/6
- **Gate failures:** None

## Files Created/Modified
- `navigators-flutter/lib/src/features/tasks/task_list_screen.dart` - Task inbox with filters, priority badges, progress bars (313 lines)
- `navigators-flutter/lib/src/features/tasks/task_detail_screen.dart` - Full task detail with progress, notes, linked items (537 lines)
- `navigators-flutter/lib/src/features/tasks/task_create_screen.dart` - Task creation form for Admin/Super Nav (309 lines)
- `navigators-flutter/lib/src/services/notification_service.dart` - FCM init, token registration, foreground/background messages, PUSH-03 (215 lines)
- `navigators-flutter/lib/src/services/task_service.dart` - ConnectRPC API client for task CRUD (113 lines)
- `navigators-flutter/lib/src/app.dart` - Added Tasks tab and TaskListScreen to navigation
- `navigators-flutter/lib/main.dart` - Added FCM background handler and Firebase init placeholder
- `navigators-flutter/pubspec.yaml` - Added firebase_core, firebase_messaging, flutter_local_notifications
- `navigators-flutter/lib/src/sync/sync_engine.dart` - Made db field public for scheduler access
- `navigators-flutter/lib/src/sync/sync_scheduler.dart` - Added PUSH-03 sync alert on reconnect
- `navigators-flutter/lib/src/database/daos/sync_dao.dart` - Added getPendingCount for PUSH-03

## Decisions Made
- Firebase.initializeApp commented out pending user running `flutterfire configure` -- app gracefully degrades without push
- SyncEngine._db renamed to public `db` field so SyncScheduler can access syncDao.getPendingCount for PUSH-03
- Added SyncDao.getPendingCount as one-shot Future (vs existing countPending stream) for non-reactive use in connectivity handler
- Tasks tab visible for all roles; FAB for task creation only shown for role >= Manager/60 (super_navigator, admin)
- Used DropdownButtonFormField.initialValue (not deprecated .value) for Flutter 3.33+ compatibility

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Made SyncEngine.db public for PUSH-03 access**
- **Found during:** Task 1 (PUSH-03 sync alert)
- **Issue:** SyncScheduler needed to access syncDao.getPendingCount via SyncEngine, but _db was private
- **Fix:** Renamed _db to db (public field), updated all internal references
- **Files modified:** navigators-flutter/lib/src/sync/sync_engine.dart
- **Verification:** dart analyze passes with no errors
- **Committed in:** b89e5f6 (Task 1 commit)

**2. [Rule 2 - Missing Critical] Added SyncDao.getPendingCount method**
- **Found during:** Task 1 (PUSH-03 sync alert)
- **Issue:** SyncDao only had countPending() stream, no one-shot Future for connectivity handler
- **Fix:** Added getPendingCount() Future<int> method using same query pattern
- **Files modified:** navigators-flutter/lib/src/database/daos/sync_dao.dart
- **Verification:** dart analyze passes
- **Committed in:** b89e5f6 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 missing critical)
**Impact on plan:** Both necessary for PUSH-03 implementation. No scope creep.

## Issues Encountered
None

## User Setup Required

**Firebase requires manual configuration.** After this TRD:
1. Run `cd navigators-flutter && flutterfire configure` to generate `firebase_options.dart`
2. Uncomment `Firebase.initializeApp()` in `main.dart` and `_firebaseMessagingBackgroundHandler`
3. Enable Push Notifications capability in Xcode: Runner -> Signing & Capabilities -> + Push Notifications
4. App works without Firebase configured -- push features gracefully disabled

## Next Objective Readiness
- Objective 08 (Tasks & Collaboration) is complete: server CRUD + auto-progress (TRD 01), events + push (TRD 02), Flutter UI + notifications (TRD 03)
- Ready for Objective 09 (Analytics & Reporting)

---
*Objective: 08-tasks-collaboration*
*Completed: 2026-04-11*
