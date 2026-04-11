---
objective: 01-foundation-auth
job: "02"
subsystem: auth
tags: [rbac, permissions, admin, password-reset, session-management, connectrpc, protobuf]

requires:
  - objective: 01-foundation-auth-01
    provides: "Go backend scaffold with eden auth/RBAC wiring, Docker Compose, navigators migration framework"
provides:
  - "Navigators permission matrix (voters/turfs/teams/audit/admin)"
  - "MaineGOP company pre-seeded with well-known UUID"
  - "Admin user creation and role assignment"
  - "Password reset flow (request + confirm)"
  - "Session management (inactivity timeout, admin revocation)"
  - "AdminService proto with 8 RPCs and generated ConnectRPC code"
affects: [01-foundation-auth-03, 02-voter-data, 03-turf-management]

tech-stack:
  added: [buf, protobuf-go, connectrpc-go]
  patterns: [navigators-permission-matrix, admin-service-pattern, password-reset-mvp-logging]

key-files:
  created:
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/internal/navigators/admin_service.go
    - navigators-go/internal/navigators/admin_handler.go
    - navigators-go/internal/navigators/password_reset.go
    - navigators-go/internal/navigators/session.go
    - navigators-go/proto/navigators/v1/admin.proto
    - navigators-go/gen/go/navigators/v1/admin.pb.go
    - navigators-go/gen/go/navigators/v1/navigatorsv1connect/admin.connect.go
    - navigators-go/migrations/navigators/002_seed_company_permissions.up.sql
    - navigators-go/migrations/navigators/003_session_tracking.up.sql
  modified:
    - navigators-go/cmd/server/main.go

key-decisions:
  - "Used 'standalone' company_type for MaineGOP (eden's CHECK constraint disallows 'organization')"
  - "Password reset logs URL to console for MVP (email service deferred)"
  - "Session timeout checker uses COALESCE(last_active_at, created_at) for backward compatibility"
  - "Admin creates users directly via auth store (not eden SignUp which creates a company per user)"
  - "Added migration 003 for last_active_at column on refresh_tokens (not in eden schema)"

patterns-established:
  - "AdminService pattern: handler wraps service, service uses eden stores + raw pool for gaps"
  - "Permission matrix: define in Go, seed in SQL migration, both must match feature:action strings"
  - "Public procedures: merge eden defaults with navigators-specific public RPCs"
  - "Role mapping: navigator=member(40), super_navigator=manager(60), admin=admin(80)"

requirements-completed: [AUTH-03, AUTH-04, AUTH-05, AUTH-06]

verification:
  gates_defined: 2
  gates_passed: 2
  auto_fix_cycles: 0
  tdd_evidence: false
  test_pairing: false

duration: 12min
completed: 2026-04-10
---

# Objective 01 TRD 02: Auth RBAC + Admin Services Summary

**Navigators permission matrix with 5 features, AdminService with user creation/password reset/session management, MaineGOP company seeded, RBAC enforcement verified**

## Performance

- **Duration:** 12 min
- **Started:** 2026-04-11T00:03:01Z
- **Completed:** 2026-04-11T00:15:01Z
- **Tasks:** 2
- **Files modified:** 16

## Accomplishments

- Navigators permission matrix defines 5 features (voters, turfs, teams, audit, admin) with 16 permission actions mapped to 3 roles
- AdminService proto with 8 RPCs: CreateUser, ListUsers, DeactivateUser, AssignRole, RequestPasswordReset, ConfirmPasswordReset, RevokeSession, ListActiveSessions
- Admin can create users in MaineGOP company with navigator/super_navigator/admin roles
- Password reset flow: consistent response for all emails (prevents enumeration), short-lived JWT token, console logging for MVP
- Session management: admin revocation of all user tokens, background inactivity timeout checker
- All admin actions logged to audit trail

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Permission matrix + seed migration | `go build ./cmd/server` | 0 | PASS |
| 1: Permissions seeded | `SELECT feature, action FROM permissions WHERE feature IN ('voters','turfs','teams','audit','admin')` | 0 | PASS (16 rows) |
| 1: MaineGOP company exists | `SELECT name, slug FROM companies WHERE id = '40000000-...'` | 0 | PASS |
| 1: Role-permissions mapped | `SELECT r.name, p.feature, p.action FROM role_permissions rp JOIN roles r...` | 0 | PASS (25 mappings) |
| 2: Server build | `go build ./cmd/server` | 0 | PASS |
| 2: CreateUser | `curl CreateUser with admin token` | 0 | PASS (returns user_id) |
| 2: ListUsers | `curl ListUsers with admin token` | 0 | PASS (returns 2 users) |
| 2: RequestPasswordReset (existing) | `curl RequestPasswordReset` | 0 | PASS (generic message) |
| 2: RequestPasswordReset (nonexistent) | `curl RequestPasswordReset` | 0 | PASS (same generic message) |
| 2: ConfirmPasswordReset | `curl ConfirmPasswordReset with token` | 0 | PASS (password changed) |
| 2: Login with new password | `curl Login` | 0 | PASS |
| 2: Old password rejected | `curl Login with old password` | 0 | PASS (invalid credentials) |
| 2: RBAC denies navigator | `curl ListUsers with navigator token` | 0 | PASS (permission_denied) |
| 2: Unauthenticated access denied | `curl CreateUser without token` | 0 | PASS (unauthenticated) |
| 2: RevokeSession | `curl RevokeSession with admin token` | 0 | PASS (tokens revoked) |
| 2: Audit trail | `SELECT action FROM audit_logs` | 0 | PASS (user.created, password_reset.completed, session.revoked) |

