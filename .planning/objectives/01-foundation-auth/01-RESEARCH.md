# Objective 1: Foundation + Auth - Research

**Researched:** 2026-04-10
**Domain:** Go backend (eden-platform-go), Flutter frontend (eden-platform-flutter), PostgreSQL, ConnectRPC
**Confidence:** HIGH

## Summary

Eden-platform-go provides a comprehensive, production-ready auth and RBAC system that covers 80%+ of the Navigators auth requirements out of the box. The platform includes: email/password signup and login, JWT access/refresh token management (ML-DSA-65 post-quantum signing), role-based access control with a hierarchical company model, permission matrices, an async audit logger, and ConnectRPC interceptors for auth, RBAC enforcement, and audit logging. The Flutter side (eden-platform-flutter) provides AuthNotifier with Riverpod, login/signup screens, token persistence via SharedPreferences, and automatic session restoration.

The key customization needed for Navigators is domain-specific: defining Navigator/Super Navigator/Admin roles mapped to eden's role levels, implementing turf-scoped data filtering (NOT provided by eden -- eden only does company-level RBAC), building the password reset flow (NOT provided -- eden has `CreateShortLivedToken` but no reset endpoint), session timeout/revocation (partial -- refresh tokens can be revoked, but no inactivity timeout exists), and the voter data audit trail (eden's audit logger handles the infra, but Navigators must emit domain-specific events).

**Primary recommendation:** Use eden-platform-go as-is for auth/RBAC infra. Build Navigators as a modular monolith consuming eden-platform-go via go.mod replace directive. Navigators-specific domain logic (turfs, voter scoping, team hierarchy) lives in the Navigators Go binary alongside eden platform handlers.

<phase_requirements>
## Objective Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUTH-01 | User can sign up with email and password | Fully provided by eden: `auth.Service.SignUp()`, `AuthService.SignUp` proto RPC, Flutter `PlatformSignUpScreen` |
| AUTH-02 | User can log in and stay logged in (JWT refresh) | Fully provided: `auth.Service.Login()`, `auth.Service.RefreshToken()`, Flutter `AuthNotifier.restoreSession()` auto-refreshes on app start |
| AUTH-03 | User can reset password via email link | NOT provided by eden. Must build: password reset request RPC, `JWTManager.CreateShortLivedToken()` for reset tokens, email sending, reset confirmation RPC |
| AUTH-04 | Session timeout after inactivity, admin revocation | Partial: `RevokeRefreshToken()` exists for admin revocation. Inactivity timeout must be built (track last activity, background cleanup) |
| AUTH-05 | Admin can create/manage user accounts with role assignment | Partial: `rbac.Service.AssignRole()` exists. Must build: admin user creation endpoint (create user without signup flow), user listing, user deactivation |
| AUTH-06 | System enforces RBAC (Admin/Super Navigator/Navigator) | Eden provides role levels and permission matrix. Must define: custom roles for Navigator (map to member/40), Super Navigator (map to manager/60), Admin (map to admin/80), seed permissions |
| AUTH-07 | Navigator can only access voters in assigned turfs | NOT provided by eden (eden is company-scoped, not turf-scoped). Must build: turf assignment model, turf-scoped query filters, enforcement interceptor or service-layer filtering |
| AUTH-08 | Super Navigator sees all data from their Navigators | NOT provided. Must build: team assignment model linking Super Nav to Navigators, query that unions all assigned navigator turfs |
| AUTH-09 | Audit trail logs all voter data access | Partial: eden provides `audit.Logger` (async buffered writer) and `AuditInterceptor`. Must emit domain-specific audit events (voter.viewed, voter.modified) with turf/voter context |
</phase_requirements>

## Standard Stack

