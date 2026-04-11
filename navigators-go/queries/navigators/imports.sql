-- name: CreateImportJob :one
INSERT INTO import_jobs (company_id, uploaded_by, file_name, file_storage_key, source_type, field_mapping)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: UpdateImportJobStatus :exec
UPDATE import_jobs SET
    status = $2,
    total_rows = $3,
    parsed_rows = $4,
    merged_rows = $5,
    skipped_rows = $6,
    error_rows = $7,
    errors = $8,
    updated_at = now()
WHERE id = $1;

-- name: GetImportJob :one
SELECT * FROM import_jobs WHERE id = $1;

-- name: ListImportJobs :many
SELECT * FROM import_jobs
WHERE company_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: CountImportJobs :one
SELECT COUNT(*) FROM import_jobs WHERE company_id = $1;

-- name: MergeStagingToVoters :exec
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
)
SELECT
    $2, s.first_name, s.middle_name, s.last_name, s.suffix, s.year_of_birth,
    s.res_street_address, s.res_street_number, s.res_street_name, s.res_unit,
    s.res_city, s.res_state, s.res_zip,
    s.mail_street_address, s.mail_city, s.mail_state, s.mail_zip,
    s.party, s.status, s.registration_date,
    s.county, s.municipality, s.ward, s.precinct,
    s.congressional_district, s.state_senate_district, s.state_house_district,
    s.source_voter_id, $3, s.dedup_key, s.voting_history,
    s.phone, s.email
FROM import_staging s
WHERE s.import_job_id = $1 AND s.is_valid = true
ON CONFLICT (company_id, dedup_key) DO UPDATE SET
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

-- name: CountStagingRows :one
SELECT
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE is_valid = true) AS valid,
    COUNT(*) FILTER (WHERE is_valid = false) AS invalid
FROM import_staging
WHERE import_job_id = $1;

-- name: CleanupStaging :exec
DELETE FROM import_staging WHERE import_job_id = $1;
