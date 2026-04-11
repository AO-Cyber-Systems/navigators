package navigators

import (
	"context"
	"fmt"
	"time"

	connect "connectrpc.com/connect"
	"github.com/google/uuid"

	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
)

// Compile-time check that SyncHandler implements the generated interface.
var _ navigatorsv1connect.SyncServiceHandler = (*SyncHandler)(nil)

// SyncHandler implements the navigators.v1.SyncService ConnectRPC handler.
type SyncHandler struct {
	syncService *SyncService
}

// NewSyncHandler creates a new SyncHandler.
func NewSyncHandler(syncService *SyncService) *SyncHandler {
	return &SyncHandler{syncService: syncService}
}

func (h *SyncHandler) PullVoterUpdates(ctx context.Context, req *connect.Request[navigatorsv1.PullVoterUpdatesRequest]) (*connect.Response[navigatorsv1.PullVoterUpdatesResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	// Resolve turf scope to ensure user can only access their assigned turfs
	scope, err := h.syncService.turfFilter.ResolveScope(ctx)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("resolve scope: %w", err))
	}

	// Determine which turf IDs to use
	turfIDs, err := h.resolveTurfIDs(req.Msg.GetTurfIds(), scope)
	if err != nil {
		return nil, err
	}

	batchSize := req.Msg.GetBatchSize()
	if batchSize <= 0 {
		batchSize = 500
	}

	result, err := h.syncService.PullVoterUpdates(ctx, companyID, turfIDs, req.Msg.GetSinceCursor(), batchSize)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("pull voter updates: %w", err))
	}

	pbVoters := make([]*navigatorsv1.SyncVoter, len(result.Voters))
	for i, v := range result.Voters {
		pbVoters[i] = &navigatorsv1.SyncVoter{
			Id:               v.ID.String(),
			TurfId:           v.TurfID.String(),
			FirstName:        v.FirstName,
			LastName:         v.LastName,
			MiddleName:       v.MiddleName,
			Suffix:           v.Suffix,
			YearOfBirth:      v.YearOfBirth,
			ResStreetAddress: v.ResStreetAddress,
			ResCity:          v.ResCity,
			ResState:         v.ResState,
			ResZip:           v.ResZip,
			Party:            v.Party,
			Status:           v.Status,
			Latitude:         v.Latitude,
			Longitude:        v.Longitude,
			VotingHistory:    v.VotingHistory,
			Phone:            v.Phone,
			Email:            v.Email,
			WalkSequence:     v.WalkSequence,
			ServerUpdatedAt:  v.UpdatedAt.Format(time.RFC3339),
		}
	}

	return connect.NewResponse(&navigatorsv1.PullVoterUpdatesResponse{
		Voters:     pbVoters,
		NextCursor: result.NextCursor,
		HasMore:    result.HasMore,
	}), nil
}

func (h *SyncHandler) PullContactLogs(ctx context.Context, req *connect.Request[navigatorsv1.PullContactLogsRequest]) (*connect.Response[navigatorsv1.PullContactLogsResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	scope, err := h.syncService.turfFilter.ResolveScope(ctx)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("resolve scope: %w", err))
	}

	turfIDs, err := h.resolveTurfIDs(req.Msg.GetTurfIds(), scope)
	if err != nil {
		return nil, err
	}

	batchSize := req.Msg.GetBatchSize()
	if batchSize <= 0 {
		batchSize = 500
	}

	result, err := h.syncService.PullContactLogs(ctx, companyID, turfIDs, req.Msg.GetSinceCursor(), batchSize)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("pull contact logs: %w", err))
	}

	pbLogs := make([]*navigatorsv1.SyncContactLog, len(result.ContactLogs))
	for i, cl := range result.ContactLogs {
		pbLogs[i] = &navigatorsv1.SyncContactLog{
			Id:          cl.ID.String(),
			VoterId:     cl.VoterID.String(),
			TurfId:      cl.TurfID.String(),
			UserId:      cl.UserID.String(),
			ContactType: cl.ContactType,
			Outcome:     cl.Outcome,
			Notes:       cl.Notes,
			CreatedAt:   cl.CreatedAt.Format(time.RFC3339),
		}
	}

	return connect.NewResponse(&navigatorsv1.PullContactLogsResponse{
		ContactLogs: pbLogs,
		NextCursor:  result.NextCursor,
		HasMore:     result.HasMore,
	}), nil
}

func (h *SyncHandler) PushSyncBatch(ctx context.Context, req *connect.Request[navigatorsv1.PushSyncBatchRequest]) (*connect.Response[navigatorsv1.PushSyncBatchResponse], error) {
	// PushSyncBatch will be fully implemented in TRD 04-02 (push sync).
	// For now, return an unimplemented error so the endpoint is registered.
	return nil, connect.NewError(connect.CodeUnimplemented, fmt.Errorf("PushSyncBatch not yet implemented"))
}

func (h *SyncHandler) GetSyncManifest(ctx context.Context, req *connect.Request[navigatorsv1.GetSyncManifestRequest]) (*connect.Response[navigatorsv1.GetSyncManifestResponse], error) {
	scope, err := h.syncService.turfFilter.ResolveScope(ctx)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("resolve scope: %w", err))
	}

	assignments, err := h.syncService.GetSyncManifest(ctx, scope.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get sync manifest: %w", err))
	}

	pbAssignments := make([]*navigatorsv1.TurfAssignmentInfo, len(assignments))
	for i, a := range assignments {
		pbAssignments[i] = &navigatorsv1.TurfAssignmentInfo{
			TurfId:          a.TurfID.String(),
			TurfName:        a.TurfName,
			BoundaryGeojson: a.BoundaryGeojson,
			VoterCount:      int32(a.VoterCount),
		}
	}

	return connect.NewResponse(&navigatorsv1.GetSyncManifestResponse{
		TurfAssignments: pbAssignments,
		ServerTime:      time.Now().UTC().Format(time.RFC3339),
	}), nil
}

// resolveTurfIDs validates and filters the requested turf IDs against the user's scope.
// For ScopeAll (admins), it uses whatever IDs the client requested.
// For ScopeOwn/ScopeTeam, it intersects with the user's allowed turfs.
func (h *SyncHandler) resolveTurfIDs(requestedIDs []string, scope *TurfScope) ([]uuid.UUID, error) {
	if scope.Type == ScopeAll {
		// Admins can access any turf -- parse whatever was requested
		if len(requestedIDs) == 0 {
			return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("turf_ids required"))
		}
		ids := make([]uuid.UUID, len(requestedIDs))
		for i, s := range requestedIDs {
			id, err := uuid.Parse(s)
			if err != nil {
				return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid turf_id: %s", s))
			}
			ids[i] = id
		}
		return ids, nil
	}

	// For non-admins, use their scoped turfs (ignore client-provided IDs for security)
	if len(scope.TurfIDs) == 0 {
		return nil, nil // No turfs assigned, empty result
	}
	return scope.TurfIDs, nil
}
