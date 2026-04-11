---
objective: 01-foundation-auth
job: "01"
subsystem: infra
tags: [go, flutter, docker, postgis, eden-platform, connect-rpc, riverpod, migrations]

# Dependency graph
requires: []
provides:
  - Go server with eden auth (signup, login, refresh, logout)
  - Flutter app shell with eden login/signup screens
  - Docker Compose (PostgreSQL+PostGIS, NATS JetStream, MinIO)
  - Dual migration strategy (eden + navigators separate tracking)
  - Proto placeholder definitions for voter, turf, team, admin
  - Justfile dev commands
affects: [01-foundation-auth, 02-voter-data, 03-turf-management]

# Tech tracking
tech-stack:
  added: [eden-platform-go, eden-platform-flutter, eden-ui-flutter, eden-platform-api-dart, golang-migrate, postgis, nats, minio, connect-rpc, flutter-riverpod, buf, sqlc]
  patterns: [eden-consumer-bootstrap, dual-migration-tracking, pgx5-url-scheme]

key-files:
  created:
    - navigators-go/cmd/server/main.go
    - navigators-go/go.mod
    - navigators-go/migrations_embed.go
    - navigators-go/migrations/navigators/001_postgis.up.sql
    - navigators-flutter/lib/main.dart
    - navigators-flutter/lib/src/app.dart
    - navigators-flutter/pubspec.yaml
    - compose.yaml
    - justfile
    - .env.dev
  modified:
    - .gitignore

key-decisions:
  - "Use pgx5:// URL scheme for DATABASE_URL -- golang-migrate pgx/v5 driver registers as 'pgx5', eden pgstore.NewPool converts to postgres:// for pgxpool"
  - "Navigators migrations use x-migrations-table=schema_migrations_navigators query param for separate tracking from eden migrations"
  - "Flutter app follows eden example pattern exactly -- PlatformLoginScreen/PlatformSignUpScreen with authProvider toggle"

patterns-established:
  - "Eden consumer bootstrap: config.Load() -> pgstore.NewBackend() -> separate navigators migrations -> wire auth/rbac/audit -> register handlers"
  - "Dual migration tracking: eden uses default schema_migrations, navigators appends x-migrations-table param to URL"
  - "Go module replace directive: replace github.com/aocybersystems/eden-platform-go => ../../eden-libs/eden-platform-go"
  - "Flutter eden path deps: path: ../../eden-libs/eden-platform-flutter"

requirements-completed: [AUTH-01, AUTH-02]

# Verification evidence
verification:
  gates_defined: 2
  gates_passed: 2
  auto_fix_cycles: 1
  tdd_evidence: false
  test_pairing: false

# Metrics
duration: 11min
completed: 2026-04-10
---

# Objective 01 TRD 01: Project Scaffold Summary

**Go backend consuming eden-platform-go with full auth wiring, Flutter app with eden login screens, Docker Compose with PostGIS/NATS/MinIO, and dual migration strategy**

## Performance

- **Duration:** 11 min
- **Started:** 2026-04-10T23:48:21Z
- **Completed:** 2026-04-10T23:59:57Z
- **Tasks:** 2
- **Files modified:** 17 (Task 1) + 135 (Task 2, includes flutter scaffolding)

## Accomplishments
- Go server starts, connects to PostgreSQL, runs eden + navigators migrations, serves /up health check at 200
- Eden auth endpoints accessible (SignUp, Login, RefreshToken, Logout via ConnectRPC)
- Flutter app compiles (macOS debug build), uses eden PlatformLoginScreen when unauthenticated
- Docker Compose runs PostgreSQL+PostGIS 3.4, NATS with JetStream, MinIO
- Dual migration tracking: eden in schema_migrations (version 11), navigators in schema_migrations_navigators (version 1)
- PostGIS extension installed and functional

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Go project + Docker Compose + Justfile | `go mod tidy` | 0 | PASS |
| 1: Go project + Docker Compose + Justfile | `docker compose up -d` | 0 | PASS |
| 1: Go project + Docker Compose + Justfile | `docker compose exec postgres psql -U navigators -d navigators_dev -c "SELECT PostGIS_Version();"` | 0 | PASS |
| 1: Go project + Docker Compose + Justfile | `go build ./cmd/server` | 0 | PASS |
| 1: Go project + Docker Compose + Justfile | `curl http://localhost:8080/up` (HTTP 200) | 0 | PASS |
| 1: Go project + Docker Compose + Justfile | `SELECT COUNT(*) FROM users;` (table exists, 0 rows) | 0 | PASS |
| 1: Go project + Docker Compose + Justfile | `SELECT * FROM schema_migrations_navigators;` (version 1) | 0 | PASS |
| 2: Flutter project setup | `flutter pub get` | 0 | PASS |
| 2: Flutter project setup | `flutter analyze` | 0 | PASS |
| 2: Flutter project setup | `flutter build macos --debug` | 0 | PASS |

