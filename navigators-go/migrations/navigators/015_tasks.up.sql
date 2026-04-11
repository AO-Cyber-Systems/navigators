-- Migration 015: Task management tables

CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    task_type TEXT NOT NULL CHECK (task_type IN ('contact_list', 'event', 'data_entry', 'custom')),
    priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled')),
    due_date TIMESTAMPTZ,
    linked_entity_type TEXT CHECK (linked_entity_type IN ('turf', 'voter', 'voter_list')),
    linked_entity_id UUID,
    progress_pct INT NOT NULL DEFAULT 0 CHECK (progress_pct >= 0 AND progress_pct <= 100),
    total_count INT NOT NULL DEFAULT 0,
    completed_count INT NOT NULL DEFAULT 0,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_tasks_company ON tasks (company_id, status);
CREATE INDEX idx_tasks_due ON tasks (due_date) WHERE status IN ('open', 'in_progress');

CREATE TABLE task_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (task_id, user_id)
);
CREATE INDEX idx_task_assignments_user ON task_assignments (user_id);

CREATE TABLE task_voters (
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    voter_id UUID NOT NULL REFERENCES voters(id),
    is_contacted BOOLEAN NOT NULL DEFAULT false,
    contacted_at TIMESTAMPTZ,
    PRIMARY KEY (task_id, voter_id)
);
CREATE INDEX idx_task_voters_task ON task_voters (task_id, is_contacted);

CREATE TABLE task_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    content TEXT NOT NULL,
    visibility TEXT NOT NULL DEFAULT 'team' CHECK (visibility IN ('team', 'org')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_task_notes_task ON task_notes (task_id, created_at);
