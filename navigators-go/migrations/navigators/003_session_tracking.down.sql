-- 003_session_tracking.down.sql
DROP INDEX IF EXISTS idx_refresh_tokens_last_active;
ALTER TABLE refresh_tokens DROP COLUMN IF EXISTS last_active_at;