### Core (from eden-platform-go)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| connectrpc.com/connect | v1.19.1 | RPC framework (HTTP/2 + HTTP/1.1) | Eden's transport layer, proto-first |
| github.com/golang-jwt/jwt/v5 | v5.3.1 | JWT creation/validation | Used by eden auth, ML-DSA-65 signing |
| github.com/cloudflare/circl | v1.6.3 | Post-quantum crypto (ML-DSA-65) | Eden's JWT signing algorithm |
| github.com/jackc/pgx/v5 | v5.9.1 | PostgreSQL driver + connection pool | Eden's DB layer, pgxpool |
| github.com/golang-migrate/migrate/v4 | v4.19.1 | Database migrations | Eden's migration runner (embed.FS + iofs) |
| golang.org/x/crypto | v0.48.0 | Argon2id password hashing | Eden's PasswordHasher |
| github.com/google/uuid | v1.6.0 | UUID generation | Used everywhere in eden models |
| google.golang.org/protobuf | v1.36.11 | Protocol Buffers | Proto code generation |

### Navigators Must Add
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| github.com/nats-io/nats.go | v1.49.0 | NATS JetStream messaging | Event bus for audit events, domain events |
| github.com/minio/minio-go/v7 | v7.0.99 | MinIO object storage | Voter file imports, attachments |
| PostGIS extension | (pg16) | Geospatial queries | Turf boundary geometry, voter location matching |
| github.com/sqlc-dev/sqlc | v1.29+ (tool) | SQL -> Go codegen | Generate type-safe query code for Navigators domain |

### Flutter Side (from eden-platform-flutter)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_riverpod | latest | State management | Eden's standard, AuthNotifier uses StateNotifier |
| shared_preferences | latest | Token persistence | Eden persists access/refresh tokens locally |
| eden_platform_api_dart | local | Generated ConnectRPC clients | Proto-generated Dart clients for all services |
| connectrpc (dart) | latest | Dart Connect transport | Used by ConnectPlatformRepository |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| eden auth (Argon2id + ML-DSA-65 JWT) | Firebase Auth, Supabase Auth | Eden is already built, integrated, no external dependency. Use eden. |
| sqlc | GORM, sqlx | Eden uses sqlc throughout. Do not introduce alternatives. |
| eden company hierarchy for team model | Custom team table | Company hierarchy is overkill for Nav teams. Use simpler team_assignments table. |

**Installation (Go consumer):**
```bash
# go.mod replace directive points to local eden-libs
# In go.mod:
replace github.com/aocybersystems/eden-platform-go => ../../eden-libs/eden-platform-go
```

**Installation (Flutter consumer):**
```yaml
# pubspec.yaml path dependencies
dependencies:
  eden_platform_flutter:
    path: ../../eden-libs/eden-platform-flutter
  eden_ui_flutter:
    path: ../../eden-libs/eden-ui-flutter
  eden_platform_api_dart:
    path: ../../eden-libs/eden-platform-api-dart
```

## Architecture Patterns

### Recommended Project Structure
```
navigators/
  navigators-go/                 # Go backend (modular monolith)
    cmd/
      server/
        main.go                  # Wires eden platform + navigators handlers
    proto/
      navigators/v1/
        voter.proto              # Navigators-specific proto definitions
        turf.proto
        team.proto
    migrations/
      platform/                  # Symlink or embed eden platform migrations
      navigators/                # Navigators-specific migrations
        001_turfs.up.sql
        002_team_assignments.up.sql
        003_voter_access_log.up.sql
    queries/
      navigators/                # sqlc queries for navigators domain
        turfs.sql
        teams.sql
        voters.sql
    internal/
      db/                        # sqlc-generated code for navigators
      domain/
        turf/                    # Turf management service + store
        team/                    # Team hierarchy service + store
        voter/                   # Voter access service + store
    sqlc.yaml
    go.mod
    go.sum
  navigators-flutter/            # Flutter frontend
    lib/
      src/
        features/
          auth/                  # Wraps eden auth, adds password reset UI
          voters/                # Voter list, detail, search
          turfs/                 # Turf management, map views
          admin/                 # Admin panels (user mgmt, audit log)
    pubspec.yaml
```

