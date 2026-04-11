-- 004_turfs_teams_audit.up.sql
-- Domain tables for turfs, team assignments, and voter access audit logging.

-- Turfs with PostGIS boundary
CREATE TABLE IF NOT EXISTS turfs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    boundary GEOMETRY(POLYGON, 4326),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_turfs_company ON turfs (company_id);
CREATE INDEX idx_turfs_boundary ON turfs USING GIST (boundary);

-- Turf assignments (Navigator <-> Turf)
CREATE TABLE IF NOT EXISTS turf_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    turf_id UUID NOT NULL REFERENCES turfs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (turf_id, user_id)
);
CREATE INDEX idx_turf_assignments_user ON turf_assignments (user_id);
CREATE INDEX idx_turf_assignments_turf ON turf_assignments (turf_id);

-- Team assignments (Super Navigator <-> Navigator)
CREATE TABLE IF NOT EXISTS team_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    super_navigator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    navigator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_id UUID NOT NULL REFERENCES companies(id),
    assigned_by UUID NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (super_navigator_id, navigator_id)
);
CREATE INDEX idx_team_assignments_super ON team_assignments (super_navigator_id);
CREATE INDEX idx_team_assignments_nav ON team_assignments (navigator_id);

-- Voter access audit log
CREATE TABLE IF NOT EXISTS voter_access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    user_id UUID NOT NULL REFERENCES users(id),
    voter_id TEXT NOT NULL,
    access_type TEXT NOT NULL CHECK (access_type IN ('view', 'edit', 'export', 'search')),
    turf_id UUID REFERENCES turfs(id),
    details JSONB NOT NULL DEFAULT '{}',
    ip_address TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_voter_access_log_company ON voter_access_log (company_id, created_at DESC);
CREATE INDEX idx_voter_access_log_user ON voter_access_log (user_id, created_at DESC);
CREATE INDEX idx_voter_access_log_voter ON voter_access_log (voter_id);
