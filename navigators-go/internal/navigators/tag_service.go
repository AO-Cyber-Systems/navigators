package navigators

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"

	"navigators-go/internal/db"
)

// TagService provides voter tag CRUD and assignment operations.
type TagService struct {
	queries      *db.Queries
	auditService *AuditService
}

// NewTagService creates a new TagService.
func NewTagService(queries *db.Queries, auditService *AuditService) *TagService {
	return &TagService{
		queries:      queries,
		auditService: auditService,
	}
}

// CreateTag creates a new voter tag for the company.
func (s *TagService) CreateTag(ctx context.Context, name, color string) (*db.VoterTag, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("parse company ID: %w", err)
	}
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, fmt.Errorf("parse user ID: %w", err)
	}

	if color == "" {
		color = "#6B7280"
	}

	tag, err := s.queries.CreateTag(ctx, db.CreateTagParams{
		CompanyID: companyID,
		Name:      name,
		Color:     color,
		CreatedBy: userID,
	})
	if err != nil {
		return nil, fmt.Errorf("create tag: %w", err)
	}

	return &tag, nil
}

// ListTags returns all tags for the company.
func (s *TagService) ListTags(ctx context.Context) ([]db.VoterTag, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("parse company ID: %w", err)
	}

	tags, err := s.queries.ListTags(ctx, companyID)
	if err != nil {
		return nil, fmt.Errorf("list tags: %w", err)
	}

	return tags, nil
}

// DeleteTag removes a voter tag. Admin only.
func (s *TagService) DeleteTag(ctx context.Context, tagID uuid.UUID) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return fmt.Errorf("parse company ID: %w", err)
	}

	if err := s.queries.DeleteTag(ctx, db.DeleteTagParams{
		ID:        tagID,
		CompanyID: companyID,
	}); err != nil {
		return fmt.Errorf("delete tag: %w", err)
	}

	return nil
}

// AssignTag assigns a tag to a voter.
func (s *TagService) AssignTag(ctx context.Context, voterID, tagID uuid.UUID) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}

	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return fmt.Errorf("parse user ID: %w", err)
	}

	if err := s.queries.AssignTagToVoter(ctx, db.AssignTagToVoterParams{
		VoterID:    voterID,
		TagID:      tagID,
		AssignedBy: userID,
	}); err != nil {
		return fmt.Errorf("assign tag: %w", err)
	}

	// Log audit
	if err := s.auditService.LogVoterAccess(ctx, voterID.String(), "edit", nil, map[string]any{
		"action": "assign_tag",
		"tag_id": tagID.String(),
	}); err != nil {
		slog.Warn("failed to log tag assignment audit", "error", err)
	}

	return nil
}

// RemoveTag removes a tag from a voter.
func (s *TagService) RemoveTag(ctx context.Context, voterID, tagID uuid.UUID) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}

	if err := s.queries.RemoveTagFromVoter(ctx, db.RemoveTagFromVoterParams{
		VoterID: voterID,
		TagID:   tagID,
	}); err != nil {
		return fmt.Errorf("remove tag: %w", err)
	}

	// Log audit
	if err := s.auditService.LogVoterAccess(ctx, voterID.String(), "edit", nil, map[string]any{
		"action": "remove_tag",
		"tag_id": tagID.String(),
	}); err != nil {
		slog.Warn("failed to log tag removal audit", "error", err)
	}

	return nil
}

// GetVoterTags returns all tags assigned to a voter.
func (s *TagService) GetVoterTags(ctx context.Context, voterID uuid.UUID) ([]db.VoterTag, error) {
	tags, err := s.queries.GetVoterTags(ctx, voterID)
	if err != nil {
		return nil, fmt.Errorf("get voter tags: %w", err)
	}

	return tags, nil
}
