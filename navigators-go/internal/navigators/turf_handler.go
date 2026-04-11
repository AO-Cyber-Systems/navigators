package navigators

import (
	"context"
	"fmt"

	connect "connectrpc.com/connect"
	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"

	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
	"navigators-go/internal/db"
)

// Compile-time check that TurfHandler implements the generated interface.
var _ navigatorsv1connect.TurfServiceHandler = (*TurfHandler)(nil)

// TurfHandler implements the navigators.v1.TurfService ConnectRPC handler.
type TurfHandler struct {
	queries *db.Queries
}

// NewTurfHandler creates a new TurfHandler.
func NewTurfHandler(queries *db.Queries) *TurfHandler {
	return &TurfHandler{queries: queries}
}

func (h *TurfHandler) CreateTurf(ctx context.Context, req *connect.Request[navigatorsv1.CreateTurfRequest]) (*connect.Response[navigatorsv1.CreateTurfResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no claims"))
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse company ID: %w", err))
	}

	name := req.Msg.GetName()
	if name == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("name is required"))
	}

	turf, err := h.queries.CreateTurf(ctx, db.CreateTurfParams{
		CompanyID:   companyID,
		Name:        name,
		Description: req.Msg.GetDescription(),
	})
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("create turf: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.CreateTurfResponse{
		TurfId: turf.ID.String(),
		Name:   turf.Name,
	}), nil
}

func (h *TurfHandler) ListTurfs(ctx context.Context, req *connect.Request[navigatorsv1.ListTurfsRequest]) (*connect.Response[navigatorsv1.ListTurfsResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no claims"))
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse company ID: %w", err))
	}

	turfs, err := h.queries.GetTurfsByCompany(ctx, companyID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("list turfs: %w", err))
	}

	pbTurfs := make([]*navigatorsv1.TurfInfo, len(turfs))
	for i, t := range turfs {
		pbTurfs[i] = &navigatorsv1.TurfInfo{
			TurfId:      t.ID.String(),
			Name:        t.Name,
			Description: t.Description,
			IsActive:    t.IsActive,
			CreatedAt:   t.CreatedAt.Format("2006-01-02T15:04:05Z"),
			UpdatedAt:   t.UpdatedAt.Format("2006-01-02T15:04:05Z"),
		}
	}

	return connect.NewResponse(&navigatorsv1.ListTurfsResponse{
		Turfs: pbTurfs,
	}), nil
}

func (h *TurfHandler) AssignUserToTurf(ctx context.Context, req *connect.Request[navigatorsv1.AssignUserToTurfRequest]) (*connect.Response[navigatorsv1.AssignUserToTurfResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no claims"))
	}

	turfID, err := uuid.Parse(req.Msg.GetTurfId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid turf_id"))
	}
	userID, err := uuid.Parse(req.Msg.GetUserId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid user_id"))
	}
	assignedBy, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse caller ID: %w", err))
	}

	if err := h.queries.AssignUserToTurf(ctx, db.AssignUserToTurfParams{
		TurfID:     turfID,
		UserID:     userID,
		AssignedBy: assignedBy,
	}); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("assign user to turf: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.AssignUserToTurfResponse{}), nil
}

func (h *TurfHandler) RemoveUserFromTurf(ctx context.Context, req *connect.Request[navigatorsv1.RemoveUserFromTurfRequest]) (*connect.Response[navigatorsv1.RemoveUserFromTurfResponse], error) {
	turfID, err := uuid.Parse(req.Msg.GetTurfId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid turf_id"))
	}
	userID, err := uuid.Parse(req.Msg.GetUserId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid user_id"))
	}

	if err := h.queries.RemoveUserFromTurf(ctx, db.RemoveUserFromTurfParams{
		TurfID: turfID,
		UserID: userID,
	}); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("remove user from turf: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.RemoveUserFromTurfResponse{}), nil
}

func (h *TurfHandler) GetUserTurfs(ctx context.Context, req *connect.Request[navigatorsv1.GetUserTurfsRequest]) (*connect.Response[navigatorsv1.GetUserTurfsResponse], error) {
	userID, err := uuid.Parse(req.Msg.GetUserId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid user_id"))
	}

	assignments, err := h.queries.GetTurfAssignmentsForUser(ctx, userID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get user turfs: %w", err))
	}

	pbAssignments := make([]*navigatorsv1.TurfAssignment, len(assignments))
	for i, a := range assignments {
		pbAssignments[i] = &navigatorsv1.TurfAssignment{
			TurfId:   a.TurfID.String(),
			TurfName: a.TurfName,
		}
	}

	return connect.NewResponse(&navigatorsv1.GetUserTurfsResponse{
		Assignments: pbAssignments,
	}), nil
}
