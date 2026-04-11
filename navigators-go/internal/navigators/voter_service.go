package navigators

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/aocybersystems/eden-platform-go/platform/server"

	"navigators-go/internal/db"
)

// VoterService provides voter search, filter, and lookup operations.
// All queries are scoped through TurfScopedFilter and audit-logged.
type VoterService struct {
	queries      *db.Queries
	pool         *pgxpool.Pool
	turfFilter   *TurfScopedFilter
	auditService *AuditService
}

// NewVoterService creates a new VoterService.
func NewVoterService(queries *db.Queries, pool *pgxpool.Pool, turfFilter *TurfScopedFilter, auditService *AuditService) *VoterService {
	return &VoterService{
		queries:      queries,
		pool:         pool,
		turfFilter:   turfFilter,
		auditService: auditService,
	}
}

// GetVoter returns a single voter by ID, scoped to the user's turfs.
func (s *VoterService) GetVoter(ctx context.Context, voterID uuid.UUID) (*db.Voter, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("parse company ID: %w", err)
	}

	// Get voter ensuring it belongs to the company
	voter, err := s.queries.GetVoterByCompany(ctx, db.GetVoterByCompanyParams{
		ID:        voterID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("get voter: %w", err)
	}

	// Check turf scope
	scope, err := s.turfFilter.ResolveScope(ctx)
	if err != nil {
		return nil, fmt.Errorf("resolve scope: %w", err)
	}

	if scope.Type != ScopeAll && len(scope.TurfIDs) > 0 {
		// For ScopeTeam/ScopeOwn: verify voter's location falls within user's turfs
		// If voter has no location (not geocoded yet), allow access
		if voter.Location != nil {
			inScope, err := s.isVoterInTurfs(ctx, voterID, scope.TurfIDs)
			if err != nil {
				return nil, fmt.Errorf("check voter turf scope: %w", err)
			}
			if !inScope {
				return nil, fmt.Errorf("voter not in assigned turfs")
			}
		}
	} else if scope.Type != ScopeAll && len(scope.TurfIDs) == 0 {
		// No turfs assigned -- cannot access any voters
		return nil, fmt.Errorf("no turfs assigned")
	}

	// Log audit access
	if err := s.auditService.LogVoterAccess(ctx, voterID.String(), "view", nil, nil); err != nil {
		slog.Warn("failed to log voter access audit", "error", err)
	}

	return &voter, nil
}

// SearchVoters performs fuzzy text search on voters, scoped to user's turfs.
func (s *VoterService) SearchVoters(ctx context.Context, query string, limit, offset int32) ([]db.SearchVotersRow, int64, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, 0, fmt.Errorf("no claims in context")
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, 0, fmt.Errorf("parse company ID: %w", err)
	}

	scope, err := s.turfFilter.ResolveScope(ctx)
	if err != nil {
		return nil, 0, fmt.Errorf("resolve scope: %w", err)
	}

	var results []db.SearchVotersRow
	var totalCount int64

	switch scope.Type {
	case ScopeAll:
		results, err = s.queries.SearchVoters(ctx, db.SearchVotersParams{
			Query:     query,
			CompanyID: companyID,
			Lim:       limit,
			Off:       offset,
		})
		if err != nil {
			return nil, 0, fmt.Errorf("search voters: %w", err)
		}
		totalCount, err = s.queries.CountSearchVoters(ctx, db.CountSearchVotersParams{
			Query:     query,
			CompanyID: companyID,
		})
		if err != nil {
			return nil, 0, fmt.Errorf("count search voters: %w", err)
		}

	case ScopeTeam, ScopeOwn:
		if len(scope.TurfIDs) == 0 {
			return []db.SearchVotersRow{}, 0, nil
		}
		results, totalCount, err = s.searchVotersInTurfs(ctx, query, companyID, scope.TurfIDs, limit, offset)
		if err != nil {
			return nil, 0, fmt.Errorf("search voters in turfs: %w", err)
		}
	}

	// Log audit
	if err := s.auditService.LogVoterAccess(ctx, "search", "search", nil, map[string]any{
		"query":        query,
		"result_count": len(results),
	}); err != nil {
		slog.Warn("failed to log search audit", "error", err)
	}

	return results, totalCount, nil
}

