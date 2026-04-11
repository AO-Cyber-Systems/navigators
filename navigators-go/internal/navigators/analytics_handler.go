package navigators

import (
	"context"
	"fmt"
	"time"

	connect "connectrpc.com/connect"

	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
)

// Compile-time check that AnalyticsHandler implements the generated interface.
var _ navigatorsv1connect.AnalyticsServiceHandler = (*AnalyticsHandler)(nil)

// AnalyticsHandler implements the navigators.v1.AnalyticsService ConnectRPC handler.
type AnalyticsHandler struct {
	analyticsService *AnalyticsService
	exportService    *ExportService
}

// NewAnalyticsHandler creates a new AnalyticsHandler.
func NewAnalyticsHandler(analyticsService *AnalyticsService, exportService *ExportService) *AnalyticsHandler {
	return &AnalyticsHandler{analyticsService: analyticsService, exportService: exportService}
}

// parseDateRange parses since/until from request, defaulting to last 30 days if empty.
func parseDateRange(sinceStr, untilStr string) (time.Time, time.Time, error) {
	now := time.Now()

	var since time.Time
	if sinceStr == "" {
		since = now.AddDate(0, 0, -30)
	} else {
		parsed, err := time.Parse(time.RFC3339, sinceStr)
		if err != nil {
			return time.Time{}, time.Time{}, fmt.Errorf("invalid since: %w", err)
		}
		since = parsed
	}

	var until time.Time
	if untilStr == "" {
		until = now
	} else {
		parsed, err := time.Parse(time.RFC3339, untilStr)
		if err != nil {
			return time.Time{}, time.Time{}, fmt.Errorf("invalid until: %w", err)
		}
		until = parsed
	}

	return since, until, nil
}

func (h *AnalyticsHandler) GetDashboardMetrics(ctx context.Context, req *connect.Request[navigatorsv1.GetDashboardMetricsRequest]) (*connect.Response[navigatorsv1.GetDashboardMetricsResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	since, until, err := parseDateRange(req.Msg.GetSince(), req.Msg.GetUntil())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}

	metrics, err := h.analyticsService.GetDashboardMetrics(ctx, companyID, since, until)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get dashboard metrics: %w", err))
	}

	// Map sentiment distribution
	sentiments := make([]*navigatorsv1.SentimentBucket, len(metrics.SentimentDistribution))
	for i, s := range metrics.SentimentDistribution {
		sentiments[i] = &navigatorsv1.SentimentBucket{
			Sentiment: s.Sentiment,
			Count:     s.Count,
		}
	}

	// Map turf summaries
	turfSummaries := make([]*navigatorsv1.TurfSummary, len(metrics.TurfSummaries))
	for i, ts := range metrics.TurfSummaries {
		turfSummaries[i] = &navigatorsv1.TurfSummary{
			TurfId:         ts.TurfID.String(),
			TurfName:       ts.TurfName,
			VoterCount:     ts.VoterCount,
			ContactedCount: ts.ContactedCount,
		}
	}

	return connect.NewResponse(&navigatorsv1.GetDashboardMetricsResponse{
		DoorsKnocked:          metrics.DoorsKnocked,
		CallsMade:             metrics.CallsMade,
		TextsSent:             metrics.TextsSent,
		ContactRate:           metrics.ContactRate,
		TotalVoters:           metrics.TotalVoters,
		ContactedVoters:       metrics.ContactedVoters,
		SentimentDistribution: sentiments,
		TotalTasks:            metrics.TotalTasks,
		CompletedTasks:        metrics.CompletedTasks,
		TurfSummaries:         turfSummaries,
	}), nil
}

func (h *AnalyticsHandler) GetTrendData(ctx context.Context, req *connect.Request[navigatorsv1.GetTrendDataRequest]) (*connect.Response[navigatorsv1.GetTrendDataResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	since, until, err := parseDateRange(req.Msg.GetSince(), req.Msg.GetUntil())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}

	interval := req.Msg.GetInterval()
	if interval == "" {
		interval = "day"
	}
	if interval != "day" && interval != "week" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("interval must be 'day' or 'week'"))
	}

	points, err := h.analyticsService.GetTrendData(ctx, companyID, since, until, interval)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get trend data: %w", err))
	}

	pbPoints := make([]*navigatorsv1.TrendPoint, len(points))
	for i, p := range points {
		pbPoints[i] = &navigatorsv1.TrendPoint{
			Date:          p.Date,
			DoorKnocks:    p.DoorKnocks,
			Calls:         p.Calls,
			Texts:         p.Texts,
			TotalContacts: p.TotalContacts,
		}
	}

	return connect.NewResponse(&navigatorsv1.GetTrendDataResponse{
		Points: pbPoints,
	}), nil
}

func (h *AnalyticsHandler) GetPerformanceReport(ctx context.Context, req *connect.Request[navigatorsv1.GetPerformanceReportRequest]) (*connect.Response[navigatorsv1.GetPerformanceReportResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	since, until, err := parseDateRange(req.Msg.GetSince(), req.Msg.GetUntil())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}

	navigators, err := h.analyticsService.GetPerformanceReport(ctx, companyID, since, until)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get performance report: %w", err))
	}

	pbNavigators := make([]*navigatorsv1.NavigatorPerformance, len(navigators))
	for i, n := range navigators {
		pbNavigators[i] = &navigatorsv1.NavigatorPerformance{
			UserId:       n.UserID.String(),
			DisplayName:  n.DisplayName,
			DoorsKnocked: n.DoorsKnocked,
			CallsMade:    n.CallsMade,
			TextsSent:    n.TextsSent,
			TotalContacts: n.TotalContacts,
			ContactRate:  n.ContactRate,
		}
	}

	return connect.NewResponse(&navigatorsv1.GetPerformanceReportResponse{
		Navigators: pbNavigators,
	}), nil
}

func (h *AnalyticsHandler) ExportData(ctx context.Context, req *connect.Request[navigatorsv1.ExportDataRequest]) (*connect.Response[navigatorsv1.ExportDataResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	since, until, err := parseDateRange(req.Msg.GetSince(), req.Msg.GetUntil())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}

	exportType := req.Msg.GetExportType()
	format := req.Msg.GetFormat()

	if exportType == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("export_type is required"))
	}
	if format == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("format is required"))
	}
	if format != "csv" && format != "xlsx" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("format must be 'csv' or 'xlsx'"))
	}

	data, filename, contentType, err := h.exportService.Export(ctx, companyID, exportType, format, since, until)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("export data: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.ExportDataResponse{
		Data:        data,
		Filename:    filename,
		ContentType: contentType,
	}), nil
}
