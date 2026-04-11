# Objective 9: Analytics + Dashboards - Research

**Researched:** 2026-04-10
**Domain:** Data aggregation, charting, CSV/Excel export, role-scoped dashboards
**Confidence:** HIGH

## Summary

Objective 9 adds per-role dashboards and data export to an existing codebase that already has the data tables (contact_logs, sms_messages, tasks, turfs, voters), a working heat map overlay, and a role-scoping system (TurfScopedFilter with ScopeOwn/ScopeTeam/ScopeAll). The work is primarily: (1) new SQL aggregation queries, (2) a new proto AnalyticsService, (3) a new Go analytics handler, (4) a Flutter charting UI with fl_chart, and (5) CSV/Excel export endpoints.

All required data already exists in the database. No new tables are needed -- only new queries and a potential materialized view for expensive aggregations. The existing TurfScopedFilter pattern in `turf_scope.go` provides the exact role-scoping mechanism needed.

**Primary recommendation:** Add sqlc aggregation queries + a new AnalyticsService proto + fl_chart for Flutter charts. Use Go stdlib `encoding/csv` for CSV and `excelize` for Excel. Reuse existing TurfScopedFilter for all role scoping.

<phase_requirements>
## Objective Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ANLYT-01 | Navigator sees personal dashboard (my tasks, my stats, my assigned turfs) | TurfScopedFilter.ScopeOwn provides turf IDs; aggregate contact_logs + tasks WHERE user_id = self. fl_chart for stats display. |
| ANLYT-02 | Super Navigator sees team dashboard (performance metrics, task completion, turf coverage) | TurfScopedFilter.ScopeTeam provides team turf IDs via GetTeamTurfIDs; aggregate across team members. |
| ANLYT-03 | Admin sees org dashboard with geographic heat maps and trend analysis | TurfScopedFilter.ScopeAll bypasses filtering; existing HeatMapOverlay reused with new modes; time-series queries for trends. |
| ANLYT-04 | System tracks key metrics: doors knocked, texts sent, calls made, contact rate, sentiment distribution | All data exists in contact_logs (door_knock/phone/text types, sentiment 1-5, outcome), sms_messages (direction/status), tasks (progress). New SQL aggregation queries needed. |
| ANLYT-05 | Admin can export any filtered dataset as CSV/Excel | New export endpoint; Go encoding/csv for CSV, excelize v2.10 for Excel. Stream rows to avoid memory issues. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| fl_chart | ^0.70.2 | Flutter charts (bar, line, pie) | Most popular Flutter chart lib, 7k+ GitHub stars, active maintenance, no native deps |
| encoding/csv | stdlib | CSV export | Go stdlib, zero dependencies, streaming writer |
| excelize | v2.10.0 | Excel (.xlsx) export | De-facto Go Excel library, pure Go, streaming API for large files |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| HeatMapOverlay | existing | Geographic heat maps | Already built in Obj 3, reuse with analytics-specific modes |
| TurfScopedFilter | existing | Role-based data scoping | Already built in Obj 2, use for all dashboard queries |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fl_chart | syncfusion_flutter_charts | Syncfusion is more feature-rich but requires license for commercial use |
| excelize | tealeg/xlsx | tealeg is less maintained, excelize has streaming API for large exports |
| SQL aggregation | Materialized views | Materialized views add complexity; use only if query performance becomes an issue |

**Installation:**
```bash
# Flutter
flutter pub add fl_chart

# Go
go get github.com/xuri/excelize/v2@v2.10.0
```

## Architecture Patterns

### Recommended Project Structure
```
# Backend (Go)
navigators-go/
  proto/navigators/v1/analytics.proto    # New AnalyticsService definition
  queries/navigators/analytics.sql       # New sqlc aggregation queries
  internal/navigators/
    analytics_service.go                 # Query orchestration + role scoping
    analytics_handler.go                 # ConnectRPC handler
    export_service.go                    # CSV/Excel generation + streaming

# Frontend (Flutter)
navigators-flutter/lib/src/features/
  dashboard/
    navigator_dashboard_screen.dart      # Navigator personal view
    team_dashboard_screen.dart           # Super Navigator team view
    admin_dashboard_screen.dart          # Admin org view
    widgets/
      metric_card.dart                   # Reusable stat card
      activity_chart.dart                # Line chart for trends
      sentiment_pie_chart.dart           # Pie chart for sentiment
      leaderboard_widget.dart            # Team performance ranking
```

