package navigators

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"

	connect "connectrpc.com/connect"
	"github.com/google/uuid"

	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
	"navigators-go/internal/db"
)

// Compile-time check that SMSHandler implements the generated interface.
var _ navigatorsv1connect.SMSServiceHandler = (*SMSHandler)(nil)

// SMSHandler implements the navigators.v1.SMSService ConnectRPC handler.
type SMSHandler struct {
	smsService      *SMSService
	templateService *SMSTemplateService
	campaignService *SMSCampaignService
}

// NewSMSHandler creates a new SMSHandler.
func NewSMSHandler(smsService *SMSService, templateService *SMSTemplateService, campaignService *SMSCampaignService) *SMSHandler {
	return &SMSHandler{
		smsService:      smsService,
		templateService: templateService,
		campaignService: campaignService,
	}
}

// --- P2P / Conversation RPCs ---

func (h *SMSHandler) SendP2PMessage(ctx context.Context, req *connect.Request[navigatorsv1.SendP2PMessageRequest]) (*connect.Response[navigatorsv1.SendP2PMessageResponse], error) {
	voterIDStr := req.Msg.GetVoterId()
	if voterIDStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("voter_id is required"))
	}
	voterID, err := uuid.Parse(voterIDStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid voter_id: %w", err))
	}

	body := req.Msg.GetBody()
	if body == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("body is required"))
	}

	msg, err := h.smsService.SendP2P(ctx, voterID, body)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.SendP2PMessageResponse{
		Message: smsMessageToProto(msg),
	}), nil
}

func (h *SMSHandler) GetConversation(ctx context.Context, req *connect.Request[navigatorsv1.GetConversationRequest]) (*connect.Response[navigatorsv1.GetConversationResponse], error) {
	voterIDStr := req.Msg.GetVoterId()
	if voterIDStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("voter_id is required"))
	}
	voterID, err := uuid.Parse(voterIDStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid voter_id: %w", err))
	}

	pageSize := req.Msg.GetPageSize()
	if pageSize <= 0 || pageSize > 100 {
		pageSize = 50
	}

	var offset int32
	if pt := req.Msg.GetPageToken(); pt != "" {
		parsed, err := strconv.ParseInt(pt, 10, 32)
		if err == nil {
			offset = int32(parsed)
		}
	}

	messages, totalCount, err := h.smsService.GetConversation(ctx, voterID, pageSize, offset)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	protoMessages := make([]*navigatorsv1.SMSMessage, len(messages))
	for i, msg := range messages {
		protoMessages[i] = smsMessageToProto(&msg)
	}

	var nextPageToken string
	nextOffset := offset + int32(len(messages))
	if int64(nextOffset) < totalCount {
		nextPageToken = strconv.FormatInt(int64(nextOffset), 10)
	}

	return connect.NewResponse(&navigatorsv1.GetConversationResponse{
		Messages:      protoMessages,
		TotalCount:    totalCount,
		NextPageToken: nextPageToken,
	}), nil
}

func (h *SMSHandler) ListConversations(ctx context.Context, req *connect.Request[navigatorsv1.ListConversationsRequest]) (*connect.Response[navigatorsv1.ListConversationsResponse], error) {
	pageSize := req.Msg.GetPageSize()
	if pageSize <= 0 || pageSize > 100 {
		pageSize = 50
	}

	var offset int32
	if pt := req.Msg.GetPageToken(); pt != "" {
		parsed, err := strconv.ParseInt(pt, 10, 32)
		if err == nil {
			offset = int32(parsed)
		}
	}

	rows, err := h.smsService.ListConversations(ctx, pageSize, offset)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	convos := make([]*navigatorsv1.ConversationSummary, len(rows))
	for i, row := range rows {
		convos[i] = &navigatorsv1.ConversationSummary{
			VoterId:         row.VoterID.String(),
			VoterName:       row.FirstName + " " + row.LastName,
			LastMessageBody: row.LastMessageBody,
			LastMessageAt:   row.LastMessageAt.Format("2006-01-02T15:04:05Z"),
		}
	}

	var nextPageToken string
	if len(rows) == int(pageSize) {
		nextPageToken = strconv.FormatInt(int64(offset+int32(len(rows))), 10)
	}

	return connect.NewResponse(&navigatorsv1.ListConversationsResponse{
		Conversations: convos,
		NextPageToken: nextPageToken,
	}), nil
}

