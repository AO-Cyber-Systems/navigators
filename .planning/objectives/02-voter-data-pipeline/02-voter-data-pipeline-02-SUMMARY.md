---
objective: 02-voter-data-pipeline
job: "02"
subsystem: api
tags: [geocoding, census, google-maps, postgis, pg_trgm, connectrpc, tags]

requires:
  - objective: 02-voter-data-pipeline-01
    provides: "Voters table with PostGIS location, pg_trgm search_text, import pipeline"
provides:
  - "Census batch geocoding (10K/batch) with Google Maps fallback"
  - "Voter search with pg_trgm fuzzy matching and similarity ranking"
  - "Voter filter with party, status, district, municipality, county, vote count, bbox"
  - "Turf-scoped voter queries via TurfScopedFilter"
  - "Tag CRUD and voter-tag assignment"
  - "VoterService ConnectRPC handlers"
  - "Post-import geocoding trigger"
affects: [03-field-tools, 04-offline-sync, 05-canvassing]

tech-stack:
  added: [googlemaps.github.io/maps]
  patterns: [census-batch-geocoding, turf-scoped-spatial-queries, raw-pool-postgis-queries]

key-files:
  created:
    - navigators-go/internal/navigators/geocode_service.go
    - navigators-go/internal/navigators/voter_service.go
    - navigators-go/internal/navigators/voter_handler.go
    - navigators-go/internal/navigators/tag_service.go
    - navigators-go/migrations/navigators/007_tags.up.sql
    - navigators-go/queries/navigators/tags.sql
  modified:
    - navigators-go/queries/navigators/voters.sql
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/internal/navigators/import_service.go
    - navigators-go/cmd/server/main.go
    - navigators-go/proto/navigators/v1/voter.proto
    - navigators-go/go.mod

key-decisions:
  - "Use 'success' (not 'matched') for geocode_status to match DB CHECK constraint values"
  - "Raw pgxpool queries for turf-scoped spatial operations (sqlc cannot handle PostGIS JOINs with ST_Within)"
  - "Tag RPCs added to VoterService proto (not separate service) since tags are voter-domain"
  - "Google geocoding cost ceiling of 500 per ProcessUngeocoded run to prevent runaway billing"
  - "Census batch retry: 3 attempts with exponential backoff (5s, 10s, 20s)"

patterns-established:
  - "Turf-scoped queries: ResolveScope -> switch ScopeAll/ScopeTeam/ScopeOwn -> select query variant"
  - "Spatial queries via raw pool.Query (not sqlc) for PostGIS ST_Within joins"
  - "Background geocoding: QueueGeocoding starts goroutine with context.Background()"

requirements-completed: [VOTER-04, VOTER-06, VOTER-07, VOTER-08]

verification:
  gates_defined: 2
  gates_passed: 2
  auto_fix_cycles: 1
  tdd_evidence: false
  test_pairing: false

duration: 8min
completed: 2026-04-10
---

# Objective 02 TRD 02: Geocode + Search/Filter + Tags Summary

**Census batch geocoding with Google fallback, pg_trgm voter search with turf-scoped spatial queries, and voter tag management via ConnectRPC**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-11T00:58:09Z
- **Completed:** 2026-04-11T01:06:17Z
- **Tasks:** 2
- **Files modified:** 19

## Accomplishments
- GeocodeService with Census batch API (10K/batch, multipart POST, CSV response parsing) and Google Maps single-address fallback with cost ceiling
- VoterService with fuzzy search (pg_trgm similarity), multi-filter listing, and geography (bbox) filtering -- all turf-scoped and audit-logged
- TagService with CRUD and voter-tag assignment, integrated into VoterHandler ConnectRPC
- Post-import geocoding trigger wired from ImportService to GeocodeService

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Geocode service + tags migration + search/filter queries | `cd navigators-go && sqlc generate && go build ./...` | 0 | PASS |
| 2: Voter service + handler + tag service + server wiring | `cd navigators-go && go build ./... && go vet ./...` | 0 | PASS |

## Task Commits

Each task was committed atomically:

