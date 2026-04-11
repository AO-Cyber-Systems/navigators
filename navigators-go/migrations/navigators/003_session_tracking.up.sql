-- 003_session_tracking.up.sql
-- Add last_active_at to refresh_tokens for session inactivity tracking.

ALTER TABLE refresh_tokens ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMPTZ;

-- Set existing tokens' last_active_at to their created_at as a baseline.
UPDATE refresh_tokens SET last_active_at = created_at WHERE last_active_at IS NULL;

-- Create index for the session timeout checker query.
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_last_active
ON refresh_tokens (last_active_at) WHERE revoked = false;