func (h *SMSHandler) GetSMSConfig(ctx context.Context, _ *connect.Request[navigatorsv1.GetSMSConfigRequest]) (*connect.Response[navigatorsv1.GetSMSConfigResponse], error) {
	config, err := h.smsService.GetConfig(ctx)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.GetSMSConfigResponse{
		Config: smsConfigToProto(config),
	}), nil
}

func (h *SMSHandler) UpdateSMSConfig(ctx context.Context, req *connect.Request[navigatorsv1.UpdateSMSConfigRequest]) (*connect.Response[navigatorsv1.UpdateSMSConfigResponse], error) {
	params := db.UpsertSMSConfigParams{
		TwilioAccountSid:         req.Msg.GetTwilioAccountSid(),
		TwilioAuthTokenEncrypted: req.Msg.GetTwilioAuthToken(), // Store as-is for now; encryption added in future
		P2pMessagingServiceSid:   req.Msg.GetP2PMessagingServiceSid(),
		A2pMessagingServiceSid:   req.Msg.GetA2PMessagingServiceSid(),
		InboundWebhookUrl:        req.Msg.GetInboundWebhookUrl(),
		StatusWebhookUrl:         req.Msg.GetStatusWebhookUrl(),
		QuietHoursStart:          req.Msg.GetQuietHoursStart(),
		QuietHoursEnd:            req.Msg.GetQuietHoursEnd(),
		TenDlcBrandSid:           req.Msg.GetTenDlcBrandSid(),
		TenDlcCampaignSid:        req.Msg.GetTenDlcCampaignSid(),
		TenDlcStatus:             req.Msg.GetTenDlcStatus(),
	}

	if err := h.smsService.UpdateConfig(ctx, params); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Fetch updated config
	config, err := h.smsService.GetConfig(ctx)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.UpdateSMSConfigResponse{
		Config: smsConfigToProto(config),
	}), nil
}

// --- Template RPCs ---

func (h *SMSHandler) CreateTemplate(ctx context.Context, req *connect.Request[navigatorsv1.CreateTemplateRequest]) (*connect.Response[navigatorsv1.CreateTemplateResponse], error) {
	name := req.Msg.GetName()
	if name == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("name is required"))
	}
	body := req.Msg.GetBody()
	if body == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("body is required"))
	}

	tmpl, err := h.templateService.CreateTemplate(ctx, name, body, req.Msg.GetMergeFields())
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.CreateTemplateResponse{
		Template: smsTemplateToProto(tmpl),
	}), nil
}

func (h *SMSHandler) ListTemplates(ctx context.Context, req *connect.Request[navigatorsv1.ListTemplatesRequest]) (*connect.Response[navigatorsv1.ListTemplatesResponse], error) {
	pageSize := req.Msg.GetPageSize()
	if pageSize <= 0 || pageSize > 100 {
		pageSize = 50
	}

	var offset int32
	if pt := req.Msg.GetPageToken(); pt != "" {
		parsed, err := strconv.ParseInt(pt, 10, 32)
		if err == nil {
			offset = int32(parsed)
		}
	}

	templates, err := h.templateService.ListTemplates(ctx, pageSize, offset)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	protoTemplates := make([]*navigatorsv1.SMSTemplate, len(templates))
	for i, t := range templates {
		protoTemplates[i] = smsTemplateToProto(&t)
	}

	var nextPageToken string
	if len(templates) == int(pageSize) {
		nextPageToken = strconv.FormatInt(int64(offset+int32(len(templates))), 10)
	}

	return connect.NewResponse(&navigatorsv1.ListTemplatesResponse{
		Templates:     protoTemplates,
		NextPageToken: nextPageToken,
	}), nil
}

