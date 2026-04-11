-- 002_seed_company_permissions.up.sql
-- Pre-create the MaineGOP company and seed navigators-specific permissions.

-- Pre-create MaineGOP company with well-known UUID.
-- Uses 'standalone' type (eden's companies.company_type CHECK constraint).
INSERT INTO companies (id, name, slug, company_type, created_at, updated_at)
VALUES (
    '40000000-0000-0000-0000-000000000001',
    'Maine Republican Party',
    'mainegop',
    'standalone',
    now(), now()
) ON CONFLICT (id) DO NOTHING;

-- Seed navigators-specific permissions.
-- These map to the NavigatorsPermissionMatrix features.
INSERT INTO permissions (id, feature, action, resource, description) VALUES
    -- Voters permissions
    (gen_random_uuid(), 'voters', 'view', '', 'View voter records'),
    (gen_random_uuid(), 'voters', 'edit', '', 'Edit voter records'),
    (gen_random_uuid(), 'voters', 'export', '', 'Export voter data'),
    (gen_random_uuid(), 'voters', 'admin', '', 'Administer voter module'),
    -- Turfs permissions
    (gen_random_uuid(), 'turfs', 'view', '', 'View turfs'),
    (gen_random_uuid(), 'turfs', 'create', '', 'Create turfs'),
    (gen_random_uuid(), 'turfs', 'assign', '', 'Assign turfs to navigators'),
    (gen_random_uuid(), 'turfs', 'admin', '', 'Administer turf module'),
    -- Teams permissions
    (gen_random_uuid(), 'teams', 'view', '', 'View teams'),
    (gen_random_uuid(), 'teams', 'manage', '', 'Manage teams'),
    (gen_random_uuid(), 'teams', 'admin', '', 'Administer team module'),
    -- Audit permissions
    (gen_random_uuid(), 'audit', 'view', '', 'View audit logs'),
    (gen_random_uuid(), 'audit', 'admin', '', 'Administer audit module'),
    -- Admin permissions
    (gen_random_uuid(), 'admin', 'users', '', 'Manage user accounts'),
    (gen_random_uuid(), 'admin', 'sessions', '', 'Manage user sessions'),
    (gen_random_uuid(), 'admin', 'admin', '', 'Full admin access')
ON CONFLICT (feature, action) DO NOTHING;

-- Map permissions to roles using eden's well-known system role IDs.

-- Admin (10000000-0000-0000-0000-000000000002) gets ALL navigators permissions.
INSERT INTO role_permissions (role_id, permission_id)
SELECT '10000000-0000-0000-0000-000000000002', id FROM permissions
WHERE feature IN ('voters', 'turfs', 'teams', 'audit', 'admin')
ON CONFLICT DO NOTHING;

-- Manager/Super Navigator (10000000-0000-0000-0000-000000000005) gets view + manage, not admin.
INSERT INTO role_permissions (role_id, permission_id)
SELECT '10000000-0000-0000-0000-000000000005', id FROM permissions
WHERE (feature = 'voters' AND action IN ('view', 'edit', 'export'))
   OR (feature = 'turfs' AND action IN ('view', 'assign'))
   OR (feature = 'teams' AND action IN ('view'))
ON CONFLICT DO NOTHING;

-- Member/Navigator (10000000-0000-0000-0000-000000000003) gets basic view + edit.
INSERT INTO role_permissions (role_id, permission_id)
SELECT '10000000-0000-0000-0000-000000000003', id FROM permissions
WHERE (feature = 'voters' AND action IN ('view', 'edit'))
   OR (feature = 'turfs' AND action IN ('view'))
ON CONFLICT DO NOTHING;
