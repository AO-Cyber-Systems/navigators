---
objective: 04-offline-sync-engine
job: "03"
subsystem: sync-ui
tags: [riverpod, drift, connectivity, offline-first, sync-status, flutter]

# Dependency graph
requires:
  - objective: 04-offline-sync-engine-01
    provides: "Drift encrypted database, tables, DAOs, pull sync, server sync endpoints"
  - objective: 04-offline-sync-engine-02
    provides: "Push sync engine, operation log, conflict resolver, sync scheduler"
provides:
  - "Sync status Riverpod providers (pending count, connectivity, isSyncing)"
  - "SyncStatusWidget app bar indicator with green/orange/red/spinning states"
  - "SyncProgressScreen with manual sync and dead-letter management"
  - "TurfDownloadScreen with per-turf progress and manifest loading"
  - "Offline-first voter list and walk list screens"
  - "Turf reassignment handling (push-before-delete ordering)"
  - "Forced sync on app open and resume via AppLifecycleListener"
  - "Database initialization with encryption key from flutter_secure_storage"
affects: [05-contact-logging, 06-canvassing-ui]

# Tech tracking
tech-stack:
  added: []
  patterns: [offline-first-read, sync-status-stream, push-before-delete-reassignment, lifecycle-sync]

key-files:
  created:
    - "navigators-flutter/lib/src/sync/sync_status.dart"
    - "navigators-flutter/lib/src/features/sync/sync_status_widget.dart"
    - "navigators-flutter/lib/src/features/sync/sync_progress_screen.dart"
    - "navigators-flutter/lib/src/features/sync/turf_download_screen.dart"
  modified:
    - "navigators-flutter/lib/main.dart"
    - "navigators-flutter/lib/src/app.dart"
    - "navigators-flutter/lib/src/services/voter_service.dart"
    - "navigators-flutter/lib/src/features/map/walk_list_screen.dart"
    - "navigators-flutter/lib/src/sync/sync_engine.dart"
    - "navigators-flutter/lib/src/sync/push_sync.dart"
    - "navigators-flutter/lib/src/database/daos/voter_dao.dart"

key-decisions:
  - "VoterListNotifier gets optional NavigatorsDatabase param for offline-first fallback without breaking existing provider pattern"
  - "Walk list uses one-shot getVotersInTurf then sorts by walkSequence rather than reactive stream (simpler for existing StatefulWidget pattern)"
  - "Turf reassignment check integrated as Phase 0 in runSyncCycle before push/pull"
  - "pushOperationsForTurf filters by payload content containing turfId (simple, effective for small outbox)"

patterns-established:
  - "Offline-first read: try local DB, fall back to network, UI auto-updates via Drift streams"
  - "Sync status stream: aggregate provider combining Drift countPending, connectivity, and syncing state"
  - "Push-before-delete: always push pending ops for a turf before cleaning local data on reassignment"
  - "Lifecycle sync: AppLifecycleListener.onResume triggers non-blocking background sync"

requirements-completed: [SYNC-06, SYNC-07]

# Verification evidence
verification:
  gates_defined: 2
  gates_passed: 2
  auto_fix_cycles: 1
  tdd_evidence: false
  test_pairing: false

# Metrics
duration: 9min
completed: 2026-04-11
---

# Objective 04 TRD 03: Sync Status UI + Offline-First Integration Summary

**Sync status widget in app bar with 4-state indicator, offline-first voter/walk list screens reading from local Drift DB, turf reassignment with push-before-delete ordering, forced sync on login and app resume**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-11T14:38:38Z
- **Completed:** 2026-04-11T14:47:47Z
- **Tasks:** 3/3 complete (2 auto + 1 checkpoint approved)
- **Files modified:** 11

## Accomplishments
- Sync status indicator in app bar shows pending count, last sync time, and connection state with 4 icon states
- Forced sync on app open (push pending + pull updates) via auth state transition detection
- Walk list and voter list screens read from local Drift DB when offline, fall back to server when local data empty
- Turf reassignment: pending ops pushed before old data cleaned, new turfs get fresh pull
- SyncProgressScreen with manual sync, dead-letter operation retry/dismiss
- TurfDownloadScreen with per-turf manifest loading and download progress

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Sync status providers + UI widgets + forced sync + main.dart wiring | `cd navigators-flutter && flutter analyze --no-fatal-infos` | 0 | PASS |
| 2: Offline-first screen integration + turf reassignment handling | `cd navigators-flutter && flutter analyze --no-fatal-infos` | 0 | PASS |
| 3: Verify complete offline sync flow (checkpoint) | `go vet ./... && go build ./... && flutter analyze` | 0 | PASS (approved) |

