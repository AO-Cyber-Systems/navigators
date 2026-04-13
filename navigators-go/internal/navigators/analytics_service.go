package navigators

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"navigators-go/internal/db"
)

// AnalyticsService provides dashboard metrics, trend data, and performance reports.
// All methods enforce role-based scoping via TurfScopedFilter.
type AnalyticsService struct {
	queries *db.Queries
	pool    *pgxpool.Pool
	scope   *TurfScopedFilter
}

// NewAnalyticsService creates a new AnalyticsService.
func NewAnalyticsService(queries *db.Queries, pool *pgxpool.Pool, scope *TurfScopedFilter) *AnalyticsService {
	return &AnalyticsService{queries: queries, pool: pool, scope: scope}
}

// DashboardMetrics holds aggregate contact stats, task stats, and turf summaries.
type DashboardMetrics struct {
	DoorsKnocked          int64
	CallsMade             int64
	TextsSent             int64
	ContactRate           float64
	TotalVoters           int64
	ContactedVoters       int64
	SentimentDistribution []SentimentBucket
	TotalTasks            int64
	CompletedTasks        int64
	TurfSummaries         []TurfSummaryResult
}

// SentimentBucket holds a sentiment value and its count.
type SentimentBucket struct {
	Sentiment int32
	Count     int64
}

// TurfSummaryResult holds per-turf voter stats.
type TurfSummaryResult struct {
	TurfID         uuid.UUID
	TurfName       string
	VoterCount     int64
	ContactedCount int64
}

// GetDashboardMetrics returns aggregate dashboard metrics scoped by the caller's role.
func (s *AnalyticsService) GetDashboardMetrics(ctx context.Context, companyID uuid.UUID, since, until time.Time) (*DashboardMetrics, error) {
	scope, err := s.scope.ResolveScope(ctx)
	if err != nil {
		return nil, fmt.Errorf("resolve scope: %w", err)
	}

	// Determine scope params for queries.
	// Use pgtype.UUID so SQL NULL is sent when no user filter is needed.
	var userID pgtype.UUID
	var turfIDs []uuid.UUID
	if scope.Type == ScopeOwn {
		userID = pgtype.UUID{Bytes: scope.UserID, Valid: true}
		turfIDs = scope.TurfIDs
	} else if scope.Type == ScopeTeam {
		turfIDs = scope.TurfIDs
	}
	// ScopeAll: userID.Valid=false (SQL NULL), turfIDs = nil (SQL NULL) -> no filtering

	// Contact stats
	contactStats, err := s.queries.GetContactStats(ctx, db.GetContactStatsParams{
		CompanyID: companyID,
		Since:     since,
		Until:     until,
		UserID:    userID,
		TurfIds:   turfIDs,
	})
	if err != nil {
		return nil, fmt.Errorf("get contact stats: %w", err)
	}

	// Compute contact rate in Go (sqlc cannot map float division result correctly).
	var contactRate float64
	if contactStats.UniqueVoters > 0 {
		contactRate = float64(contactStats.SuccessfulContacts) / float64(contactStats.UniqueVoters)
	}

	// Build sentiment distribution
	sentiments := []SentimentBucket{
		{Sentiment: 1, Count: contactStats.Sentiment1},
		{Sentiment: 2, Count: contactStats.Sentiment2},
		{Sentiment: 3, Count: contactStats.Sentiment3},
		{Sentiment: 4, Count: contactStats.Sentiment4},
		{Sentiment: 5, Count: contactStats.Sentiment5},
	}

	// Task stats
	taskStats, err := s.queries.GetTaskStats(ctx, db.GetTaskStatsParams{
		CompanyID: companyID,
		UserID:    userID,
	})
	if err != nil {
		return nil, fmt.Errorf("get task stats: %w", err)
	}

	// Turf summaries
	turfRows, err := s.queries.GetAnalyticsTurfSummaries(ctx, db.GetAnalyticsTurfSummariesParams{
		CompanyID: companyID,
		TurfIds:   turfIDs,
	})
	if err != nil {
		return nil, fmt.Errorf("get turf summaries: %w", err)
	}

	var totalVoters, contactedVoters int64
	turfSummaries := make([]TurfSummaryResult, len(turfRows))
	for i, row := range turfRows {
		turfSummaries[i] = TurfSummaryResult{
			TurfID:         row.TurfID,
			TurfName:       row.TurfName,
			VoterCount:     row.VoterCount,
			ContactedCount: row.ContactedCount,
		}
		totalVoters += row.VoterCount
		contactedVoters += row.ContactedCount
	}

	return &DashboardMetrics{
		DoorsKnocked:          contactStats.DoorsKnocked,
		CallsMade:             contactStats.CallsMade,
		TextsSent:             contactStats.TextsSent,
		ContactRate:           contactRate,
		TotalVoters:           totalVoters,
		ContactedVoters:       contactedVoters,
		SentimentDistribution: sentiments,
		TotalTasks:            taskStats.TotalTasks,
		CompletedTasks:        taskStats.CompletedTasks,
		TurfSummaries:         turfSummaries,
	}, nil
}

