-- 009_contact_logs.up.sql
-- Contact log table for tracking voter outreach and turf completion stats.

CREATE TABLE contact_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    voter_id UUID NOT NULL REFERENCES voters(id),
    user_id UUID NOT NULL REFERENCES users(id),
    turf_id UUID REFERENCES turfs(id),
    contact_type TEXT NOT NULL CHECK (contact_type IN ('door_knock', 'phone', 'text', 'other')),
    outcome TEXT NOT NULL DEFAULT '' CHECK (outcome IN ('', 'support', 'oppose', 'undecided', 'not_home', 'refused', 'moved')),
    notes TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_logs_voter ON contact_logs (voter_id);
CREATE INDEX idx_contact_logs_turf ON contact_logs (turf_id);
CREATE INDEX idx_contact_logs_company ON contact_logs (company_id, created_at DESC);