## Task Commits

Each task was committed atomically:

1. **Task 1: Permission matrix, seed migration, RBAC wiring** - `a77cba5` (feat)
2. **Task 2: Admin service, password reset, session management** - `a695b04` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `go vet ./...` | 0 | PASS |
| build | `go build ./cmd/server` | 0 | PASS |

## Post-TRD Verification

- **Auto-fix cycles used:** 0
- **Must-haves verified:** 6/6
- **Gate failures:** None

## Files Created/Modified

- `navigators-go/internal/navigators/permissions.go` - Permission matrix with 5 features, procedure permissions, public procedures
- `navigators-go/internal/navigators/admin_service.go` - AdminService with CreateUser, ListUsers, DeactivateUser, AssignRole
- `navigators-go/internal/navigators/admin_handler.go` - ConnectRPC handler implementing AdminServiceHandler interface
- `navigators-go/internal/navigators/password_reset.go` - RequestPasswordReset (enum-safe) and ConfirmPasswordReset
- `navigators-go/internal/navigators/session.go` - RevokeSession, ListActiveSessions, StartSessionTimeoutChecker
- `navigators-go/proto/navigators/v1/admin.proto` - AdminService with 8 RPCs, all request/response messages
- `navigators-go/gen/go/navigators/v1/` - Generated protobuf and ConnectRPC Go code
- `navigators-go/migrations/navigators/002_seed_company_permissions.up.sql` - MaineGOP company + 16 permissions + role mappings
- `navigators-go/migrations/navigators/003_session_tracking.up.sql` - last_active_at column on refresh_tokens
- `navigators-go/cmd/server/main.go` - Wired AdminService handler, session timeout checker, navigators RBAC

## Decisions Made

- Used `standalone` company_type for MaineGOP (eden's CHECK constraint does not allow `organization` -- TRD specified `organization`)
- Password reset logs URL to console for MVP (email integration deferred to later objective)
- Session timeout checker uses `COALESCE(last_active_at, created_at)` for backward compatibility with existing tokens
- Admin creates users directly via eden auth store in a transaction (not via SignUp which creates a new company)
- Added migration 003 for `last_active_at` column since eden's `refresh_tokens` schema does not include it

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Changed company_type from 'organization' to 'standalone'**
- **Found during:** Task 1 (Seed migration)
- **Issue:** TRD specified `company_type = 'organization'` but eden's companies table has CHECK constraint limiting to holding/subsidiary/brand/standalone
- **Fix:** Used `standalone` type which is the most appropriate for the MaineGOP company
- **Files modified:** navigators-go/migrations/navigators/002_seed_company_permissions.up.sql
- **Verification:** Migration runs successfully, company created
- **Committed in:** a77cba5

**2. [Rule 3 - Blocking] Added migration 003 for session tracking**
- **Found during:** Task 2 (Session management)
- **Issue:** Eden's refresh_tokens table lacks `last_active_at` column needed for inactivity timeout
- **Fix:** Created navigators migration 003 to ADD COLUMN last_active_at with index
- **Files modified:** navigators-go/migrations/navigators/003_session_tracking.up.sql, 003_session_tracking.down.sql
- **Verification:** Column exists, index created
- **Committed in:** a695b04

---

**Total deviations:** 2 auto-fixed (2 blocking issues)
**Impact on plan:** Both were necessary for correctness. No scope creep.

## Issues Encountered

None beyond the documented deviations.

## User Setup Required

None - no external service configuration required.

## Next Objective Readiness

- Auth foundation complete: RBAC enforcer, admin user management, password reset, session management all working
- Ready for TRD-03 (Flutter screens for password reset, profile) or Objective 02 (voter data)
- Note: first admin user must be bootstrapped via eden SignUp + manual membership creation (or seeded in migration)

---
*Objective: 01-foundation-auth*
*TRD: 02*
*Completed: 2026-04-10*
