package navigators

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"navigators-go/internal/db"
)

// SyncService provides sync query operations scoped to user's turfs.
type SyncService struct {
	queries    *db.Queries
	pool       *pgxpool.Pool
	turfFilter *TurfScopedFilter
}

// NewSyncService creates a new SyncService.
func NewSyncService(queries *db.Queries, pool *pgxpool.Pool, turfFilter *TurfScopedFilter) *SyncService {
	return &SyncService{
		queries:    queries,
		pool:       pool,
		turfFilter: turfFilter,
	}
}

// SyncVoterRow represents a voter row returned for sync pull.
type SyncVoterRow struct {
	ID               uuid.UUID
	TurfID           uuid.UUID
	FirstName        string
	LastName         string
	MiddleName       string
	Suffix           string
	YearOfBirth      int32
	ResStreetAddress string
	ResCity          string
	ResState         string
	ResZip           string
	Party            string
	Status           string
	Latitude         float64
	Longitude        float64
	VotingHistory    string
	Phone            string
	Email            string
	WalkSequence     int32
	UpdatedAt        time.Time
}

// SyncContactLogRow represents a contact log row returned for sync pull.
type SyncContactLogRow struct {
	ID          uuid.UUID
	VoterID     uuid.UUID
	TurfID      uuid.UUID
	UserID      uuid.UUID
	ContactType string
	Outcome     string
	Notes       string
	CreatedAt   time.Time
}

// PullVoterUpdatesResult contains the result of a voter pull operation.
type PullVoterUpdatesResult struct {
	Voters     []SyncVoterRow
	NextCursor string
	HasMore    bool
}

// PullContactLogsResult contains the result of a contact log pull operation.
type PullContactLogsResult struct {
	ContactLogs []SyncContactLogRow
	NextCursor  string
	HasMore     bool
}

// TurfAssignmentResult contains turf info for the sync manifest.
type TurfAssignmentResult struct {
	TurfID          uuid.UUID
	TurfName        string
	BoundaryGeojson string
	VoterCount      int64
}

// PullVoterUpdates returns voters updated since cursor, scoped to the user's turfs.
// Uses raw pgxpool for spatial JOIN (same pattern as turf_stats.go).
func (s *SyncService) PullVoterUpdates(ctx context.Context, companyID uuid.UUID, turfIDs []uuid.UUID, sinceCursor string, batchSize int32) (*PullVoterUpdatesResult, error) {
	if batchSize <= 0 || batchSize > 500 {
		batchSize = 500
	}

	if len(turfIDs) == 0 {
		return &PullVoterUpdatesResult{}, nil
	}

	// Parse cursor or use epoch for full sync
	var sinceTime time.Time
	if sinceCursor != "" {
		var err error
		sinceTime, err = time.Parse(time.RFC3339Nano, sinceCursor)
		if err != nil {
			return nil, fmt.Errorf("parse cursor: %w", err)
		}
	} else {
		sinceTime = time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC)
	}

	// Build turf ID array for ANY() clause
	turfIDStrings := make([]interface{}, len(turfIDs))
	for i, id := range turfIDs {
		turfIDStrings[i] = id
	}

	// Raw spatial query: get voters in turfs updated after cursor
	// Fetch batchSize+1 to detect has_more
	query := `
		SELECT DISTINCT v.id, t.id as turf_id,
			v.first_name, v.last_name, v.middle_name, v.suffix, v.year_of_birth,
			v.res_street_address, v.res_city, v.res_state, v.res_zip,
			v.party, v.status,
			COALESCE(ST_Y(v.location), 0) as latitude,
			COALESCE(ST_X(v.location), 0) as longitude,
			v.voting_history::text, COALESCE(v.phone, ''), COALESCE(v.email, ''),
			0 as walk_sequence,
			v.updated_at
		FROM voters v
		JOIN turfs t ON t.company_id = v.company_id
			AND t.id = ANY($1::uuid[])
			AND v.location IS NOT NULL
			AND v.geocode_status = 'success'
			AND ST_Contains(t.boundary, v.location)
		WHERE v.company_id = $2
			AND v.updated_at > $3
		ORDER BY v.updated_at ASC
		LIMIT $4`

	rows, err := s.pool.Query(ctx, query, turfIDs, companyID, sinceTime, batchSize+1)
	if err != nil {
		return nil, fmt.Errorf("pull voter updates: %w", err)
	}
	defer rows.Close()

	var voters []SyncVoterRow
	for rows.Next() {
		var v SyncVoterRow
		if err := rows.Scan(
			&v.ID, &v.TurfID,
			&v.FirstName, &v.LastName, &v.MiddleName, &v.Suffix, &v.YearOfBirth,
			&v.ResStreetAddress, &v.ResCity, &v.ResState, &v.ResZip,
			&v.Party, &v.Status,
			&v.Latitude, &v.Longitude,
			&v.VotingHistory, &v.Phone, &v.Email,
			&v.WalkSequence,
			&v.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan voter row: %w", err)
		}
		voters = append(voters, v)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate voter rows: %w", err)
	}

	hasMore := len(voters) > int(batchSize)
	if hasMore {
		voters = voters[:batchSize]
	}

	var nextCursor string
	if len(voters) > 0 {
		nextCursor = voters[len(voters)-1].UpdatedAt.Format(time.RFC3339Nano)
	}

	return &PullVoterUpdatesResult{
		Voters:     voters,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}, nil
}

