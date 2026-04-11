package navigators

import (
	"context"
	"fmt"
	"net/url"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/minio/minio-go/v7"

	"navigators-go/internal/db"
)

// VolunteerService provides onboarding, leaderboard, and training material operations.
type VolunteerService struct {
	queries        *db.Queries
	pool           *pgxpool.Pool
	minioClient    *minio.Client
	trainingBucket string
}

// NewVolunteerService creates a new VolunteerService.
func NewVolunteerService(queries *db.Queries, pool *pgxpool.Pool, minioClient *minio.Client, trainingBucket string) *VolunteerService {
	return &VolunteerService{
		queries:        queries,
		pool:           pool,
		minioClient:    minioClient,
		trainingBucket: trainingBucket,
	}
}

// GetOrCreateProfile returns an existing profile or creates a new one.
func (s *VolunteerService) GetOrCreateProfile(ctx context.Context, companyID, userID uuid.UUID) (*db.NavigatorProfile, error) {
	profile, err := s.queries.UpsertNavigatorProfile(ctx, db.UpsertNavigatorProfileParams{
		UserID:    userID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("upsert navigator profile: %w", err)
	}
	return &profile, nil
}

// AcknowledgeLegal records a legal acknowledgment with version string for audit.
func (s *VolunteerService) AcknowledgeLegal(ctx context.Context, userID uuid.UUID, version string) error {
	if err := s.queries.UpdateLegalAcknowledgment(ctx, db.UpdateLegalAcknowledgmentParams{
		UserID:                     userID,
		LegalAcknowledgmentVersion: &version,
	}); err != nil {
		return fmt.Errorf("update legal acknowledgment: %w", err)
	}
	return nil
}

// CompleteOnboarding marks onboarding as complete, gating app access.
func (s *VolunteerService) CompleteOnboarding(ctx context.Context, userID uuid.UUID) (*db.NavigatorProfile, error) {
	profile, err := s.queries.CompleteOnboarding(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("complete onboarding: %w", err)
	}
	return &profile, nil
}

// UpdateLeaderboardOptIn toggles leaderboard participation.
func (s *VolunteerService) UpdateLeaderboardOptIn(ctx context.Context, userID uuid.UUID, optIn bool) error {
	if err := s.queries.UpdateLeaderboardOptIn(ctx, db.UpdateLeaderboardOptInParams{
		UserID:           userID,
		LeaderboardOptIn: optIn,
	}); err != nil {
		return fmt.Errorf("update leaderboard opt-in: %w", err)
	}
	return nil
}

// GetLeaderboard returns aggregated metrics for opted-in navigators.
func (s *VolunteerService) GetLeaderboard(ctx context.Context, companyID uuid.UUID, timeWindow string) ([]db.GetLeaderboardRow, error) {
	var since time.Time
	switch timeWindow {
	case "week":
		since = time.Now().UTC().AddDate(0, 0, -7)
	case "month":
		since = time.Now().UTC().AddDate(0, 0, -30)
	case "all_time":
		since = time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC)
	default:
		return nil, fmt.Errorf("invalid time_window: %s (must be week, month, or all_time)", timeWindow)
	}

	rows, err := s.queries.GetLeaderboard(ctx, db.GetLeaderboardParams{
		CompanyID:   companyID,
		CheckedInAt: since,
	})
	if err != nil {
		return nil, fmt.Errorf("get leaderboard: %w", err)
	}
	return rows, nil
}

// ListTrainingMaterials returns published training materials for a company.
func (s *VolunteerService) ListTrainingMaterials(ctx context.Context, companyID uuid.UUID) ([]db.TrainingMaterial, error) {
	materials, err := s.queries.ListTrainingMaterials(ctx, companyID)
	if err != nil {
		return nil, fmt.Errorf("list training materials: %w", err)
	}
	return materials, nil
}

// CreateTrainingMaterial creates a new training material entry.
func (s *VolunteerService) CreateTrainingMaterial(ctx context.Context, companyID, userID uuid.UUID, title, description, contentURL string, sortOrder int32) (*db.TrainingMaterial, error) {
	material, err := s.queries.CreateTrainingMaterial(ctx, db.CreateTrainingMaterialParams{
		CompanyID:   companyID,
		Title:       title,
		Description: description,
		ContentUrl:  contentURL,
		SortOrder:   sortOrder,
		CreatedBy:   userID,
	})
	if err != nil {
		return nil, fmt.Errorf("create training material: %w", err)
	}
	return &material, nil
}

// GetTrainingDownloadURL returns a presigned download URL for a training material.
func (s *VolunteerService) GetTrainingDownloadURL(ctx context.Context, materialID uuid.UUID) (string, error) {
	material, err := s.queries.GetTrainingMaterial(ctx, materialID)
	if err != nil {
		return "", fmt.Errorf("get training material: %w", err)
	}

	// Generate a 15-minute presigned URL for the MinIO object
	reqParams := make(url.Values)
	presignedURL, err := s.minioClient.PresignedGetObject(ctx, s.trainingBucket, material.ContentUrl, 15*time.Minute, reqParams)
	if err != nil {
		return "", fmt.Errorf("generate presigned URL: %w", err)
	}

	return presignedURL.String(), nil
}
