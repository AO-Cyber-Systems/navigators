package navigators

import (
	"context"
	"fmt"
	"strconv"
	"strings"

	connect "connectrpc.com/connect"
	"github.com/google/uuid"

	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
	"navigators-go/internal/db"
)

// Compile-time check that VoterHandler implements the generated interface.
var _ navigatorsv1connect.VoterServiceHandler = (*VoterHandler)(nil)

// VoterHandler implements the navigators.v1.VoterService ConnectRPC handler.
type VoterHandler struct {
	voterService       *VoterService
	tagService         *TagService
	suppressionService *SuppressionService
}

// NewVoterHandler creates a new VoterHandler.
func NewVoterHandler(voterService *VoterService, tagService *TagService, suppressionService *SuppressionService) *VoterHandler {
	return &VoterHandler{
		voterService:       voterService,
		tagService:         tagService,
		suppressionService: suppressionService,
	}
}

// GetVoter returns a single voter by ID.
func (h *VoterHandler) GetVoter(ctx context.Context, req *connect.Request[navigatorsv1.GetVoterRequest]) (*connect.Response[navigatorsv1.GetVoterResponse], error) {
	voterID, err := uuid.Parse(req.Msg.GetVoterId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid voter_id"))
	}

	voter, err := h.voterService.GetVoter(ctx, voterID)
	if err != nil {
		if strings.Contains(err.Error(), "not in assigned turfs") || strings.Contains(err.Error(), "no turfs assigned") {
			return nil, connect.NewError(connect.CodePermissionDenied, err)
		}
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("voter not found"))
	}

	// Check suppression status
	isSuppressed, _ := h.suppressionService.IsVoterSuppressed(ctx, voterID)

	// Get voter tags
	voterTags, err := h.tagService.GetVoterTags(ctx, voterID)
	if err != nil {
		// Non-fatal: return voter without tags rather than failing
		voterTags = nil
	}

	pbTags := make([]*navigatorsv1.VoterTag, len(voterTags))
	for i := range voterTags {
		pbTags[i] = voterTagToProto(&voterTags[i])
	}

	return connect.NewResponse(&navigatorsv1.GetVoterResponse{
		Voter:        voterToProto(voter),
		IsSuppressed: isSuppressed,
		Tags:         pbTags,
	}), nil
}

// SearchVoters performs fuzzy text search on voters.
func (h *VoterHandler) SearchVoters(ctx context.Context, req *connect.Request[navigatorsv1.SearchVotersRequest]) (*connect.Response[navigatorsv1.SearchVotersResponse], error) {
	query := req.Msg.GetQuery()
	if query == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("query is required"))
	}

	pageSize := req.Msg.GetPageSize()
	if pageSize <= 0 || pageSize > 100 {
		pageSize = 50
	}
	page := req.Msg.GetPage()
	if page < 0 {
		page = 0
	}
	offset := page * pageSize

	results, totalCount, err := h.voterService.SearchVoters(ctx, query, pageSize, offset)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("search voters: %w", err))
	}

	voters := make([]*navigatorsv1.VoterSummary, len(results))
	for i, r := range results {
		voters[i] = searchRowToSummary(&r)
	}

	return connect.NewResponse(&navigatorsv1.SearchVotersResponse{
		Voters:     voters,
		TotalCount: totalCount,
	}), nil
}