// VoterFilterParams holds the filter parameters for ListVoters.
type VoterFilterParams struct {
	Party                 *string
	VoterStatus           *string
	CongressionalDistrict *string
	StateSenateDistrict   *string
	StateHouseDistrict    *string
	Municipality          *string
	County                *string
	MinVoteCount          *int32
	BBox                  *BBox // optional bounding box
}

// BBox represents a geographic bounding box.
type BBox struct {
	MinLon float64
	MinLat float64
	MaxLon float64
	MaxLat float64
}

// ListVoters returns a filtered, paginated list of voters, scoped to user's turfs.
func (s *VoterService) ListVoters(ctx context.Context, filters VoterFilterParams, limit, offset int32) ([]db.ListVotersByFiltersRow, int64, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, 0, fmt.Errorf("no claims in context")
	}

	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, 0, fmt.Errorf("parse company ID: %w", err)
	}

	scope, err := s.turfFilter.ResolveScope(ctx)
	if err != nil {
		return nil, 0, fmt.Errorf("resolve scope: %w", err)
	}

	var results []db.ListVotersByFiltersRow
	var totalCount int64

	// If bbox filter is provided, use raw spatial query
	if filters.BBox != nil {
		results, totalCount, err = s.listVotersInBBox(ctx, companyID, scope, filters, limit, offset)
		if err != nil {
			return nil, 0, fmt.Errorf("list voters in bbox: %w", err)
		}
	} else {
		switch scope.Type {
		case ScopeAll:
			results, err = s.queries.ListVotersByFilters(ctx, db.ListVotersByFiltersParams{
				CompanyID:             companyID,
				Party:                 filters.Party,
				VoterStatus:           filters.VoterStatus,
				CongressionalDistrict: filters.CongressionalDistrict,
				StateSenateDistrict:   filters.StateSenateDistrict,
				StateHouseDistrict:    filters.StateHouseDistrict,
				Municipality:          filters.Municipality,
				County:                filters.County,
				MinVoteCount:          filters.MinVoteCount,
				Lim:                   limit,
				Off:                   offset,
			})
			if err != nil {
				return nil, 0, fmt.Errorf("list voters: %w", err)
			}
			totalCount, err = s.queries.CountVotersByFilters(ctx, db.CountVotersByFiltersParams{
				CompanyID:             companyID,
				Party:                 filters.Party,
				VoterStatus:           filters.VoterStatus,
				CongressionalDistrict: filters.CongressionalDistrict,
				StateSenateDistrict:   filters.StateSenateDistrict,
				StateHouseDistrict:    filters.StateHouseDistrict,
				Municipality:          filters.Municipality,
				County:                filters.County,
				MinVoteCount:          filters.MinVoteCount,
			})
			if err != nil {
				return nil, 0, fmt.Errorf("count voters: %w", err)
			}

		case ScopeTeam, ScopeOwn:
			if len(scope.TurfIDs) == 0 {
				return []db.ListVotersByFiltersRow{}, 0, nil
			}
			results, totalCount, err = s.listVotersInTurfs(ctx, companyID, scope.TurfIDs, filters, limit, offset)
			if err != nil {
				return nil, 0, fmt.Errorf("list voters in turfs: %w", err)
			}
		}
	}

	// Log audit
	if err := s.auditService.LogVoterAccess(ctx, "list", "search", nil, map[string]any{
		"result_count": len(results),
		"has_bbox":     filters.BBox != nil,
	}); err != nil {
		slog.Warn("failed to log list audit", "error", err)
	}

	return results, totalCount, nil
}