### Pattern 1: Consumer App Main (Bootstrap Pattern)
**What:** How a consumer app wires eden platform services with its own domain handlers
**When to use:** The server's main.go
**Example:**
```go
// Source: Derived from eden-platform-go/cmd/eden-platform-dev/main.go
func main() {
    cfg := config.Load()

    // 1. Run eden platform migrations (embedded FS)
    platformMigrationsFS, _ := fs.Sub(edenplatform.MigrationsFS, "migrations/platform")
    // 2. Run navigators domain migrations (own embedded FS)
    // 3. Create pgstore.Backend for eden platform stores
    pgBackend, _ := pgstore.NewBackend(ctx, cfg.DatabaseURL, platformMigrationsFS)
    defer pgBackend.Close()

    // 4. Wire eden services
    jwtManager, _ := auth.NewJWTManager(auth.JWTConfig{...})
    authService := auth.NewService(pgBackend.AuthStore(), jwtManager, auth.NewPasswordHasher())
    enforcer := rbac.NewEnforcer(pgBackend.RBACStore(), navigatorsPermissionMatrix())
    auditLogger := audit.NewLogger(pgBackend.AuditStore())
    auditLogger.Start()
    defer auditLogger.Stop()

    // 5. Wire navigators domain services
    turfService := turf.NewService(navigatorsDB)
    teamService := team.NewService(navigatorsDB)

    // 6. Register handlers on mux
    mux := http.NewServeMux()
    authInterceptor := server.NewAuthInterceptor(jwtManager, publicProcedures())
    rbacInterceptor := server.NewRBACInterceptor(enforcer, rbacConfig())
    auditInterceptor := server.NewAuditInterceptor(auditLogger, publicProcedures())

    server.RegisterPlatformHandlers(mux, server.PlatformHandlers{...},
        connect.WithInterceptors(authInterceptor, rbacInterceptor, auditInterceptor))
    // Register navigators-specific handlers too

    http.ListenAndServe(cfg.ServerAddr, server.CORSMiddleware(server.LoggingMiddleware(mux)))
}
```

### Pattern 2: Custom Permission Matrix for Navigators
**What:** Define Navigators-specific features and their role-level requirements
**When to use:** When mapping eden RBAC to Navigators domain concepts
**Example:**
```go
// Source: Derived from eden-platform-go/platform/rbac/features.go
func navigatorsPermissionMatrix() rbac.PermissionMatrix {
    return rbac.PermissionMatrix{
        "voters": {
            "view":   rbac.RoleLevelMember,   // Navigator (40)
            "edit":   rbac.RoleLevelMember,   // Navigator
            "export": rbac.RoleLevelManager,  // Super Navigator (60)
            "admin":  rbac.RoleLevelAdmin,    // Admin (80)
        },
        "turfs": {
            "view":   rbac.RoleLevelMember,   // Navigator sees own turfs
            "create": rbac.RoleLevelAdmin,    // Admin creates turfs
            "assign": rbac.RoleLevelManager,  // Super Nav assigns
            "admin":  rbac.RoleLevelAdmin,
        },
        "teams": {
            "view":   rbac.RoleLevelManager,  // Super Nav sees team
            "manage": rbac.RoleLevelAdmin,    // Admin manages teams
            "admin":  rbac.RoleLevelAdmin,
        },
        "audit": {
            "view":   rbac.RoleLevelAdmin,    // Only Admin sees audit logs
            "admin":  rbac.RoleLevelAdmin,
        },
    }
}
```