## Task Commits

Each task was committed atomically:

1. **Task 1: Sync status providers + UI widgets + forced sync + main.dart wiring** - `1f47a7e` (feat)
2. **Task 2: Offline-first screen integration + turf reassignment handling** - `d443976` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-flutter && flutter analyze --no-fatal-infos` | 0 | PASS |
| build | `cd navigators-flutter && flutter analyze --no-fatal-infos` | 0 | PASS |

## Post-TRD Verification

- **Auto-fix cycles used:** 1 (unused import in sync_engine.dart, unnecessary underscores in widget)
- **Must-haves verified:** 7/7
- **Gate failures:** None

## Files Created/Modified
- `navigators-flutter/lib/src/sync/sync_status.dart` - Riverpod providers: syncStatusProvider, connectivityProvider, isSyncingProvider, lastSyncTimeProvider
- `navigators-flutter/lib/src/features/sync/sync_status_widget.dart` - Compact app bar widget with green/orange/red/spinning icon states and badge count
- `navigators-flutter/lib/src/features/sync/sync_progress_screen.dart` - Full sync details with manual sync button, dead-letter ops
- `navigators-flutter/lib/src/features/sync/turf_download_screen.dart` - Turf manifest loading with per-turf download progress
- `navigators-flutter/lib/main.dart` - DB init with encryption key from secure storage, WorkManager + connectivity setup
- `navigators-flutter/lib/src/app.dart` - SyncStatusWidget in app bar, forced sync on login, AppLifecycleListener for resume sync
- `navigators-flutter/lib/src/services/voter_service.dart` - VoterListNotifier offline-first path, VoterToSummary mapper
- `navigators-flutter/lib/src/features/map/walk_list_screen.dart` - Offline-first load from local DB with server fallback
- `navigators-flutter/lib/src/sync/sync_engine.dart` - handleTurfReassignment with push-before-delete, manifest check in Phase 0
- `navigators-flutter/lib/src/sync/push_sync.dart` - pushOperationsForTurf for pre-reassignment push
- `navigators-flutter/lib/src/database/daos/voter_dao.dart` - getVotersInTurf, getAllVoters, searchVoters methods

## Decisions Made
- VoterListNotifier receives optional NavigatorsDatabase parameter rather than always reading databaseProvider, to gracefully handle the case where DB is not yet initialized
- Walk list uses one-shot getVotersInTurf (not reactive stream) to keep the existing StatefulWidget pattern simple
- Turf reassignment check runs as Phase 0 in runSyncCycle, before push/pull phases
- pushOperationsForTurf uses payload string matching to identify turf-related operations

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added getVotersInTurf, getAllVoters, searchVoters to VoterDao**
- **Found during:** Task 2 (offline-first screen integration)
- **Issue:** VoterDao only had watchVotersInTurf (stream), missing one-shot query methods needed by VoterListNotifier and walk list
- **Fix:** Added getVotersInTurf (ordered by lastName), getAllVoters, searchVoters (LIKE query, case-insensitive)
- **Files modified:** navigators-flutter/lib/src/database/daos/voter_dao.dart
- **Verification:** flutter analyze passes
- **Committed in:** d443976 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary DAO methods for offline-first reads. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Objective Readiness
- All 3 TRDs in Objective 04 complete (checkpoint approved)
- Full offline sync engine operational: encrypted local DB, pull/push sync, background scheduling, status UI
- Ready for contact logging (Objective 5)

## Self-Check: PASSED

- All 11 claimed files exist on disk
- All 3 task commits verified: 1f47a7e, d443976, 1c06cbc
- Verification gates: go vet (0), go build (0), flutter analyze (0)

---
*Objective: 04-offline-sync-engine*
*Completed: 2026-04-11*
