-- 010_sync_cursors.up.sql
-- Track server-side sync state per user per entity type (for cursor validation).

CREATE TABLE sync_server_cursors (
    user_id UUID NOT NULL REFERENCES users(id),
    entity_type TEXT NOT NULL,
    last_cursor TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, entity_type)
);