1. **Task 1: Geocode service + tags migration + search/filter queries** - `ea0c9ed` (feat)
2. **Task 2: Voter service + handler + tag service + server wiring** - `8f79937` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-go && go vet ./...` | 0 | PASS |
| build | `cd navigators-go && go build ./...` | 0 | PASS |

## Post-TRD Verification

- **Auto-fix cycles used:** 1 (proto field name casing: SourceVoterID -> SourceVoterId)
- **Must-haves verified:** 7/7
- **Gate failures:** None

## Files Created/Modified
- `navigators-go/internal/navigators/geocode_service.go` - Census batch geocoding + Google fallback + background worker
- `navigators-go/internal/navigators/voter_service.go` - Voter search, filter, list with turf scoping
- `navigators-go/internal/navigators/voter_handler.go` - ConnectRPC handlers for VoterService + tag RPCs
- `navigators-go/internal/navigators/tag_service.go` - Tag CRUD and voter-tag assignment with audit
- `navigators-go/migrations/navigators/007_tags.up.sql` - voter_tags and voter_tag_assignments tables
- `navigators-go/migrations/navigators/007_tags.down.sql` - Drop tag tables
- `navigators-go/queries/navigators/voters.sql` - SearchVoters, ListVotersByFilters, GetUngeocoded, UpdateVoterGeocode
- `navigators-go/queries/navigators/tags.sql` - Tag CRUD + assignment queries
- `navigators-go/internal/navigators/permissions.go` - VoterService and tag RPC permission mappings
- `navigators-go/internal/navigators/import_service.go` - GeocodeService integration + post-import trigger
- `navigators-go/cmd/server/main.go` - Wire VoterService, TagService, GeocodeService, VoterHandler
- `navigators-go/proto/navigators/v1/voter.proto` - Tag RPCs and messages added to VoterService
- `navigators-go/go.mod` - Added googlemaps.github.io/maps dependency

## Decisions Made
- Used 'success' for geocode_status value (DB CHECK constraint defines: pending/success/failed/skipped, not 'matched' as TRD suggested)
- Raw pgxpool queries for turf-scoped spatial operations since sqlc cannot generate PostGIS ST_Within JOINs across the turfs table
- Added tag RPCs to existing VoterService proto rather than creating a separate TagService proto
- Cost ceiling of 500 Google geocodes per ProcessUngeocoded run
- Census retry with exponential backoff: 5s, 10s, 20s (3 attempts)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Proto field naming convention**
- **Found during:** Task 2 (VoterHandler compilation)
- **Issue:** Go proto generates `SourceVoterId` (not `SourceVoterID`) for proto field `source_voter_id`
- **Fix:** Updated voter_handler.go to use correct proto field name
- **Files modified:** navigators-go/internal/navigators/voter_handler.go
- **Verification:** go build passes
- **Committed in:** 8f79937

**2. [Rule 1 - Bug] geocode_status value mismatch**
- **Found during:** Task 1 (geocode service design)
- **Issue:** TRD specified 'matched' but DB CHECK constraint uses 'success'
- **Fix:** Used 'success' to match the existing DB schema
- **Files modified:** navigators-go/internal/navigators/geocode_service.go
- **Verification:** Aligns with 005_voters.up.sql CHECK constraint
- **Committed in:** ea0c9ed

**3. [Rule 3 - Blocking] Proto tag RPCs missing**
- **Found during:** Task 1 (proto analysis)
- **Issue:** voter.proto only had VoterService with Get/Search/List -- no tag RPCs
- **Fix:** Added CreateTag, ListTags, DeleteTag, AssignTagToVoter, RemoveTagFromVoter, GetVoterTags RPCs and messages
- **Files modified:** navigators-go/proto/navigators/v1/voter.proto
- **Verification:** buf generate + go build pass
- **Committed in:** ea0c9ed

---

**Total deviations:** 3 auto-fixed (2 bug, 1 blocking)
**Impact on plan:** All necessary for correctness. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required. GOOGLE_MAPS_API_KEY is optional (Google fallback disabled if not set).

## Next Objective Readiness
- Geocoding, search, filter, and tag services ready for TRD 02-03
- VoterService handlers registered and accepting ConnectRPC requests
- All queries turf-scoped and audit-logged
- Post-import geocoding trigger active

---
*Objective: 02-voter-data-pipeline*
*Completed: 2026-04-10*