### Pattern 1: Role-Scoped Analytics Queries
**What:** Every analytics endpoint calls TurfScopedFilter.ResolveScope() first, then uses the scope to constrain queries.
**When to use:** Every dashboard data fetch.
**Example:**
```go
// Follows existing pattern in turf_scope.go
func (h *AnalyticsHandler) GetDashboard(ctx context.Context, req *connect.Request[...]) (*connect.Response[...], error) {
    scope, err := h.scopeFilter.ResolveScope(ctx)
    if err != nil {
        return nil, err
    }

    switch scope.Type {
    case ScopeOwn:
        return h.getNavigatorDashboard(ctx, scope)
    case ScopeTeam:
        return h.getTeamDashboard(ctx, scope)
    case ScopeAll:
        return h.getAdminDashboard(ctx, scope)
    }
}
```

### Pattern 2: SQL Aggregation with Scope Filtering
**What:** Build aggregation queries that accept optional turf_id/user_id filters.
**When to use:** All metric queries.
**Example:**
```sql
-- name: GetContactStats :one
-- Aggregate contact metrics scoped by optional user/turf filters.
SELECT
    COUNT(*) FILTER (WHERE contact_type = 'door_knock') AS doors_knocked,
    COUNT(*) FILTER (WHERE contact_type = 'phone') AS calls_made,
    COUNT(*) FILTER (WHERE contact_type = 'text') AS texts_sent,
    COUNT(*)::float / NULLIF(COUNT(DISTINCT voter_id), 0) AS contacts_per_voter,
    COUNT(*) FILTER (WHERE outcome NOT IN ('', 'not_home', 'refused'))::float
        / NULLIF(COUNT(*), 0) AS contact_rate,
    COUNT(*) FILTER (WHERE sentiment = 1) AS sentiment_1,
    COUNT(*) FILTER (WHERE sentiment = 2) AS sentiment_2,
    COUNT(*) FILTER (WHERE sentiment = 3) AS sentiment_3,
    COUNT(*) FILTER (WHERE sentiment = 4) AS sentiment_4,
    COUNT(*) FILTER (WHERE sentiment = 5) AS sentiment_5
FROM contact_logs
WHERE company_id = @company_id
  AND (@user_id::uuid IS NULL OR user_id = @user_id)
  AND (@turf_ids::uuid[] IS NULL OR turf_id = ANY(@turf_ids))
  AND created_at >= @since
  AND created_at < @until;
```

### Pattern 3: Streaming CSV/Excel Export
**What:** Stream export rows directly from DB cursor to HTTP response to avoid loading all data into memory.
**When to use:** All export endpoints (voters can be 1M+ rows).
**Example:**
```go
func (s *ExportService) ExportContactLogsCSV(ctx context.Context, w io.Writer, companyID uuid.UUID, filters ExportFilters) error {
    csvWriter := csv.NewWriter(w)
    defer csvWriter.Flush()

    // Write header
    csvWriter.Write([]string{"Date", "Voter", "Type", "Outcome", "Sentiment", "Navigator", "Turf"})

    // Stream rows from DB
    rows, err := s.pool.Query(ctx, exportContactLogsQuery, companyID, filters.Since, filters.Until)
    if err != nil {
        return err
    }
    defer rows.Close()

    for rows.Next() {
        // scan and write each row
        csvWriter.Write(record)
    }
    return rows.Err()
}
```

### Pattern 4: Time-Series Aggregation for Trend Charts
**What:** Group metrics by day/week for line chart display.
**When to use:** Admin trend analysis (ANLYT-03).
**Example:**
```sql
-- name: GetContactTrend :many
SELECT
    date_trunc('day', created_at)::date AS day,
    COUNT(*) AS total_contacts,
    COUNT(*) FILTER (WHERE contact_type = 'door_knock') AS door_knocks,
    COUNT(*) FILTER (WHERE contact_type = 'phone') AS calls,
    COUNT(*) FILTER (WHERE contact_type = 'text') AS texts
FROM contact_logs
WHERE company_id = @company_id
  AND created_at >= @since
  AND created_at < @until
GROUP BY day
ORDER BY day;
```