// ListVoters returns a filtered, paginated list of voters.
func (h *VoterHandler) ListVoters(ctx context.Context, req *connect.Request[navigatorsv1.ListVotersRequest]) (*connect.Response[navigatorsv1.ListVotersResponse], error) {
	pageSize := req.Msg.GetPageSize()
	if pageSize <= 0 || pageSize > 100 {
		pageSize = 50
	}
	page := req.Msg.GetPage()
	if page < 0 {
		page = 0
	}
	offset := page * pageSize

	filters := VoterFilterParams{}
	if f := req.Msg.GetFilters(); f != nil {
		if f.Party != "" {
			filters.Party = &f.Party
		}
		if f.Status != "" {
			filters.VoterStatus = &f.Status
		}
		if f.CongressionalDistrict != "" {
			filters.CongressionalDistrict = &f.CongressionalDistrict
		}
		if f.StateSenateDistrict != "" {
			filters.StateSenateDistrict = &f.StateSenateDistrict
		}
		if f.StateHouseDistrict != "" {
			filters.StateHouseDistrict = &f.StateHouseDistrict
		}
		if f.Municipality != "" {
			filters.Municipality = &f.Municipality
		}
		if f.County != "" {
			filters.County = &f.County
		}
		if f.MinVoteCount > 0 {
			mvc := f.MinVoteCount
			filters.MinVoteCount = &mvc
		}
		if f.Bbox != "" {
			bbox, err := parseBBox(f.Bbox)
			if err != nil {
				return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid bbox: %w", err))
			}
			filters.BBox = bbox
		}
	}

	results, totalCount, err := h.voterService.ListVoters(ctx, filters, pageSize, offset)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("list voters: %w", err))
	}

	voters := make([]*navigatorsv1.VoterSummary, len(results))
	for i, r := range results {
		voters[i] = filterRowToSummary(&r)
	}

	return connect.NewResponse(&navigatorsv1.ListVotersResponse{
		Voters:     voters,
		TotalCount: totalCount,
	}), nil
}

// --- Tag RPCs ---

// CreateTag creates a new voter tag.
func (h *VoterHandler) CreateTag(ctx context.Context, req *connect.Request[navigatorsv1.CreateTagRequest]) (*connect.Response[navigatorsv1.CreateTagResponse], error) {
	name := req.Msg.GetName()
	if name == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("name is required"))
	}

	tag, err := h.tagService.CreateTag(ctx, name, req.Msg.GetColor())
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("create tag: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.CreateTagResponse{
		Tag: voterTagToProto(tag),
	}), nil
}

// ListTags returns all tags for the company.
func (h *VoterHandler) ListTags(ctx context.Context, _ *connect.Request[navigatorsv1.ListTagsRequest]) (*connect.Response[navigatorsv1.ListTagsResponse], error) {
	tags, err := h.tagService.ListTags(ctx)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("list tags: %w", err))
	}

	pbTags := make([]*navigatorsv1.VoterTag, len(tags))
	for i := range tags {
		pbTags[i] = voterTagToProto(&tags[i])
	}

	return connect.NewResponse(&navigatorsv1.ListTagsResponse{
		Tags: pbTags,
	}), nil
}

