---
objective: 05-door-knocking-contact-log
job: "01"
subsystem: database
tags: [postgres, drift, sqlc, protobuf, sync, surveys, voter-notes, door-knocking]

requires:
  - objective: 04-offline-sync-engine
    provides: "Drift encrypted DB, outbox sync, PushSyncBatch/Pull RPCs, SyncDao.writeWithOutbox"
  - objective: 03-turf-spatial-walk
    provides: "contact_logs table (migration 009), turf-scoped queries"
provides:
  - "Migration 012: door_status/sentiment on contact_logs, survey_forms, survey_responses, voter_notes tables"
  - "SurveyService: form CRUD + response processing from push sync"
  - "VoterNotesService: role-scoped note pull + note processing from push sync"
  - "Sync: survey_response and voter_note push/pull entity types"
  - "Drift: SurveyForms, SurveyResponses, VoterNotes tables with DAOs"
affects: [05-02, 05-03, 06-sms-outreach]

tech-stack:
  added: []
  patterns:
    - "Role-scoped pull sync: raw pgxpool WHERE clause with role_level parameter"
    - "Nullable int column: sqlc generates *int32, Drift uses integer().nullable()"

key-files:
  created:
    - navigators-go/migrations/navigators/012_door_knocking.up.sql
    - navigators-go/internal/navigators/survey_service.go
    - navigators-go/internal/navigators/voter_notes_service.go
    - navigators-go/queries/navigators/surveys.sql
    - navigators-go/queries/navigators/voter_notes.sql
    - navigators-flutter/lib/src/database/tables/survey_forms.dart
    - navigators-flutter/lib/src/database/tables/survey_responses.dart
    - navigators-flutter/lib/src/database/tables/voter_notes.dart
    - navigators-flutter/lib/src/database/daos/survey_dao.dart
    - navigators-flutter/lib/src/database/daos/voter_note_dao.dart
  modified:
    - navigators-go/internal/navigators/sync_service.go
    - navigators-go/internal/navigators/sync_handler.go
    - navigators-go/proto/navigators/v1/sync.proto
    - navigators-go/queries/navigators/sync.sql
    - navigators-go/internal/navigators/permissions.go
    - navigators-flutter/lib/src/database/tables/contact_logs.dart
    - navigators-flutter/lib/src/database/daos/contact_log_dao.dart
    - navigators-flutter/lib/src/database/database.dart

key-decisions:
  - "sqlc generates *int32 for nullable INT columns (sentiment) -- pass directly instead of pgtype.Int4"
  - "PullVoterNotes uses raw pgxpool for role-scoped filtering (complex WHERE clause with role_level param)"
  - "Survey forms are pull-only (admin creates on server); responses and notes are push+pull"

patterns-established:
  - "Role-scoped pull sync: pass roleLevel int and userID to raw pgxpool query with tiered visibility WHERE clause"
  - "New entity type sync: add case to PushSyncBatch switch, add Pull RPC handler, add Drift DAO with writeWithOutbox"

requirements-completed: [DOOR-02, DOOR-03, DOOR-04, DOOR-05, NOTE-01, NOTE-03, NOTE-04]

verification:
  gates_defined: 2
  gates_passed: 2
  auto_fix_cycles: 1
  tdd_evidence: false
  test_pairing: false

duration: 11min
completed: 2026-04-11
---

# Objective 05 TRD 01: Door Knocking Data Layer Summary

**PostgreSQL migration 012 with door_status/sentiment on contact_logs, 3 new tables (survey_forms, survey_responses, voter_notes), Go services for surveys and notes, extended sync for 3 new entity types, Drift tables and DAOs with outbox sync**

## Performance

- **Duration:** 11 min
- **Started:** 2026-04-11T15:56:40Z
- **Completed:** 2026-04-11T16:07:19Z
- **Tasks:** 2
- **Files modified:** 27

## Accomplishments
- Migration 012 adds door_status and sentiment to contact_logs, creates survey_forms, survey_responses, and voter_notes tables with proper indexes and CHECK constraints
- SurveyService and VoterNotesService process push sync operations; PullVoterNotes enforces role-scoped visibility server-side
- PushSyncBatch handles "survey_response" and "voter_note" entity types; PullContactLogs now includes door_status and sentiment
- Drift schema bumped to v2 with migration; SurveyDao and VoterNoteDao follow established writeWithOutbox pattern

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Server migration + services + sync endpoints | `cd navigators-go && sqlc generate && buf generate && go build ./...` | 0 | PASS |
| 2: Drift tables + DAOs + database registration | `cd navigators-flutter && dart run build_runner build --delete-conflicting-outputs && flutter analyze` | 0 | PASS |

