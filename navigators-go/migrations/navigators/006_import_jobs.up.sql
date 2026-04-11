-- 006_import_jobs.up.sql
-- Import jobs tracking and staging tables for voter file imports.

-- Import jobs
CREATE TABLE IF NOT EXISTS import_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    uploaded_by UUID NOT NULL REFERENCES users(id),
    file_name TEXT NOT NULL,
    file_storage_key TEXT NOT NULL DEFAULT '',
    source_type TEXT NOT NULL CHECK (source_type IN ('cvr', 'l2', 'manual')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'parsing', 'staging', 'merging', 'complete', 'failed')),

    -- Row counters
    total_rows INT NOT NULL DEFAULT 0,
    parsed_rows INT NOT NULL DEFAULT 0,
    merged_rows INT NOT NULL DEFAULT 0,
    skipped_rows INT NOT NULL DEFAULT 0,
    error_rows INT NOT NULL DEFAULT 0,
    geocoded_rows INT NOT NULL DEFAULT 0,

    -- Error details and field mapping configuration
    errors JSONB NOT NULL DEFAULT '[]',
    field_mapping JSONB NOT NULL DEFAULT '{}',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_import_jobs_company ON import_jobs (company_id, created_at DESC);

-- Import staging table (high-volume temp table, BIGSERIAL PK for performance)
CREATE TABLE IF NOT EXISTS import_staging (
    id BIGSERIAL PRIMARY KEY,
    import_job_id UUID NOT NULL REFERENCES import_jobs(id) ON DELETE CASCADE,
    line_number INT NOT NULL DEFAULT 0,
    is_valid BOOLEAN NOT NULL DEFAULT true,
    validation_error TEXT NOT NULL DEFAULT '',

    -- Raw voter fields (populated by parser)
    first_name TEXT NOT NULL DEFAULT '',
    middle_name TEXT NOT NULL DEFAULT '',
    last_name TEXT NOT NULL DEFAULT '',
    suffix TEXT NOT NULL DEFAULT '',
    year_of_birth INT,

    res_street_address TEXT NOT NULL DEFAULT '',
    res_street_number TEXT NOT NULL DEFAULT '',
    res_street_name TEXT NOT NULL DEFAULT '',
    res_unit TEXT NOT NULL DEFAULT '',
    res_city TEXT NOT NULL DEFAULT '',
    res_state TEXT NOT NULL DEFAULT 'ME',
    res_zip TEXT NOT NULL DEFAULT '',

    mail_street_address TEXT NOT NULL DEFAULT '',
    mail_city TEXT NOT NULL DEFAULT '',
    mail_state TEXT NOT NULL DEFAULT '',
    mail_zip TEXT NOT NULL DEFAULT '',

    party TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT '',
    registration_date TEXT NOT NULL DEFAULT '',

    county TEXT NOT NULL DEFAULT '',
    municipality TEXT NOT NULL DEFAULT '',
    ward TEXT NOT NULL DEFAULT '',
    precinct TEXT NOT NULL DEFAULT '',
    congressional_district TEXT NOT NULL DEFAULT '',
    state_senate_district TEXT NOT NULL DEFAULT '',
    state_house_district TEXT NOT NULL DEFAULT '',

    source_voter_id TEXT NOT NULL DEFAULT '',
    voting_history JSONB NOT NULL DEFAULT '[]',

    phone TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL DEFAULT '',

    -- Computed dedup key
    dedup_key TEXT NOT NULL DEFAULT '',

    -- Original raw line for debugging
    raw_line TEXT NOT NULL DEFAULT ''
);

CREATE INDEX idx_import_staging_job ON import_staging (import_job_id);
