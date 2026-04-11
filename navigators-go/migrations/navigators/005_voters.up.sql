-- 005_voters.up.sql
-- Voter data model with PostGIS location, trigram search, and dedup key.

-- Enable pg_trgm for fuzzy text search
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Voters table
CREATE TABLE IF NOT EXISTS voters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),

    -- Identity fields (Maine 21-A s196-A compliant: NO full DOB, NO SSN, NO driver license, NO felony status)
    first_name TEXT NOT NULL DEFAULT '',
    middle_name TEXT NOT NULL DEFAULT '',
    last_name TEXT NOT NULL DEFAULT '',
    suffix TEXT NOT NULL DEFAULT '',
    year_of_birth INT,

    -- Residence address
    res_street_address TEXT NOT NULL DEFAULT '',
    res_street_number TEXT NOT NULL DEFAULT '',
    res_street_name TEXT NOT NULL DEFAULT '',
    res_unit TEXT NOT NULL DEFAULT '',
    res_city TEXT NOT NULL DEFAULT '',
    res_state TEXT NOT NULL DEFAULT 'ME',
    res_zip TEXT NOT NULL DEFAULT '',

    -- Mailing address
    mail_street_address TEXT NOT NULL DEFAULT '',
    mail_city TEXT NOT NULL DEFAULT '',
    mail_state TEXT NOT NULL DEFAULT '',
    mail_zip TEXT NOT NULL DEFAULT '',

    -- Registration
    party TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT '',
    registration_date TEXT NOT NULL DEFAULT '',

    -- Districts
    county TEXT NOT NULL DEFAULT '',
    municipality TEXT NOT NULL DEFAULT '',
    ward TEXT NOT NULL DEFAULT '',
    precinct TEXT NOT NULL DEFAULT '',
    congressional_district TEXT NOT NULL DEFAULT '',
    state_senate_district TEXT NOT NULL DEFAULT '',
    state_house_district TEXT NOT NULL DEFAULT '',

    -- Geolocation
    location GEOMETRY(POINT, 4326),
    geocode_status TEXT NOT NULL DEFAULT 'pending' CHECK (geocode_status IN ('pending', 'success', 'failed', 'skipped')),
    geocode_source TEXT NOT NULL DEFAULT '',

    -- Source tracking
    source_voter_id TEXT NOT NULL DEFAULT '',
    source TEXT NOT NULL DEFAULT '',

    -- Dedup key: UPPER(last_name)|street_number|UPPER(normalized_street_name)|zip5|year_of_birth
    dedup_key TEXT NOT NULL DEFAULT '',

    -- Voting history as JSONB array
    voting_history JSONB NOT NULL DEFAULT '[]',

    -- Phone and email (if available from L2)
    phone TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL DEFAULT '',

    -- Generated search text for trigram search
    search_text TEXT GENERATED ALWAYS AS (
        first_name || ' ' || last_name || ' ' || res_street_address || ' ' || res_city
    ) STORED,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Unique constraint on dedup key per company
ALTER TABLE voters ADD CONSTRAINT uq_voters_company_dedup UNIQUE (company_id, dedup_key);

-- Indexes
CREATE INDEX idx_voters_company ON voters (company_id);
CREATE INDEX idx_voters_location ON voters USING GIST (location);
CREATE INDEX idx_voters_party ON voters (company_id, party);
CREATE INDEX idx_voters_status ON voters (company_id, status);
CREATE INDEX idx_voters_district ON voters (company_id, congressional_district, state_senate_district, state_house_district);
CREATE INDEX idx_voters_source_id ON voters (company_id, source_voter_id);
CREATE INDEX idx_voters_search_text ON voters USING GIN (search_text gin_trgm_ops);
