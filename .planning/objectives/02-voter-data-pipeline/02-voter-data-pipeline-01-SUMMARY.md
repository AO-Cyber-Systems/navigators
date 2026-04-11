---
objective: 02-voter-data-pipeline
job: "01"
subsystem: database, api
tags: [postgis, pg_trgm, minio, connectrpc, sqlc, voter-import, csv-parser]

requires:
  - objective: 01-foundation-auth
    provides: "Go backend scaffold, eden auth/RBAC, Docker Compose with PostGIS/MinIO, sqlc config, migration framework"
provides:
  - "voters table with PostGIS POINT, pg_trgm search, dedup_key unique constraint"
  - "import_jobs and import_staging tables for bulk import pipeline"
  - "VoterImportService RPCs (StartImport, ConfirmUpload, GetImportStatus, ListImportJobs)"
  - "VoterService RPCs defined (GetVoter, SearchVoters, ListVoters) -- handlers in TRD 02-02"
  - "CVR pipe-delimited and L2 tab-delimited parsers with configurable field mapping"
  - "pgx CopyFrom bulk staging and UPSERT merge pipeline"
  - "MinIO presigned URL for direct voter file upload (bypasses eden upload.Service 100MB limit)"
affects: [02-voter-data-pipeline, 03-geocoding-maps, 05-offline-sync]

tech-stack:
  added: [minio-go/v7]
  patterns: [configurable-field-mapping, dedup-key-normalization, background-goroutine-import, pgx-copyfrom-staging]

key-files:
  created:
    - navigators-go/migrations/navigators/005_voters.up.sql
    - navigators-go/migrations/navigators/006_import_jobs.up.sql
    - navigators-go/internal/navigators/import_service.go
    - navigators-go/internal/navigators/import_handler.go
    - navigators-go/queries/navigators/voters.sql
    - navigators-go/queries/navigators/imports.sql
    - navigators-go/proto/navigators/v1/voter.proto
  modified:
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/cmd/server/main.go

key-decisions:
  - "Use MinIO client directly for voter file uploads (not eden upload.Service) because voter files can exceed 100MB"
  - "Configurable field mapping (map[int]string) stored in import_jobs.field_mapping JSONB for CVR/L2 column flexibility"
  - "Background goroutine with context.Background() for import processing since HTTP request context cancels after response"
  - "Dedup key format: LASTNAME|STREETNUM|STREETNAME|ZIP5|YOB with normalization (strip non-alpha, abbreviate street suffixes)"
  - "Import pipeline stages: pending -> parsing -> staging -> merging -> complete/failed with row counters at each stage"

patterns-established:
  - "Import pipeline: presigned upload -> confirm -> background parse+stage+merge"
  - "Field mapping: JSON map of column index to canonical field name"
  - "Dedup key normalization: GenerateDedupKey with street abbreviation table"
  - "Prohibited field filtering: explicitly skip SSN, driver license, felony in parser"

requirements-completed: [VOTER-01, VOTER-02, VOTER-03, VOTER-10]

verification:
  gates_defined: 2
  gates_passed: 2
  auto_fix_cycles: 1
  tdd_evidence: false
  test_pairing: false

duration: 8min
completed: 2026-04-10
---

# Objective 02 TRD 01: Voter Data Model and Import Pipeline Summary

**Voter data model with PostGIS/pg_trgm, CVR and L2 parsers with configurable field mapping, bulk CopyFrom staging, and UPSERT merge pipeline via ConnectRPC**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-11T00:46:49Z
- **Completed:** 2026-04-11T00:54:49Z
- **Tasks:** 2/2
- **Files modified:** 18

## Accomplishments
- Voters table with PostGIS POINT geometry, pg_trgm trigram search, and deterministic dedup_key unique constraint (year_of_birth only, no full DOB per Maine 21-A)
- Import pipeline with CVR pipe-delimited and L2 tab-delimited parsers using configurable field mapping, pgx CopyFrom bulk staging, and INSERT ON CONFLICT UPSERT merge
- VoterImportService with 4 RPCs (StartImport, ConfirmUpload, GetImportStatus, ListImportJobs) all requiring voters:admin permission
- MinIO presigned URL upload bypassing eden upload.Service 100MB limit for large voter files

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Voter data model migrations + proto + sqlc | `cd navigators-go && buf generate && sqlc generate && go build ./...` | 0 | PASS |
| 2: Import service + handler + wiring | `cd navigators-go && go build ./... && go vet ./...` | 0 | PASS |

## Task Commits

Each task was committed atomically:

1. **Task 1: Voter data model migrations + proto definitions + sqlc queries** - `28fda82` (feat)
2. **Task 2: Import service with CVR/L2 parsers, handler, and server wiring** - `f78b89b` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-go && go vet ./...` | 0 | PASS |
| build | `cd navigators-go && go build ./...` | 0 | PASS |

## Post-TRD Verification

- **Auto-fix cycles used:** 1 (missing db import in import_handler.go)
- **Must-haves verified:** 6/6
- **Gate failures:** None

## Files Created/Modified
- `navigators-go/migrations/navigators/005_voters.up.sql` - Voters table with PostGIS, pg_trgm, dedup constraint
- `navigators-go/migrations/navigators/005_voters.down.sql` - Drop voters table
- `navigators-go/migrations/navigators/006_import_jobs.up.sql` - Import jobs and staging tables
- `navigators-go/migrations/navigators/006_import_jobs.down.sql` - Drop import tables
- `navigators-go/proto/navigators/v1/voter.proto` - VoterImportService and VoterService definitions
- `navigators-go/queries/navigators/voters.sql` - Voter CRUD with UPSERT on dedup_key
- `navigators-go/queries/navigators/imports.sql` - Import job CRUD, merge, staging cleanup
- `navigators-go/internal/navigators/import_service.go` - CVR/L2 parsers, dedup key, staging pipeline, merge
- `navigators-go/internal/navigators/import_handler.go` - ConnectRPC handler for VoterImportService
- `navigators-go/internal/navigators/permissions.go` - Added VoterImportService procedure permissions
- `navigators-go/cmd/server/main.go` - MinIO client, voter-imports bucket, import handler registration

## Decisions Made
- Used MinIO client directly for voter file uploads because eden upload.Service has 100MB limit and voter files can exceed that
- Configurable field mapping stored as JSONB in import_jobs allows admins to map columns on first import without code changes
- Background goroutine uses context.Background() since HTTP request context cancels after response
- Dedup key normalizes with street abbreviation table (STREET->ST, AVENUE->AVE, etc.) for consistent matching

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Missing db package import in import_handler.go**
- **Found during:** Task 2 (go build)
- **Issue:** import_handler.go referenced db.ImportJob but did not import navigators-go/internal/db
- **Fix:** Added missing import
- **Files modified:** navigators-go/internal/navigators/import_handler.go
- **Verification:** go build ./... passes
- **Committed in:** f78b89b (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Trivial missing import. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Objective Readiness
- Voter data model and import pipeline ready for TRD 02-02 (voter query handlers, search, filtering)
- VoterService RPCs defined in proto, handlers to be implemented
- Geocoding deferred to TRD 02-02/02-03 (geocode_status defaults to 'pending')

---
*Objective: 02-voter-data-pipeline*
*Completed: 2026-04-10*