### Anti-Patterns to Avoid
- **N+1 queries per turf:** Do NOT loop over turfs fetching stats one-by-one. Use GROUP BY turf_id in a single query.
- **Client-side aggregation:** Do NOT send raw contact_logs to Flutter and aggregate there. Always aggregate server-side.
- **Unbounded exports:** Always require date range filters on exports. Never allow exporting the entire database without constraints.
- **Real-time dashboards via polling:** Use reasonable cache TTLs (30-60 seconds) rather than polling every few seconds.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Excel generation | Custom XML/ZIP writer | excelize v2.10.0 | Excel format is complex ZIP+XML; excelize handles styles, sheets, streaming |
| Chart rendering | Custom Canvas/Paint | fl_chart | Animations, touch interactions, accessibility all handled |
| Date range bucketing | Application-level grouping | PostgreSQL date_trunc() | DB-level grouping is faster and handles timezone correctly |
| Heat maps | New heat map widget | Existing HeatMapOverlay | Already built with density grid, debounced fetch, custom painter |
| Role scoping | Manual if/else chains | Existing TurfScopedFilter | Already resolves ScopeOwn/ScopeTeam/ScopeAll from JWT claims |

## Common Pitfalls

### Pitfall 1: Slow Aggregation on Large Tables
**What goes wrong:** COUNT + GROUP BY on contact_logs with 1M+ rows takes seconds.
**Why it happens:** Full table scans without proper indexing or time bounds.
**How to avoid:** Always require date range (AND created_at >= X). The existing `idx_contact_logs_company` index on `(company_id, created_at DESC)` helps. Add compound indexes if needed for specific filters.
**Warning signs:** Dashboard load time > 2 seconds.

### Pitfall 2: Export Memory Exhaustion
**What goes wrong:** Loading 1M voter rows into memory for Excel export causes OOM.
**Why it happens:** Excelize default mode buffers entire file in memory.
**How to avoid:** Use excelize StreamWriter for large exports. For CSV, use Go's streaming csv.Writer with pgx row-by-row iteration.
**Warning signs:** Export endpoint crashes on large datasets.

### Pitfall 3: Inconsistent Scope Between Dashboard and Export
**What goes wrong:** Dashboard shows Navigator-scoped data but export accidentally returns all company data.
**Why it happens:** Export endpoint doesn't apply same TurfScopedFilter.
**How to avoid:** Both dashboard and export endpoints must call ResolveScope() and apply the same WHERE clauses.
**Warning signs:** Navigator can export data they shouldn't see.

### Pitfall 4: Timezone Confusion in Date Grouping
**What goes wrong:** Day boundaries in trend charts don't match user expectations.
**Why it happens:** PostgreSQL date_trunc uses UTC by default; users are in Eastern time.
**How to avoid:** Use `date_trunc('day', created_at AT TIME ZONE 'America/New_York')` for Maine-specific grouping.
**Warning signs:** Activity shows up on wrong day in charts.

### Pitfall 5: Empty State UI
**What goes wrong:** Dashboard shows blank/broken charts when no data exists yet.
**Why it happens:** fl_chart crashes or shows meaningless empty charts with zero data.
**How to avoid:** Check for empty datasets before rendering charts; show "No data yet" placeholder with guidance.
**Warning signs:** New Navigator sees error screen instead of empty dashboard.

## Code Examples

### fl_chart Line Chart (Trend)
```dart
// fl_chart line chart for contact trends
LineChart(
  LineChartData(
    gridData: const FlGridData(show: true),
    titlesData: FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) => Text(
            DateFormat('M/d').format(DateTime.fromMillisecondsSinceEpoch(value.toInt())),
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: trendData.map((d) => FlSpot(
          d.date.millisecondsSinceEpoch.toDouble(),
          d.count.toDouble(),
        )).toList(),
        isCurved: true,
        color: Colors.blue,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ),
    ],
  ),
)
```

### fl_chart Pie Chart (Sentiment Distribution)
```dart
PieChart(
  PieChartData(
    sections: [
      PieChartSectionData(value: stats.sentiment1.toDouble(), title: '1', color: Colors.red),
      PieChartSectionData(value: stats.sentiment2.toDouble(), title: '2', color: Colors.orange),
      PieChartSectionData(value: stats.sentiment3.toDouble(), title: '3', color: Colors.yellow),
      PieChartSectionData(value: stats.sentiment4.toDouble(), title: '4', color: Colors.lightGreen),
      PieChartSectionData(value: stats.sentiment5.toDouble(), title: '5', color: Colors.green),
    ],
  ),
)
```

