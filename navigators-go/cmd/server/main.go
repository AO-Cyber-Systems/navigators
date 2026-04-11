package main

import (
	"context"
	"io/fs"
	"log"
	"log/slog"
	"net/http"
	"os"
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
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"

	navigators "navigators-go"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
	"navigators-go/internal/db"
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

	// --- sqlc queries for navigators domain ---
	navQueries := db.New(pgBackend.Pool())

	// --- Audit service ---
	navAuditService := navpkg.NewAuditService(navQueries, auditLogger)

	// --- Navigators admin service ---
	adminService := navpkg.NewAdminService(
		authStore,
		rbacStore,
		auth.NewPasswordHasher(),
		jwtManager,
		auditLogger,
		pgBackend.Pool(),
	)
	adminHandler := navpkg.NewAdminHandler(adminService, navAuditService)
	adminPath, adminHTTPHandler := navigatorsv1connect.NewAdminServiceHandler(adminHandler, interceptors)
	mux.Handle(adminPath, adminHTTPHandler)

	// --- Turf service ---
	turfHandler := navpkg.NewTurfHandler(navQueries)
	turfPath, turfHTTPHandler := navigatorsv1connect.NewTurfServiceHandler(turfHandler, interceptors)
	mux.Handle(turfPath, turfHTTPHandler)

	// --- Team service ---
	teamHandler := navpkg.NewTeamHandler(navQueries)
	teamPath, teamHTTPHandler := navigatorsv1connect.NewTeamServiceHandler(teamHandler, interceptors)
	mux.Handle(teamPath, teamHTTPHandler)

	// --- MinIO client for voter file imports ---
	minioClient, err := minio.New(cfg.MinIOEndpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.MinIOAccessKey, cfg.MinIOSecretKey, ""),
		Secure: cfg.MinIOUseSSL,
		Region: cfg.MinIORegion,
	})
	if err != nil {
		log.Fatalf("minio client: %v", err)
	}

	// Ensure voter-imports bucket exists
	voterImportsBucket := "voter-imports"
	exists, err := minioClient.BucketExists(ctx, voterImportsBucket)
	if err != nil {
		log.Fatalf("check voter-imports bucket: %v", err)
	}
	if !exists {
		if err := minioClient.MakeBucket(ctx, voterImportsBucket, minio.MakeBucketOptions{Region: cfg.MinIORegion}); err != nil {
			log.Fatalf("create voter-imports bucket: %v", err)
		}
		slog.Info("created voter-imports bucket")
	}

	// --- Turf scoped filter ---
	turfScopedFilter := navpkg.NewTurfScopedFilter(navQueries)

	// --- Geocode service ---
	googleMapsAPIKey := os.Getenv("GOOGLE_MAPS_API_KEY")
	geocodeService := navpkg.NewGeocodeService(navQueries, pgBackend.Pool(), googleMapsAPIKey)

	// --- Voter import service ---
	importService := navpkg.NewImportService(navQueries, pgBackend.Pool(), minioClient, voterImportsBucket, navAuditService)
	importService.SetGeocodeService(geocodeService)
	importHandler := navpkg.NewImportHandler(importService)
	importPath, importHTTPHandler := navigatorsv1connect.NewVoterImportServiceHandler(importHandler, interceptors)
	mux.Handle(importPath, importHTTPHandler)

	// --- Suppression service ---
	suppressionService := navpkg.NewSuppressionService(navQueries, navAuditService)

	// --- Voter query service ---
	voterService := navpkg.NewVoterService(navQueries, pgBackend.Pool(), turfScopedFilter, navAuditService)
	tagService := navpkg.NewTagService(navQueries, navAuditService)
	voterHandler := navpkg.NewVoterHandler(voterService, tagService, suppressionService)
	voterPath, voterHTTPHandler := navigatorsv1connect.NewVoterServiceHandler(voterHandler, interceptors)
	mux.Handle(voterPath, voterHTTPHandler)

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

