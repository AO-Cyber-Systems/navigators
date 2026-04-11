-- Reverse migration 015: Drop task management tables

DROP TABLE IF EXISTS task_notes;
DROP TABLE IF EXISTS task_voters;
DROP TABLE IF EXISTS task_assignments;
DROP TABLE IF EXISTS tasks;