### Go Excel Export with Streaming
```go
import "github.com/xuri/excelize/v2"

func (s *ExportService) ExportContactLogsExcel(ctx context.Context, w io.Writer, companyID uuid.UUID) error {
    f := excelize.NewFile()
    defer f.Close()

    sw, err := f.NewStreamWriter("Sheet1")
    if err != nil {
        return err
    }

    // Header row
    sw.SetRow("A1", []interface{}{
        excelize.Cell{Value: "Date"},
        excelize.Cell{Value: "Voter"},
        excelize.Cell{Value: "Type"},
        excelize.Cell{Value: "Outcome"},
        excelize.Cell{Value: "Sentiment"},
    })

    // Stream data rows
    row := 2
    rows, _ := s.pool.Query(ctx, query, companyID)
    defer rows.Close()
    for rows.Next() {
        // scan...
        cell, _ := excelize.CoordinatesToCellName(1, row)
        sw.SetRow(cell, []interface{}{date, voter, typ, outcome, sentiment})
        row++
    }

    sw.Flush()
    return f.Write(w)
}
```

### Metric Definitions (SQL)
```sql
-- Key metrics derivable from existing tables:
-- Doors knocked:    COUNT(*) FROM contact_logs WHERE contact_type = 'door_knock'
-- Texts sent:       COUNT(*) FROM sms_messages WHERE direction = 'outbound'
-- Calls made:       COUNT(*) FROM contact_logs WHERE contact_type = 'phone'
-- Contact rate:     contacted_voters / total_voters (per turf, already in GetTurfCompletionStats)
-- Sentiment dist:   COUNT(*) GROUP BY sentiment FROM contact_logs WHERE sentiment IS NOT NULL
-- Task completion:  completed_count / total_count FROM tasks (already tracked)
-- Response rate:    COUNT(outcome NOT IN ('', 'not_home')) / COUNT(*) FROM contact_logs
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| charts_flutter | fl_chart | 2023+ | fl_chart is actively maintained; charts_flutter is Google but less customizable |
| tealeg/xlsx | excelize v2 | 2022+ | excelize has streaming, better maintenance, broader format support |
| Custom aggregation code | PostgreSQL FILTER clause | PG 9.4+ | FILTER is cleaner than CASE WHEN for conditional aggregation |

## Open Questions

1. **Dashboard refresh strategy**
   - What we know: Data changes as Navigators work in the field
   - What's unclear: How fresh should dashboard data be?
   - Recommendation: Fetch on screen load + pull-to-refresh. No live updates needed for analytics.

2. **Export file size limits**
   - What we know: Full voter file could be 1M+ rows
   - What's unclear: Should there be a row limit or should we always allow full export?
   - Recommendation: Always require date range filter. For voter exports, cap at 100k rows per file and offer pagination.

3. **Materialized views vs. live queries**
   - What we know: Most queries will be fast with proper indexes and date bounds
   - What's unclear: Whether team/admin dashboards need pre-computed rollups at scale
   - Recommendation: Start with live queries. Add materialized views only if query times exceed 2 seconds at production scale.

## Sources

### Primary (HIGH confidence)
- Codebase inspection: contact_logs, sms_messages, tasks, voters schemas
- Codebase inspection: turf_scope.go (TurfScopedFilter with ScopeOwn/ScopeTeam/ScopeAll)
- Codebase inspection: turf_stats.go (existing aggregation patterns, DensityGridCell, heat map)
- Codebase inspection: heat_map_overlay.dart (existing Flutter heat map widget)

### Secondary (MEDIUM confidence)
- [fl_chart pub.dev](https://pub.dev/packages/fl_chart) - v0.70.2, Line/Bar/Pie/Scatter/Radar charts
- [excelize GitHub](https://github.com/qax-os/excelize) - v2.10.0, streaming API, Go 1.24+ required
- [excelize pkg.go.dev](https://pkg.go.dev/github.com/xuri/excelize/v2) - API documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - fl_chart and excelize are well-established, versions verified
- Architecture: HIGH - follows existing codebase patterns (TurfScopedFilter, sqlc queries, ConnectRPC handlers)
- Pitfalls: HIGH - standard data engineering concerns, verified against codebase scale expectations
- Metric definitions: HIGH - all source tables inspected, columns and indexes verified

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (stable domain, no fast-moving dependencies)
