-- Revert migration 016: drop volunteer management and events tables in reverse order.

DROP TABLE IF EXISTS training_materials;
DROP TABLE IF EXISTS event_checkins;
DROP TABLE IF EXISTS event_rsvps;
DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS navigator_profiles;
