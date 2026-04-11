# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-10)

**Core value:** Navigators can go into the field with a complete voter list, map, and outreach tools -- work entirely offline in rural Maine -- and have every interaction automatically sync back to give leadership real-time visibility into grassroots organizing efforts.
**Current focus:** Analytics Dashboards (Objective 9)

## Current Position

**Objective:** 9 of 10 (Analytics Dashboards)
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
| Objective 04 P03 | 11min | 3 tasks | 11 files |
| Objective 05 P01 | 11min | 2 tasks | 27 files |
| Objective 05 P02 | 12min | 2 tasks | 9 files |
| Objective 05 P03 | 5min | 2 tasks | 5 files |
| Objective 06 P01 | 12min | 2 tasks | 12 files |
| Objective 06 P02 | 8min | 2 tasks | 10 files |
| Objective 06-sms-integration P03 | 6min | 2 tasks | 9 files |
| Objective 07 P01 | 6min | 2 tasks | 19 files |
| Objective 07 P02 | 7min | 2 tasks | 8 files |
| Objective 08 P01 | 11min | 2 tasks | 20 files |
| Objective 08 P02 | 8min | 2 tasks | 10 files |
| Objective 08 P03 | 8min | 2 tasks | 11 files |
| Objective 09 P01 | 7min | 2 tasks | 8 files |
| Objective 09 P02 | 4min | 2 tasks | 8 files |

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
- [Objective 05]: sqlc generates *int32 for nullable INT columns (sentiment) -- pass directly instead of pgtype.Int4
- [Objective 05]: PullVoterNotes uses raw pgxpool for role-scoped filtering (complex WHERE clause with role_level param)
- [Objective 05]: Survey forms are pull-only (admin creates on server); responses and notes are push+pull via outbox
- [Objective 05]: Step-based flow with local enum state instead of EdenFormWizard for door knock screen
- [Objective 05]: UUID v4 generated with dart:math Random.secure (no uuid package dependency)
- [Objective 05]: Walk list map view extracted to widgets/ subdirectory to keep screen under 400 lines
- [Objective 05]: Custom StreamController merging instead of rxdart for combining Drift watch streams
- [Objective 05]: Custom timeline ListView instead of EdenTimeline (does not exist in eden-ui-flutter)
- [Objective 05]: Optional turfId parameter on VoterDetailScreen for notes context
- [Objective 06]: NATS connection failure is non-fatal: SMS features degrade but server starts
- [Objective 06]: Single-company (MaineGOP) assumption for inbound webhook voter lookup in v1
- [Objective 06]: Company admin user for opt-out FK: GetCompanyAdminUserID for suppression_list.added_by
- [Objective 06]: VoterContext struct with 5 merge fields for text/template rendering
- [Objective 06]: Campaign segment filtering simplified to company-wide for v1; full JSONB parsing deferred
- [Objective 06]: Rate limiter at 1 msg/sec for A2P sends using golang.org/x/time/rate
- [Objective 06-sms-integration]: Admin sees Templates/Campaigns via AppBar IconButtons (not sub-tabs) for simplicity
- [Objective 06-sms-integration]: Optimistic message add in thread screen with rollback on send error
- [Objective 06-sms-integration]: Local template preview with sample data for unsaved templates
- [Objective 07]: Call scripts use TEXT content (not JSONB) with {{variable}} interpolation at display time
- [Objective 07]: door_status CHECK extended with voicemail/no_answer/busy for phone dispositions; answered/refused shared
- [Objective 07]: PullCallScriptsUpdated returns all scripts (not just active) so client detects deactivations during sync
- [Objective 07]: CallScriptManagerScreen is read-only (view synced scripts) since no ConnectRPC handler for create/update exists yet
- [Objective 07]: Phone call screen launches dialer immediately on open, does not gate flow on dialer success
- [Objective 07]: Phone flow has 4 steps (calling, disposition, sentiment, notes) with calling step showing script before disposition
- [Objective 08]: DueDate uses pgtype.Timestamptz; LinkedEntityID uses pgtype.UUID; InsertTaskVoters uses sqlc copyfrom; task_note entity type for push sync
- [Objective 08]: Firebase init moved before service wiring for dependency order (NATS, Firebase, then services)
- [Objective 08]: FCMDispatcher uses raw pgxpool queries for device_tokens (eden pgstore.Backend has no NotificationStore)
- [Objective 08]: TaskService.AssignTask signature expanded to include companyID for task title lookup in NATS event
- [Objective 08]: Firebase init commented out pending flutterfire configure -- graceful degradation pattern
- [Objective 08]: SyncEngine.db made public for SyncScheduler PUSH-03 outbox access
- [Objective 08]: Tasks tab visible for all roles; FAB create only for Manager/60+ (super_navigator, admin)
- [Objective 09]: Contact rate computed in Go (sqlc maps float division to int32)
- [Objective 09]: Separate day/week trend queries (sqlc cannot parameterize date_trunc interval)
- [Objective 09]: Display names via company_memberships JOIN (eden users has no company_id)
- [Objective 09]: All analytics SQL compiled by sqlc (FILTER/LATERAL supported); no raw pgxpool fallback needed
- [Objective 09]: AnalyticsService.toRfc3339 made public static for dashboard screen date range formatting
- [Objective 09]: Admin dashboard is a local placeholder in app.dart until TRD 09-03

### Pending Todos

None yet.

### Blockers/Concerns

- 10DLC registration takes 15-30 days -- start in Objective 1 before any SMS code (Objective 6)
- Maine CVR exact field list needed from MaineGOP before Objective 2 import schema design
- Isar abandoned in 2025 -- all offline DB work uses Drift + sqlcipher (not Isar despite older docs)

## Session Continuity

Last session: 2026-04-11
Stopped at: Completed 09-02-TRD.md
Resume file: None

## History

- 2026-04-11: Completed 09-02-TRD (Flutter dashboard UI: AnalyticsService client, NavigatorDashboardScreen, TeamDashboardScreen, fl_chart widgets, role-based Home tab)
- 2026-04-11: Completed 09-01-TRD (Analytics proto, SQL aggregation queries, AnalyticsService with role scoping, ExportService with CSV/Excel streaming, handler + server wiring)
- 2026-04-11: Completed 08-03-TRD (Flutter task UI screens, NotificationService, TaskService, PUSH-03 sync alert, Tasks tab)
- 2026-04-11: Completed 08-02-TRD (NATS task events, FCM dispatcher, device token registration, task assignment notifications)
- 2026-04-11: Completed 08-01-TRD (Task data model, CRUD service, assignment, linking, notes, proto, Drift tables/DAO, pull sync)
- 2026-04-11: Completed 07-01-TRD (Call scripts backend + phone call data layer: migration 014, CallScriptService, PullCallScripts sync, Drift table/DAO)
- 2026-04-11: Completed 06-01-TRD (SMS infrastructure: migration 013, Twilio SDK, P2P send, webhooks, NATS workers, compliance)
- 2026-04-11: Completed 05-01-TRD (Door knocking data layer: migration 012, survey/notes services, sync endpoints, Drift tables/DAOs)
- 2026-04-11: Completed 04-03-TRD (Sync status UI, offline-first screens, turf reassignment -- checkpoint approved, Objective 04 complete)
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