## Task Commits

Each task was committed atomically:

1. **Task 1: Server migration + services + sync endpoints** - `045772b` (feat)
2. **Task 2: Drift tables + DAOs + database registration** - `7063bdc` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-go && go vet ./...` | 0 | PASS |
| build | `cd navigators-go && go build ./... && cd navigators-flutter && flutter analyze` | 0 | PASS |

## Post-TRD Verification

- **Auto-fix cycles used:** 1 (sqlc generated *int32 for nullable sentiment, fixed pgtype.Int4 to *int32)
- **Must-haves verified:** 7/7
- **Gate failures:** None

## Files Created/Modified
- `navigators-go/migrations/navigators/012_door_knocking.up.sql` - ALTER contact_logs + CREATE survey_forms, survey_responses, voter_notes
- `navigators-go/migrations/navigators/012_door_knocking.down.sql` - Reverse migration
- `navigators-go/queries/navigators/surveys.sql` - CRUD + sync queries for survey forms and responses
- `navigators-go/queries/navigators/voter_notes.sql` - Upsert + role-scoped query for voter notes
- `navigators-go/queries/navigators/sync.sql` - Updated UpsertContactLogFromSync, added Pull queries
- `navigators-go/proto/navigators/v1/sync.proto` - PullSurveyForms/Responses/VoterNotes RPCs + messages
- `navigators-go/internal/navigators/survey_service.go` - Form CRUD + ProcessSurveyResponse
- `navigators-go/internal/navigators/voter_notes_service.go` - ProcessVoterNote + role-scoped PullVoterNotes
- `navigators-go/internal/navigators/sync_service.go` - New entity push cases, pull methods, updated contact log fields
- `navigators-go/internal/navigators/sync_handler.go` - New Pull RPC handlers, door_status/sentiment in PullContactLogs
- `navigators-go/internal/navigators/permissions.go` - FeatureSurveys, FeatureNotes with procedure mappings
- `navigators-go/cmd/server/main.go` - Wire SurveyService + VoterNotesService into SyncService
- `navigators-flutter/lib/src/database/tables/contact_logs.dart` - Added doorStatus and sentiment columns
- `navigators-flutter/lib/src/database/tables/survey_forms.dart` - New Drift table
- `navigators-flutter/lib/src/database/tables/survey_responses.dart` - New Drift table
- `navigators-flutter/lib/src/database/tables/voter_notes.dart` - New Drift table
- `navigators-flutter/lib/src/database/daos/contact_log_dao.dart` - Updated payload, door knock history methods
- `navigators-flutter/lib/src/database/daos/survey_dao.dart` - Upsert from sync, insertResponseWithOutbox
- `navigators-flutter/lib/src/database/daos/voter_note_dao.dart` - insertNoteWithOutbox, upsert from sync
- `navigators-flutter/lib/src/database/database.dart` - Schema v2, new tables/DAOs registered, onUpgrade migration

## Decisions Made
- sqlc generates `*int32` for nullable INT columns (sentiment) -- used directly instead of pgtype.Int4
- PullVoterNotes uses raw pgxpool for role-scoped filtering (complex WHERE clause not expressible in simple sqlc)
- Survey forms are pull-only (admin creates on server); responses and notes are push+pull via outbox

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed sentiment type mismatch in processContactLog**
- **Found during:** Task 1 (go build)
- **Issue:** Used pgtype.Int4 for sentiment but sqlc generated *int32
- **Fix:** Changed to pass payload.Sentiment (*int32) directly to UpsertContactLogFromSync
- **Files modified:** navigators-go/internal/navigators/sync_service.go
- **Verification:** go build ./... passes
- **Committed in:** 045772b (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Type mismatch between assumed and generated sqlc types. No scope creep.

## Issues Encountered
None beyond the auto-fixed type mismatch above.

## User Setup Required
None - no external service configuration required.

## Next TRD Readiness
- All data layer infrastructure ready for TRD 05-02 (door knocking UI) and TRD 05-03 (survey/notes UI)
- SurveyDao and VoterNoteDao ready for screen integration
- Sync engine will automatically handle new entity types via existing WorkManager/connectivity scheduling

---
*Objective: 05-door-knocking-contact-log*
*Completed: 2026-04-11*