func (h *SMSHandler) GetTemplate(ctx context.Context, req *connect.Request[navigatorsv1.GetTemplateRequest]) (*connect.Response[navigatorsv1.GetTemplateResponse], error) {
	templateIDStr := req.Msg.GetTemplateId()
	if templateIDStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("template_id is required"))
	}
	templateID, err := uuid.Parse(templateIDStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid template_id: %w", err))
	}

	tmpl, err := h.templateService.GetTemplate(ctx, templateID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.GetTemplateResponse{
		Template: smsTemplateToProto(tmpl),
	}), nil
}

func (h *SMSHandler) UpdateTemplate(ctx context.Context, req *connect.Request[navigatorsv1.UpdateTemplateRequest]) (*connect.Response[navigatorsv1.UpdateTemplateResponse], error) {
	templateIDStr := req.Msg.GetTemplateId()
	if templateIDStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("template_id is required"))
	}
	templateID, err := uuid.Parse(templateIDStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid template_id: %w", err))
	}

	name := req.Msg.GetName()
	if name == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("name is required"))
	}
	body := req.Msg.GetBody()
	if body == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("body is required"))
	}

	if err := h.templateService.UpdateTemplate(ctx, templateID, name, body, req.Msg.GetMergeFields()); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	// Fetch updated template
	tmpl, err := h.templateService.GetTemplate(ctx, templateID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.UpdateTemplateResponse{
		Template: smsTemplateToProto(tmpl),
	}), nil
}

func (h *SMSHandler) DeleteTemplate(ctx context.Context, req *connect.Request[navigatorsv1.DeleteTemplateRequest]) (*connect.Response[navigatorsv1.DeleteTemplateResponse], error) {
	templateIDStr := req.Msg.GetTemplateId()
	if templateIDStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("template_id is required"))
	}
	templateID, err := uuid.Parse(templateIDStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid template_id: %w", err))
	}

	if err := h.templateService.DeleteTemplate(ctx, templateID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.DeleteTemplateResponse{}), nil
}

func (h *SMSHandler) PreviewTemplate(ctx context.Context, req *connect.Request[navigatorsv1.PreviewTemplateRequest]) (*connect.Response[navigatorsv1.PreviewTemplateResponse], error) {
	templateIDStr := req.Msg.GetTemplateId()
	if templateIDStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("template_id is required"))
	}
	templateID, err := uuid.Parse(templateIDStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid template_id: %w", err))
	}

	rendered, err := h.templateService.PreviewTemplate(ctx, templateID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.PreviewTemplateResponse{
		RenderedBody: rendered,
	}), nil
}

// --- Campaign RPCs ---

func (h *SMSHandler) CreateCampaign(ctx context.Context, req *connect.Request[navigatorsv1.CreateCampaignRequest]) (*connect.Response[navigatorsv1.CreateCampaignResponse], error) {
	name := req.Msg.GetName()
	if name == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("name is required"))
	}
	templateIDStr := req.Msg.GetTemplateId()
	if templateIDStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("template_id is required"))
	}
	templateID, err := uuid.Parse(templateIDStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid template_id: %w", err))
	}

	var segmentFilters json.RawMessage
	if sf := req.Msg.GetSegmentFilters(); sf != "" {
		segmentFilters = json.RawMessage(sf)
	}

	campaign, err := h.campaignService.CreateCampaign(ctx, name, templateID, segmentFilters)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.CreateCampaignResponse{
		Campaign: smsCampaignToProto(campaign),
	}), nil
}

func (h *SMSHandler) LaunchCampaign(ctx context.Context, req *connect.Request[navigatorsv1.LaunchCampaignRequest]) (*connect.Response[navigatorsv1.LaunchCampaignResponse], error) {
	campaignIDStr := req.Msg.GetCampaignId()
	if campaignIDStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("campaign_id is required"))
	}
	campaignID, err := uuid.Parse(campaignIDStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid campaign_id: %w", err))
	}

	if err := h.campaignService.LaunchCampaign(ctx, campaignID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.LaunchCampaignResponse{}), nil
}

