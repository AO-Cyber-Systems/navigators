package navigators

import (
	"context"
	"fmt"

	connect "connectrpc.com/connect"
	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
	"github.com/google/uuid"
)

// Compile-time check that AdminHandler implements the generated interface.
var _ navigatorsv1connect.AdminServiceHandler = (*AdminHandler)(nil)

// AdminHandler implements the navigators.v1.AdminService ConnectRPC handler.
type AdminHandler struct {
	service *AdminService
}

// NewAdminHandler creates a new AdminHandler wrapping the AdminService.
func NewAdminHandler(service *AdminService) *AdminHandler {
	return &AdminHandler{service: service}
}

// --- User Management ---

func (h *AdminHandler) CreateUser(ctx context.Context, req *connect.Request[navigatorsv1.CreateUserRequest]) (*connect.Response[navigatorsv1.CreateUserResponse], error) {
	userID, err := h.service.CreateUser(ctx,
		req.Msg.GetEmail(),
		req.Msg.GetDisplayName(),
		req.Msg.GetPassword(),
		req.Msg.GetRole(),
	)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}

	return connect.NewResponse(&navigatorsv1.CreateUserResponse{
		UserId: userID.String(),
		Email:  req.Msg.GetEmail(),
		Role:   req.Msg.GetRole(),
	}), nil
}

func (h *AdminHandler) ListUsers(ctx context.Context, req *connect.Request[navigatorsv1.ListUsersRequest]) (*connect.Response[navigatorsv1.ListUsersResponse], error) {
	users, err := h.service.ListUsers(ctx)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	pbUsers := make([]*navigatorsv1.UserInfo, len(users))
	for i, u := range users {
		pbUsers[i] = &navigatorsv1.UserInfo{
			UserId:      u.ID.String(),
			Email:       u.Email,
			DisplayName: u.DisplayName,
			Role:        u.Role,
			IsActive:    u.IsActive,
			CreatedAt:   u.CreatedAt,
		}
	}

	return connect.NewResponse(&navigatorsv1.ListUsersResponse{
		Users: pbUsers,
	}), nil
}

func (h *AdminHandler) DeactivateUser(ctx context.Context, req *connect.Request[navigatorsv1.DeactivateUserRequest]) (*connect.Response[navigatorsv1.DeactivateUserResponse], error) {
	userID, err := uuid.Parse(req.Msg.GetUserId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid user_id"))
	}

	if err := h.service.DeactivateUser(ctx, userID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.DeactivateUserResponse{}), nil
}

func (h *AdminHandler) AssignRole(ctx context.Context, req *connect.Request[navigatorsv1.AssignRoleRequest]) (*connect.Response[navigatorsv1.AssignRoleResponse], error) {
	userID, err := uuid.Parse(req.Msg.GetUserId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid user_id"))
	}

	if err := h.service.AssignRole(ctx, userID, req.Msg.GetRole()); err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}

	return connect.NewResponse(&navigatorsv1.AssignRoleResponse{}), nil
}

// --- Password Reset ---

func (h *AdminHandler) RequestPasswordReset(ctx context.Context, req *connect.Request[navigatorsv1.RequestPasswordResetRequest]) (*connect.Response[navigatorsv1.RequestPasswordResetResponse], error) {
	// Always returns success to prevent user enumeration
	_ = h.service.RequestPasswordReset(ctx, req.Msg.GetEmail())

	return connect.NewResponse(&navigatorsv1.RequestPasswordResetResponse{
		Message: "If an account exists with that email, a password reset link has been sent.",
	}), nil
}

func (h *AdminHandler) ConfirmPasswordReset(ctx context.Context, req *connect.Request[navigatorsv1.ConfirmPasswordResetRequest]) (*connect.Response[navigatorsv1.ConfirmPasswordResetResponse], error) {
	if err := h.service.ConfirmPasswordReset(ctx, req.Msg.GetToken(), req.Msg.GetNewPassword()); err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}

	return connect.NewResponse(&navigatorsv1.ConfirmPasswordResetResponse{
		Message: "Password has been reset successfully. Please log in with your new password.",
	}), nil
}

// --- Session Management ---

func (h *AdminHandler) RevokeSession(ctx context.Context, req *connect.Request[navigatorsv1.RevokeSessionRequest]) (*connect.Response[navigatorsv1.RevokeSessionResponse], error) {
	userID, err := uuid.Parse(req.Msg.GetUserId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid user_id"))
	}

	if err := h.service.RevokeSession(ctx, userID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.RevokeSessionResponse{}), nil
}

func (h *AdminHandler) ListActiveSessions(ctx context.Context, req *connect.Request[navigatorsv1.ListActiveSessionsRequest]) (*connect.Response[navigatorsv1.ListActiveSessionsResponse], error) {
	sessions, err := h.service.ListActiveSessions(ctx)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	pbSessions := make([]*navigatorsv1.SessionInfo, len(sessions))
	for i, s := range sessions {
		lastActive := ""
		if s.LastActiveAt != nil {
			lastActive = s.LastActiveAt.Format("2006-01-02T15:04:05Z")
		}
		pbSessions[i] = &navigatorsv1.SessionInfo{
			UserId:       s.UserID.String(),
			Email:        s.Email,
			CreatedAt:    s.CreatedAt.Format("2006-01-02T15:04:05Z"),
			LastActiveAt: lastActive,
		}
	}

	return connect.NewResponse(&navigatorsv1.ListActiveSessionsResponse{
		Sessions: pbSessions,
	}), nil
}
