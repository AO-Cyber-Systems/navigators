---
objective: 08-tasks-collaboration
trd: "01"
subsystem: tasks
tags: [tasks, crud, sync, drift, proto]
dependency_graph:
  requires: [migration-014, sync-service, drift-database]
  provides: [tasks-schema, task-service, task-sync, task-drift]
  affects: [permissions, main-wiring, sync-handler]
tech_stack:
  added: []
  patterns: [sqlc-copyfrom, pgtype-timestamptz, drift-schema-v4]
key_files:
  created:
    - navigators-go/migrations/navigators/015_tasks.up.sql
    - navigators-go/migrations/navigators/015_tasks.down.sql
    - navigators-go/queries/navigators/tasks.sql
    - navigators-go/proto/navigators/v1/task.proto
    - navigators-go/internal/navigators/task_service.go
    - navigators-go/internal/navigators/task_handler.go
    - navigators-flutter/lib/src/database/tables/tasks.dart
    - navigators-flutter/lib/src/database/tables/task_assignments.dart
    - navigators-flutter/lib/src/database/tables/task_notes.dart
    - navigators-flutter/lib/src/database/daos/task_dao.dart
  modified:
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/internal/navigators/sync_service.go
    - navigators-go/internal/navigators/sync_handler.go
    - navigators-go/cmd/server/main.go
    - navigators-go/proto/navigators/v1/sync.proto
    - navigators-flutter/lib/src/database/database.dart
    - navigators-flutter/lib/src/sync/pull_sync.dart
decisions:
  - "DueDate uses pgtype.Timestamptz (nullable TIMESTAMPTZ column)"
  - "LinkedEntityID uses pgtype.UUID (nullable UUID column)"
  - "InsertTaskVoters uses sqlc copyfrom for bulk insert"
  - "SyncService constructor extended with TaskService parameter"
  - "Task notes use 'task_note' entity type for push sync"
metrics:
  duration: 11min
  completed: "2026-04-11T18:26:44Z"
---

# Objective 08 TRD 01: Task Data Model, Service, and Sync Summary

Task data model with server-side CRUD, ConnectRPC handler, proto definitions, Drift local tables with offline sync, and pull/push sync for tasks and task notes.

## What Was Built

### Server (Go)

**Migration 015** creates four tables:
- `tasks`: UUID PK, company scoping, task_type/priority/status CHECK constraints, polymorphic linked_entity_type/id, progress tracking (progress_pct, total_count, completed_count)
- `task_assignments`: user-to-task mapping with UNIQUE(task_id, user_id)
- `task_voters`: composite PK junction table for contact_list tasks with is_contacted tracking
- `task_notes`: company-scoped notes with team/org visibility

**TaskService** provides: CreateTask, GetTask, ListTasksByCompany, ListTasksByAssignee, UpdateTaskStatus, DeleteTask, AssignTask, UnassignTask, GetTaskAssignments, LinkTaskVoters, CreateTaskNote, ListTaskNotes.

**TaskHandler** implements ConnectRPC TaskService interface with role-scoped ListTasks (Manager/Admin see all company tasks, Member sees only assigned).

**task.proto** defines TaskService with 11 RPCs. **sync.proto** extended with PullTasks and PullTaskNotes RPCs.

**Permissions**: FeatureTasks added with view(40), create(60), assign(60), admin(80). All TaskService and sync RPCs mapped in procedure permissions.

**SyncService**: PullTasks returns tasks + assignments for company. PullTaskNotes returns notes for company. PushSyncBatch handles "task_note" entity type.

### Flutter (Dart)

**Three Drift tables**: Tasks (17 columns), TaskAssignments (5 columns), TaskNotes (8 columns). Schema version bumped to 4.

**TaskDao**: watchMyTasks (JOIN task_assignments), watchTaskNotes, watchTasksByStatus, upsertTasks, upsertTaskAssignments, upsertTaskNotes, insertTaskNoteWithOutbox (outbox pattern), getTask.

**Pull sync**: pullTasks (tasks + assignments in one call), pullTaskNotes, pullAllTasks (cursored loop), pullAllTaskNotes (cursored loop). Data classes with fromJson and toCompanion for each.

## Deviations from Plan

None - TRD executed exactly as written.

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Server-side task data model, service, handler, and proto | `cd navigators-go && sqlc generate && go build ./cmd/server/` | 0 | PASS |
| 2: Flutter Drift tables, DAO, pull sync, and push sync | `cd navigators-flutter && dart run build_runner build --delete-conflicting-outputs && dart analyze` | 0 | PASS |

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-go && go vet ./...` | 0 | PASS |
| build (Go) | `cd navigators-go && go build ./cmd/server/` | 0 | PASS |
| build (Flutter) | `cd navigators-flutter && dart run build_runner build --delete-conflicting-outputs && dart analyze` | 0 | PASS |

## Post-TRD Verification

- Auto-fix cycles used: 0
- Must-haves verified: 5/5
- Gate failures: None

## Commits

| Hash | Message |
|---|---|
| 322aaf8 | feat(08-01): task data model, service, handler, proto, and sync |
| 11091b8 | feat(08-01): Flutter Drift tables, DAO, and pull sync for tasks |
