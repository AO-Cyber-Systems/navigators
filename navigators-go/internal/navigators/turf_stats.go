package navigators

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"navigators-go/internal/db"
)

// TurfStatsService provides spatial voter queries and turf completion statistics.
type TurfStatsService struct {
	pool    *pgxpool.Pool
	queries *db.Queries
}

// NewTurfStatsService creates a new TurfStatsService.
func NewTurfStatsService(pool *pgxpool.Pool, queries *db.Queries) *TurfStatsService {
	return &TurfStatsService{pool: pool, queries: queries}
}

// VoterPin holds a geocoded voter's map-pin data.
type VoterPin struct {
	ID        uuid.UUID
	FirstName string
	LastName  string
	Lat       float64
	Lng       float64
	Party     string
	Status    string
}

// GetVotersInTurf returns geocoded voters spatially contained by a turf boundary.
func (s *TurfStatsService) GetVotersInTurf(ctx context.Context, companyID, turfID uuid.UUID, limit, offset int32) ([]VoterPin, int64, error) {
	query := `
		SELECT v.id, v.first_name, v.last_name, v.party, v.status,
		       ST_Y(v.location) as lat, ST_X(v.location) as lng
		FROM voters v
		JOIN turfs t ON t.id = $1
		WHERE v.company_id = $2
		  AND v.location IS NOT NULL
		  AND v.geocode_status = 'success'
		  AND ST_Contains(t.boundary, v.location)
		ORDER BY v.last_name, v.first_name
		LIMIT $3 OFFSET $4
	`
	rows, err := s.pool.Query(ctx, query, turfID, companyID, limit, offset)
	if err != nil {
		return nil, 0, fmt.Errorf("query voters in turf: %w", err)
	}
	defer rows.Close()

	var voters []VoterPin
	for rows.Next() {
		var v VoterPin
		if err := rows.Scan(&v.ID, &v.FirstName, &v.LastName, &v.Party, &v.Status, &v.Lat, &v.Lng); err != nil {
			return nil, 0, fmt.Errorf("scan voter pin: %w", err)
		}
		voters = append(voters, v)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("rows error: %w", err)
	}

	// Count total
	countQuery := `
		SELECT COUNT(*) FROM voters v
		JOIN turfs t ON t.id = $1
		WHERE v.company_id = $2
		  AND v.location IS NOT NULL
		  AND v.geocode_status = 'success'
		  AND ST_Contains(t.boundary, v.location)
	`
	var total int64
	if err := s.pool.QueryRow(ctx, countQuery, turfID, companyID).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count voters in turf: %w", err)
	}

	return voters, total, nil
}

// GetAllVotersInTurf returns all geocoded voters in a turf (no pagination) with address for walk list.
func (s *TurfStatsService) GetAllVotersInTurf(ctx context.Context, companyID, turfID uuid.UUID) ([]VoterLocation, error) {
	query := `
		SELECT v.id, v.first_name, v.last_name, v.res_street_address,
		       ST_Y(v.location) as lat, ST_X(v.location) as lng
		FROM voters v
		JOIN turfs t ON t.id = $1
		WHERE v.company_id = $2
		  AND v.location IS NOT NULL
		  AND v.geocode_status = 'success'
		  AND ST_Contains(t.boundary, v.location)
		ORDER BY v.last_name, v.first_name
	`
	rows, err := s.pool.Query(ctx, query, turfID, companyID)
	if err != nil {
		return nil, fmt.Errorf("query all voters in turf: %w", err)
	}
	defer rows.Close()

	var voters []VoterLocation
	for rows.Next() {
		var v VoterLocation
		if err := rows.Scan(&v.ID, &v.FirstName, &v.LastName, &v.Address, &v.Lat, &v.Lng); err != nil {
			return nil, fmt.Errorf("scan voter location: %w", err)
		}
		voters = append(voters, v)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}

	return voters, nil
}

// TurfCompletionStats holds turf completion statistics.
type TurfCompletionStats struct {
	TotalVoters     int64
	ContactedVoters int64
}

// GetTurfCompletionStats returns voter count and contacted count for a turf.
func (s *TurfStatsService) GetTurfCompletionStats(ctx context.Context, companyID, turfID uuid.UUID) (*TurfCompletionStats, error) {
	row, err := s.queries.GetTurfCompletionStats(ctx, db.GetTurfCompletionStatsParams{
		TurfID:    turfID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("get turf completion stats: %w", err)
	}

	return &TurfCompletionStats{
		TotalVoters:     row.TotalVoters,
		ContactedVoters: row.ContactedVoters,
	}, nil
}

// DensityGridCell holds aggregated voter density for a grid cell.
type DensityGridCell struct {
	GridLat        float64
	GridLng        float64
	VoterCount     int32
	ContactedCount int32
	SupportCount   int32
}

// GetVoterDensityGrid returns aggregated voter density grid cells for heat map rendering.
func (s *TurfStatsService) GetVoterDensityGrid(ctx context.Context, companyID uuid.UUID, minLat, minLng, maxLat, maxLng, gridSize float64) ([]DensityGridCell, error) {
	query := `
		SELECT
			ST_Y(ST_SnapToGrid(v.location, $3)) as grid_lat,
			ST_X(ST_SnapToGrid(v.location, $3)) as grid_lng,
			COUNT(*)::int as voter_count,
			COUNT(DISTINCT cl.voter_id)::int as contacted_count,
			COUNT(DISTINCT CASE WHEN cl.outcome = 'support' THEN cl.voter_id END)::int as support_count
		FROM voters v
		LEFT JOIN contact_logs cl ON cl.voter_id = v.id
		WHERE v.company_id = $1
		  AND v.location IS NOT NULL
		  AND v.geocode_status = 'success'
		  AND ST_Within(v.location, ST_MakeEnvelope($4, $5, $6, $7, 4326))
		GROUP BY grid_lat, grid_lng
		ORDER BY grid_lat, grid_lng
	`
	rows, err := s.pool.Query(ctx, query, companyID, companyID, gridSize, minLng, minLat, maxLng, maxLat)
	if err != nil {
		return nil, fmt.Errorf("query density grid: %w", err)
	}
	defer rows.Close()

	var cells []DensityGridCell
	for rows.Next() {
		var c DensityGridCell
		if err := rows.Scan(&c.GridLat, &c.GridLng, &c.VoterCount, &c.ContactedCount, &c.SupportCount); err != nil {
			return nil, fmt.Errorf("scan density cell: %w", err)
		}
		cells = append(cells, c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("rows error: %w", err)
	}

	return cells, nil
}