// TrendPoint holds a single time-series data point.
type TrendPoint struct {
	Date          string
	DoorKnocks    int64
	Calls         int64
	Texts         int64
	TotalContacts int64
}

// GetTrendData returns time-series contact data for trend charts.
func (s *AnalyticsService) GetTrendData(ctx context.Context, companyID uuid.UUID, since, until time.Time, interval string) ([]TrendPoint, error) {
	scope, err := s.scope.ResolveScope(ctx)
	if err != nil {
		return nil, fmt.Errorf("resolve scope: %w", err)
	}

	var userID pgtype.UUID
	var turfIDs []uuid.UUID
	if scope.Type == ScopeOwn {
		userID = pgtype.UUID{Bytes: scope.UserID, Valid: true}
		turfIDs = scope.TurfIDs
	} else if scope.Type == ScopeTeam {
		turfIDs = scope.TurfIDs
	}

	var points []TrendPoint

	if interval == "week" {
		rows, err := s.queries.GetContactTrendWeek(ctx, db.GetContactTrendWeekParams{
			CompanyID: companyID,
			Since:     since,
			Until:     until,
			UserID:    userID,
			TurfIds:   turfIDs,
		})
		if err != nil {
			return nil, fmt.Errorf("get contact trend (week): %w", err)
		}
		for _, row := range rows {
			date := ""
			if row.Day.Valid {
				date = row.Day.Time.Format("2006-01-02")
			}
			points = append(points, TrendPoint{
				Date:          date,
				DoorKnocks:    row.DoorKnocks,
				Calls:         row.Calls,
				Texts:         row.Texts,
				TotalContacts: row.TotalContacts,
			})
		}
	} else {
		// Default to daily
		rows, err := s.queries.GetContactTrendDay(ctx, db.GetContactTrendDayParams{
			CompanyID: companyID,
			Since:     since,
			Until:     until,
			UserID:    userID,
			TurfIds:   turfIDs,
		})
		if err != nil {
			return nil, fmt.Errorf("get contact trend (day): %w", err)
		}
		for _, row := range rows {
			date := ""
			if row.Day.Valid {
				date = row.Day.Time.Format("2006-01-02")
			}
			points = append(points, TrendPoint{
				Date:          date,
				DoorKnocks:    row.DoorKnocks,
				Calls:         row.Calls,
				Texts:         row.Texts,
				TotalContacts: row.TotalContacts,
			})
		}
	}

	return points, nil
}

// NavigatorPerformance holds per-navigator metrics.
type NavigatorPerformance struct {
	UserID       uuid.UUID
	DisplayName  string
	DoorsKnocked int64
	CallsMade    int64
	TextsSent    int64
	TotalContacts int64
	ContactRate  float64
}

// GetPerformanceReport returns per-navigator metrics scoped by role.
func (s *AnalyticsService) GetPerformanceReport(ctx context.Context, companyID uuid.UUID, since, until time.Time) ([]NavigatorPerformance, error) {
	scope, err := s.scope.ResolveScope(ctx)
	if err != nil {
		return nil, fmt.Errorf("resolve scope: %w", err)
	}

	var turfIDs []uuid.UUID
	if scope.Type == ScopeOwn || scope.Type == ScopeTeam {
		turfIDs = scope.TurfIDs
	}

	rows, err := s.queries.GetNavigatorPerformance(ctx, db.GetNavigatorPerformanceParams{
		CompanyID: companyID,
		Since:     since,
		Until:     until,
		TurfIds:   turfIDs,
	})
	if err != nil {
		return nil, fmt.Errorf("get navigator performance: %w", err)
	}

	// Build display name map
	nameRows, err := s.queries.GetDisplayNames(ctx, companyID)
	if err != nil {
		return nil, fmt.Errorf("get display names: %w", err)
	}
	nameMap := make(map[uuid.UUID]string, len(nameRows))
	for _, n := range nameRows {
		nameMap[n.ID] = n.DisplayName
	}

	var results []NavigatorPerformance
	for _, row := range rows {
		// For ScopeOwn, only return the requesting user's row
		if scope.Type == ScopeOwn && row.UserID != scope.UserID {
			continue
		}

		var contactRate float64
		if row.UniqueVoters > 0 {
			contactRate = float64(row.SuccessfulContacts) / float64(row.UniqueVoters)
		}

		results = append(results, NavigatorPerformance{
			UserID:        row.UserID,
			DisplayName:   nameMap[row.UserID],
			DoorsKnocked:  row.DoorsKnocked,
			CallsMade:     row.CallsMade,
			TextsSent:     row.TextsSent,
			TotalContacts: row.TotalContacts,
			ContactRate:   contactRate,
		})
	}

	return results, nil
}
