---
objective: 02-voter-data-pipeline
job: "03"
subsystem: backend, flutter-ui
tags: [suppression-list, voter-profile, flutter-screens, riverpod, connectrpc, file-upload, minio]

# Dependency graph
requires:
  - objective: 02-voter-data-pipeline-01
    provides: "Voters table, import pipeline, geocoding, VoterService, ImportService"
  - objective: 02-voter-data-pipeline-02
    provides: "Search/filter endpoints, tag system, turf scoping, audit service"
provides:
  - "Suppression list backend (migration, service, RPCs)"
  - "Fail-closed IsVoterSuppressed gating check"
  - "Enhanced GetVoter with is_suppressed and tags"
  - "Flutter VoterListScreen with search, filters, pagination"
  - "Flutter VoterDetailScreen with full voter profile display"
  - "Flutter ImportScreen with file upload and progress tracking"
  - "Flutter VoterService and ImportService (ConnectRPC JSON)"
  - "Bottom navigation with admin-gated Import tab"
affects: [03-offline-sync, 04-canvassing, 06-sms-outreach]

# Tech tracking
tech-stack:
  added: [file_picker, http, intl]
  patterns: [ConnectRPC JSON protocol from Flutter, Riverpod StateNotifier for search/list/import state, presigned URL file upload, fail-closed suppression check]

key-files:
  created:
    - navigators-go/migrations/navigators/008_suppression.up.sql
    - navigators-go/internal/navigators/suppression_service.go
    - navigators-go/queries/navigators/suppression.sql
    - navigators-flutter/lib/src/services/voter_service.dart
    - navigators-flutter/lib/src/services/import_service.dart
    - navigators-flutter/lib/src/features/voters/voter_list_screen.dart
    - navigators-flutter/lib/src/features/voters/voter_detail_screen.dart
    - navigators-flutter/lib/src/features/voters/voter_search_bar.dart
    - navigators-flutter/lib/src/features/voters/voter_filter_panel.dart
    - navigators-flutter/lib/src/features/import/import_screen.dart
    - navigators-flutter/lib/src/features/import/import_progress_card.dart
  modified:
    - navigators-go/proto/navigators/v1/voter.proto
    - navigators-go/internal/navigators/voter_handler.go
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/cmd/server/main.go
    - navigators-flutter/lib/src/app.dart
    - navigators-flutter/pubspec.yaml

key-decisions:
  - "Suppression RPCs added to VoterService (not separate service) -- keeps voter domain cohesive"
  - "IsVoterSuppressed fails closed (returns true on error) to prevent outreach to potentially suppressed voters"
  - "Flutter services use ConnectRPC JSON protocol (POST with JSON body) rather than gRPC -- simpler for web/mobile"
  - "Import screen uses presigned URL upload (PUT to MinIO) -- keeps Go server out of data path for large files"
  - "Bottom nav with admin-gated Import tab (role check via auth.role)"

patterns-established:
  - "Flutter ConnectRPC pattern: POST to /service.Package/Method with JSON body, Bearer token header"
  - "Riverpod StateNotifier pattern for paginated lists with loadMore() and refresh()"
  - "FutureProvider.family for detail screens (voter detail by ID)"
  - "Admin-gated UI tabs via auth.role check in bottom navigation"

requirements-completed: [VOTER-05, VOTER-09]

# Verification evidence
verification:
  gates_defined: 2
  gates_passed: 2
  auto_fix_cycles: 0
  tdd_evidence: false
  test_pairing: false

# Metrics
duration: 9min
completed: 2026-04-10
---

# Objective 02 TRD 03: Voter Profile, Suppression List, and Flutter UI Summary

**Suppression list with fail-closed gating, voter profile enrichment (is_suppressed + tags), and full Flutter UI for voter search/detail/import with admin-only import tab**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-11T01:08:41Z
- **Completed:** 2026-04-11T01:17:43Z
- **Tasks:** 2/2 auto tasks completed (checkpoint pending)
- **Files modified:** 22

