# Objective 2: Voter Data Pipeline - Research

**Researched:** 2026-04-10
**Domain:** Voter data import, geocoding, search, PostgreSQL bulk operations
**Confidence:** HIGH

## Summary

The Voter Data Pipeline objective requires building a complete voter data lifecycle: admin file upload, parsing two file formats (Maine CVR pipe-delimited and L2 vendor CSV), deduplication/merge, batch geocoding via Census API with Google fallback, full-text search and filtering, voter profiles, tagging, and a suppression list. The existing codebase already has PostGIS, turf-scoped data filtering (`TurfScopedFilter`), voter access audit logging (`AuditService`), and an empty `VoterService` proto stub ready for implementation.

The architecture follows the established modular monolith pattern: sqlc queries, ConnectRPC handlers with service layer separation, pgx/v5 for database access. File uploads use eden's MinIO-backed `upload.Service` with presigned URLs. The key technical challenges are (1) parsing pipe-delimited CVR files with an underdocumented field layout, (2) efficient bulk loading via pgx `CopyFrom` into staging tables with UPSERT merge, (3) batch geocoding 10K records at a time via Census API, and (4) fast fuzzy search using pg_trgm GIN indexes.

**Primary recommendation:** Use a staging table pattern -- COPY raw data into a temp staging table, validate/normalize, then INSERT ... ON CONFLICT to merge into the production voters table. Geocode asynchronously in background batches after import completes.

<phase_requirements>
## Objective Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| VOTER-01 | Admin can upload Maine CVR pipe-delimited voter files | CVR format research (pipe-delimited, field layout from CVR Data Request Form), eden upload.Service for MinIO presigned URLs, pgx CopyFrom for bulk staging |
| VOTER-02 | Admin can upload L2/vendor CSV voter files | L2 tab-delimited format with VM2 dataset structure, configurable field mapping, same staging pipeline |
| VOTER-03 | System merges/deduplicates voters across sources | Staging table + INSERT ON CONFLICT pattern, composite dedup key (normalized last_name + street_number + street_name + zip + yob) |
| VOTER-04 | System batch geocodes using Census API (primary) + Google (overflow) | Census Geocoder batch endpoint (10K/batch), googlemaps/google-maps-services-go for fallback, async background worker |
| VOTER-05 | User can view full voter profile | Data model with all permitted fields per Maine 21-A s196-A, turf-scoped access via TurfScopedFilter, audit logging via AuditService |
| VOTER-06 | User can search voters by name, address, or voter ID | pg_trgm GIN indexes for fuzzy name/address search, B-tree index on voter_id for exact lookup |
| VOTER-07 | User can filter voters by district, party, voting frequency, status, geography, custom tags | Composite indexes on filter columns, PostGIS ST_Within for geography filtering, JSONB voting_history for frequency calculation |
| VOTER-08 | Admin can create and manage voter tags | voter_tags and voter_tag_assignments tables, simple CRUD |
| VOTER-09 | System maintains global suppression list | suppression_list table keyed on voter_id, checked before any outreach operation |
| VOTER-10 | No prohibited data fields stored | Schema enforces: no SSN column, no full DOB (only year_of_birth INT), no felony/criminal fields, no driver's license |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| pgx/v5 | 5.9.1 | PostgreSQL driver + CopyFrom bulk loading | Already in go.mod, CopyFrom uses COPY protocol for 10-100x faster bulk inserts |
| sqlc | 1.30.0 | Type-safe SQL query generation | Already used throughout codebase |
| connectrpc/connect | 1.19.1 | RPC framework | Already used for all handlers |
| minio-go/v7 | (eden dep) | File upload storage | Already available via eden upload.Service |
| googlemaps/google-maps-services-go | latest | Google Maps geocoding fallback | Official Go client with built-in rate limiting |
| pg_trgm | (PostgreSQL ext) | Trigram-based fuzzy text search | Standard PostgreSQL extension for name/address search |
| PostGIS | (already installed) | Spatial queries and geocoded point storage | Already enabled in migration 001 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| encoding/csv | stdlib | Parse L2 CSV/TSV files | L2 file import |
| bufio | stdlib | Line-by-line pipe-delimited file parsing | Maine CVR file import |
| net/http | stdlib | Census Geocoder batch API calls | Geocoding (no Go client library exists) |
| mime/multipart | stdlib | Census batch file upload | Geocoding batch submission |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| pg_trgm for search | Elasticsearch/Meilisearch | External service adds complexity; pg_trgm handles 1M voters fine at this scale |
| pgx CopyFrom | batch INSERT VALUES | CopyFrom is 10-100x faster for >1000 rows; batch INSERT caps around 1000 params |
| Census Geocoder | Google-only geocoding | Census is free and handles 85-90%; Google at $5/1000 reqs would cost $5K for 1M voters |

