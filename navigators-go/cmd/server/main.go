package main

import (
	"context"
	"io/fs"
	"log"
	"log/slog"
	"net/http"
	"strings"
	"time"

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
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
	navpkg "navigators-go/internal/navigators"
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
	enforcer := rbac.NewEnforcer(rbacStore, navpkg.NavigatorsPermissionMatrix())

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

	publicProcedures := navpkg.MergedPublicProcedures()
	authInterceptor := server.NewAuthInterceptor(jwtManager, publicProcedures)
	rbacConfig := server.InterceptorConfig{
		PublicProcedures:     publicProcedures,
		ProcedurePermissions: navpkg.NavigatorsProcedurePermissions(),
	}
	rbacInterceptor := server.NewRBACInterceptor(enforcer, rbacConfig)
	auditInterceptor := server.NewAuditInterceptor(auditLogger, publicProcedures)

	interceptors := connect.WithInterceptors(obsInterceptor, authInterceptor, rbacInterceptor, auditInterceptor)

	server.RegisterPlatformHandlers(
		mux,
		server.PlatformHandlers{
			Auth: connectapi.NewAuthHandler(authService, ssoService),
		},
		interceptors,
	)

	// --- Navigators admin service ---
	adminService := navpkg.NewAdminService(
		authStore,
		rbacStore,
		auth.NewPasswordHasher(),
		jwtManager,
		auditLogger,
		pgBackend.Pool(),
	)
	adminHandler := navpkg.NewAdminHandler(adminService)
	adminPath, adminHTTPHandler := navigatorsv1connect.NewAdminServiceHandler(adminHandler, interceptors)
	mux.Handle(adminPath, adminHTTPHandler)

	// --- Session timeout checker ---
	// Check every 5 minutes, revoke tokens inactive for 30 minutes.
	navpkg.StartSessionTimeoutChecker(ctx, pgBackend.Pool(), 5*time.Minute, 30*time.Minute)

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

