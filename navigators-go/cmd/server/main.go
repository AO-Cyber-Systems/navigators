package main

import (
	"context"
	"io/fs"
	"log"
	"log/slog"
	"net/http"
	"strings"

	connect "connectrpc.com/connect"
	edenplatform "github.com/aocybersystems/eden-platform-go"
	"github.com/aocybersystems/eden-platform-go/platform/audit"
	"github.com/aocybersystems/eden-platform-go/platform/auth"
	"github.com/aocybersystems/eden-platform-go/platform/config"
	"github.com/aocybersystems/eden-platform-go/platform/connectapi"
	"github.com/aocybersystems/eden-platform-go/platform/observability"
	"github.com/aocybersystems/eden-platform-go/platform/pgstore"
	"github.com/aocybersystems/eden-platform-go/platform/rbac"
	"github.com/aocybersystems/eden-platform-go/platform/server"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"
	"github.com/golang-migrate/migrate/v4/source/iofs"

	navigators "navigators-go"
)

func main() {
	observability.InitLogging("", "")

	cfg := config.Load()
	ctx := context.Background()

	// --- Eden platform bootstrap ---
	edenMigrationsFS, err := fs.Sub(edenplatform.MigrationsFS, "migrations/platform")
	if err != nil {
		log.Fatalf("sub eden migrations fs: %v", err)
	}

	pgBackend, err := pgstore.NewBackend(ctx, cfg.DatabaseURL, edenMigrationsFS)
	if err != nil {
		log.Fatalf("pgstore backend: %v", err)
	}
	defer pgBackend.Close()

	// --- Navigators migrations (separate tracking table) ---
	navMigrationsFS, err := fs.Sub(navigators.NavigatorsMigrationsFS, "migrations/navigators")
	if err != nil {
		log.Fatalf("sub navigators migrations fs: %v", err)
	}
	if err := runNavigatorsMigrations(cfg.DatabaseURL, navMigrationsFS); err != nil {
		log.Fatalf("navigators migrations: %v", err)
	}

	// --- Auth + RBAC wiring ---
	jwtManager, err := auth.NewJWTManager(auth.JWTConfig{
		KeySeedPath:        cfg.JWTKeySeedPath,
		Issuer:             "navigators",
		AccessTokenExpiry:  auth.DefaultJWTConfig().AccessTokenExpiry,
		RefreshTokenExpiry: auth.DefaultJWTConfig().RefreshTokenExpiry,
	})
	if err != nil {
		log.Fatalf("create jwt manager: %v", err)
	}

	authStore := pgBackend.AuthStore()
	authService := auth.NewService(authStore, jwtManager, auth.NewPasswordHasher())
	ssoService := auth.NewSSOService(authStore, jwtManager, "http://localhost"+cfg.ServerAddr)

	rbacStore := pgBackend.RBACStore()
	enforcer := rbac.NewEnforcer(rbacStore, navigatorsPermissionMatrix())

	// --- Audit logging ---
	auditStore := pgBackend.AuditStore()
	auditLogger := audit.NewLogger(auditStore)
	auditLogger.Start()
	defer auditLogger.Stop()

	// --- Observability ---
	metrics := observability.NewMetrics()
	obsInterceptor := observability.NewObservabilityInterceptor(metrics)

	// --- HTTP server ---
	mux := http.NewServeMux()

	publicProcedures := publicProcedures()
	authInterceptor := server.NewAuthInterceptor(jwtManager, publicProcedures)
	rbacConfig := server.InterceptorConfig{
		PublicProcedures:     publicProcedures,
		ProcedurePermissions: navigatorsProcedurePermissions(),
	}
	rbacInterceptor := server.NewRBACInterceptor(enforcer, rbacConfig)
	auditInterceptor := server.NewAuditInterceptor(auditLogger, publicProcedures)

	server.RegisterPlatformHandlers(
		mux,
		server.PlatformHandlers{
			Auth: connectapi.NewAuthHandler(authService, ssoService),
		},
		connect.WithInterceptors(obsInterceptor, authInterceptor, rbacInterceptor, auditInterceptor),
	)

	// Health check
	healthChecker := server.NewHealthChecker()
	mux.Handle("/up", healthChecker.Handler())
	mux.Handle("/metrics", metrics.MetricsHandler())

	handler := server.CORSMiddleware(server.LoggingMiddleware(mux))

	slog.Info("navigators server starting", "addr", cfg.ServerAddr)
	if err := http.ListenAndServe(cfg.ServerAddr, handler); err != nil {
		log.Fatalf("server error: %v", err)
	}
}

// runNavigatorsMigrations runs navigators-specific migrations with a separate tracking table.
func runNavigatorsMigrations(databaseURL string, migrationsFS fs.FS) error {
	source, err := iofs.New(migrationsFS, ".")
	if err != nil {
		return err
	}

	// Append custom migration table parameter
	sep := "?"
	if strings.Contains(databaseURL, "?") {
		sep = "&"
	}
	navDatabaseURL := databaseURL + sep + "x-migrations-table=schema_migrations_navigators"

	m, err := migrate.NewWithSourceInstance("iofs", source, navDatabaseURL)
	if err != nil {
		return err
	}
	if err := m.Up(); err != nil && err != migrate.ErrNoChange {
		return err
	}
	return nil
}

// publicProcedures returns the set of procedures that do not require authentication.
// Includes eden's default public procedures.
func publicProcedures() map[string]bool {
	return server.DefaultPublicProcedures()
}

// navigatorsPermissionMatrix returns the RBAC permission matrix for navigators.
// Placeholder: TRD-02 will populate this with voter, turf, team, admin permissions.
func navigatorsPermissionMatrix() rbac.PermissionMatrix {
	return nil
}

// navigatorsProcedurePermissions returns the procedure-to-permission mapping for navigators.
// Placeholder: TRD-02 will populate this with navigators-specific procedure permissions.
func navigatorsProcedurePermissions() map[string]server.Permission {
	return map[string]server.Permission{}
}