// isVoterInTurfs checks if a voter's location falls within any of the given turfs.
func (s *VoterService) isVoterInTurfs(ctx context.Context, voterID uuid.UUID, turfIDs []uuid.UUID) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1 FROM voters v
			JOIN turfs t ON t.id = ANY($2) AND t.is_active = true
			WHERE v.id = $1
			  AND v.location IS NOT NULL
			  AND ST_Within(v.location, t.boundary)
		)
	`
	var exists bool
	err := s.pool.QueryRow(ctx, query, voterID, turfIDs).Scan(&exists)
	return exists, err
}

// searchVotersInTurfs performs fuzzy search scoped to turf boundaries.
func (s *VoterService) searchVotersInTurfs(ctx context.Context, queryStr string, companyID uuid.UUID, turfIDs []uuid.UUID, limit, offset int32) ([]db.SearchVotersRow, int64, error) {
	query := `
		SELECT v.id, v.first_name, v.last_name, v.party, v.status,
		       v.res_city, v.res_zip, v.municipality, v.year_of_birth,
		       similarity(v.search_text, $1) AS score
		FROM voters v
		JOIN turfs t ON t.id = ANY($3) AND t.is_active = true
		WHERE v.company_id = $2
		  AND v.search_text % $1
		  AND v.location IS NOT NULL
		  AND ST_Within(v.location, t.boundary)
		ORDER BY similarity(v.search_text, $1) DESC
		LIMIT $4 OFFSET $5
	`
	rows, err := s.pool.Query(ctx, query, queryStr, companyID, turfIDs, limit, offset)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var results []db.SearchVotersRow
	for rows.Next() {
		var r db.SearchVotersRow
		if err := rows.Scan(&r.ID, &r.FirstName, &r.LastName, &r.Party, &r.Status,
			&r.ResCity, &r.ResZip, &r.Municipality, &r.YearOfBirth, &r.Score); err != nil {
			return nil, 0, err
		}
		results = append(results, r)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}

	// Count query
	countQuery := `
		SELECT COUNT(DISTINCT v.id) FROM voters v
		JOIN turfs t ON t.id = ANY($3) AND t.is_active = true
		WHERE v.company_id = $2
		  AND v.search_text % $1
		  AND v.location IS NOT NULL
		  AND ST_Within(v.location, t.boundary)
	`
	var count int64
	if err := s.pool.QueryRow(ctx, countQuery, queryStr, companyID, turfIDs).Scan(&count); err != nil {
		return nil, 0, err
	}

	return results, count, nil
}

// listVotersInTurfs returns filtered voters within turf boundaries.
func (s *VoterService) listVotersInTurfs(ctx context.Context, companyID uuid.UUID, turfIDs []uuid.UUID, filters VoterFilterParams, limit, offset int32) ([]db.ListVotersByFiltersRow, int64, error) {
	query := `
		SELECT v.id, v.first_name, v.last_name, v.party, v.status,
		       v.res_city, v.res_zip, v.municipality, v.year_of_birth
		FROM voters v
		JOIN turfs t ON t.id = ANY($1) AND t.is_active = true
		WHERE v.company_id = $2
		  AND v.location IS NOT NULL
		  AND ST_Within(v.location, t.boundary)
		  AND ($3::text IS NULL OR v.party = $3)
		  AND ($4::text IS NULL OR v.status = $4)
		  AND ($5::text IS NULL OR v.congressional_district = $5)
		  AND ($6::text IS NULL OR v.state_senate_district = $6)
		  AND ($7::text IS NULL OR v.state_house_district = $7)
		  AND ($8::text IS NULL OR v.municipality = $8)
		  AND ($9::text IS NULL OR v.county = $9)
		  AND ($10::int IS NULL OR jsonb_array_length(v.voting_history) >= $10)
		ORDER BY v.last_name, v.first_name
		LIMIT $11 OFFSET $12
	`
	rows, err := s.pool.Query(ctx, query,
		turfIDs, companyID,
		filters.Party, filters.VoterStatus,
		filters.CongressionalDistrict, filters.StateSenateDistrict,
		filters.StateHouseDistrict, filters.Municipality,
		filters.County, filters.MinVoteCount,
		limit, offset,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var results []db.ListVotersByFiltersRow
	for rows.Next() {
		var r db.ListVotersByFiltersRow
		if err := rows.Scan(&r.ID, &r.FirstName, &r.LastName, &r.Party, &r.Status,
			&r.ResCity, &r.ResZip, &r.Municipality, &r.YearOfBirth); err != nil {
			return nil, 0, err
		}
		results = append(results, r)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}

	// Count
	countQuery := `
		SELECT COUNT(DISTINCT v.id) FROM voters v
		JOIN turfs t ON t.id = ANY($1) AND t.is_active = true
		WHERE v.company_id = $2
		  AND v.location IS NOT NULL
		  AND ST_Within(v.location, t.boundary)
		  AND ($3::text IS NULL OR v.party = $3)
		  AND ($4::text IS NULL OR v.status = $4)
		  AND ($5::text IS NULL OR v.congressional_district = $5)
		  AND ($6::text IS NULL OR v.state_senate_district = $6)
		  AND ($7::text IS NULL OR v.state_house_district = $7)
		  AND ($8::text IS NULL OR v.municipality = $8)
		  AND ($9::text IS NULL OR v.county = $9)
		  AND ($10::int IS NULL OR jsonb_array_length(v.voting_history) >= $10)
	`
	var count int64
	if err := s.pool.QueryRow(ctx, countQuery,
		turfIDs, companyID,
		filters.Party, filters.VoterStatus,
		filters.CongressionalDistrict, filters.StateSenateDistrict,
		filters.StateHouseDistrict, filters.Municipality,
		filters.County, filters.MinVoteCount,
	).Scan(&count); err != nil {
		return nil, 0, err
	}

	return results, count, nil
}

// listVotersInBBox returns filtered voters within a bounding box.
func (s *VoterService) listVotersInBBox(ctx context.Context, companyID uuid.UUID, scope *TurfScope, filters VoterFilterParams, limit, offset int32) ([]db.ListVotersByFiltersRow, int64, error) {
	bbox := filters.BBox

	// Base query with bbox filter
	baseWhere := `
		v.company_id = $1
		AND v.location IS NOT NULL
		AND ST_Within(v.location, ST_MakeEnvelope($2, $3, $4, $5, 4326))
		AND ($6::text IS NULL OR v.party = $6)
		AND ($7::text IS NULL OR v.status = $7)
		AND ($8::text IS NULL OR v.congressional_district = $8)
		AND ($9::text IS NULL OR v.state_senate_district = $9)
		AND ($10::text IS NULL OR v.state_house_district = $10)
		AND ($11::text IS NULL OR v.municipality = $11)
		AND ($12::text IS NULL OR v.county = $12)
		AND ($13::int IS NULL OR jsonb_array_length(v.voting_history) >= $13)
	`

	args := []any{
		companyID,
		bbox.MinLon, bbox.MinLat, bbox.MaxLon, bbox.MaxLat,
		filters.Party, filters.VoterStatus,
		filters.CongressionalDistrict, filters.StateSenateDistrict,
		filters.StateHouseDistrict, filters.Municipality,
		filters.County, filters.MinVoteCount,
	}

	// Add turf scope if needed
	var turfJoin string
	if scope.Type != ScopeAll && len(scope.TurfIDs) > 0 {
		turfJoin = fmt.Sprintf("JOIN turfs t ON t.id = ANY($%d) AND t.is_active = true AND ST_Within(v.location, t.boundary)", len(args)+1)
		args = append(args, scope.TurfIDs)
	} else if scope.Type != ScopeAll && len(scope.TurfIDs) == 0 {
		return []db.ListVotersByFiltersRow{}, 0, nil
	}

	query := fmt.Sprintf(`
		SELECT v.id, v.first_name, v.last_name, v.party, v.status,
		       v.res_city, v.res_zip, v.municipality, v.year_of_birth
		FROM voters v
		%s
		WHERE %s
		ORDER BY v.last_name, v.first_name
		LIMIT $%d OFFSET $%d
	`, turfJoin, baseWhere, len(args)+1, len(args)+2)
	args = append(args, limit, offset)

	rows, err := s.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var results []db.ListVotersByFiltersRow
	for rows.Next() {
		var r db.ListVotersByFiltersRow
		if err := rows.Scan(&r.ID, &r.FirstName, &r.LastName, &r.Party, &r.Status,
			&r.ResCity, &r.ResZip, &r.Municipality, &r.YearOfBirth); err != nil {
			return nil, 0, err
		}
		results = append(results, r)
	}
	if err := rows.Err(); err != nil {
		return nil, 0, err
	}

	// Count - reuse same args minus limit/offset
	countArgs := args[:len(args)-2]
	countQuery := fmt.Sprintf(`
		SELECT COUNT(DISTINCT v.id) FROM voters v
		%s
		WHERE %s
	`, turfJoin, baseWhere)
	var count int64
	if err := s.pool.QueryRow(ctx, countQuery, countArgs...).Scan(&count); err != nil {
		return nil, 0, err
	}

	return results, count, nil
}