### Pattern 3: Turf-Scoped Data Filtering (Beyond Eden RBAC)
**What:** Eden RBAC checks company-level permissions. Turf scoping requires additional filtering at the query/service layer.
**When to use:** Every voter data query
**Example:**
```go
// Service layer enforces turf scoping AFTER eden RBAC allows the request
func (s *VoterService) ListVoters(ctx context.Context, userID, companyID uuid.UUID) ([]Voter, error) {
    claims := server.ClaimsFromContext(ctx)

    switch {
    case claims.RoleLevel >= int(rbac.RoleLevelAdmin):
        // Admin: see all voters in company
        return s.store.ListAllVoters(ctx, companyID)

    case claims.RoleLevel >= int(rbac.RoleLevelManager):
        // Super Navigator: see voters in all assigned navigator turfs
        turfIDs, _ := s.teamStore.GetTeamTurfIDs(ctx, userID)
        return s.store.ListVotersByTurfs(ctx, turfIDs)

    default:
        // Navigator: see only voters in own assigned turfs
        turfIDs, _ := s.turfStore.GetUserTurfIDs(ctx, userID)
        return s.store.ListVotersByTurfs(ctx, turfIDs)
    }
}
```

### Pattern 4: Eden Migration + Consumer Migration (Dual Migration)
**What:** Run eden platform migrations first, then consumer-specific migrations
**When to use:** Server startup
**Example:**
```go
// Eden migrations create: users, companies, roles, permissions, audit_logs, etc.
platformFS, _ := fs.Sub(edenplatform.MigrationsFS, "migrations/platform")
pgstore.RunMigrations(databaseURL, platformFS)

// Navigators migrations create: turfs, team_assignments, voter_access_log, etc.
// These reference eden tables (users, companies) via foreign keys
navigatorsFS, _ := fs.Sub(navigatorsMigrationsFS, "migrations/navigators")
pgstore.RunMigrations(databaseURL, navigatorsFS)
```

### Anti-Patterns to Avoid
- **DO NOT fork eden-platform-go:** Always consume via go.mod replace. If eden is missing something, either extend in Navigators or contribute upstream.
- **DO NOT use eden company hierarchy for team hierarchy:** Eden companies are for multi-tenant org structures. Navigator/Super Navigator teams are a simpler domain concept -- use a dedicated team_assignments table.
- **DO NOT implement RBAC checks in Flutter:** All authorization decisions happen server-side. Flutter only uses role info for UI gating (showing/hiding admin panels).
- **DO NOT build custom JWT handling:** Eden's JWTManager with ML-DSA-65 is production-ready. Just configure it.
- **DO NOT put turf-scoping logic in interceptors:** Interceptors handle permission checks (can user access this feature?). Turf scoping is data filtering and belongs in the service/query layer.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Password hashing | Custom bcrypt/scrypt impl | `auth.NewPasswordHasher()` (Argon2id) | OWASP params, constant-time comparison, proper salt generation |
| JWT management | Custom token creation/validation | `auth.NewJWTManager()` | ML-DSA-65 post-quantum, key rotation, kid headers |
| Auth interceptor | Custom middleware | `server.NewAuthInterceptor()` | Handles Bearer extraction, public procedure bypass, context injection |
| RBAC enforcement | Custom permission checks | `rbac.Enforcer` + `server.NewRBACInterceptor()` | Cached, permission matrix, hierarchy-aware |
| Audit logging | Synchronous insert per request | `audit.NewLogger()` + `server.NewAuditInterceptor()` | Async buffered (10k channel, 50-batch, 100ms tick), non-blocking |
| Database migrations | Manual SQL execution | `pgstore.RunMigrations()` with `embed.FS` | golang-migrate with iofs source, pgx5 driver |
| Connection pooling | Manual pgx connections | `pgstore.NewPool()` / `pgstore.NewBackend()` | pgxpool with health checks |
| CORS/Logging middleware | Custom HTTP middleware | `server.CORSMiddleware()`, `server.LoggingMiddleware()` | Pre-configured for ConnectRPC headers |
| Flutter auth state | Custom auth state machine | `AuthNotifier` + `authProvider` | Handles login, signup, refresh, restore, logout, SSO, error states |
| Proto-to-Dart clients | Manual HTTP calls | `eden_platform_api_dart` generated clients | Type-safe, ConnectRPC transport |