**Installation:**
```bash
go get googlemaps.github.io/maps
# pg_trgm extension added via migration:
# CREATE EXTENSION IF NOT EXISTS pg_trgm;
```

## Architecture Patterns

### Recommended Project Structure
```
navigators-go/
├── internal/navigators/
│   ├── voter_handler.go         # ConnectRPC handler (thin, delegates to services)
│   ├── voter_service.go         # Business logic: search, filter, profile
│   ├── import_handler.go        # ConnectRPC handler for file upload + import trigger
│   ├── import_service.go        # Import orchestration: parse, stage, merge, geocode
│   ├── geocode_service.go       # Census batch + Google fallback geocoding
│   ├── tag_service.go           # Voter tag CRUD
│   ├── suppression_service.go   # Suppression list management
│   ├── turf_scope.go            # (existing) TurfScopedFilter
│   └── audit_service.go         # (existing) AuditService
├── queries/navigators/
│   ├── voters.sql               # Voter CRUD, search, filter queries
│   ├── imports.sql              # Import job tracking queries
│   ├── tags.sql                 # Tag management queries
│   └── suppression.sql          # Suppression list queries
├── migrations/navigators/
│   ├── 005_voters.up.sql        # voters table, indexes, pg_trgm
│   ├── 006_import_jobs.up.sql   # import_jobs, import_staging tables
│   ├── 007_tags.up.sql          # voter_tags, voter_tag_assignments
│   └── 008_suppression.up.sql   # suppression_list table
└── proto/navigators/v1/
    └── voter.proto              # VoterService RPCs (currently empty stub)
```

### Pattern 1: Staging Table Import Pipeline
**What:** Upload file to MinIO -> parse file -> COPY into staging table -> validate -> INSERT ON CONFLICT into production voters table -> report results
**When to use:** Every voter file import (both CVR and L2)
**Example:**
```go
// 1. Parse file into rows (format-specific parser)
rows, parseErrors := parser.Parse(reader) // returns []VoterRow, []ParseError

// 2. CopyFrom into staging table
_, err := pool.CopyFrom(ctx,
    pgx.Identifier{"import_staging"},
    []string{"import_job_id", "line_number", "first_name", "last_name", "street_address", "city", "state", "zip", "year_of_birth", "party", "voter_id_source", "raw_line"},
    pgx.CopyFromRows(stagingRows),
)

// 3. Merge into production with dedup
_, err = pool.Exec(ctx, `
    INSERT INTO voters (company_id, first_name, last_name, ...)
    SELECT $1, s.first_name, s.last_name, ...
    FROM import_staging s
    WHERE s.import_job_id = $2 AND s.is_valid = true
    ON CONFLICT (company_id, dedup_key)
    DO UPDATE SET
        party = EXCLUDED.party,
        voter_status = EXCLUDED.voter_status,
        updated_at = now(),
        source = EXCLUDED.source
    RETURNING id
`)
```

