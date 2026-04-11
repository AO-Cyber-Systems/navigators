---
objective: 04-offline-sync-engine
job: "02"
subsystem: sync
tags: [push-sync, outbox, workmanager, connectivity, lww, idempotent, conflict-resolution]

requires:
  - objective: 04-offline-sync-engine-01
    provides: "Drift encrypted DB, sync_operations table, SyncDao, PullSync client, SyncService proto+handler"
provides:
  - "PushSync engine (reads outbox, batches to server via PushSyncBatch)"
  - "SyncEngine (orchestrates push-then-pull cycle)"
  - "SyncScheduler (WorkManager periodic + connectivity_plus foreground with jitter)"
  - "ConflictResolver (LWW for voter metadata, append-only for contact logs)"
  - "Server PushSyncBatch with idempotent upserts"
  - "Migration 011: sync_received_operations table"
affects: [04-offline-sync-engine-03, 05-field-operations]

tech-stack:
  added: [workmanager, connectivity_plus, internet_connection_checker_plus]
  patterns: [transactional-outbox, push-then-pull, lww-conflict-resolution, idempotent-upsert, jitter-reconnect]

key-files:
  created:
    - navigators-flutter/lib/src/sync/push_sync.dart
    - navigators-flutter/lib/src/sync/sync_engine.dart
    - navigators-flutter/lib/src/sync/sync_scheduler.dart
    - navigators-flutter/lib/src/sync/conflict_resolver.dart
    - navigators-go/migrations/navigators/011_sync_push.up.sql
    - navigators-go/migrations/navigators/011_sync_push.down.sql
  modified:
    - navigators-flutter/lib/src/database/daos/sync_dao.dart
    - navigators-flutter/lib/src/database/daos/contact_log_dao.dart
    - navigators-flutter/lib/src/sync/pull_sync.dart
    - navigators-go/internal/navigators/sync_handler.go
    - navigators-go/internal/navigators/sync_service.go
    - navigators-go/queries/navigators/sync.sql

key-decisions:
  - "Voter metadata LWW uses UpdateVoterUpdatedAtFromSync (timestamp-only update) since voters table has no notes column; field-specific updates handled via raw pgxpool"
  - "ExistingPeriodicWorkPolicy.keep for WorkManager (not ExistingWorkPolicy which is for one-time tasks)"
  - "SyncEngine.instance static field for access from connectivity listener and WorkManager isolate"

patterns-established:
  - "Transactional outbox: writeWithOutbox ensures data + outbox entry in single transaction"
  - "Push-then-pull: SyncEngine always pushes first to avoid overwriting server data"
  - "Jitter reconnect: 0-60s random delay on connectivity restore to prevent sync storms"
  - "Idempotent server upserts: client_operation_id keyed INSERT ON CONFLICT for dedup"

requirements-completed: [SYNC-04, SYNC-05]

verification:
  gates_defined: 3
  gates_passed: 3
  auto_fix_cycles: 1
  tdd_evidence: false
  test_pairing: false

duration: 43min
completed: 2026-04-11
---

# Objective 04 TRD 02: Push Sync Engine Summary

**Push sync engine with transactional outbox writes, batched PushSyncBatch RPC, server-side idempotent upserts with LWW conflict resolution, and WorkManager + connectivity_plus background scheduling with jitter**

## Performance

- **Duration:** 43 min
- **Started:** 2026-04-11T13:51:45Z
- **Completed:** 2026-04-11T14:34:45Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments
- Transactional outbox pattern: every contact log write atomically enqueues a sync_operations entry
- PushSync reads outbox in FIFO order, batches up to 50, sends via PushSyncBatch RPC with retry/dead-letter handling
- SyncEngine orchestrates push-then-pull cycle with internet connectivity check and mutex lock
- SyncScheduler: WorkManager 15min periodic background sync + connectivity_plus foreground sync with 0-60s jitter
- Server PushSyncBatch processes operations idempotently via sync_received_operations tracking table
- Contact logs append-only (INSERT ON CONFLICT DO NOTHING); voter metadata uses LWW with server timestamps

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Push sync engine + transactional outbox + conflict resolver (Flutter) | `cd navigators-flutter && flutter analyze --no-fatal-infos` | 0 | PASS |
| 2: Server PushSyncBatch handler + idempotency + conflict resolution (Go) | `cd navigators-go && go build ./...` | 0 | PASS |

## Task Commits

Each task was committed atomically:

1. **Task 1: Push sync engine + transactional outbox + conflict resolver** - `aca457d` (feat)
2. **Task 2: Server PushSyncBatch handler + idempotency + conflict resolution** - `68de7d7` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-flutter && flutter analyze --no-fatal-infos` | 0 | PASS |
| test | `cd navigators-go && go test ./...` | 0 | PASS |
| build | `cd navigators-go && go build ./...` | 0 | PASS |

## Post-TRD Verification

- **Auto-fix cycles used:** 1 (ExistingWorkPolicy -> ExistingPeriodicWorkPolicy, removed unnecessary cast, removed unnecessary dart:typed_data import)
- **Must-haves verified:** 6/6
- **Gate failures:** None

## Files Created/Modified
- `navigators-flutter/lib/src/sync/push_sync.dart` - Reads sync_operations outbox, batches to server via PushSyncBatch RPC
- `navigators-flutter/lib/src/sync/sync_engine.dart` - Orchestrates full sync cycle: push pending, then pull updates
- `navigators-flutter/lib/src/sync/sync_scheduler.dart` - WorkManager + connectivity_plus integration for background/foreground sync
- `navigators-flutter/lib/src/sync/conflict_resolver.dart` - LWW conflict resolution for voter metadata, append-only for contact logs
- `navigators-flutter/lib/src/database/daos/sync_dao.dart` - Added writeWithOutbox, resetToPending, markFailedWithRetry, getRetriableFailedOperations, getDeadLetterOperations, resetInProgressToPending
- `navigators-flutter/lib/src/database/daos/contact_log_dao.dart` - Added insertContactLogWithOutbox for transactional write with outbox
- `navigators-flutter/lib/src/sync/pull_sync.dart` - Added pushSyncBatch method to SyncClient
- `navigators-go/migrations/navigators/011_sync_push.up.sql` - sync_received_operations table + voters.updated_at index
- `navigators-go/migrations/navigators/011_sync_push.down.sql` - Rollback for migration 011
- `navigators-go/internal/navigators/sync_handler.go` - PushSyncBatch handler implementation (replaces stub)
- `navigators-go/internal/navigators/sync_service.go` - PushSyncBatch service with idempotent upserts, LWW, processContactLog, processVoterMetadata
- `navigators-go/queries/navigators/sync.sql` - CheckSyncOperationProcessed, RecordSyncOperationProcessed, UpsertContactLogFromSync, UpdateVoterUpdatedAtFromSync

## Decisions Made
- Voter metadata LWW uses timestamp-only update (UpdateVoterUpdatedAtFromSync) since voters table has no `notes` column. The existing `updated_at` from migration 005 is sufficient for LWW resolution. Field-specific voter metadata updates can be added when needed.
- Used `ExistingPeriodicWorkPolicy.keep` (not `ExistingWorkPolicy.keep`) for WorkManager periodic tasks -- the API changed in workmanager 0.9.x.
- SyncEngine uses static `instance` field for access from connectivity listener and WorkManager isolate callback. Thread-safe via `_isSyncing` flag.
- Migration 011 does NOT add `updated_at` to voters (already exists from 005). Only adds the composite index on `(company_id, updated_at)` for LWW query performance.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed WorkManager ExistingPeriodicWorkPolicy type mismatch**
- **Found during:** Task 1 (flutter analyze)
- **Issue:** TRD specified `ExistingWorkPolicy.keep` but periodic tasks require `ExistingPeriodicWorkPolicy`
- **Fix:** Changed to `ExistingPeriodicWorkPolicy.keep` and removed deprecated `isInDebugMode` parameter
- **Files modified:** navigators-flutter/lib/src/sync/sync_scheduler.dart
- **Verification:** flutter analyze passes with no issues
- **Committed in:** aca457d (Task 1 commit)

**2. [Rule 1 - Bug] Removed unnecessary cast in contact_log_dao.dart**
- **Found during:** Task 1 (flutter analyze)
- **Issue:** `attachedDatabase as NavigatorsDatabase` unnecessary cast -- DatabaseAccessor already typed
- **Fix:** Removed the `as NavigatorsDatabase` cast
- **Files modified:** navigators-flutter/lib/src/database/daos/contact_log_dao.dart
- **Committed in:** aca457d (Task 1 commit)

**3. [Rule 1 - Bug] Adjusted UpdateVoterMetadataFromSync query for actual schema**
- **Found during:** Task 2 (sqlc queries)
- **Issue:** TRD query referenced `voters.notes` column which does not exist in migration 005
- **Fix:** Changed to `UpdateVoterUpdatedAtFromSync` which only updates the timestamp (LWW marker)
- **Files modified:** navigators-go/queries/navigators/sync.sql
- **Committed in:** 68de7d7 (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (1 blocking, 2 bugs)
**Impact on plan:** All necessary for correctness. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Objective Readiness
- Push + pull sync cycle fully wired. TRD 04-03 can build on this for sync status UI, manual sync triggers, and sync health monitoring.
- Server migration 011 ready to apply when deploying.
- WorkManager requires Android-side setup in AndroidManifest.xml (already done by workmanager package, but worth verifying in integration).

---
*Objective: 04-offline-sync-engine*
*Completed: 2026-04-11*