// DeleteTag removes a voter tag.
func (h *VoterHandler) DeleteTag(ctx context.Context, req *connect.Request[navigatorsv1.DeleteTagRequest]) (*connect.Response[navigatorsv1.DeleteTagResponse], error) {
	tagID, err := uuid.Parse(req.Msg.GetTagId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid tag_id"))
	}

	if err := h.tagService.DeleteTag(ctx, tagID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("delete tag: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.DeleteTagResponse{}), nil
}

// AssignTagToVoter assigns a tag to a voter.
func (h *VoterHandler) AssignTagToVoter(ctx context.Context, req *connect.Request[navigatorsv1.AssignTagToVoterRequest]) (*connect.Response[navigatorsv1.AssignTagToVoterResponse], error) {
	voterID, err := uuid.Parse(req.Msg.GetVoterId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid voter_id"))
	}
	tagID, err := uuid.Parse(req.Msg.GetTagId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid tag_id"))
	}

	if err := h.tagService.AssignTag(ctx, voterID, tagID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("assign tag: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.AssignTagToVoterResponse{}), nil
}

// RemoveTagFromVoter removes a tag from a voter.
func (h *VoterHandler) RemoveTagFromVoter(ctx context.Context, req *connect.Request[navigatorsv1.RemoveTagFromVoterRequest]) (*connect.Response[navigatorsv1.RemoveTagFromVoterResponse], error) {
	voterID, err := uuid.Parse(req.Msg.GetVoterId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid voter_id"))
	}
	tagID, err := uuid.Parse(req.Msg.GetTagId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid tag_id"))
	}

	if err := h.tagService.RemoveTag(ctx, voterID, tagID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("remove tag: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.RemoveTagFromVoterResponse{}), nil
}

// GetVoterTags returns all tags assigned to a voter.
func (h *VoterHandler) GetVoterTags(ctx context.Context, req *connect.Request[navigatorsv1.GetVoterTagsRequest]) (*connect.Response[navigatorsv1.GetVoterTagsResponse], error) {
	voterID, err := uuid.Parse(req.Msg.GetVoterId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid voter_id"))
	}

	tags, err := h.tagService.GetVoterTags(ctx, voterID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get voter tags: %w", err))
	}

	pbTags := make([]*navigatorsv1.VoterTag, len(tags))
	for i := range tags {
		pbTags[i] = voterTagToProto(&tags[i])
	}

	return connect.NewResponse(&navigatorsv1.GetVoterTagsResponse{
		Tags: pbTags,
	}), nil
}

// --- Suppression RPCs ---

// AddToSuppressionList adds a voter to the global suppression list.
func (h *VoterHandler) AddToSuppressionList(ctx context.Context, req *connect.Request[navigatorsv1.AddToSuppressionListRequest]) (*connect.Response[navigatorsv1.AddToSuppressionListResponse], error) {
	voterID, err := uuid.Parse(req.Msg.GetVoterId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid voter_id"))
	}

	if err := h.suppressionService.AddToSuppressionList(ctx, voterID, req.Msg.GetReason()); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("add to suppression list: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.AddToSuppressionListResponse{}), nil
}

// RemoveFromSuppressionList removes a voter from the suppression list.
func (h *VoterHandler) RemoveFromSuppressionList(ctx context.Context, req *connect.Request[navigatorsv1.RemoveFromSuppressionListRequest]) (*connect.Response[navigatorsv1.RemoveFromSuppressionListResponse], error) {
	voterID, err := uuid.Parse(req.Msg.GetVoterId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid voter_id"))
	}

	if err := h.suppressionService.RemoveFromSuppressionList(ctx, voterID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("remove from suppression list: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.RemoveFromSuppressionListResponse{}), nil
}

// IsVoterSuppressed checks if a voter is on the suppression list.
func (h *VoterHandler) IsVoterSuppressed(ctx context.Context, req *connect.Request[navigatorsv1.IsVoterSuppressedRequest]) (*connect.Response[navigatorsv1.IsVoterSuppressedResponse], error) {
	voterID, err := uuid.Parse(req.Msg.GetVoterId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid voter_id"))
	}

	suppressed, err := h.suppressionService.IsVoterSuppressed(ctx, voterID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("check suppression: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.IsVoterSuppressedResponse{
		IsSuppressed: suppressed,
	}), nil
}

// ListSuppressedVoters returns a paginated list of suppressed voters.
func (h *VoterHandler) ListSuppressedVoters(ctx context.Context, req *connect.Request[navigatorsv1.ListSuppressedVotersRequest]) (*connect.Response[navigatorsv1.ListSuppressedVotersResponse], error) {
	pageSize := req.Msg.GetPageSize()
	if pageSize <= 0 || pageSize > 100 {
		pageSize = 50
	}
	page := req.Msg.GetPage()
	if page < 0 {
		page = 0
	}
	offset := page * pageSize

	rows, totalCount, err := h.suppressionService.ListSuppressedVoters(ctx, pageSize, offset)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("list suppressed voters: %w", err))
	}

	voters := make([]*navigatorsv1.SuppressedVoter, len(rows))
	for i, r := range rows {
		voters[i] = &navigatorsv1.SuppressedVoter{
			Id:               r.ID.String(),
			VoterId:          r.VoterID.String(),
			FirstName:        r.FirstName,
			LastName:         r.LastName,
			ResStreetAddress: r.ResStreetAddress,
			ResCity:          r.ResCity,
			ResState:         r.ResState,
			ResZip:           r.ResZip,
			Reason:           r.Reason,
			AddedBy:          r.AddedBy.String(),
			AddedAt:          r.AddedAt.Format("2006-01-02T15:04:05Z"),
		}
	}

	return connect.NewResponse(&navigatorsv1.ListSuppressedVotersResponse{
		Voters:     voters,
		TotalCount: totalCount,
	}), nil
}

// --- Proto conversion helpers ---

func voterToProto(v *db.Voter) *navigatorsv1.Voter {
	yob := int32(0)
	if v.YearOfBirth != nil {
		yob = *v.YearOfBirth
	}

	return &navigatorsv1.Voter{
		Id:                    v.ID.String(),
		FirstName:             v.FirstName,
		MiddleName:            v.MiddleName,
		LastName:              v.LastName,
		Suffix:                v.Suffix,
		YearOfBirth:           yob,
		ResStreetAddress:      v.ResStreetAddress,
		ResCity:               v.ResCity,
		ResState:              v.ResState,
		ResZip:                v.ResZip,
		MailStreetAddress:     v.MailStreetAddress,
		MailCity:              v.MailCity,
		MailState:             v.MailState,
		MailZip:               v.MailZip,
		Party:                 v.Party,
		Status:                v.Status,
		RegistrationDate:      v.RegistrationDate,
		County:                v.County,
		Municipality:          v.Municipality,
		Ward:                  v.Ward,
		Precinct:              v.Precinct,
		CongressionalDistrict: v.CongressionalDistrict,
		StateSenateDistrict:   v.StateSenateDistrict,
		StateHouseDistrict:    v.StateHouseDistrict,
		GeocodeStatus:         v.GeocodeStatus,
		SourceVoterId:         v.SourceVoterID,
		Source:                v.Source,
		VotingHistory:         string(v.VotingHistory),
		Phone:                 v.Phone,
		Email:                 v.Email,
		CreatedAt:             v.CreatedAt.Format("2006-01-02T15:04:05Z"),
		UpdatedAt:             v.UpdatedAt.Format("2006-01-02T15:04:05Z"),
	}
}

func searchRowToSummary(r *db.SearchVotersRow) *navigatorsv1.VoterSummary {
	yob := int32(0)
	if r.YearOfBirth != nil {
		yob = *r.YearOfBirth
	}
	return &navigatorsv1.VoterSummary{
		Id:           r.ID.String(),
		FirstName:    r.FirstName,
		LastName:     r.LastName,
		Party:        r.Party,
		Status:       r.Status,
		ResCity:      r.ResCity,
		ResZip:       r.ResZip,
		Municipality: r.Municipality,
		YearOfBirth:  yob,
	}
}

func filterRowToSummary(r *db.ListVotersByFiltersRow) *navigatorsv1.VoterSummary {
	yob := int32(0)
	if r.YearOfBirth != nil {
		yob = *r.YearOfBirth
	}
	return &navigatorsv1.VoterSummary{
		Id:           r.ID.String(),
		FirstName:    r.FirstName,
		LastName:     r.LastName,
		Party:        r.Party,
		Status:       r.Status,
		ResCity:      r.ResCity,
		ResZip:       r.ResZip,
		Municipality: r.Municipality,
		YearOfBirth:  yob,
	}
}

func voterTagToProto(t *db.VoterTag) *navigatorsv1.VoterTag {
	return &navigatorsv1.VoterTag{
		Id:        t.ID.String(),
		Name:      t.Name,
		Color:     t.Color,
		CreatedBy: t.CreatedBy.String(),
		CreatedAt: t.CreatedAt.Format("2006-01-02T15:04:05Z"),
	}
}

// parseBBox parses a bbox string "min_lon,min_lat,max_lon,max_lat" into a BBox.
func parseBBox(s string) (*BBox, error) {
	parts := strings.Split(s, ",")
	if len(parts) != 4 {
		return nil, fmt.Errorf("bbox must be 'min_lon,min_lat,max_lon,max_lat'")
	}

	minLon, err := strconv.ParseFloat(strings.TrimSpace(parts[0]), 64)
	if err != nil {
		return nil, fmt.Errorf("invalid min_lon: %w", err)
	}
	minLat, err := strconv.ParseFloat(strings.TrimSpace(parts[1]), 64)
	if err != nil {
		return nil, fmt.Errorf("invalid min_lat: %w", err)
	}
	maxLon, err := strconv.ParseFloat(strings.TrimSpace(parts[2]), 64)
	if err != nil {
		return nil, fmt.Errorf("invalid max_lon: %w", err)
	}
	maxLat, err := strconv.ParseFloat(strings.TrimSpace(parts[3]), 64)
	if err != nil {
		return nil, fmt.Errorf("invalid max_lat: %w", err)
	}

	return &BBox{
		MinLon: minLon,
		MinLat: minLat,
		MaxLon: maxLon,
		MaxLat: maxLat,
	}, nil
}