## Task Commits

Each task was committed atomically:

1. **Task 1: Go project + Docker Compose + Justfile** - `3385368` (feat)
2. **Task 2: Flutter project setup with eden platform** - `4cd79ef` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-go && go vet ./...` | 0 | PASS |
| build | `cd navigators-go && go build ./cmd/server` | 0 | PASS |

## Post-TRD Verification

- **Auto-fix cycles used:** 1 (DATABASE_URL scheme fix from postgres:// to pgx5://)
- **Must-haves verified:** 6/6
- **Gate failures:** None

## Files Created/Modified
- `navigators-go/cmd/server/main.go` - Server bootstrap wiring eden auth, RBAC, audit, health check
- `navigators-go/go.mod` - Go module with eden replace directive
- `navigators-go/migrations_embed.go` - Embedded navigators migrations FS
- `navigators-go/migrations/navigators/001_postgis.up.sql` - CREATE EXTENSION postgis
- `navigators-go/sqlc.yaml` - Navigators-specific sqlc config
- `navigators-go/proto/navigators/v1/*.proto` - Placeholder proto definitions
- `navigators-go/buf.yaml` + `buf.gen.yaml` - Buf protobuf config
- `navigators-flutter/pubspec.yaml` - Flutter with eden path dependencies
- `navigators-flutter/lib/main.dart` - App entry with ProviderScope
- `navigators-flutter/lib/src/app.dart` - App shell with eden auth screens and EdenTheme
- `compose.yaml` - Docker Compose: PostGIS 16-3.4, NATS 2.11 JetStream, MinIO
- `justfile` - Dev commands (infra, dev-go, dev-flutter, generate, test-go, sqlc, db-reset)
- `.env.dev` - Local development environment variables
- `.gitignore` - Updated to allow .env.dev and ignore compiled server binary

## Decisions Made
- Used `pgx5://` URL scheme for DATABASE_URL because golang-migrate pgx/v5 driver registers as "pgx5" not "postgres". Eden's pgstore.NewPool handles conversion to postgres:// for pgxpool.
- Navigators migrations use custom tracking table via `x-migrations-table=schema_migrations_navigators` query param on the database URL passed to golang-migrate.
- Flutter app follows eden-platform-flutter example pattern exactly: authProvider watch, PlatformLoginScreen/PlatformSignUpScreen toggle, EdenTheme.light()/dark().
- Passed `nil` for navigatorsPermissionMatrix() and empty map for navigatorsProcedurePermissions() -- TRD-02 will populate these.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] DATABASE_URL scheme must be pgx5:// not postgres://**
- **Found during:** Task 1 (server startup)
- **Issue:** golang-migrate pgx/v5 driver registers as "pgx5" scheme, not "postgres". Using postgres:// URL caused "unknown driver postgres (forgotten import?)" error.
- **Fix:** Changed .env.dev DATABASE_URL from `postgres://` to `pgx5://`. Eden's pgstore.NewPool converts pgx5:// to postgres:// for pgxpool connection.
- **Files modified:** .env.dev
- **Verification:** Server starts successfully, all migrations run
- **Committed in:** 3385368 (Task 1 commit)

**2. [Rule 1 - Bug] Flutter test referenced deleted MyApp class**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** Generated widget_test.dart referenced MyApp which was replaced by NavigatorsApp
- **Fix:** Rewrote test to use NavigatorsApp with ProviderScope
- **Files modified:** navigators-flutter/test/widget_test.dart
- **Verification:** flutter analyze reports no issues
- **Committed in:** 4cd79ef (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required. Docker Compose provides all infrastructure locally.

## Next Objective Readiness
- Auth foundation complete: signup, login, refresh, logout all functional via eden platform
- Ready for TRD-02 (RBAC + user management) which fills in navigatorsPermissionMatrix() and navigatorsProcedurePermissions()
- Ready for TRD-03 which will add navigators-specific service implementations

---
*Objective: 01-foundation-auth*
*Completed: 2026-04-10*
