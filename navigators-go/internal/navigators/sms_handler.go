package navigators

import (
	"context"
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
	smsService *SMSService
}

// NewSMSHandler creates a new SMSHandler.
func NewSMSHandler(smsService *SMSService) *SMSHandler {
	return &SMSHandler{smsService: smsService}
}

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
