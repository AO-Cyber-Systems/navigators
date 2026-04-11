# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-10)

**Core value:** Navigators can go into the field with a complete voter list, map, and outreach tools -- work entirely offline in rural Maine -- and have every interaction automatically sync back to give leadership real-time visibility into grassroots organizing efforts.
**Current focus:** Voter Data Pipeline (Objective 2)

## Current Position

**Objective:** 2 of 10 (Voter Data Pipeline)
**Current Job:** 2
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

### Pending Todos

None yet.

### Blockers/Concerns

- 10DLC registration takes 15-30 days -- start in Objective 1 before any SMS code (Objective 6)
- Maine CVR exact field list needed from MaineGOP before Objective 2 import schema design
- Isar abandoned in 2025 -- all offline DB work uses Drift + sqlcipher (not Isar despite older docs)

## Session Continuity

Last session: 2026-04-10
Stopped at: Completed 02-01-TRD.md (voter data model + import pipeline)
Resume file: None

## History

- 2026-04-10: Completed 02-01-TRD (voter data model, import pipeline: voters table with PostGIS/pg_trgm, CVR/L2 parsers, CopyFrom staging, UPSERT merge)
- 2026-04-10: Completed 01-03-TRD (turfs, teams, audit: domain schema, turf-scoped filter, audit service, handlers)
- 2026-04-10: Completed 01-02-TRD (auth RBAC + admin services: permission matrix, admin user CRUD, password reset, session management)
- 2026-04-10: Completed 01-01-TRD (project scaffold: Go backend, Flutter app, Docker Compose, Justfile)
- 2026-04-10: Project initialized, roadmap created with 10 objectives covering 74 v1 requirements