### Pattern 2: Async Background Geocoding
**What:** After import, queue geocoding as background job. Process in batches of 10K (Census limit). Failed addresses go to Google fallback queue.
**When to use:** After every import that adds/updates addresses
**Example:**
```go
// Census Geocoder batch API - multipart form upload
func (g *GeocodeService) BatchGeocodeWithCensus(ctx context.Context, addresses []Address) ([]GeocodeResult, []Address) {
    // Format CSV: UniqueID, Street, City, State, ZIP
    var buf bytes.Buffer
    for _, addr := range addresses {
        fmt.Fprintf(&buf, "%s,%s,%s,%s,%s\n",
            addr.ID, addr.Street, addr.City, addr.State, addr.ZIP)
    }

    // POST to Census batch endpoint
    body := &bytes.Buffer{}
    writer := multipart.NewWriter(body)
    part, _ := writer.CreateFormFile("addressFile", "addresses.csv")
    io.Copy(part, &buf)
    writer.WriteField("benchmark", "Public_AR_Current")
    writer.WriteField("returntype", "locations")
    writer.Close()

    resp, err := http.Post(
        "https://geocoding.geo.census.gov/geocoder/locations/addressbatch",
        writer.FormDataContentType(), body)
    // Parse CSV response: ID, InputAddress, Match, MatchType, MatchedAddress, Coords, TigerLineID, Side
    // Coords format: "-70.12345,43.67890" (lon,lat)
}
```

### Pattern 3: Turf-Scoped Voter Queries
**What:** All voter queries filter through TurfScopedFilter to enforce RBAC
**When to use:** Every voter list, search, and profile view
**Example:**
```go
func (s *VoterService) SearchVoters(ctx context.Context, query string, filters VoterFilters) ([]Voter, error) {
    scope, err := s.turfFilter.ResolveScope(ctx)
    if err != nil {
        return nil, err
    }

    switch scope.Type {
    case ScopeAll:
        return s.queries.SearchVotersAll(ctx, query, filters)
    case ScopeTeam, ScopeOwn:
        // Filter voters whose geocoded point falls within assigned turf boundaries
        return s.queries.SearchVotersInTurfs(ctx, query, filters, scope.TurfIDs)
    }
}
```

### Anti-Patterns to Avoid
- **Loading entire file into memory:** Stream-parse line by line. CVR files can be 500MB+ for statewide data. Use `bufio.Scanner` with line-by-line processing.
- **Synchronous geocoding during import:** Geocoding 1M addresses takes hours. Always run async after import completes. Return import results immediately.
- **Single-row INSERTs in a loop:** Use pgx CopyFrom for staging. A 500K row import with individual INSERTs takes 30+ minutes; CopyFrom does it in seconds.
- **Storing full DOB:** Maine law permits only year of birth for party/campaign files. Never parse or store month/day even if present in source data.
- **Building dedup on full address string:** Normalize components separately (uppercase, strip apartment/unit suffixes, standardize abbreviations) for reliable matching.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| File upload + storage | Custom multipart upload handler | Eden `upload.Service` with MinIO presigned URLs | Handles presigned URLs, bucket creation, status tracking |
| Google geocoding client | Raw HTTP calls to Google | `googlemaps.github.io/maps` | Built-in rate limiting (50 QPS), retry, error handling |
| Fuzzy text search | Custom Levenshtein implementation | `pg_trgm` with GIN indexes | Database-level, index-backed, handles typos and partial matches |
| Spatial point-in-polygon | Custom geometry math | PostGIS `ST_Within` / `ST_Contains` | Battle-tested, uses spatial indexes (GIST), handles edge cases |
| Audit logging | Custom log tables | Existing `AuditService` | Already built, writes to both domain table and eden audit logger |
| Role-based data scoping | Custom permission checks | Existing `TurfScopedFilter` | Already resolves Admin/Team/Own scope from JWT claims |
| CSV parsing | Custom tokenizer | `encoding/csv` stdlib | Handles quoted fields, embedded commas, multiline values |

**Key insight:** The existing eden platform and Objective 1 deliverables already provide most infrastructure. The real work is the domain-specific pipeline: file parsing, field mapping, dedup logic, and geocoding orchestration.

