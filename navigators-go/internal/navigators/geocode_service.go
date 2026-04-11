package navigators

import (
	"bytes"
	"context"
	"encoding/csv"
	"fmt"
	"io"
	"log/slog"
	"mime/multipart"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"googlemaps.github.io/maps"

	"navigators-go/internal/db"
)

// AddressToGeocode represents an address that needs geocoding.
type AddressToGeocode struct {
	VoterID uuid.UUID
	Street  string
	City    string
	State   string
	Zip     string
}

// GeocodeResult holds a successful geocoding result.
type GeocodeResult struct {
	VoterID   uuid.UUID
	Longitude float64 // X coordinate (Census returns lon,lat)
	Latitude  float64 // Y coordinate
	Source    string  // "census" or "google"
}

// GeocodeService provides geocoding of voter addresses using Census batch API
// with Google Maps fallback.
type GeocodeService struct {
	pool           *pgxpool.Pool
	queries        *db.Queries
	googleClient   *maps.Client
	censusBaseURL  string
	maxGoogleCost  int // max Google geocodes per ProcessUngeocoded call
}

// NewGeocodeService creates a new GeocodeService.
// If googleAPIKey is empty, Google fallback is disabled.
func NewGeocodeService(queries *db.Queries, pool *pgxpool.Pool, googleAPIKey string) *GeocodeService {
	gs := &GeocodeService{
		pool:          pool,
		queries:       queries,
		censusBaseURL: "https://geocoding.geo.census.gov/geocoder/locations/addressbatch",
		maxGoogleCost: 500, // cost ceiling per run
	}

	if googleAPIKey != "" {
		client, err := maps.NewClient(maps.WithAPIKey(googleAPIKey), maps.WithRateLimit(50))
		if err != nil {
			slog.Warn("failed to create Google Maps client, fallback disabled", "error", err)
		} else {
			gs.googleClient = client
			slog.Info("Google Maps geocoding fallback enabled")
		}
	} else {
		slog.Warn("GOOGLE_MAPS_API_KEY not set, Google geocoding fallback disabled")
	}

	return gs
}

