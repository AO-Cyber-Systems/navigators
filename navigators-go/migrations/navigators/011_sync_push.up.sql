-- Track received sync operations for idempotency.
-- If a client retries a push, we can skip already-processed operations.
CREATE TABLE sync_received_operations (
    client_operation_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    operation_type TEXT NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (client_operation_id, company_id)
);

CREATE INDEX idx_sync_received_ops_user ON sync_received_operations (user_id, processed_at DESC);

-- Add index on voters.updated_at for LWW conflict resolution queries.
-- The updated_at column already exists from migration 005.
CREATE INDEX IF NOT EXISTS idx_voters_updated_at ON voters (company_id, updated_at);