**Key insight:** Eden provides the entire authentication and authorization infrastructure. Navigators' custom work is limited to: (1) domain schema (turfs, teams, voters), (2) turf-scoped query filtering, (3) password reset flow, (4) domain-specific audit events.

## Common Pitfalls

### Pitfall 1: Confusing Eden RBAC with Turf Scoping
**What goes wrong:** Assuming eden's `HasPermission` or `CheckFeatureAction` will filter voters by turf. It won't -- eden RBAC is company-scoped permission checks only.
**Why it happens:** Eden RBAC looks comprehensive and people assume it handles all authorization.
**How to avoid:** Use eden RBAC for "can this user access the voters feature?" and implement turf scoping as a separate concern in the service/query layer.
**Warning signs:** Voter endpoints returning all voters regardless of turf assignment.

### Pitfall 2: Running Migrations in Wrong Order
**What goes wrong:** Navigators migrations reference eden tables (users, companies) that don't exist yet.
**Why it happens:** Both use golang-migrate with separate migration directories, and ordering matters.
**How to avoid:** Always run eden platform migrations first, then navigators migrations. Use separate golang-migrate instances with separate `schema_migrations` version tracking (different database names or separate tracking tables).
**Warning signs:** "relation does not exist" errors on startup.

### Pitfall 3: Not Seeding Navigators Roles and Permissions
**What goes wrong:** Eden seeds system roles (super_admin, owner, admin, manager, member, viewer) and generic permissions (content, settings, etc.). Navigators needs its own permissions (voters:view, turfs:create, etc.) seeded.
**Why it happens:** Eden's seed migration (011_seed_permissions.up.sql) only seeds eden-generic permissions.
**How to avoid:** Create a navigators migration that seeds navigators-specific permissions and maps them to roles. Use eden's well-known role IDs (e.g., `AdminRoleID = 10000000-0000-0000-0000-000000000002`).
**Warning signs:** RBAC interceptor denying all requests because permissions don't exist in the database.

### Pitfall 4: Password Reset Token Leaking User Existence
**What goes wrong:** Password reset endpoint returns different responses for existing vs non-existing emails, enabling user enumeration.
**Why it happens:** Natural to return "email not found" vs "reset email sent".
**How to avoid:** Always return "If an account exists with this email, a reset link has been sent" regardless of whether the email exists.
**Warning signs:** Different HTTP response codes or messages for found vs not-found emails.

### Pitfall 5: Forgetting to Track Navigators Migrations Separately
**What goes wrong:** Eden platform migrations and navigators migrations share the same `schema_migrations` table, causing version conflicts.
**Why it happens:** golang-migrate uses a default `schema_migrations` table.
**How to avoid:** Use different migration table names. Eden uses default. Navigators should use `schema_migrations_navigators` or a custom table name parameter in golang-migrate.
**Warning signs:** "Dirty database version" errors, migrations skipped or applied out of order.

### Pitfall 6: Not Handling B2B Company Context
**What goes wrong:** Navigators is a single-org app but eden is multi-tenant B2B by default. SignUp creates a new company per user.
**Why it happens:** Eden's default SignUp flow creates "User's Company" per registration.
**How to avoid:** Either: (a) Use B2C mode (`PlatformMode: "b2c"`) which creates personal workspaces, or (b) Pre-create the MaineGOP company and have Admin invite/create users into it. Recommendation: Pre-create the company, disable public signup, have Admin create accounts. This maps cleanly to the "Admin creates and manages user accounts" requirement (AUTH-05).
**Warning signs:** Each user getting their own company instead of joining the MaineGOP org.

## Code Examples