// BatchGeocodeWithCensus sends a batch of addresses to the Census Geocoder API.
// Returns matched results and unmatched addresses.
// CRITICAL: Census coords are lon,lat (longitude first). Do NOT swap.
func (g *GeocodeService) BatchGeocodeWithCensus(ctx context.Context, addresses []AddressToGeocode) ([]GeocodeResult, []AddressToGeocode, error) {
	if len(addresses) == 0 {
		return nil, nil, nil
	}

	// Build CSV content: UniqueID,Street,City,State,ZIP
	var csvBuf bytes.Buffer
	for _, addr := range addresses {
		// Escape commas in address fields by quoting
		line := fmt.Sprintf("%s,%s,%s,%s,%s\n",
			addr.VoterID.String(),
			addr.Street,
			addr.City,
			addr.State,
			addr.Zip,
		)
		csvBuf.WriteString(line)
	}

	// Build multipart form
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)

	part, err := writer.CreateFormFile("addressFile", "addresses.csv")
	if err != nil {
		return nil, nil, fmt.Errorf("create form file: %w", err)
	}
	if _, err := part.Write(csvBuf.Bytes()); err != nil {
		return nil, nil, fmt.Errorf("write csv data: %w", err)
	}

	if err := writer.WriteField("benchmark", "Public_AR_Current"); err != nil {
		return nil, nil, fmt.Errorf("write benchmark field: %w", err)
	}
	if err := writer.WriteField("returntype", "locations"); err != nil {
		return nil, nil, fmt.Errorf("write returntype field: %w", err)
	}
	if err := writer.Close(); err != nil {
		return nil, nil, fmt.Errorf("close multipart writer: %w", err)
	}

	// POST to Census API
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, g.censusBaseURL, &body)
	if err != nil {
		return nil, nil, fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	client := &http.Client{Timeout: 5 * time.Minute}
	resp, err := client.Do(req)
	if err != nil {
		return nil, nil, fmt.Errorf("census API request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, nil, fmt.Errorf("census API returned status %d", resp.StatusCode)
	}

	// Parse CSV response
	// Format: UniqueID, InputAddress, Match, MatchType, MatchedAddress, Coordinates, TigerLineID, Side
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, nil, fmt.Errorf("read response: %w", err)
	}

	// Build lookup map for unmatched
	addrMap := make(map[string]AddressToGeocode, len(addresses))
	for _, addr := range addresses {
		addrMap[addr.VoterID.String()] = addr
	}

	var matched []GeocodeResult
	var unmatched []AddressToGeocode
	matchedIDs := make(map[string]bool)

	reader := csv.NewReader(bytes.NewReader(respBody))
	reader.FieldsPerRecord = -1 // variable fields
	reader.LazyQuotes = true

	for {
		record, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			slog.Warn("census CSV parse error", "error", err)
			continue
		}

		if len(record) < 3 {
			continue
		}

		voterIDStr := strings.TrimSpace(strings.Trim(record[0], "\""))
		matchStatus := strings.TrimSpace(record[2])

		voterID, parseErr := uuid.Parse(voterIDStr)
		if parseErr != nil {
			slog.Warn("invalid voter ID in census response", "id", voterIDStr)
			continue
		}

		if matchStatus == "Match" && len(record) >= 6 {
			coords := strings.TrimSpace(strings.Trim(record[5], "\""))
			parts := strings.Split(coords, ",")
			if len(parts) == 2 {
				// CRITICAL: Census returns lon,lat (longitude first)
				lon, err1 := strconv.ParseFloat(strings.TrimSpace(parts[0]), 64)
				lat, err2 := strconv.ParseFloat(strings.TrimSpace(parts[1]), 64)
				if err1 == nil && err2 == nil {
					matched = append(matched, GeocodeResult{
						VoterID:   voterID,
						Longitude: lon,
						Latitude:  lat,
						Source:    "census",
					})
					matchedIDs[voterIDStr] = true
					continue
				}
			}
		}

		// No match or parse failure
		if addr, ok := addrMap[voterIDStr]; ok {
			unmatched = append(unmatched, addr)
			matchedIDs[voterIDStr] = true // mark as processed
		}
	}

	// Any address not in the response at all is also unmatched
	for _, addr := range addresses {
		if !matchedIDs[addr.VoterID.String()] {
			unmatched = append(unmatched, addr)
		}
	}

	return matched, unmatched, nil
}

// GeocodeWithGoogle geocodes a single address using Google Maps API.
func (g *GeocodeService) GeocodeWithGoogle(ctx context.Context, addr AddressToGeocode) (*GeocodeResult, error) {
	if g.googleClient == nil {
		return nil, fmt.Errorf("Google Maps client not configured")
	}

	fullAddr := fmt.Sprintf("%s, %s, %s %s", addr.Street, addr.City, addr.State, addr.Zip)

	results, err := g.googleClient.Geocode(ctx, &maps.GeocodingRequest{
		Address: fullAddr,
	})
	if err != nil {
		return nil, fmt.Errorf("google geocode: %w", err)
	}

	if len(results) == 0 {
		return nil, fmt.Errorf("no results from Google for address: %s", fullAddr)
	}

	loc := results[0].Geometry.Location
	return &GeocodeResult{
		VoterID:   addr.VoterID,
		Longitude: loc.Lng,
		Latitude:  loc.Lat,
		Source:    "google",
	}, nil
}

