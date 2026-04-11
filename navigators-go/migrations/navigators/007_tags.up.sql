-- 007_tags.up.sql
-- Voter tags for segmentation and voter-tag assignments.

CREATE TABLE voter_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    name TEXT NOT NULL,
    color TEXT NOT NULL DEFAULT '#6B7280',
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(company_id, name)
);
CREATE INDEX idx_voter_tags_company ON voter_tags (company_id);

CREATE TABLE voter_tag_assignments (
    voter_id UUID NOT NULL REFERENCES voters(id) ON DELETE CASCADE,
    tag_id UUID NOT NULL REFERENCES voter_tags(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (voter_id, tag_id)
);
CREATE INDEX idx_voter_tag_assignments_tag ON voter_tag_assignments (tag_id);