### Eden Auth Service Wiring
```go
// Source: eden-platform-go/cmd/eden-platform-dev/main.go (verified)
jwtManager, err := auth.NewJWTManager(auth.JWTConfig{
    KeySeedPath:        cfg.JWTKeySeedPath,
    Issuer:             "navigators",
    AccessTokenExpiry:  15 * time.Minute,   // default
    RefreshTokenExpiry: 7 * 24 * time.Hour, // default
})
authService := auth.NewService(pgBackend.AuthStore(), jwtManager, auth.NewPasswordHasher())
```

### Eden RBAC Enforcer + Interceptor Wiring
```go
// Source: eden-platform-go/cmd/eden-platform-dev/main.go (verified)
enforcer := rbac.NewEnforcer(pgBackend.RBACStore(), navigatorsPermissionMatrix())
rbacResolver := rbac.NewHierarchyResolver(pgBackend.RBACStore())
rbacService := rbac.NewService(pgBackend.RBACStore(), enforcer, rbacResolver)

rbacInterceptor := server.NewRBACInterceptor(enforcer, server.InterceptorConfig{
    PublicProcedures:     publicProcedures,
    ProcedurePermissions: navigatorsProcedurePermissions(),
})
```

### Extracting Claims in Handler
```go
// Source: eden-platform-go/platform/server/interceptors.go (verified)
func (h *VoterHandler) ListVoters(ctx context.Context, req *connect.Request[...]) (...) {
    userID, companyID, role := server.ExtractClaims(ctx)
    // Or for full claims:
    claims := server.ClaimsFromContext(ctx)
    // claims.UserID, claims.CompanyID, claims.Role, claims.RoleLevel
}
```

### Async Audit Logging
```go
// Source: eden-platform-go/platform/audit/logger.go (verified)
auditLogger := audit.NewLogger(pgBackend.AuditStore())
auditLogger.Start()
defer auditLogger.Stop()

// Log domain-specific events from service layer:
auditLogger.Log(audit.Event{
    CompanyID:  companyID,
    ActorID:    userID,
    Action:     "voter.viewed",
    Resource:   "voter",
    ResourceID: voterID,
    Details:    map[string]any{"turf_id": turfID},
    IPAddress:  ipAddr,
})
```

### Password Reset (Must Build)
```go
// Eden provides CreateShortLivedToken for this pattern:
// Source: eden-platform-go/platform/auth/jwt.go (verified)
resetToken, err := jwtManager.CreateShortLivedToken(userEmail, 30*time.Minute)
// Send resetToken via email link: https://app/reset?token=...

// On reset confirmation:
email, err := jwtManager.ValidateShortLivedToken(resetToken)
// Then: look up user by email, hash new password, update in DB
```

### Navigators Domain Migration Example
```sql
-- migrations/navigators/001_turfs.up.sql
CREATE TABLE IF NOT EXISTS turfs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    boundary GEOMETRY(POLYGON, 4326),  -- PostGIS
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_turfs_company ON turfs (company_id);
CREATE INDEX idx_turfs_boundary ON turfs USING GIST (boundary);

-- Turf assignments (Navigator <-> Turf)
CREATE TABLE IF NOT EXISTS turf_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    turf_id UUID NOT NULL REFERENCES turfs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (turf_id, user_id)
);

CREATE INDEX idx_turf_assignments_user ON turf_assignments (user_id);
CREATE INDEX idx_turf_assignments_turf ON turf_assignments (turf_id);
```

```sql
-- migrations/navigators/002_team_assignments.up.sql
-- Super Navigator <-> Navigator relationship
CREATE TABLE IF NOT EXISTS team_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    super_navigator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    navigator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES companies(id),
    assigned_by UUID NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (super_navigator_id, navigator_id)
);

CREATE INDEX idx_team_assignments_super ON team_assignments (super_navigator_id);
CREATE INDEX idx_team_assignments_nav ON team_assignments (navigator_id);
```

