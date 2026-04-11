package navigators

import (
	"context"
	"fmt"

	connect "connectrpc.com/connect"
	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
	"navigators-go/internal/db"
)

// Compile-time check that TurfHandler implements the generated interface.
var _ navigatorsv1connect.TurfServiceHandler = (*TurfHandler)(nil)

// TurfHandler implements the navigators.v1.TurfService ConnectRPC handler.
type TurfHandler struct {
	queries      *db.Queries
	pool         *pgxpool.Pool
	statsService *TurfStatsService
}

// NewTurfHandler creates a new TurfHandler.
func NewTurfHandler(queries *db.Queries, pool *pgxpool.Pool, statsService *TurfStatsService) *TurfHandler {
	return &TurfHandler{queries: queries, pool: pool, statsService: statsService}
}

// extractCompanyID is a helper that pulls and parses the company ID from JWT claims.
func extractCompanyID(ctx context.Context) (uuid.UUID, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return uuid.Nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("no claims"))
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return uuid.Nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse company ID: %w", err))
	}
	return companyID, nil
}

func (h *TurfHandler) CreateTurf(ctx context.Context, req *connect.Request[navigatorsv1.CreateTurfRequest]) (*connect.Response[navigatorsv1.CreateTurfResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	name := req.Msg.GetName()
	if name == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("name is required"))
	}

	boundaryGeoJSON := req.Msg.GetBoundaryGeojson()

	// If boundary is provided, use the spatial query; otherwise use basic insert.
	if boundaryGeoJSON != "" {
		turf, err := h.queries.CreateTurfWithBoundary(ctx, db.CreateTurfWithBoundaryParams{
			CompanyID:       companyID,
			Name:            name,
			Description:     req.Msg.GetDescription(),
			BoundaryGeojson: boundaryGeoJSON,
		})
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("create turf with boundary: %w", err))
		}

		return connect.NewResponse(&navigatorsv1.CreateTurfResponse{
			TurfId: turf.ID.String(),
			Name:   turf.Name,
		}), nil
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
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	turfs, err := h.queries.GetTurfsByCompanyWithBoundary(ctx, companyID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("list turfs: %w", err))
	}

	pbTurfs := make([]*navigatorsv1.TurfInfo, len(turfs))
	for i, t := range turfs {
		pbTurfs[i] = mapBoundaryRowToTurfInfo(
			t.ID, t.Name, t.Description, t.IsActive,
			t.BoundaryGeojson, t.CenterLat, t.CenterLng, t.AreaSqMeters,
			t.VoterCount,
			t.CreatedAt, t.UpdatedAt,
		)
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

func (h *TurfHandler) GetTurf(ctx context.Context, req *connect.Request[navigatorsv1.GetTurfRequest]) (*connect.Response[navigatorsv1.GetTurfResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	turfID, err := uuid.Parse(req.Msg.GetTurfId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid turf_id"))
	}

	turf, err := h.queries.GetTurfByID(ctx, db.GetTurfByIDParams{
		TurfID:    turfID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("turf not found: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.GetTurfResponse{
		Turf: mapBoundaryRowToTurfInfo(
			turf.ID, turf.Name, turf.Description, turf.IsActive,
			turf.BoundaryGeojson, turf.CenterLat, turf.CenterLng, turf.AreaSqMeters,
			turf.VoterCount,
			turf.CreatedAt, turf.UpdatedAt,
		),
	}), nil
}

func (h *TurfHandler) UpdateTurfBoundary(ctx context.Context, req *connect.Request[navigatorsv1.UpdateTurfBoundaryRequest]) (*connect.Response[navigatorsv1.UpdateTurfBoundaryResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	turfID, err := uuid.Parse(req.Msg.GetTurfId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid turf_id"))
	}

	boundaryGeoJSON := req.Msg.GetBoundaryGeojson()
	if boundaryGeoJSON == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("boundary_geojson is required"))
	}

	turf, err := h.queries.UpdateTurfBoundary(ctx, db.UpdateTurfBoundaryParams{
		BoundaryGeojson: boundaryGeoJSON,
		TurfID:          turfID,
		CompanyID:       companyID,
	})
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("update turf boundary: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.UpdateTurfBoundaryResponse{
		Turf: mapBoundaryRowToTurfInfo(
			turf.ID, turf.Name, turf.Description, turf.IsActive,
			turf.BoundaryGeojson, turf.CenterLat, turf.CenterLng, turf.AreaSqMeters,
			int64(0), // UpdateTurfBoundary doesn't return voter_count; we could do another query but it's not critical here
			turf.CreatedAt, turf.UpdatedAt,
		),
	}), nil
}

func (h *TurfHandler) GetVotersInTurf(ctx context.Context, req *connect.Request[navigatorsv1.GetVotersInTurfRequest]) (*connect.Response[navigatorsv1.GetVotersInTurfResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	turfID, err := uuid.Parse(req.Msg.GetTurfId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid turf_id"))
	}

	pageSize := req.Msg.GetPageSize()
	if pageSize <= 0 {
		pageSize = 100
	}
	page := req.Msg.GetPage()
	if page <= 0 {
		page = 1
	}
	offset := (page - 1) * pageSize

	voters, total, err := h.statsService.GetVotersInTurf(ctx, companyID, turfID, pageSize, offset)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get voters in turf: %w", err))
	}

	pbVoters := make([]*navigatorsv1.VoterPin, len(voters))
	for i, v := range voters {
		pbVoters[i] = &navigatorsv1.VoterPin{
			VoterId:   v.ID.String(),
			FirstName: v.FirstName,
			LastName:  v.LastName,
			Latitude:  v.Lat,
			Longitude: v.Lng,
			Party:     v.Party,
			Status:    v.Status,
		}
	}

	return connect.NewResponse(&navigatorsv1.GetVotersInTurfResponse{
		Voters:     pbVoters,
		TotalCount: int32(total),
	}), nil
}

func (h *TurfHandler) GenerateWalkList(ctx context.Context, req *connect.Request[navigatorsv1.GenerateWalkListRequest]) (*connect.Response[navigatorsv1.GenerateWalkListResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	turfID, err := uuid.Parse(req.Msg.GetTurfId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid turf_id"))
	}

	// Get all voters in turf (unpaginated, with addresses)
	voters, err := h.statsService.GetAllVotersInTurf(ctx, companyID, turfID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get voters for walk list: %w", err))
	}

	// Determine start point
	startLat := req.Msg.GetStartLat()
	startLng := req.Msg.GetStartLng()
	if startLat == 0 && startLng == 0 {
		// Use turf centroid as starting point
		turf, err := h.queries.GetTurfByID(ctx, db.GetTurfByIDParams{
			TurfID:    turfID,
			CompanyID: companyID,
		})
		if err != nil {
			return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get turf for centroid: %w", err))
		}
		startLat = toFloat64(turf.CenterLat)
		startLng = toFloat64(turf.CenterLng)
	}

	// Generate nearest-neighbor walk order
	ordered := generateWalkList(voters, startLat, startLng)

	pbVoters := make([]*navigatorsv1.WalkListVoter, len(ordered))
	for i, v := range ordered {
		pbVoters[i] = &navigatorsv1.WalkListVoter{
			VoterId:           v.ID.String(),
			FirstName:         v.FirstName,
			LastName:          v.LastName,
			Latitude:          v.Lat,
			Longitude:         v.Lng,
			ResStreetAddress:  v.Address,
			Sequence:          int32(i + 1),
		}
	}

	return connect.NewResponse(&navigatorsv1.GenerateWalkListResponse{
		Voters:      pbVoters,
		TotalVoters: int32(len(ordered)),
	}), nil
}

func (h *TurfHandler) GetTurfStats(ctx context.Context, req *connect.Request[navigatorsv1.GetTurfStatsRequest]) (*connect.Response[navigatorsv1.GetTurfStatsResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	turfID, err := uuid.Parse(req.Msg.GetTurfId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid turf_id"))
	}

	stats, err := h.statsService.GetTurfCompletionStats(ctx, companyID, turfID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get turf stats: %w", err))
	}

	var pct float32
	if stats.TotalVoters > 0 {
		pct = float32(stats.ContactedVoters) / float32(stats.TotalVoters) * 100
	}

	return connect.NewResponse(&navigatorsv1.GetTurfStatsResponse{
		Stats: &navigatorsv1.TurfStats{
			TurfId:               turfID.String(),
			TotalVoters:          int32(stats.TotalVoters),
			ContactedVoters:      int32(stats.ContactedVoters),
			CompletionPercentage: pct,
		},
	}), nil
}

func (h *TurfHandler) GetVoterDensityGrid(ctx context.Context, req *connect.Request[navigatorsv1.GetVoterDensityGridRequest]) (*connect.Response[navigatorsv1.GetVoterDensityGridResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	gridSize := req.Msg.GetGridSize()
	if gridSize <= 0 {
		gridSize = 0.001 // ~100m default
	}

	cells, err := h.statsService.GetVoterDensityGrid(ctx, companyID,
		req.Msg.GetMinLat(), req.Msg.GetMinLng(),
		req.Msg.GetMaxLat(), req.Msg.GetMaxLng(),
		gridSize,
	)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get voter density grid: %w", err))
	}

	pbCells := make([]*navigatorsv1.DensityGridCell, len(cells))
	for i, c := range cells {
		pbCells[i] = &navigatorsv1.DensityGridCell{
			GridLat:        c.GridLat,
			GridLng:        c.GridLng,
			VoterCount:     c.VoterCount,
			ContactedCount: c.ContactedCount,
			SupportCount:   c.SupportCount,
		}
	}

	return connect.NewResponse(&navigatorsv1.GetVoterDensityGridResponse{
		Cells: pbCells,
	}), nil
}

// --- Helpers ---

// mapBoundaryRowToTurfInfo converts sqlc row fields (with interface{} spatial values) to a proto TurfInfo.
func mapBoundaryRowToTurfInfo(
	id uuid.UUID, name, description string, isActive bool,
	boundaryGeojson, centerLat, centerLng, areaSqMeters interface{},
	voterCount int64,
	createdAt, updatedAt interface{},
) *navigatorsv1.TurfInfo {
	info := &navigatorsv1.TurfInfo{
		TurfId:      id.String(),
		Name:        name,
		Description: description,
		IsActive:    isActive,
		VoterCount:  int32(voterCount),
	}

	if s, ok := boundaryGeojson.(string); ok {
		info.BoundaryGeojson = s
	}
	info.CenterLat = toFloat64(centerLat)
	info.CenterLng = toFloat64(centerLng)
	info.AreaSqMeters = toFloat64(areaSqMeters)

	// Format timestamps
	if t, ok := createdAt.(interface{ Format(string) string }); ok {
		info.CreatedAt = t.Format("2006-01-02T15:04:05Z")
	}
	if t, ok := updatedAt.(interface{ Format(string) string }); ok {
		info.UpdatedAt = t.Format("2006-01-02T15:04:05Z")
	}

	return info
}

// toFloat64 safely converts an interface{} (from pgx scan of float8/numeric) to float64.
func toFloat64(v interface{}) float64 {
	switch val := v.(type) {
	case float64:
		return val
	case float32:
		return float64(val)
	case int64:
		return float64(val)
	case int32:
		return float64(val)
	case nil:
		return 0
	default:
		return 0
	}
}