// ProcessUngeocoded geocodes all pending voters for a company.
// Processes in 10K batches with 5s delays between Census API calls.
// Uses context.Background() for background processing -- not tied to request lifecycle.
func (g *GeocodeService) ProcessUngeocoded(ctx context.Context, companyID uuid.UUID) {
	logger := slog.With("company_id", companyID, "operation", "geocode")
	logger.Info("starting geocoding pass")

	batchSize := int32(10000)
	totalMatched := 0
	totalFailed := 0
	googleUsed := 0

	for {
		select {
		case <-ctx.Done():
			logger.Info("geocoding cancelled", "matched", totalMatched, "failed", totalFailed)
			return
		default:
		}

		// Fetch ungeocoded voters
		rows, err := g.queries.GetUngeocoded(ctx, db.GetUngeocodedParams{
			CompanyID: companyID,
			Limit:     batchSize,
		})
		if err != nil {
			logger.Error("failed to get ungeocoded voters", "error", err)
			return
		}

		if len(rows) == 0 {
			logger.Info("geocoding complete", "matched", totalMatched, "failed", totalFailed, "google_used", googleUsed)
			return
		}

		logger.Info("processing batch", "size", len(rows))

		// Convert to AddressToGeocode
		addresses := make([]AddressToGeocode, len(rows))
		for i, r := range rows {
			addresses[i] = AddressToGeocode{
				VoterID: r.ID,
				Street:  r.ResStreetAddress,
				City:    r.ResCity,
				State:   r.ResState,
				Zip:     r.ResZip,
			}
		}

		// Census batch geocode with retry (3 attempts, exponential backoff)
		var matched []GeocodeResult
		var unmatched []AddressToGeocode
		var censusErr error

		for attempt := 0; attempt < 3; attempt++ {
			matched, unmatched, censusErr = g.BatchGeocodeWithCensus(ctx, addresses)
			if censusErr == nil {
				break
			}
			backoff := time.Duration(5*(1<<attempt)) * time.Second // 5s, 10s, 20s
			logger.Warn("census batch failed, retrying", "attempt", attempt+1, "backoff", backoff, "error", censusErr)
			select {
			case <-time.After(backoff):
			case <-ctx.Done():
				return
			}
		}

		if censusErr != nil {
			// All retries failed -- mark all as failed and queue for Google
			logger.Error("census batch failed after retries", "error", censusErr)
			unmatched = addresses
			matched = nil
		}

		// Update matched voters in DB
		for _, m := range matched {
			if err := g.queries.UpdateVoterGeocode(ctx, db.UpdateVoterGeocodeParams{
				ID:             m.VoterID,
				Longitude:      m.Longitude,
				Latitude:       m.Latitude,
				GeocodeStatus:  "success",
				GeocodeSource:  m.Source,
			}); err != nil {
				logger.Error("failed to update geocode", "voter_id", m.VoterID, "error", err)
			} else {
				totalMatched++
			}
		}

		// Google fallback for unmatched (with cost ceiling)
		for _, addr := range unmatched {
			if g.googleClient == nil {
				// No Google client -- mark as failed
				_ = g.queries.UpdateVoterGeocodeFailure(ctx, db.UpdateVoterGeocodeFailureParams{
					ID:            addr.VoterID,
					GeocodeSource: "none",
				})
				totalFailed++
				continue
			}

			if googleUsed >= g.maxGoogleCost {
				logger.Warn("Google geocoding cost ceiling reached", "limit", g.maxGoogleCost)
				_ = g.queries.UpdateVoterGeocodeFailure(ctx, db.UpdateVoterGeocodeFailureParams{
					ID:            addr.VoterID,
					GeocodeSource: "cost_limit",
				})
				totalFailed++
				continue
			}

			result, err := g.GeocodeWithGoogle(ctx, addr)
			if err != nil {
				logger.Warn("google geocode failed", "voter_id", addr.VoterID, "error", err)
				_ = g.queries.UpdateVoterGeocodeFailure(ctx, db.UpdateVoterGeocodeFailureParams{
					ID:            addr.VoterID,
					GeocodeSource: "google",
				})
				totalFailed++
			} else {
				if err := g.queries.UpdateVoterGeocode(ctx, db.UpdateVoterGeocodeParams{
					ID:             result.VoterID,
					Longitude:      result.Longitude,
					Latitude:       result.Latitude,
					GeocodeStatus:  "success",
					GeocodeSource:  result.Source,
				}); err != nil {
					logger.Error("failed to update google geocode", "voter_id", result.VoterID, "error", err)
				} else {
					totalMatched++
				}
			}
			googleUsed++
		}

		// 5-second delay between Census batches
		logger.Info("batch complete, waiting before next batch",
			"batch_matched", len(matched), "batch_unmatched", len(unmatched))
		select {
		case <-time.After(5 * time.Second):
		case <-ctx.Done():
			return
		}
	}
}

// QueueGeocoding starts geocoding in a background goroutine.
// Uses context.Background() so it's not tied to the request lifecycle.
func (g *GeocodeService) QueueGeocoding(companyID uuid.UUID) {
	go g.ProcessUngeocoded(context.Background(), companyID)
}
