-- Migration 016: Volunteer management and events tables

CREATE TABLE navigator_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    company_id UUID NOT NULL REFERENCES companies(id),
    onboarding_completed_at TIMESTAMPTZ,
    legal_acknowledgment_at TIMESTAMPTZ,
    legal_acknowledgment_version TEXT,
    leaderboard_opt_in BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_navigator_profiles_company ON navigator_profiles (company_id);

CREATE TABLE events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    event_type TEXT NOT NULL CHECK (event_type IN ('canvass', 'phone_bank', 'meeting', 'other')),
    status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'in_progress', 'completed', 'cancelled')),
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    location_name TEXT,
    location_lat DOUBLE PRECISION,
    location_lng DOUBLE PRECISION,
    linked_turf_id UUID REFERENCES turfs(id),
    max_attendees INT,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_events_company ON events (company_id, status);
CREATE INDEX idx_events_upcoming ON events (starts_at) WHERE status IN ('scheduled', 'in_progress');

CREATE TABLE event_rsvps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    status TEXT NOT NULL DEFAULT 'going' CHECK (status IN ('going', 'maybe', 'declined')),
    last_reminder_sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (event_id, user_id)
);
CREATE INDEX idx_event_rsvps_user ON event_rsvps (user_id);

CREATE TABLE event_checkins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    checked_in_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (event_id, user_id)
);

CREATE TABLE training_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    content_url TEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    is_published BOOLEAN NOT NULL DEFAULT false,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_training_materials_company ON training_materials (company_id, is_published, sort_order);
