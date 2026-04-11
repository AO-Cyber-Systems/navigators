package navigators

import (
	"context"
	"encoding/json"
	"fmt"

	connect "connectrpc.com/connect"
	"github.com/google/uuid"

	"github.com/aocybersystems/eden-platform-go/platform/server"

	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
	"navigators-go/internal/db"
)

// Compile-time check that ImportHandler implements the generated interface.
var _ navigatorsv1connect.VoterImportServiceHandler = (*ImportHandler)(nil)

// ImportHandler implements the navigators.v1.VoterImportService ConnectRPC handler.
type ImportHandler struct {
	importService *ImportService
}

// NewImportHandler creates a new ImportHandler wrapping the ImportService.
func NewImportHandler(importService *ImportService) *ImportHandler {
	return &ImportHandler{importService: importService}
}

// StartImport creates a new import job and returns a presigned upload URL.
func (h *ImportHandler) StartImport(ctx context.Context, req *connect.Request[navigatorsv1.StartImportRequest]) (*connect.Response[navigatorsv1.StartImportResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("not authenticated"))
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("invalid company ID in claims"))
	}
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("invalid user ID in claims"))
	}

	fileName := req.Msg.GetFileName()
	if fileName == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("file_name is required"))
	}

	sourceType := req.Msg.GetSourceType()
	if sourceType != "cvr" && sourceType != "l2" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("source_type must be 'cvr' or 'l2'"))
	}

	// Parse field mapping from JSON string
	fieldMappingStr := req.Msg.GetFieldMapping()
	if fieldMappingStr == "" {
		fieldMappingStr = "{}"
	}
	var fieldMapping json.RawMessage
	if err := json.Unmarshal([]byte(fieldMappingStr), &fieldMapping); err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid field_mapping JSON: %w", err))
	}

	jobID, uploadURL, err := h.importService.StartImport(ctx, companyID, userID, fileName, sourceType, fieldMapping)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("start import: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.StartImportResponse{
		JobId:     jobID.String(),
		UploadUrl: uploadURL,
	}), nil
}

// ConfirmUpload triggers processing of an uploaded file.
func (h *ImportHandler) ConfirmUpload(ctx context.Context, req *connect.Request[navigatorsv1.ConfirmUploadRequest]) (*connect.Response[navigatorsv1.ConfirmUploadResponse], error) {
	jobID, err := uuid.Parse(req.Msg.GetJobId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid job_id"))
	}

	if err := h.importService.ConfirmUploadAndProcess(ctx, jobID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("confirm upload: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.ConfirmUploadResponse{
		Status: "processing",
	}), nil
}

// GetImportStatus returns the current status and progress of an import job.
func (h *ImportHandler) GetImportStatus(ctx context.Context, req *connect.Request[navigatorsv1.GetImportStatusRequest]) (*connect.Response[navigatorsv1.GetImportStatusResponse], error) {
	jobID, err := uuid.Parse(req.Msg.GetJobId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid job_id"))
	}

	job, err := h.importService.GetImportStatus(ctx, jobID)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("import job not found"))
	}

	return connect.NewResponse(&navigatorsv1.GetImportStatusResponse{
		Job: importJobToProto(job),
	}), nil
}

// ListImportJobs returns a paginated list of import jobs.
func (h *ImportHandler) ListImportJobs(ctx context.Context, req *connect.Request[navigatorsv1.ListImportJobsRequest]) (*connect.Response[navigatorsv1.ListImportJobsResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, connect.NewError(connect.CodeUnauthenticated, fmt.Errorf("not authenticated"))
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("invalid company ID in claims"))
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

	jobs, totalCount, err := h.importService.ListImportJobs(ctx, companyID, pageSize, offset)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("list import jobs: %w", err))
	}

	pbJobs := make([]*navigatorsv1.ImportJob, len(jobs))
	for i, j := range jobs {
		pbJobs[i] = importJobToProto(j)
	}

	return connect.NewResponse(&navigatorsv1.ListImportJobsResponse{
		Jobs:       pbJobs,
		TotalCount: totalCount,
	}), nil
}

// importJobToProto converts a db.ImportJob to a proto ImportJob message.
func importJobToProto(j db.ImportJob) *navigatorsv1.ImportJob {
	return &navigatorsv1.ImportJob{
		Id:           j.ID.String(),
		UploadedBy:   j.UploadedBy.String(),
		FileName:     j.FileName,
		SourceType:   j.SourceType,
		Status:       j.Status,
		TotalRows:    j.TotalRows,
		ParsedRows:   j.ParsedRows,
		MergedRows:   j.MergedRows,
		SkippedRows:  j.SkippedRows,
		ErrorRows:    j.ErrorRows,
		GeocodedRows: j.GeocodedRows,
		Errors:       string(j.Errors),
		FieldMapping: string(j.FieldMapping),
		CreatedAt:    j.CreatedAt.Format("2006-01-02T15:04:05Z"),
		UpdatedAt:    j.UpdatedAt.Format("2006-01-02T15:04:05Z"),
	}
}