## Common Pitfalls

### Pitfall 1: Maine CVR Field Layout Assumptions
**What goes wrong:** Assuming a specific field order without verifying against actual file. The CVR data request form does NOT document the exact pipe-delimited column layout.
**Why it happens:** The Maine SOS provides instructions for "importing CVR data to Excel" but not a formal schema document. Field order may change between exports.
**How to avoid:** Build a configurable field mapper. On first import, admin maps columns to system fields via UI or config. Alternatively, parse header row if present. Store field mapping per import source for reuse.
**Warning signs:** First import fails with data in wrong columns.

### Pitfall 2: Geocoding Rate Limits and Failures
**What goes wrong:** Census Geocoder returns timeouts or 500 errors on large batches. Google API costs spike unexpectedly.
**Why it happens:** Census Geocoder is free government service with no SLA. Processing 10K addresses takes 30-60 seconds. Service may be slow during peak hours.
**How to avoid:** Implement retry with exponential backoff for Census. Track geocoding costs for Google. Set a configurable ceiling for Google geocoding spend per import. Process Census batches sequentially (not parallel) to avoid overwhelming the service.
**Warning signs:** Census batch requests timing out, Google billing alerts.

### Pitfall 3: Deduplication False Positives/Negatives
**What goes wrong:** "JOHN SMITH" at "123 MAIN ST" matches wrong person, or "John A. Smith" at "123 Main Street" doesn't match existing "JOHN SMITH" at "123 MAIN ST".
**Why it happens:** Name variations (middle initials, suffixes), address format differences (St vs Street, Apt vs #).
**How to avoid:** Build a composite `dedup_key` from normalized components: `UPPER(last_name) || '|' || street_number || '|' || UPPER(normalized_street_name) || '|' || zip5 || '|' || year_of_birth`. This is intentionally conservative -- same last name, same street number, same zip, same birth year is almost certainly the same voter.
**Warning signs:** Duplicate voter records appearing in search results, voter count significantly exceeding expected registration numbers.

### Pitfall 4: Storing Prohibited Data Fields
**What goes wrong:** Importing SSN, full date of birth, driver's license number, or felony information from vendor files that include these fields.
**Why it happens:** L2 files contain 600+ fields including some that Maine law prohibits storing for party/campaign use.
**How to avoid:** Whitelist approach: only parse and store explicitly permitted fields. Log and discard any field that maps to a prohibited category. The migration schema should have NO columns for: ssn, date_of_birth (only year_of_birth), drivers_license, felony_status, criminal_history.
**Warning signs:** Full DOB appearing in voter profiles, any 9-digit numbers in imported data.

### Pitfall 5: Import Blocking the Main Server
**What goes wrong:** Parsing a 500MB file or geocoding 100K addresses blocks the HTTP server thread.
**Why it happens:** Running import pipeline synchronously in the RPC handler.
**How to avoid:** Import flow: (1) Upload file to MinIO via presigned URL, (2) Create import_job record with status "pending", (3) Return job ID immediately, (4) Background goroutine picks up job, processes file, updates status. Client polls job status via separate RPC.
**Warning signs:** Server becoming unresponsive during imports, request timeouts.

### Pitfall 6: pg_trgm Index Bloat on Large Tables
**What goes wrong:** GIN trigram indexes on 1M+ row tables become very large (multiple GB) and slow to update during bulk imports.
**Why it happens:** GIN indexes store every trigram for every row. Bulk inserts trigger massive index updates.
**How to avoid:** Drop or disable trigram indexes before bulk import, re-create after. Use `CREATE INDEX CONCURRENTLY` to avoid locking. Consider maintaining a `search_text` column (pre-concatenated name + address) with a single GIN index instead of multiple.
**Warning signs:** Import taking hours to complete, disk usage spikes during import.

## Code Examples

### Maine CVR Pipe-Delimited Parser
```go
// CVR files are pipe-delimited text. Field order is configured per-source.
func ParseCVRLine(line string, fieldMap map[int]string) (map[string]string, error) {
    fields := strings.Split(line, "|")
    record := make(map[string]string, len(fieldMap))
    for idx, fieldName := range fieldMap {
        if idx < len(fields) {
            record[fieldName] = strings.TrimSpace(fields[idx])
        }
    }
    return record, nil
}

// Example field map (configured by admin on first import):
// 0: "voter_id", 1: "last_name", 2: "first_name", 3: "middle_name",
// 4: "suffix", 5: "residence_street", 6: "residence_city",
// 7: "residence_zip", 8: "mailing_street", 9: "mailing_city",
// 10: "mailing_zip", 11: "year_of_birth", 12: "party",
// 13: "voter_status", 14: "registration_date",
// 15: "congressional_district", 16: "state_senate_district",
// 17: "state_house_district", 18: "county",
// 19: "municipality", 20: "ward", 21: "precinct"
```

### Deduplication Key Generation
```go
// Source: domain pattern for voter dedup
func GenerateDedupKey(lastName, streetAddr, zip, yob string) string {
    // Normalize last name: uppercase, remove punctuation
    ln := strings.ToUpper(strings.TrimSpace(lastName))
    ln = regexp.MustCompile(`[^A-Z]`).ReplaceAllString(ln, "")

    // Extract street number from address
    parts := strings.Fields(strings.TrimSpace(streetAddr))
    streetNum := ""
    streetName := ""
    if len(parts) > 0 {
        streetNum = parts[0]
    }
    if len(parts) > 1 {
        streetName = strings.ToUpper(strings.Join(parts[1:], " "))
        // Normalize common abbreviations
        streetName = strings.ReplaceAll(streetName, "STREET", "ST")
        streetName = strings.ReplaceAll(streetName, "AVENUE", "AVE")
        streetName = strings.ReplaceAll(streetName, "DRIVE", "DR")
        streetName = strings.ReplaceAll(streetName, "ROAD", "RD")
        streetName = strings.ReplaceAll(streetName, "LANE", "LN")
        streetName = strings.ReplaceAll(streetName, "BOULEVARD", "BLVD")
    }

    zip5 := strings.TrimSpace(zip)
    if len(zip5) > 5 {
        zip5 = zip5[:5]
    }

    return fmt.Sprintf("%s|%s|%s|%s|%s", ln, streetNum, streetName, zip5, strings.TrimSpace(yob))
}
```

### Census Geocoder Batch Response Parser
```go
// Census batch response is CSV:
// UniqueID, InputAddress, Match, MatchType, MatchedAddress, Coordinates, TigerLineID, Side
// Coordinates are "lon,lat" (note: longitude first)
func ParseCensusResponse(body io.Reader) ([]GeocodeResult, error) {
    reader := csv.NewReader(body)
    var results []GeocodeResult
    for {
        record, err := reader.Read()
        if err == io.EOF { break }
        if err != nil { continue }
        if len(record) < 6 { continue }

        result := GeocodeResult{ID: record[0], Match: record[2] == "Match"}
        if result.Match {
            coords := strings.Split(record[5], ",")
            if len(coords) == 2 {
                result.Longitude, _ = strconv.ParseFloat(coords[0], 64)
                result.Latitude, _ = strconv.ParseFloat(coords[1], 64)
            }
        }
        results = append(results, result)
    }
    return results, nil
}
```

### Voter Search with pg_trgm
```sql
-- Migration: enable pg_trgm and create search indexes
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Concatenated search column for single-index approach
ALTER TABLE voters ADD COLUMN search_text TEXT GENERATED ALWAYS AS (
    COALESCE(first_name, '') || ' ' || COALESCE(last_name, '') || ' ' ||
    COALESCE(residence_street, '') || ' ' || COALESCE(residence_city, '')
) STORED;

CREATE INDEX idx_voters_search_trgm ON voters USING gin (search_text gin_trgm_ops);
CREATE INDEX idx_voters_voter_id ON voters (source_voter_id);

-- sqlc query: search voters with fuzzy matching
-- name: SearchVoters :many
SELECT v.*, similarity(v.search_text, @query) AS score
FROM voters v
WHERE v.company_id = @company_id
  AND v.search_text % @query
ORDER BY score DESC
LIMIT @result_limit OFFSET @result_offset;
```

### Voter Data Model (Migration)
```sql
-- 005_voters.up.sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE voters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),

    -- Identity (permitted per Maine 21-A s196-A)
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    middle_name TEXT NOT NULL DEFAULT '',
    suffix TEXT NOT NULL DEFAULT '',
    year_of_birth INT,  -- NOT full DOB, per Maine law

    -- Residence address
    residence_street TEXT NOT NULL DEFAULT '',
    residence_city TEXT NOT NULL DEFAULT '',
    residence_state TEXT NOT NULL DEFAULT 'ME',
    residence_zip TEXT NOT NULL DEFAULT '',

    -- Mailing address
    mailing_street TEXT NOT NULL DEFAULT '',
    mailing_city TEXT NOT NULL DEFAULT '',
    mailing_state TEXT NOT NULL DEFAULT '',
    mailing_zip TEXT NOT NULL DEFAULT '',

    -- Registration
    party TEXT NOT NULL DEFAULT '',  -- D, G, L, NL, R, or unenrolled
    voter_status TEXT NOT NULL DEFAULT 'active',  -- active, inactive, cancelled
    registration_date DATE,

    -- Electoral districts
    congressional_district TEXT NOT NULL DEFAULT '',
    state_senate_district TEXT NOT NULL DEFAULT '',
    state_house_district TEXT NOT NULL DEFAULT '',
    county TEXT NOT NULL DEFAULT '',
    municipality TEXT NOT NULL DEFAULT '',
    ward TEXT NOT NULL DEFAULT '',
    precinct TEXT NOT NULL DEFAULT '',

    -- Geocoded location
    location GEOMETRY(POINT, 4326),
    geocode_status TEXT NOT NULL DEFAULT 'pending',  -- pending, matched, failed
    geocode_source TEXT NOT NULL DEFAULT '',  -- census, google, manual

    -- Source tracking
    source_voter_id TEXT NOT NULL DEFAULT '',  -- original voter ID from CVR/L2
    source TEXT NOT NULL DEFAULT '',  -- 'cvr', 'l2', 'manual'
    dedup_key TEXT NOT NULL,  -- normalized dedup key

    -- Voting history (array of election participation records)
    voting_history JSONB NOT NULL DEFAULT '[]',

    -- Metadata
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Dedup: one voter per company per dedup_key
    UNIQUE (company_id, dedup_key)
);

CREATE INDEX idx_voters_company ON voters (company_id);
CREATE INDEX idx_voters_location ON voters USING GIST (location);
CREATE INDEX idx_voters_party ON voters (company_id, party);
CREATE INDEX idx_voters_status ON voters (company_id, voter_status);
CREATE INDEX idx_voters_district ON voters (company_id, congressional_district, state_senate_district, state_house_district);
CREATE INDEX idx_voters_source_id ON voters (company_id, source_voter_id);

-- Full-text search column
ALTER TABLE voters ADD COLUMN search_text TEXT GENERATED ALWAYS AS (
    COALESCE(first_name, '') || ' ' || COALESCE(last_name, '') || ' ' ||
    COALESCE(residence_street, '') || ' ' || COALESCE(residence_city, '')
) STORED;
CREATE INDEX idx_voters_search_trgm ON voters USING gin (search_text gin_trgm_ops);
```

### Import Job Tracking
```sql
-- 006_import_jobs.up.sql
CREATE TABLE import_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    uploaded_by UUID NOT NULL REFERENCES users(id),
    file_name TEXT NOT NULL,
    file_storage_key TEXT NOT NULL,  -- MinIO key
    source_type TEXT NOT NULL CHECK (source_type IN ('cvr', 'l2', 'manual')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'parsing', 'staging', 'merging', 'geocoding', 'complete', 'failed')),
    total_rows INT NOT NULL DEFAULT 0,
    parsed_rows INT NOT NULL DEFAULT 0,
    merged_rows INT NOT NULL DEFAULT 0,
    skipped_rows INT NOT NULL DEFAULT 0,
    error_rows INT NOT NULL DEFAULT 0,
    geocoded_rows INT NOT NULL DEFAULT 0,
    errors JSONB NOT NULL DEFAULT '[]',  -- [{line: N, error: "msg"}, ...]
    field_mapping JSONB NOT NULL DEFAULT '{}',  -- {0: "last_name", 1: "first_name", ...}
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_import_jobs_company ON import_jobs (company_id, created_at DESC);

-- Temporary staging table (truncated per import)
CREATE TABLE import_staging (
    id BIGSERIAL PRIMARY KEY,
    import_job_id UUID NOT NULL REFERENCES import_jobs(id) ON DELETE CASCADE,
    line_number INT NOT NULL,
    is_valid BOOLEAN NOT NULL DEFAULT true,
    validation_error TEXT NOT NULL DEFAULT '',
    -- Raw parsed fields
    source_voter_id TEXT NOT NULL DEFAULT '',
    first_name TEXT NOT NULL DEFAULT '',
    last_name TEXT NOT NULL DEFAULT '',
    middle_name TEXT NOT NULL DEFAULT '',
    suffix TEXT NOT NULL DEFAULT '',
    year_of_birth INT,
    residence_street TEXT NOT NULL DEFAULT '',
    residence_city TEXT NOT NULL DEFAULT '',
    residence_state TEXT NOT NULL DEFAULT 'ME',
    residence_zip TEXT NOT NULL DEFAULT '',
    mailing_street TEXT NOT NULL DEFAULT '',
    mailing_city TEXT NOT NULL DEFAULT '',
    mailing_state TEXT NOT NULL DEFAULT '',
    mailing_zip TEXT NOT NULL DEFAULT '',
    party TEXT NOT NULL DEFAULT '',
    voter_status TEXT NOT NULL DEFAULT '',
    registration_date TEXT NOT NULL DEFAULT '',
    congressional_district TEXT NOT NULL DEFAULT '',
    state_senate_district TEXT NOT NULL DEFAULT '',
    state_house_district TEXT NOT NULL DEFAULT '',
    county TEXT NOT NULL DEFAULT '',
    municipality TEXT NOT NULL DEFAULT '',
    ward TEXT NOT NULL DEFAULT '',
    precinct TEXT NOT NULL DEFAULT '',
    voting_history_raw TEXT NOT NULL DEFAULT '',
    dedup_key TEXT NOT NULL DEFAULT '',
    raw_line TEXT NOT NULL DEFAULT ''
);
CREATE INDEX idx_import_staging_job ON import_staging (import_job_id);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| COPY from file on disk | pgx CopyFrom (programmatic) | pgx v5 | No need for server-side file access; stream rows directly from Go |
| INSERT ON CONFLICT for upserts | MERGE statement (PG 15+) | PostgreSQL 15, 2022 | MERGE is more expressive but INSERT ON CONFLICT is simpler for this use case |
| Google-only geocoding | Census (free primary) + Google (paid fallback) | Census Geocoder has been free for years | Saves ~$5K per 1M voter geocoding run |
| Full-text search via tsvector | pg_trgm for fuzzy name/address matching | pg_trgm has been available since PG 9.2 | tsvector is for document search; pg_trgm is better for name/address typo tolerance |

**Deprecated/outdated:**
- Google Maps Go client at `google.golang.org/api/...` -- use `googlemaps.github.io/maps` instead (official community client)
- Census Geocoder "Public_AR_ACS2019" vintage -- use "Public_AR_Current" benchmark for latest data

## Open Questions

1. **Maine CVR exact field layout**
   - What we know: Pipe-delimited text file. Fields include name, address, YOB, party, voting history, districts, registration date, voter status. The CVR Data Request Form and import-to-Excel instructions exist but exact column order is undocumented publicly.
   - What's unclear: Exact column positions and whether a header row is included. Whether voting history is inline (columns per election) or separate file.
   - Recommendation: Build configurable field mapping (admin selects which column maps to which field on first import). Persist mapping per source_type. This also handles L2 format differences.

2. **L2 file format variations**
   - What we know: L2 uses tab-delimited format with 600+ fields across demographic and vote history datasets. They provide a "VM2 Uniform" combined format.
   - What's unclear: Exact column subset Maine uses, whether MaineGOP already has an L2 subscription with known field layout.
   - Recommendation: Same configurable field mapper as CVR. L2's tab-delimited format uses standard `encoding/csv` with `Comma = '\t'`.

3. **Census Geocoder reliability**
   - What we know: Free, 10K records per batch, no explicit rate limits documented, returns CSV.
   - What's unclear: Actual throughput/reliability for 100K+ addresses. Some community reports suggest slowness.
   - Recommendation: Build retry with backoff. Process in serial 10K batches with 5-second delays between batches. Track match rate -- if Census match rate drops below 80%, flag for investigation.

4. **Voting history data structure**
   - What we know: CVR allows requesting participation history for up to 2 elections per request. L2 provides full history in separate dataset.
   - What's unclear: Whether to store as JSONB array or normalized table.
   - Recommendation: JSONB array on voter record `[{"election": "2024-11-05 General", "voted": true, "method": "in_person"}]`. Simpler than a join table, and voting history is always read with the voter profile. Index with GIN for filtering by election participation.

## Sources

### Primary (HIGH confidence)
- Existing codebase: `navigators-go/internal/navigators/` -- turf_scope.go, audit_service.go, admin_handler.go patterns
- Eden platform: `eden-platform-go/platform/upload/` -- MinIO upload service
- Eden platform: `eden-platform-go/platform/config/` -- MinIO configuration (endpoint, keys, bucket)
- Maine CVR Data Request Form (Rev. 3/21/24) -- PDF read directly, confirms pipe-delimited format, permitted fields, enrollment codes (D, G, L, NL, R)
- Maine Title 21-A s196-A -- Full statute text confirms accessible fields for party/campaign use
- Census Geocoder API docs: https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html
- pgx v5 CopyFrom docs: https://pkg.go.dev/github.com/jackc/pgx/v5
- PostgreSQL pg_trgm docs: https://www.postgresql.org/docs/current/pgtrgm.html

### Secondary (MEDIUM confidence)
- Google Maps Go client: https://github.com/googlemaps/google-maps-services-go -- confirmed official, rate limiting built in
- Google Geocoding pricing: ~$5/1000 requests after free tier (~10K free/month as of March 2025)
- L2 voter file structure: tab-delimited, VM2 format, 600+ fields, separate demographic and vote history datasets

### Tertiary (LOW confidence)
- Maine CVR exact column order -- not publicly documented; must be verified against actual file
- Census Geocoder actual throughput under load -- community reports vary; no official SLA
- L2 Maine-specific field subset -- depends on MaineGOP's subscription level

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all libraries already in use or well-established Go ecosystem standards
- Architecture: HIGH - follows exact patterns established in Objective 1 codebase
- Data model: HIGH - fields directly derived from Maine statute s196-A permitted data
- Import pipeline: HIGH - staging table + UPSERT is standard PostgreSQL bulk loading pattern
- Geocoding: MEDIUM - Census API is straightforward but reliability at scale is unverified
- CVR file format: MEDIUM - format type confirmed (pipe-delimited), exact field layout needs verification against actual file
- Pitfalls: HIGH - based on well-known patterns for voter data systems and PostgreSQL bulk operations

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (stable domain; Maine law and Census API are slow-changing)
