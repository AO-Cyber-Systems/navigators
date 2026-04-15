package navigators

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	connect "connectrpc.com/connect"
	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"

	"navigators-go/internal/db"

	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
)

// Compile-time check that CallScriptHandler implements the generated interface.
var _ navigatorsv1connect.CallScriptServiceHandler = (*CallScriptHandler)(nil)

// CallScriptHandler implements the navigators.v1.CallScriptService ConnectRPC
// handler. Mutations are gated on RoleLevel >= 80 (Admin); reads are open to
// all authenticated users (RBAC is further enforced by the eden RBAC
// interceptor via permissions.go).
type CallScriptHandler struct {
	svc *CallScriptService
}

// NewCallScriptHandler creates a new CallScriptHandler.
func NewCallScriptHandler(svc *CallScriptService) *CallScriptHandler {
	return &CallScriptHandler{svc: svc}
}

func (h *CallScriptHandler) CreateCallScript(ctx context.Context, req *connect.Request[navigatorsv1.CreateCallScriptRequest]) (*connect.Response[navigatorsv1.CreateCallScriptResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	claims := server.ClaimsFromContext(ctx)
	if claims == nil || claims.RoleLevel < 80 {
		return nil, connect.NewError(connect.CodePermissionDenied, errors.New("admin role required"))
	}
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	title := strings.TrimSpace(req.Msg.GetTitle())
	content := req.Msg.GetContent()
	if title == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, errors.New("title is required"))
	}
	if content == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, errors.New("content is required"))
	}

	script, err := h.svc.CreateCallScript(ctx, companyID, userID, title, content)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("create call script: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.CreateCallScriptResponse{
		Script: dbCallScriptToProto(script),
	}), nil
}

func (h *CallScriptHandler) UpdateCallScript(ctx context.Context, req *connect.Request[navigatorsv1.UpdateCallScriptRequest]) (*connect.Response[navigatorsv1.UpdateCallScriptResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	claims := server.ClaimsFromContext(ctx)
	if claims == nil || claims.RoleLevel < 80 {
		return nil, connect.NewError(connect.CodePermissionDenied, errors.New("admin role required"))
	}

	id, err := uuid.Parse(req.Msg.GetId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid id: %w", err))
	}

	title := strings.TrimSpace(req.Msg.GetTitle())
	content := req.Msg.GetContent()
	if title == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, errors.New("title is required"))
	}
	if content == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, errors.New("content is required"))
	}

	script, err := h.svc.UpdateCallScriptFields(ctx, companyID, id, title, content, req.Msg.GetIsActive())
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("update call script: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.UpdateCallScriptResponse{
		Script: dbCallScriptToProto(script),
	}), nil
}

func (h *CallScriptHandler) DeactivateCallScript(ctx context.Context, req *connect.Request[navigatorsv1.DeactivateCallScriptRequest]) (*connect.Response[navigatorsv1.DeactivateCallScriptResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	claims := server.ClaimsFromContext(ctx)
	if claims == nil || claims.RoleLevel < 80 {
		return nil, connect.NewError(connect.CodePermissionDenied, errors.New("admin role required"))
	}

	id, err := uuid.Parse(req.Msg.GetId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid id: %w", err))
	}

	if err := h.svc.DeactivateCallScript(ctx, companyID, id); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("deactivate call script: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.DeactivateCallScriptResponse{}), nil
}

func (h *CallScriptHandler) ListCallScripts(ctx context.Context, req *connect.Request[navigatorsv1.ListCallScriptsRequest]) (*connect.Response[navigatorsv1.ListCallScriptsResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	var scripts []db.CallScript
	if req.Msg.GetIncludeInactive() {
		scripts, err = h.svc.ListAllCallScripts(ctx, companyID)
	} else {
		scripts, err = h.svc.ListActiveCallScripts(ctx, companyID)
	}
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("list call scripts: %w", err))
	}

	pbScripts := make([]*navigatorsv1.CallScript, len(scripts))
	for i := range scripts {
		pbScripts[i] = dbCallScriptToProto(&scripts[i])
	}

	return connect.NewResponse(&navigatorsv1.ListCallScriptsResponse{
		Scripts: pbScripts,
	}), nil
}

// dbCallScriptToProto converts a db.CallScript to its proto representation.
func dbCallScriptToProto(s *db.CallScript) *navigatorsv1.CallScript {
	return &navigatorsv1.CallScript{
		Id:        s.ID.String(),
		CompanyId: s.CompanyID.String(),
		Title:     s.Title,
		Content:   s.Content,
		Version:   s.Version,
		IsActive:  s.IsActive,
		CreatedAt: s.CreatedAt.Format(time.RFC3339),
		UpdatedAt: s.UpdatedAt.Format(time.RFC3339),
	}
}
