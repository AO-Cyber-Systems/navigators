-- Revert migration 014: remove call_scripts and restore original door_status CHECK.

DROP TABLE IF EXISTS call_scripts;

-- Restore original door_status CHECK (without phone values)
ALTER TABLE contact_logs DROP CONSTRAINT IF EXISTS contact_logs_door_status_check;
ALTER TABLE contact_logs ADD CONSTRAINT contact_logs_door_status_check
    CHECK (door_status IN ('', 'answered', 'not_home', 'refused', 'moved', 'inaccessible'));