func (h *SMSHandler) PauseCampaign(ctx context.Context, req *connect.Request[navigatorsv1.PauseCampaignRequest]) (*connect.Response[navigatorsv1.PauseCampaignResponse], error) {
	campaignIDStr := req.Msg.GetCampaignId()
	if campaignIDStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("campaign_id is required"))
	}
	campaignID, err := uuid.Parse(campaignIDStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid campaign_id: %w", err))
	}

	if err := h.campaignService.PauseCampaign(ctx, campaignID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.PauseCampaignResponse{}), nil
}

func (h *SMSHandler) CancelCampaign(ctx context.Context, req *connect.Request[navigatorsv1.CancelCampaignRequest]) (*connect.Response[navigatorsv1.CancelCampaignResponse], error) {
	campaignIDStr := req.Msg.GetCampaignId()
	if campaignIDStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("campaign_id is required"))
	}
	campaignID, err := uuid.Parse(campaignIDStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid campaign_id: %w", err))
	}

	if err := h.campaignService.CancelCampaign(ctx, campaignID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.CancelCampaignResponse{}), nil
}

func (h *SMSHandler) GetCampaign(ctx context.Context, req *connect.Request[navigatorsv1.GetCampaignRequest]) (*connect.Response[navigatorsv1.GetCampaignResponse], error) {
	campaignIDStr := req.Msg.GetCampaignId()
	if campaignIDStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("campaign_id is required"))
	}
	campaignID, err := uuid.Parse(campaignIDStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid campaign_id: %w", err))
	}

	campaign, err := h.campaignService.GetCampaign(ctx, campaignID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.GetCampaignResponse{
		Campaign: smsCampaignToProto(campaign),
	}), nil
}

func (h *SMSHandler) ListCampaigns(ctx context.Context, req *connect.Request[navigatorsv1.ListCampaignsRequest]) (*connect.Response[navigatorsv1.ListCampaignsResponse], error) {
	pageSize := req.Msg.GetPageSize()
	if pageSize <= 0 || pageSize > 100 {
		pageSize = 50
	}

	var offset int32
	if pt := req.Msg.GetPageToken(); pt != "" {
		parsed, err := strconv.ParseInt(pt, 10, 32)
		if err == nil {
			offset = int32(parsed)
		}
	}

	campaigns, err := h.campaignService.ListCampaigns(ctx, pageSize, offset)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	protoCampaigns := make([]*navigatorsv1.SMSCampaign, len(campaigns))
	for i, c := range campaigns {
		protoCampaigns[i] = smsCampaignToProto(&c)
	}

	var nextPageToken string
	if len(campaigns) == int(pageSize) {
		nextPageToken = strconv.FormatInt(int64(offset+int32(len(campaigns))), 10)
	}

	return connect.NewResponse(&navigatorsv1.ListCampaignsResponse{
		Campaigns:     protoCampaigns,
		NextPageToken: nextPageToken,
	}), nil
}

// --- 10DLC RPCs ---

func (h *SMSHandler) Get10DLCStatus(ctx context.Context, _ *connect.Request[navigatorsv1.Get10DLCStatusRequest]) (*connect.Response[navigatorsv1.Get10DLCStatusResponse], error) {
	config, err := h.smsService.GetConfig(ctx)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.Get10DLCStatusResponse{
		Status:      config.TenDlcStatus,
		BrandSid:    config.TenDlcBrandSid,
		CampaignSid: config.TenDlcCampaignSid,
	}), nil
}

func (h *SMSHandler) Update10DLCStatus(ctx context.Context, req *connect.Request[navigatorsv1.Update10DLCStatusRequest]) (*connect.Response[navigatorsv1.Update10DLCStatusResponse], error) {
	status := req.Msg.GetStatus()
	if status == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("status is required"))
	}

	if err := h.campaignService.Update10DLCStatus(ctx, req.Msg.GetBrandSid(), req.Msg.GetCampaignSid(), status); err != nil {
		return nil, connect.NewError(connect.CodeInternal, err)
	}

	return connect.NewResponse(&navigatorsv1.Update10DLCStatusResponse{
		Status: status,
	}), nil
}

