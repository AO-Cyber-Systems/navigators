# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-10)

**Core value:** Navigators can go into the field with a complete voter list, map, and outreach tools -- work entirely offline in rural Maine -- and have every interaction automatically sync back to give leadership real-time visibility into grassroots organizing efforts.
**Current focus:** Offline Sync Engine (Objective 4)

## Current Position

**Objective:** 4 of 10 (Offline Sync Engine)
**Current Job:** 3
**Total Jobs in Objective:** 3
**Status:** Ready to execute
**Last Activity:** 2026-04-11

Progress: [##........] 13%

## Performance Metrics

**Velocity:**
- Total plans completed: 3
- Average duration: 10 min
- Total execution time: 0.52 hours

**By Objective:**

| Objective | Plans | Total | Avg/Plan |
|-----------|-------|-------|----------|
| 01-foundation-auth | 3/3 | 31 min | 10 min |

**Recent Trend:**
- Last 5 jobs: 01-01 (11 min), 01-02 (12 min), 01-03 (8 min)
- Trend: Improving
| Objective 02 P01 | 8min | 2 tasks | 18 files |
| Objective 02 P02 | 8min | 2 tasks | 19 files |
| Objective 02 P03 | 9min | 2 tasks | 22 files |
| Objective 03 P01 | 7min | 2 tasks | 8 files |
| Objective 03 P02 | 6min | 2 tasks | 7 files |
| Objective 03 P03 | 9min | 2 tasks | 10 files |
| Objective 04 P01 | 7min | 2 tasks | 28 files |
| Objective 04 P02 | 43min | 2 tasks | 12 files |
| Objective 04 P03 | 9min | 2 tasks | 11 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Use pgx5:// URL scheme for DATABASE_URL -- golang-migrate pgx/v5 driver registers as "pgx5", eden pgstore.NewPool converts to postgres:// for pgxpool
- Navigators migrations use x-migrations-table=schema_migrations_navigators for separate tracking
- Flutter app follows eden example pattern: authProvider, PlatformLoginScreen/PlatformSignUpScreen
- MaineGOP company uses 'standalone' type (eden CHECK constraint disallows 'organization')
- Admin creates users via auth store directly (not eden SignUp which creates a company per user)
- Role mapping: navigator=member(40), super_navigator=manager(60), admin=admin(80)
- Password reset logs URL to console for MVP (email service deferred)
- Turf scoping is service-layer (not interceptor): TurfScopedFilter.ResolveScope returns ScopeOwn/ScopeTeam/ScopeAll
- Dual audit trail: voter_access_log table (domain-specific) + eden audit.Logger (general events)
- sqlc.yaml includes eden migrations for FK resolution; geometry type overridden to string
- Migration numbered 004 (not 003 as TRD specified, because 003 was already taken)
- [Objective 02]: Use MinIO client directly for voter file uploads (not eden upload.Service) because voter files can exceed 100MB
- [Objective 02]: Configurable field mapping (map[int]string) stored in import_jobs JSONB for CVR/L2 column flexibility
- [Objective 02]: Dedup key format: LASTNAME|STREETNUM|STREETNAME|ZIP5|YOB with normalization (strip non-alpha, abbreviate street suffixes)
- [Objective 02-voter-data-pipeline]: Use 'success' (not 'matched') for geocode_status to match DB CHECK constraint
- [Objective 02-voter-data-pipeline]: Raw pgxpool queries for turf-scoped spatial PostGIS operations (sqlc cannot handle ST_Within JOINs)
- [Objective 02-voter-data-pipeline]: Tag RPCs added to VoterService proto (not separate service) since tags are voter-domain
- [Objective 02]: Suppression RPCs added to VoterService (not separate proto service) for cohesive voter domain
- [Objective 02]: IsVoterSuppressed fails closed (returns true on error) -- legal requirement for outreach gating
- [Objective 02]: Flutter services use ConnectRPC JSON protocol (POST with JSON body) for cross-platform simplicity
- [Objective 03]: sqlc spatial columns return interface{} -- use toFloat64 helper for safe type assertion
- [Objective 03]: Walk list uses Go-side O(n^2) haversine greedy nearest-neighbor (correct for 100-2000 voters)
- [Objective 03]: GetVotersInTurf and GetVoterDensityGrid use raw pgxpool (not sqlc) for complex spatial JOINs
- [Objective 03]: PolygonLayer uses generic type parameter <String> for hitValue to satisfy flutter_map 8 nullability constraints
- [Objective 03]: Map tab positioned for all roles (not just admin) between Voters and Import tabs
- [Objective 03]: Voter pins loaded per-turf on selection rather than viewport-based to avoid loading all voters at once
- [Objective 03]: FMTC store naming: 'turf-{turfId}' for per-turf caching
- [Objective 03]: Heat map uses MapCamera.getOffsetFromOrigin for flutter_map 8 projection
- [Objective 03]: FMTC 10.1.1: countTiles (not check), startForeground returns record, stats use .length
- [Objective 04]: Raw pgxpool for sync voter pull (spatial ST_Contains JOIN not expressible in sqlc)
- [Objective 04]: Non-admin turf scope enforced server-side (client-provided turf_ids ignored for Navigator/SuperNavigator)
- [Objective 04]: SQLite3MultipleCiphers via pubspec hooks (NOT sqlcipher_flutter_libs which is deprecated)
- [Objective 04]: Voter metadata LWW uses timestamp-only update since voters table has no notes column
- [Objective 04]: SyncEngine.instance static field for WorkManager isolate and connectivity listener access
- [Objective 04]: VoterListNotifier gets optional NavigatorsDatabase param for offline-first fallback
- [Objective 04]: Turf reassignment check runs as Phase 0 in runSyncCycle before push/pull

### Pending Todos

None yet.

### Blockers/Concerns

- 10DLC registration takes 15-30 days -- start in Objective 1 before any SMS code (Objective 6)
- Maine CVR exact field list needed from MaineGOP before Objective 2 import schema design
- Isar abandoned in 2025 -- all offline DB work uses Drift + sqlcipher (not Isar despite older docs)

## Session Continuity

Last session: 2026-04-11
Stopped at: Completed 04-02-TRD.md
Resume file: None

## History

- 2026-04-11: Completed 04-02-TRD (Push sync engine, transactional outbox, PushSyncBatch RPC, LWW conflict resolution, WorkManager+connectivity scheduling)
- 2026-04-11: Completed 04-01-TRD (Drift encrypted DB, 5 local tables, 3 DAOs, SyncService proto+handler, cursor-based pull sync)
- 2026-04-11: Completed 03-01-TRD (turf spatial backend: GeoJSON boundary CRUD, voters-in-turf, walk list, stats, density grid, contact_logs)
- 2026-04-10: Completed 02-03-TRD (voter profile, suppression list, Flutter UI -- checkpoint approved, all gates pass)
- 2026-04-10: Completed 02-02-TRD (geocode service, search/filter, tags)
- 2026-04-10: Completed 02-01-TRD (voter data model, import pipeline: voters table with PostGIS/pg_trgm, CVR/L2 parsers, CopyFrom staging, UPSERT merge)
- 2026-04-10: Completed 01-03-TRD (turfs, teams, audit: domain schema, turf-scoped filter, audit service, handlers)
- 2026-04-10: Completed 01-02-TRD (auth RBAC + admin services: permission matrix, admin user CRUD, password reset, session management)
- 2026-04-10: Completed 01-01-TRD (project scaffold: Go backend, Flutter app, Docker Compose, Justfile)
- 2026-04-10: Project initialized, roadmap created with 10 objectives covering 74 v1 requirements
