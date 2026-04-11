-- 002_seed_company_permissions.down.sql
-- Remove navigators-specific permissions and the MaineGOP company seed.

-- Remove role-permission mappings for navigators features.
DELETE FROM role_permissions WHERE permission_id IN (
    SELECT id FROM permissions WHERE feature IN ('voters', 'turfs', 'teams', 'audit', 'admin')
);

-- Remove navigators-specific permissions.
DELETE FROM permissions WHERE feature IN ('voters', 'turfs', 'teams', 'audit', 'admin');

-- Remove MaineGOP company (only if no memberships reference it).
DELETE FROM companies WHERE id = '40000000-0000-0000-0000-000000000001';
