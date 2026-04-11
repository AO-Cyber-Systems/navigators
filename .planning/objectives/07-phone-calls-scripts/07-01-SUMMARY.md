---
objective: 07-phone-calls-scripts
job: "01"
subsystem: database, api, sync
tags: [call-scripts, phone-calls, drift, sqlc, protobuf, pull-sync]

requires:
  - objective: 05-door-knocking
    provides: survey_forms pattern, contact_logs table, door_status column
  - objective: 04-offline-sync
    provides: sync engine, cursor-based pull sync, Drift database

provides:
  - call_scripts table (server + local)
  - CallScriptService CRUD
  - PullCallScripts sync RPC
  - Extended door_status CHECK for phone dispositions (voicemail, no_answer, busy)
  - CallScriptDao with upsert/getActive/watchActive
  - Drift schema version 3

affects: [07-02-phone-call-ui]

tech-stack:
  added: []
  patterns:
    - "Call scripts follow survey_forms pull-sync pattern exactly"
    - "door_status reused for phone dispositions (no separate call_status column)"

key-files:
  created:
    - navigators-go/migrations/navigators/014_phone_calls.up.sql
    - navigators-go/queries/navigators/call_scripts.sql
    - navigators-go/internal/navigators/call_script_service.go
    - navigators-flutter/lib/src/database/tables/call_scripts.dart
    - navigators-flutter/lib/src/database/daos/call_script_dao.dart
  modified:
    - navigators-go/internal/navigators/sync_service.go
    - navigators-go/internal/navigators/sync_handler.go
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/proto/navigators/v1/sync.proto
    - navigators-go/cmd/server/main.go
    - navigators-flutter/lib/src/database/database.dart
    - navigators-flutter/lib/src/sync/pull_sync.dart
    - navigators-flutter/lib/src/sync/sync_engine.dart

key-decisions:
  - "Call scripts use TEXT content (not JSONB schema like surveys) with {{variable}} interpolation at display time"
  - "door_status CHECK extended with voicemail/no_answer/busy; answered/refused shared between door knock and phone"
  - "PullCallScriptsUpdated query returns all scripts (not just is_active=true) so client can mark deactivated scripts"

patterns-established:
  - "Call scripts mirror survey_forms pattern: admin-created, company-scoped, pull-synced"

requirements-completed: [CALL-03]

verification:
  gates_defined: 3
  gates_passed: 3
  auto_fix_cycles: 0
  tdd_evidence: false
  test_pairing: false

duration: 6min
completed: 2026-04-11
---

# Objective 07 TRD 01: Call Scripts Backend + Phone Call Data Layer Summary

**CallScriptService CRUD with migration 014, PullCallScripts sync RPC, Drift table/DAO, extended door_status CHECK for phone dispositions**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-11T17:38:49Z
- **Completed:** 2026-04-11T17:45:16Z
- **Tasks:** 2
- **Files modified:** 19

## Accomplishments
- Migration 014 creates call_scripts table and extends door_status CHECK with phone values (voicemail, no_answer, busy)
- CallScriptService with Create/List/Update CRUD, wired into SyncService for PullCallScripts
- PullCallScripts RPC defined in proto, implemented in sync handler, permission-mapped
- Drift CallScripts table + CallScriptDao with upsert/getActive/watchActive, schema version 3
- Full pull sync integration: SyncClient, pullAllCallScripts cursor loop, SyncEngine wiring

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Server migration, sqlc, service, proto, sync | `cd navigators-go && sqlc compile && go build ./...` | 0 | PASS |
| 2: Flutter Drift table, DAO, database, pull sync | `cd navigators-flutter && dart run build_runner build --delete-conflicting-outputs && dart analyze` | 0 | PASS |

## Task Commits

Each task was committed atomically:

1. **Task 1: Server migration, sqlc, CallScriptService, proto, sync** - `4eace24` (feat)
2. **Task 2: Flutter Drift table, DAO, pull sync** - `2e984df` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-flutter && dart analyze` | 0 | PASS (12 pre-existing infos only) |
| test | `cd navigators-go && go test ./...` | 0 | PASS (no test files) |
| build | `cd navigators-go && go build ./...` | 0 | PASS |

## Post-TRD Verification

- **Auto-fix cycles used:** 0
- **Must-haves verified:** 3/3
  - Admin can create a call script with title and content via the server (CallScriptService.CreateCallScript)
  - Call scripts pull-sync to Flutter local database (PullCallScripts RPC + pullAllCallScripts + CallScriptDao.upsertCallScripts)
  - Phone call contact logs use door_status column with extended CHECK (voicemail, no_answer, busy added)
- **Gate failures:** None

## Files Created/Modified
- `navigators-go/migrations/navigators/014_phone_calls.up.sql` - call_scripts table + extended door_status CHECK
- `navigators-go/migrations/navigators/014_phone_calls.down.sql` - Rollback migration
- `navigators-go/queries/navigators/call_scripts.sql` - sqlc queries (Create, Get, ListActive, Update, PullUpdated)
- `navigators-go/internal/navigators/call_script_service.go` - CallScriptService CRUD
- `navigators-go/internal/navigators/permissions.go` - FeatureCallScripts + PullCallScripts procedure permission
- `navigators-go/proto/navigators/v1/sync.proto` - PullCallScripts RPC + SyncCallScript message
- `navigators-go/internal/navigators/sync_service.go` - SyncCallScriptRow, PullCallScripts method, callScriptService field
- `navigators-go/internal/navigators/sync_handler.go` - PullCallScripts handler
- `navigators-go/cmd/server/main.go` - Wire CallScriptService into SyncService
- `navigators-flutter/lib/src/database/tables/call_scripts.dart` - Drift CallScripts table
- `navigators-flutter/lib/src/database/daos/call_script_dao.dart` - CallScriptDao with upsert/getActive/watchActive
- `navigators-flutter/lib/src/database/database.dart` - Schema version 3, CallScripts table + CallScriptDao
- `navigators-flutter/lib/src/sync/pull_sync.dart` - pullCallScripts RPC, pullAllCallScripts, SyncCallScriptData model
- `navigators-flutter/lib/src/sync/sync_engine.dart` - pulledCallScripts in SyncResult, wired into runSyncCycle

## Decisions Made
- Call scripts use TEXT content (not JSONB schema like surveys) with {{variable}} interpolation at display time (Flutter side)
- door_status CHECK extended with voicemail/no_answer/busy; answered/refused shared between door knock and phone
- PullCallScriptsUpdated query returns all scripts (not just is_active=true) so client can detect deactivated scripts during sync

## Deviations from Plan

None - TRD executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Objective Readiness
- Call scripts data layer complete, ready for TRD 07-02 phone call UI
- door_status CHECK supports all phone dispositions needed for call screen
- Pull sync integration means call scripts will be available offline on devices

---
*Objective: 07-phone-calls-scripts*
*Completed: 2026-04-11*