```sql
-- migrations/navigators/003_voter_access_log.up.sql
-- Detailed audit trail for voter data access (supplements eden audit_logs)
CREATE TABLE IF NOT EXISTS voter_access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    user_id UUID NOT NULL REFERENCES users(id),
    voter_id TEXT NOT NULL,       -- External voter ID from CVR
    access_type TEXT NOT NULL,    -- 'view', 'edit', 'export', 'search'
    turf_id UUID REFERENCES turfs(id),
    details JSONB NOT NULL DEFAULT '{}',
    ip_address TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_voter_access_log_company ON voter_access_log (company_id, created_at DESC);
CREATE INDEX idx_voter_access_log_user ON voter_access_log (user_id, created_at DESC);
CREATE INDEX idx_voter_access_log_voter ON voter_access_log (voter_id);
```

### Eden Role Level Mapping for Navigators
```go
// Eden's system roles and levels (from eden migrations 003_roles_permissions.up.sql):
// super_admin = 100, owner = 90, admin = 80, manager = 60, member = 40, viewer = 20

// Navigators role mapping:
// Admin       -> eden admin  (level 80, ID: 10000000-0000-0000-0000-000000000002)
// Super Nav   -> eden manager (level 60, ID: 10000000-0000-0000-0000-000000000005)
// Navigator   -> eden member  (level 40, ID: 10000000-0000-0000-0000-000000000003)

// Well-known IDs from eden-platform-go/platform/rbac/service.go:
var (
    AdminRoleID   = uuid.MustParse("10000000-0000-0000-0000-000000000002") // Admin
    ManagerRoleID = uuid.MustParse("10000000-0000-0000-0000-000000000005") // Super Navigator
    MemberRoleID  = uuid.MustParse("10000000-0000-0000-0000-000000000003") // Navigator
)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| bcrypt passwords | Argon2id (OWASP params) | Eden uses since inception | More resistant to GPU attacks |
| RSA/ECDSA JWT | ML-DSA-65 (post-quantum) | Eden uses circl/mldsa65 | Future-proof against quantum |
| Session cookies | JWT access + refresh tokens | Standard in eden | Stateless auth, token rotation |
| Manual permission checks | Interceptor chain (auth -> RBAC -> audit) | Eden pattern | Declarative, centralized |
| Synchronous audit writes | Async buffered audit logger | Eden pattern | Non-blocking, 10k buffer, batch insert |

**Note on eden-platform-go currency:** The codebase was verified directly from `/Users/justin/dev/eden-libs/eden-platform-go/` on 2026-04-10. All code examples are from actual source files, not documentation.

## Open Questions

1. **Email delivery for password reset**
   - What we know: Eden has no email sending capability. The notification package only handles push notifications (device tokens).
   - What's unclear: Which email provider to use (SES, SendGrid, Postmark, etc.)
   - Recommendation: Use a simple SMTP/API-based email service. For MVP, even a basic `net/smtp` call works. Defer provider choice to implementation. The password reset token generation is solved (eden's `CreateShortLivedToken`).

2. **Single company vs multi-tenant for Navigators**
   - What we know: Eden defaults to creating a company per signup. Navigators is a single-org app (MaineGOP).
   - What's unclear: Whether to use B2C mode or pre-create the org.
   - Recommendation: Pre-create the MaineGOP company in a seed migration. Disable public signup. Admin creates user accounts and assigns them to the company with appropriate roles. This is the cleanest approach for AUTH-05.

3. **Separate migration tracking for eden vs navigators**
   - What we know: golang-migrate defaults to `schema_migrations` table. Both eden and navigators need separate migration streams.
   - What's unclear: Whether to use separate table names or a shared sequence.
   - Recommendation: Use golang-migrate's `MigrationsTable` option. Eden uses default `schema_migrations`. Navigators uses `schema_migrations_navigators`. This prevents version conflicts.

4. **PostGIS extension installation**
   - What we know: Eden's compose.yaml uses `pgvector/pgvector:pg16`. PostGIS is a separate extension.
   - What's unclear: Whether to use a different base image or install PostGIS into the existing one.
   - Recommendation: Use `postgis/postgis:16-3.4` image (includes pgvector compatibility) or create a custom Dockerfile. Add `CREATE EXTENSION IF NOT EXISTS postgis;` as the first navigators migration.

5. **Inactivity session timeout mechanism**
   - What we know: Eden stores refresh tokens with expiry. There is no "last active" tracking.
   - What's unclear: Best approach for inactivity timeout.
   - Recommendation: Add `last_active_at` column to refresh_tokens or a separate session table. Check on refresh token use. A background goroutine can revoke tokens inactive for > N minutes. Alternatively, use short access token expiry (already 15 min) and refuse refresh when last activity exceeds threshold.

## Sources

### Primary (HIGH confidence)
- `/Users/justin/dev/eden-libs/eden-platform-go/platform/auth/` -- Full auth implementation (service.go, jwt.go, password.go, store.go)
- `/Users/justin/dev/eden-libs/eden-platform-go/platform/rbac/` -- Full RBAC implementation (enforcer.go, hierarchy.go, service.go, store.go, features.go)
- `/Users/justin/dev/eden-libs/eden-platform-go/platform/audit/` -- Audit logger (logger.go, store.go)
- `/Users/justin/dev/eden-libs/eden-platform-go/platform/server/` -- Interceptors, router, middleware
- `/Users/justin/dev/eden-libs/eden-platform-go/platform/pgstore/` -- All PostgreSQL store implementations
- `/Users/justin/dev/eden-libs/eden-platform-go/platform/config/` -- Configuration loading
- `/Users/justin/dev/eden-libs/eden-platform-go/cmd/eden-platform-dev/main.go` -- Reference consumer bootstrap
- `/Users/justin/dev/eden-libs/eden-platform-go/proto/platform/v1/` -- All proto definitions
- `/Users/justin/dev/eden-libs/eden-platform-go/migrations/platform/` -- All 11 migration files
- `/Users/justin/dev/eden-libs/eden-platform-go/queries/platform/` -- All sqlc query files
- `/Users/justin/dev/eden-libs/eden-platform-go/sqlc.yaml` -- sqlc configuration pattern
- `/Users/justin/dev/eden-libs/eden-platform-flutter/lib/src/auth/` -- Flutter auth (auth_provider.dart, login/signup screens)
- `/Users/justin/dev/eden-libs/eden-platform-flutter/lib/src/api/platform_repository.dart` -- Flutter Connect client
- `/Users/justin/dev/eden-libs/eden-platform-flutter/example/lib/main.dart` -- Consumer Flutter app example
- `/Users/justin/dev/eden-libs/compose.yaml` -- Infrastructure services (PostgreSQL, NATS, MinIO)
- `/Users/justin/dev/aodex-dev/aodex-go/go.mod` -- Verified consumer go.mod pattern

### Secondary (MEDIUM confidence)
- Role level mapping (Navigator=member, Super Nav=manager, Admin=admin) -- logical mapping based on eden level semantics, not prescribed by eden docs

### Tertiary (LOW confidence)
- PostGIS image recommendation -- needs validation that postgis/postgis:16-3.4 includes all needed extensions
- Inactivity timeout approach -- design recommendation, not verified pattern

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all verified from actual source code in eden-libs
- Architecture: HIGH -- consumer pattern verified from aodex-dev and eden-platform-dev
- Eden auth/RBAC capabilities: HIGH -- read every line of auth/, rbac/, server/ packages
- Turf scoping approach: MEDIUM -- logical design, no eden precedent exists
- Password reset flow: MEDIUM -- eden provides token primitives but no complete flow
- Pitfalls: HIGH -- derived from actual code analysis of eden internals

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (eden-libs is locally controlled, stable)
