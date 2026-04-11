-- Reverse migration 012: Drop new tables and remove added columns

DROP TABLE IF EXISTS survey_responses;
DROP TABLE IF EXISTS survey_forms;
DROP TABLE IF EXISTS voter_notes;

ALTER TABLE contact_logs DROP COLUMN IF EXISTS sentiment;
ALTER TABLE contact_logs DROP COLUMN IF EXISTS door_status;