## Accomplishments
- Suppression list migration + SuppressionService with fail-closed IsVoterSuppressed check and audit logging
- GetVoter response enriched with is_suppressed flag and voter tags (single RPC for full profile)
- Flutter VoterListScreen with debounced search, multi-filter panel (party, status, districts, vote count), pagination with load-more
- Flutter VoterDetailScreen displaying all Maine 21-A permitted fields including voting history, tags, and suppression status
- Flutter ImportScreen with file picker, source type selector (CVR/L2), presigned URL upload, and ImportProgressCard with real-time polling

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Suppression list backend + voter profile enhancements | `cd navigators-go && buf generate && sqlc generate && go build ./... && go vet ./...` | 0 | PASS |
| 2: Flutter voter list, detail, and import screens | `cd navigators-flutter && flutter pub get && flutter analyze` | 0 | PASS |

## Task Commits

Each task was committed atomically:

1. **Task 1: Suppression list backend + voter profile enhancements** - `dc4cbf4` (feat)
2. **Task 2: Flutter voter list, detail, and import screens** - `e768e20` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-go && go vet ./...` | 0 | PASS |
| build | `cd navigators-go && go build ./... && cd navigators-flutter && flutter analyze` | 0 | PASS |

## Post-TRD Verification

- **Auto-fix cycles used:** 0
- **Must-haves verified:** 6/6
- **Gate failures:** None

## Files Created/Modified
- `navigators-go/migrations/navigators/008_suppression.up.sql` - Suppression list table with voter FK, reason, audit trail
- `navigators-go/migrations/navigators/008_suppression.down.sql` - Drop suppression_list
- `navigators-go/queries/navigators/suppression.sql` - sqlc queries for add, remove, check, list, count
- `navigators-go/internal/navigators/suppression_service.go` - SuppressionService with fail-closed check + audit
- `navigators-go/internal/navigators/voter_handler.go` - Suppression RPC handlers, GetVoter enrichment
- `navigators-go/internal/navigators/permissions.go` - Suppression endpoint permissions
- `navigators-go/cmd/server/main.go` - Wire SuppressionService
- `navigators-go/proto/navigators/v1/voter.proto` - Suppression RPCs + GetVoterResponse enrichment
- `navigators-flutter/lib/src/services/voter_service.dart` - VoterService + models + Riverpod providers
- `navigators-flutter/lib/src/services/import_service.dart` - ImportService + presigned upload + polling
- `navigators-flutter/lib/src/features/voters/voter_list_screen.dart` - Search + filter + paginated list
- `navigators-flutter/lib/src/features/voters/voter_detail_screen.dart` - Full voter profile display
- `navigators-flutter/lib/src/features/voters/voter_search_bar.dart` - Debounced search input
- `navigators-flutter/lib/src/features/voters/voter_filter_panel.dart` - Expandable multi-filter panel
- `navigators-flutter/lib/src/features/import/import_screen.dart` - Admin file upload with progress
- `navigators-flutter/lib/src/features/import/import_progress_card.dart` - Import job status card
- `navigators-flutter/lib/src/app.dart` - Bottom nav with Home, Voters, Import (admin-only)
- `navigators-flutter/pubspec.yaml` - Added http, file_picker, intl dependencies

## Decisions Made
- Suppression RPCs added to VoterService (not separate service) to keep voter domain cohesive
- IsVoterSuppressed fails closed (returns true on error) as a legal requirement for outreach gating
- Flutter services use ConnectRPC JSON protocol (POST with JSON body) for simplicity
- Import uses presigned URL upload (PUT directly to MinIO) to keep Go server out of data path
- DropdownButtonFormField uses initialValue (not deprecated value) for Flutter 3.33+

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed DropdownButtonFormField deprecation**
- **Found during:** Task 2 (Flutter voter filter panel)
- **Issue:** `value` property deprecated in Flutter 3.33+ in favor of `initialValue`
- **Fix:** Changed to `initialValue` on both party and status dropdowns
- **Files modified:** navigators-flutter/lib/src/features/voters/voter_filter_panel.dart
- **Verification:** `flutter analyze` passes with 0 issues
- **Committed in:** e768e20 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Trivial API deprecation fix. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Objective Readiness
- Voter data pipeline complete: import, geocoding, search/filter, profile, suppression, Flutter UI
- Ready for Objective 03 (Offline Sync) once checkpoint verification passes
- Suppression list gating function ready for Objective 06 (SMS Outreach) integration

---
*Objective: 02-voter-data-pipeline*
*Completed: 2026-04-10*
