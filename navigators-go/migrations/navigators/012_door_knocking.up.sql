-- Migration 012: Door knocking enhancement + surveys + voter notes
-- Adds door_status and sentiment to contact_logs,
-- creates survey_forms, survey_responses, and voter_notes tables.

-- ALTER contact_logs: add door_status and sentiment columns
ALTER TABLE contact_logs ADD COLUMN door_status TEXT NOT NULL DEFAULT ''
    CHECK (door_status IN ('', 'answered', 'not_home', 'refused', 'moved', 'inaccessible'));
ALTER TABLE contact_logs ADD COLUMN sentiment INT
    CHECK (sentiment IS NULL OR (sentiment >= 1 AND sentiment <= 5));

-- CREATE survey_forms (admin-created, pull-synced to devices)
CREATE TABLE survey_forms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    schema JSONB NOT NULL,
    version INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_survey_forms_company ON survey_forms (company_id, is_active);

-- CREATE survey_responses (offline-created, push+pull synced)
CREATE TABLE survey_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    form_id UUID NOT NULL REFERENCES survey_forms(id),
    form_version INT NOT NULL,
    voter_id UUID NOT NULL REFERENCES voters(id),
    user_id UUID NOT NULL REFERENCES users(id),
    turf_id UUID REFERENCES turfs(id),
    contact_log_id UUID REFERENCES contact_logs(id),
    responses JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_survey_responses_voter ON survey_responses (voter_id);
CREATE INDEX idx_survey_responses_form ON survey_responses (form_id);

-- CREATE voter_notes (offline-created, push+pull synced, role-scoped)
CREATE TABLE voter_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    voter_id UUID NOT NULL REFERENCES voters(id),
    user_id UUID NOT NULL REFERENCES users(id),
    turf_id UUID REFERENCES turfs(id),
    content TEXT NOT NULL,
    visibility TEXT NOT NULL DEFAULT 'team' CHECK (visibility IN ('private', 'team', 'org')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_voter_notes_voter ON voter_notes (voter_id);
CREATE INDEX idx_voter_notes_company ON voter_notes (company_id, created_at DESC);
