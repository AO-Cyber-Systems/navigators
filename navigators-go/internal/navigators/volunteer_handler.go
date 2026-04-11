package navigators

import (
	"context"
	"fmt"
	"time"

	connect "connectrpc.com/connect"
	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"

	"navigators-go/internal/db"

	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
)

// --- OnboardingHandler ---

// Compile-time check that OnboardingHandler implements the generated interface.
var _ navigatorsv1connect.OnboardingServiceHandler = (*OnboardingHandler)(nil)

// OnboardingHandler implements the navigators.v1.OnboardingService ConnectRPC handler.
type OnboardingHandler struct {
	volunteerService *VolunteerService
}

// NewOnboardingHandler creates a new OnboardingHandler.
func NewOnboardingHandler(volunteerService *VolunteerService) *OnboardingHandler {
	return &OnboardingHandler{volunteerService: volunteerService}
}

func (h *OnboardingHandler) GetOnboardingStatus(ctx context.Context, req *connect.Request[navigatorsv1.GetOnboardingStatusRequest]) (*connect.Response[navigatorsv1.GetOnboardingStatusResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	claims := server.ClaimsFromContext(ctx)
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	profile, err := h.volunteerService.GetOrCreateProfile(ctx, companyID, userID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get onboarding status: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.GetOnboardingStatusResponse{
		Profile:            dbProfileToProto(profile),
		OnboardingComplete: profile.OnboardingCompletedAt.Valid,
	}), nil
}

func (h *OnboardingHandler) AcknowledgeLegal(ctx context.Context, req *connect.Request[navigatorsv1.AcknowledgeLegalRequest]) (*connect.Response[navigatorsv1.AcknowledgeLegalResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	version := req.Msg.GetVersion()
	if version == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("version is required"))
	}

	if err := h.volunteerService.AcknowledgeLegal(ctx, userID, version); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("acknowledge legal: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.AcknowledgeLegalResponse{}), nil
}

func (h *OnboardingHandler) CompleteOnboarding(ctx context.Context, req *connect.Request[navigatorsv1.CompleteOnboardingRequest]) (*connect.Response[navigatorsv1.CompleteOnboardingResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	profile, err := h.volunteerService.CompleteOnboarding(ctx, userID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("complete onboarding: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.CompleteOnboardingResponse{
		Profile: dbProfileToProto(profile),
	}), nil
}

func (h *OnboardingHandler) UpdateLeaderboardOptIn(ctx context.Context, req *connect.Request[navigatorsv1.UpdateLeaderboardOptInRequest]) (*connect.Response[navigatorsv1.UpdateLeaderboardOptInResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	if err := h.volunteerService.UpdateLeaderboardOptIn(ctx, userID, req.Msg.GetOptIn()); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("update leaderboard opt-in: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.UpdateLeaderboardOptInResponse{}), nil
}

// --- LeaderboardHandler ---

// Compile-time check that LeaderboardHandler implements the generated interface.
var _ navigatorsv1connect.LeaderboardServiceHandler = (*LeaderboardHandler)(nil)

// LeaderboardHandler implements the navigators.v1.LeaderboardService ConnectRPC handler.
type LeaderboardHandler struct {
	volunteerService *VolunteerService
}

// NewLeaderboardHandler creates a new LeaderboardHandler.
func NewLeaderboardHandler(volunteerService *VolunteerService) *LeaderboardHandler {
	return &LeaderboardHandler{volunteerService: volunteerService}
}

func (h *LeaderboardHandler) GetLeaderboard(ctx context.Context, req *connect.Request[navigatorsv1.GetLeaderboardRequest]) (*connect.Response[navigatorsv1.GetLeaderboardResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	timeWindow := req.Msg.GetTimeWindow()
	if timeWindow == "" {
		timeWindow = "all_time"
	}
	switch timeWindow {
	case "week", "month", "all_time":
	default:
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("time_window must be week, month, or all_time"))
	}

	rows, err := h.volunteerService.GetLeaderboard(ctx, companyID, timeWindow)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get leaderboard: %w", err))
	}

	entries := make([]*navigatorsv1.LeaderboardEntry, len(rows))
	for i, r := range rows {
		entries[i] = &navigatorsv1.LeaderboardEntry{
			UserId:         r.UserID.String(),
			DisplayName:    r.DisplayName,
			DoorsKnocked:   r.DoorsKnocked,
			TextsSent:      r.TextsSent,
			CallsMade:      r.CallsMade,
			TotalActions:   r.TotalActions,
			EventsAttended: r.EventsAttended,
		}
	}

	return connect.NewResponse(&navigatorsv1.GetLeaderboardResponse{
		Entries: entries,
	}), nil
}

// --- TrainingHandler ---

// Compile-time check that TrainingHandler implements the generated interface.
var _ navigatorsv1connect.TrainingServiceHandler = (*TrainingHandler)(nil)

// TrainingHandler implements the navigators.v1.TrainingService ConnectRPC handler.
type TrainingHandler struct {
	volunteerService *VolunteerService
}

// NewTrainingHandler creates a new TrainingHandler.
func NewTrainingHandler(volunteerService *VolunteerService) *TrainingHandler {
	return &TrainingHandler{volunteerService: volunteerService}
}

func (h *TrainingHandler) ListTrainingMaterials(ctx context.Context, req *connect.Request[navigatorsv1.ListTrainingMaterialsRequest]) (*connect.Response[navigatorsv1.ListTrainingMaterialsResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	materials, err := h.volunteerService.ListTrainingMaterials(ctx, companyID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("list training materials: %w", err))
	}

	pbMaterials := make([]*navigatorsv1.TrainingMaterial, len(materials))
	for i := range materials {
		pbMaterials[i] = dbTrainingMaterialToProto(&materials[i])
	}

	return connect.NewResponse(&navigatorsv1.ListTrainingMaterialsResponse{
		Materials: pbMaterials,
	}), nil
}

func (h *TrainingHandler) CreateTrainingMaterial(ctx context.Context, req *connect.Request[navigatorsv1.CreateTrainingMaterialRequest]) (*connect.Response[navigatorsv1.CreateTrainingMaterialResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	claims := server.ClaimsFromContext(ctx)
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	// Role gate: admin/manager only (RoleLevel >= 60)
	if claims.RoleLevel < 60 {
		return nil, connect.NewError(connect.CodePermissionDenied, fmt.Errorf("insufficient permissions"))
	}

	title := req.Msg.GetTitle()
	if title == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("title is required"))
	}

	contentURL := req.Msg.GetContentUrl()
	if contentURL == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("content_url is required"))
	}

	material, err := h.volunteerService.CreateTrainingMaterial(ctx, companyID, userID, title, req.Msg.GetDescription(), contentURL, req.Msg.GetSortOrder())
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("create training material: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.CreateTrainingMaterialResponse{
		Material: dbTrainingMaterialToProto(material),
	}), nil
}

