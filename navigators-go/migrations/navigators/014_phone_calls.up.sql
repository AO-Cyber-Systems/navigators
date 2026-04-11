-- Migration 014: Phone calls - call scripts + extended door_status for phone dispositions
-- Call scripts are admin-created text content, pull-synced to devices (mirrors survey_forms pattern).

-- CREATE call_scripts (admin-created, pull-synced to devices)
CREATE TABLE call_scripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    title TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    version INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_call_scripts_company ON call_scripts (company_id, is_active);

-- Extend door_status CHECK to include phone-specific disposition values.
-- 'answered' and 'refused' are shared between door knock and phone.
ALTER TABLE contact_logs DROP CONSTRAINT IF EXISTS contact_logs_door_status_check;
ALTER TABLE contact_logs ADD CONSTRAINT contact_logs_door_status_check
    CHECK (door_status IN ('', 'answered', 'not_home', 'refused', 'moved', 'inaccessible', 'voicemail', 'no_answer', 'busy'));
