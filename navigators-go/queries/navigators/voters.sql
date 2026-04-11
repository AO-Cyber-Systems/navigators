-- name: InsertVoter :exec
INSERT INTO voters (
    company_id, first_name, middle_name, last_name, suffix, year_of_birth,
    res_street_address, res_street_number, res_street_name, res_unit,
    res_city, res_state, res_zip,
    mail_street_address, mail_city, mail_state, mail_zip,
    party, status, registration_date,
    county, municipality, ward, precinct,
    congressional_district, state_senate_district, state_house_district,
    source_voter_id, source, dedup_key, voting_history,
    phone, email
) VALUES (
    $1, $2, $3, $4, $5, $6,
    $7, $8, $9, $10,
    $11, $12, $13,
    $14, $15, $16, $17,
    $18, $19, $20,
    $21, $22, $23, $24,
    $25, $26, $27,
    $28, $29, $30, $31,
    $32, $33
) ON CONFLICT (company_id, dedup_key) DO UPDATE SET
    first_name = EXCLUDED.first_name,
    middle_name = EXCLUDED.middle_name,
    suffix = EXCLUDED.suffix,
    res_street_address = EXCLUDED.res_street_address,
    res_unit = EXCLUDED.res_unit,
    res_city = EXCLUDED.res_city,
    res_state = EXCLUDED.res_state,
    res_zip = EXCLUDED.res_zip,
    mail_street_address = EXCLUDED.mail_street_address,
    mail_city = EXCLUDED.mail_city,
    mail_state = EXCLUDED.mail_state,
    mail_zip = EXCLUDED.mail_zip,
    party = EXCLUDED.party,
    status = EXCLUDED.status,
    registration_date = EXCLUDED.registration_date,
    county = EXCLUDED.county,
    municipality = EXCLUDED.municipality,
    ward = EXCLUDED.ward,
    precinct = EXCLUDED.precinct,
    congressional_district = EXCLUDED.congressional_district,
    state_senate_district = EXCLUDED.state_senate_district,
    state_house_district = EXCLUDED.state_house_district,
    source_voter_id = EXCLUDED.source_voter_id,
    source = EXCLUDED.source,
    voting_history = EXCLUDED.voting_history,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    updated_at = now();

-- name: GetVoterByID :one
SELECT * FROM voters WHERE id = $1;

-- name: GetVoterBySourceID :one
SELECT * FROM voters WHERE company_id = $1 AND source_voter_id = $2;

-- name: CountVotersByCompany :one
SELECT COUNT(*) FROM voters WHERE company_id = $1;

-- name: GetVoterByCompany :one
SELECT * FROM voters WHERE id = $1 AND company_id = $2;

-- name: SearchVoters :many
SELECT id, first_name, last_name, party, status, res_city, res_zip, municipality, year_of_birth,
       similarity(search_text, @query::text) AS score
FROM voters
WHERE company_id = @company_id
  AND search_text % @query::text
ORDER BY similarity(search_text, @query::text) DESC
LIMIT @lim OFFSET @off;

-- name: CountSearchVoters :one
SELECT COUNT(*) FROM voters
WHERE company_id = @company_id
  AND search_text % @query::text;

-- name: ListVotersByFilters :many
SELECT id, first_name, last_name, party, status, res_city, res_zip, municipality, year_of_birth
FROM voters
WHERE company_id = @company_id
  AND (sqlc.narg('party')::text IS NULL OR party = sqlc.narg('party'))
  AND (sqlc.narg('voter_status')::text IS NULL OR status = sqlc.narg('voter_status'))
  AND (sqlc.narg('congressional_district')::text IS NULL OR congressional_district = sqlc.narg('congressional_district'))
  AND (sqlc.narg('state_senate_district')::text IS NULL OR state_senate_district = sqlc.narg('state_senate_district'))
  AND (sqlc.narg('state_house_district')::text IS NULL OR state_house_district = sqlc.narg('state_house_district'))
  AND (sqlc.narg('municipality')::text IS NULL OR municipality = sqlc.narg('municipality'))
  AND (sqlc.narg('county')::text IS NULL OR county = sqlc.narg('county'))
  AND (sqlc.narg('min_vote_count')::int IS NULL OR jsonb_array_length(voting_history) >= sqlc.narg('min_vote_count'))
ORDER BY last_name, first_name
LIMIT @lim OFFSET @off;

-- name: CountVotersByFilters :one
SELECT COUNT(*) FROM voters
WHERE company_id = @company_id
  AND (sqlc.narg('party')::text IS NULL OR party = sqlc.narg('party'))
  AND (sqlc.narg('voter_status')::text IS NULL OR status = sqlc.narg('voter_status'))
  AND (sqlc.narg('congressional_district')::text IS NULL OR congressional_district = sqlc.narg('congressional_district'))
  AND (sqlc.narg('state_senate_district')::text IS NULL OR state_senate_district = sqlc.narg('state_senate_district'))
  AND (sqlc.narg('state_house_district')::text IS NULL OR state_house_district = sqlc.narg('state_house_district'))
  AND (sqlc.narg('municipality')::text IS NULL OR municipality = sqlc.narg('municipality'))
  AND (sqlc.narg('county')::text IS NULL OR county = sqlc.narg('county'))
  AND (sqlc.narg('min_vote_count')::int IS NULL OR jsonb_array_length(voting_history) >= sqlc.narg('min_vote_count'));

-- name: GetUngeocoded :many
SELECT id, res_street_address, res_city, res_state, res_zip
FROM voters
WHERE company_id = $1 AND geocode_status = 'pending'
ORDER BY created_at
LIMIT $2;

-- name: UpdateVoterGeocode :exec
UPDATE voters
SET location = ST_SetSRID(ST_MakePoint(@longitude::float8, @latitude::float8), 4326),
    geocode_status = @geocode_status,
    geocode_source = @geocode_source,
    updated_at = now()
WHERE id = @id;

-- name: UpdateVoterGeocodeFailure :exec
UPDATE voters
SET geocode_status = 'failed',
    geocode_source = @geocode_source,
    updated_at = now()
WHERE id = @id;
