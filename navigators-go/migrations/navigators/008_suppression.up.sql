CREATE TABLE suppression_list (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    voter_id UUID NOT NULL REFERENCES voters(id) ON DELETE CASCADE,
    reason TEXT NOT NULL DEFAULT '',
    added_by UUID NOT NULL REFERENCES users(id),
    added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(company_id, voter_id)
);
CREATE INDEX idx_suppression_list_company ON suppression_list (company_id);
CREATE INDEX idx_suppression_list_voter ON suppression_list (voter_id);