// PullContactLogs returns contact logs created since cursor, scoped to the user's turfs.
func (s *SyncService) PullContactLogs(ctx context.Context, companyID uuid.UUID, turfIDs []uuid.UUID, sinceCursor string, batchSize int32) (*PullContactLogsResult, error) {
	if batchSize <= 0 || batchSize > 500 {
		batchSize = 500
	}

	if len(turfIDs) == 0 {
		return &PullContactLogsResult{}, nil
	}

	var sinceTime time.Time
	if sinceCursor != "" {
		var err error
		sinceTime, err = time.Parse(time.RFC3339Nano, sinceCursor)
		if err != nil {
			return nil, fmt.Errorf("parse cursor: %w", err)
		}
	} else {
		sinceTime = time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC)
	}

	query := `
		SELECT cl.id, cl.voter_id, cl.turf_id, cl.user_id,
			cl.contact_type, cl.outcome, cl.notes, cl.created_at
		FROM contact_logs cl
		WHERE cl.company_id = $1
			AND cl.turf_id = ANY($2::uuid[])
			AND cl.created_at > $3
		ORDER BY cl.created_at ASC
		LIMIT $4`

	rows, err := s.pool.Query(ctx, query, companyID, turfIDs, sinceTime, batchSize+1)
	if err != nil {
		return nil, fmt.Errorf("pull contact logs: %w", err)
	}
	defer rows.Close()

	var logs []SyncContactLogRow
	for rows.Next() {
		var cl SyncContactLogRow
		if err := rows.Scan(
			&cl.ID, &cl.VoterID, &cl.TurfID, &cl.UserID,
			&cl.ContactType, &cl.Outcome, &cl.Notes, &cl.CreatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan contact log row: %w", err)
		}
		logs = append(logs, cl)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate contact log rows: %w", err)
	}

	hasMore := len(logs) > int(batchSize)
	if hasMore {
		logs = logs[:batchSize]
	}

	var nextCursor string
	if len(logs) > 0 {
		nextCursor = logs[len(logs)-1].CreatedAt.Format(time.RFC3339Nano)
	}

	return &PullContactLogsResult{
		ContactLogs: logs,
		NextCursor:  nextCursor,
		HasMore:     hasMore,
	}, nil
}

// GetSyncManifest returns the user's turf assignments with boundary and voter count.
func (s *SyncService) GetSyncManifest(ctx context.Context, userID uuid.UUID) ([]TurfAssignmentResult, error) {
	sqlcRows, err := s.queries.GetSyncTurfAssignments(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("get sync turf assignments: %w", err)
	}

	results := make([]TurfAssignmentResult, len(sqlcRows))
	for i, row := range sqlcRows {
		var geojson string
		if s, ok := row.BoundaryGeojson.(string); ok {
			geojson = s
		}
		results[i] = TurfAssignmentResult{
			TurfID:          row.TurfID,
			TurfName:        row.TurfName,
			BoundaryGeojson: geojson,
			VoterCount:      row.VoterCount,
		}
	}

	return results, nil
}