// --- Proto conversion helpers ---

// smsMessageToProto converts a db.SmsMessage to its proto representation.
func smsMessageToProto(msg *db.SmsMessage) *navigatorsv1.SMSMessage {
	userID := ""
	if msg.UserID.Valid {
		userID = uuid.UUID(msg.UserID.Bytes).String()
	}

	return &navigatorsv1.SMSMessage{
		Id:          msg.ID.String(),
		VoterId:     msg.VoterID.String(),
		UserId:      userID,
		Direction:   msg.Direction,
		MessageType: msg.MessageType,
		Body:        msg.Body,
		Status:      msg.Status,
		CreatedAt:   msg.CreatedAt.Format("2006-01-02T15:04:05Z"),
		FromNumber:  msg.FromNumber,
		ToNumber:    msg.ToNumber,
	}
}

// smsConfigToProto converts a db.SmsConfig to its proto representation.
// Excludes the encrypted auth token from the response.
func smsConfigToProto(config *db.SmsConfig) *navigatorsv1.SMSConfig {
	return &navigatorsv1.SMSConfig{
		CompanyId:              config.CompanyID.String(),
		TwilioAccountSid:      config.TwilioAccountSid,
		P2PMessagingServiceSid: config.P2pMessagingServiceSid,
		A2PMessagingServiceSid: config.A2pMessagingServiceSid,
		InboundWebhookUrl:     config.InboundWebhookUrl,
		StatusWebhookUrl:      config.StatusWebhookUrl,
		QuietHoursStart:       config.QuietHoursStart,
		QuietHoursEnd:         config.QuietHoursEnd,
		TenDlcBrandSid:        config.TenDlcBrandSid,
		TenDlcCampaignSid:     config.TenDlcCampaignSid,
		TenDlcStatus:          config.TenDlcStatus,
	}
}

// smsTemplateToProto converts a db.SmsTemplate to its proto representation.
func smsTemplateToProto(tmpl *db.SmsTemplate) *navigatorsv1.SMSTemplate {
	return &navigatorsv1.SMSTemplate{
		Id:          tmpl.ID.String(),
		Name:        tmpl.Name,
		Body:        tmpl.Body,
		MergeFields: tmpl.MergeFields,
		IsActive:    tmpl.IsActive,
		CreatedAt:   tmpl.CreatedAt.Format("2006-01-02T15:04:05Z"),
		UpdatedAt:   tmpl.UpdatedAt.Format("2006-01-02T15:04:05Z"),
	}
}

// smsCampaignToProto converts a db.SmsCampaign to its proto representation.
func smsCampaignToProto(c *db.SmsCampaign) *navigatorsv1.SMSCampaign {
	templateID := ""
	if c.TemplateID.Valid {
		templateID = uuid.UUID(c.TemplateID.Bytes).String()
	}

	launchedAt := ""
	if c.LaunchedAt.Valid {
		launchedAt = c.LaunchedAt.Time.Format("2006-01-02T15:04:05Z")
	}

	completedAt := ""
	if c.CompletedAt.Valid {
		completedAt = c.CompletedAt.Time.Format("2006-01-02T15:04:05Z")
	}

	segmentFilters := ""
	if c.SegmentFilters != nil {
		segmentFilters = string(c.SegmentFilters)
	}

	return &navigatorsv1.SMSCampaign{
		Id:              c.ID.String(),
		Name:            c.Name,
		TemplateId:      templateID,
		SegmentFilters:  segmentFilters,
		Status:          c.Status,
		TotalRecipients: c.TotalRecipients,
		SentCount:       c.SentCount,
		DeliveredCount:  c.DeliveredCount,
		FailedCount:     c.FailedCount,
		LaunchedAt:      launchedAt,
		CompletedAt:     completedAt,
		CreatedAt:       c.CreatedAt.Format("2006-01-02T15:04:05Z"),
		UpdatedAt:       c.UpdatedAt.Format("2006-01-02T15:04:05Z"),
	}
}
