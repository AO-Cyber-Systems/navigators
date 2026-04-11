-- 013_sms.up.sql
-- SMS infrastructure: config, templates, campaigns, and messages tables.

-- SMS configuration per company (Twilio credentials, messaging service SIDs, quiet hours)
CREATE TABLE sms_config (
    company_id UUID PRIMARY KEY REFERENCES companies(id),
    twilio_account_sid TEXT NOT NULL DEFAULT '',
    twilio_auth_token_encrypted TEXT NOT NULL DEFAULT '',
    p2p_messaging_service_sid TEXT NOT NULL DEFAULT '',
    a2p_messaging_service_sid TEXT NOT NULL DEFAULT '',
    inbound_webhook_url TEXT NOT NULL DEFAULT '',
    status_webhook_url TEXT NOT NULL DEFAULT '',
    quiet_hours_start INT NOT NULL DEFAULT 21,
    quiet_hours_end INT NOT NULL DEFAULT 8,
    ten_dlc_brand_sid TEXT NOT NULL DEFAULT '',
    ten_dlc_campaign_sid TEXT NOT NULL DEFAULT '',
    ten_dlc_status TEXT NOT NULL DEFAULT 'not_started'
        CHECK (ten_dlc_status IN ('not_started', 'pending', 'approved', 'failed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- SMS message templates with merge field support
CREATE TABLE sms_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    name TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    merge_fields TEXT[] NOT NULL DEFAULT '{}',
    created_by UUID NOT NULL REFERENCES users(id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(company_id, name)
);

-- SMS campaigns for bulk messaging
CREATE TABLE sms_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    name TEXT NOT NULL,
    template_id UUID REFERENCES sms_templates(id),
    segment_filters JSONB NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'sending', 'paused', 'completed', 'cancelled')),
    total_recipients INT NOT NULL DEFAULT 0,
    sent_count INT NOT NULL DEFAULT 0,
    delivered_count INT NOT NULL DEFAULT 0,
    failed_count INT NOT NULL DEFAULT 0,
    created_by UUID NOT NULL REFERENCES users(id),
    launched_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Individual SMS messages (both inbound and outbound)
CREATE TABLE sms_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    voter_id UUID NOT NULL REFERENCES voters(id),
    user_id UUID REFERENCES users(id),
    campaign_id UUID REFERENCES sms_campaigns(id),
    direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
    message_type TEXT NOT NULL CHECK (message_type IN ('p2p', 'a2p')),
    from_number TEXT NOT NULL DEFAULT '',
    to_number TEXT NOT NULL DEFAULT '',
    body TEXT NOT NULL DEFAULT '',
    twilio_message_sid TEXT UNIQUE,
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued', 'sent', 'delivered', 'undelivered', 'failed', 'received')),
    error_code TEXT NOT NULL DEFAULT '',
    segments INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for efficient querying
CREATE INDEX idx_sms_messages_voter ON sms_messages (company_id, voter_id, created_at);
CREATE INDEX idx_sms_messages_campaign ON sms_messages (campaign_id) WHERE campaign_id IS NOT NULL;
CREATE INDEX idx_sms_messages_twilio_sid ON sms_messages (twilio_message_sid) WHERE twilio_message_sid IS NOT NULL AND twilio_message_sid != '';