func (h *TrainingHandler) GetTrainingDownloadUrl(ctx context.Context, req *connect.Request[navigatorsv1.GetTrainingDownloadUrlRequest]) (*connect.Response[navigatorsv1.GetTrainingDownloadUrlResponse], error) {
	materialID, err := uuid.Parse(req.Msg.GetMaterialId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid material_id: %w", err))
	}

	presignedURL, err := h.volunteerService.GetTrainingDownloadURL(ctx, materialID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get training download url: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.GetTrainingDownloadUrlResponse{
		PresignedUrl: presignedURL,
	}), nil
}

// --- Proto conversion helpers ---

func dbProfileToProto(p *db.NavigatorProfile) *navigatorsv1.NavigatorProfile {
	var onboardingCompletedAt string
	if p.OnboardingCompletedAt.Valid {
		onboardingCompletedAt = p.OnboardingCompletedAt.Time.Format(time.RFC3339)
	}
	var legalAcknowledgmentAt string
	if p.LegalAcknowledgmentAt.Valid {
		legalAcknowledgmentAt = p.LegalAcknowledgmentAt.Time.Format(time.RFC3339)
	}
	var legalVersion string
	if p.LegalAcknowledgmentVersion != nil {
		legalVersion = *p.LegalAcknowledgmentVersion
	}

	return &navigatorsv1.NavigatorProfile{
		UserId:                     p.UserID.String(),
		CompanyId:                  p.CompanyID.String(),
		OnboardingCompletedAt:      onboardingCompletedAt,
		LegalAcknowledgmentAt:      legalAcknowledgmentAt,
		LegalAcknowledgmentVersion: legalVersion,
		LeaderboardOptIn:           p.LeaderboardOptIn,
		CreatedAt:                  p.CreatedAt.Format(time.RFC3339),
		UpdatedAt:                  p.UpdatedAt.Format(time.RFC3339),
	}
}

func dbTrainingMaterialToProto(m *db.TrainingMaterial) *navigatorsv1.TrainingMaterial {
	return &navigatorsv1.TrainingMaterial{
		Id:          m.ID.String(),
		Title:       m.Title,
		Description: m.Description,
		ContentUrl:  m.ContentUrl,
		SortOrder:   m.SortOrder,
		IsPublished: m.IsPublished,
		CreatedAt:   m.CreatedAt.Format(time.RFC3339),
	}
}
