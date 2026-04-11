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

// Compile-time check that TeamHandler implements the generated interface.
var _ navigatorsv1connect.TeamServiceHandler = (*TeamHandler)(nil)

// TeamHandler implements the navigators.v1.TeamService ConnectRPC handler.
type TeamHandler struct {
	queries *db.Queries
}

// NewTeamHandler creates a new TeamHandler.
func NewTeamHandler(queries *db.Queries) *TeamHandler {
	return &TeamHandler{queries: queries}
}

func (h *TeamHandler) AssignNavigatorToTeam(ctx context.Context, req *connect.Request[navigatorsv1.AssignNavigatorToTeamRequest]) (*connect.Response[navigatorsv1.AssignNavigatorToTeamResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no claims"))
	}

	superNavID, err := uuid.Parse(req.Msg.GetSuperNavigatorId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid super_navigator_id"))
	}
	navID, err := uuid.Parse(req.Msg.GetNavigatorId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid navigator_id"))
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse company ID: %w", err))
	}
	assignedBy, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse caller ID: %w", err))
	}

	if err := h.queries.AssignNavigatorToTeam(ctx, db.AssignNavigatorToTeamParams{
		SuperNavigatorID: superNavID,
		NavigatorID:      navID,
		CompanyID:        companyID,
		AssignedBy:       assignedBy,
	}); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("assign navigator to team: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.AssignNavigatorToTeamResponse{}), nil
}

func (h *TeamHandler) RemoveNavigatorFromTeam(ctx context.Context, req *connect.Request[navigatorsv1.RemoveNavigatorFromTeamRequest]) (*connect.Response[navigatorsv1.RemoveNavigatorFromTeamResponse], error) {
	superNavID, err := uuid.Parse(req.Msg.GetSuperNavigatorId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid super_navigator_id"))
	}
	navID, err := uuid.Parse(req.Msg.GetNavigatorId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid navigator_id"))
	}

	if err := h.queries.RemoveNavigatorFromTeam(ctx, db.RemoveNavigatorFromTeamParams{
		SuperNavigatorID: superNavID,
		NavigatorID:      navID,
	}); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("remove navigator from team: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.RemoveNavigatorFromTeamResponse{}), nil
}

func (h *TeamHandler) GetTeamNavigators(ctx context.Context, req *connect.Request[navigatorsv1.GetTeamNavigatorsRequest]) (*connect.Response[navigatorsv1.GetTeamNavigatorsResponse], error) {
	superNavID, err := uuid.Parse(req.Msg.GetSuperNavigatorId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid super_navigator_id"))
	}

	navs, err := h.queries.GetTeamNavigators(ctx, superNavID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get team navigators: %w", err))
	}

	pbNavs := make([]*navigatorsv1.TeamNavigator, len(navs))
	for i, n := range navs {
		pbNavs[i] = &navigatorsv1.TeamNavigator{
			UserId:      n.NavigatorID.String(),
			Email:       n.Email,
			DisplayName: n.DisplayName,
		}
	}

	return connect.NewResponse(&navigatorsv1.GetTeamNavigatorsResponse{
		Navigators: pbNavs,
	}), nil
}
