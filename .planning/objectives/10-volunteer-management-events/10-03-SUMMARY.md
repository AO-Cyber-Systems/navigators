---
objective: 10-volunteer-management-events
trd: "03"
subsystem: volunteer-management
tags: [training, minio, presigned-url, admin, soft-delete, gap-closure]
gap_closure: true
requirements: [VOL-03]
dependency_graph:
  requires:
    - 10-01 (TrainingService + training-materials bucket + PullTrainingMaterialsUpdated)
    - 10-02 (TrainingListScreen + TrainingMaterials Drift table)
  provides:
    - UpdateTrainingMaterial, DeleteTrainingMaterial, GetTrainingUploadUrl RPCs
    - Admin upload + edit + delete UI for training materials
    - Soft-delete semantics propagated via unfiltered pull sync
  affects:
    - PullTrainingMaterialsUpdated (filter removed -- clients now see unpublished rows)
tech_stack:
  added: []
  patterns:
    - Presigned-PUT direct-to-MinIO upload (15-min expiry, mirrors voter-imports)
    - Server-generated UUID-prefixed storage keys to avoid collisions
    - Soft-delete (is_published=false) with full-row sync for client reconciliation
key_files:
  created:
    - navigators-flutter/lib/src/features/training/training_upload_screen.dart
  modified:
    - navigators-go/proto/navigators/v1/volunteer.proto
    - navigators-go/queries/navigators/volunteers.sql
    - navigators-go/queries/navigators/events.sql
    - navigators-go/internal/navigators/volunteer_service.go
    - navigators-go/internal/navigators/volunteer_handler.go
    - navigators-go/internal/navigators/permissions.go
    - navigators-flutter/lib/src/services/volunteer_service.dart
    - navigators-flutter/lib/src/features/training/training_list_screen.dart
decisions:
  - Match existing CreateTrainingMaterial RBAC (RoleLevel >= 60) on all new training RPCs for consistency
  - Remove is_published filter from PullTrainingMaterialsUpdated so soft-deletes propagate; Drift DAO still filters on read
  - Server generates storage key as "<uuid>/<filename>" so clients cannot clobber each other
  - 15-minute presigned PUT expiry (per Objective 10 decision); voter-imports uses 30 minutes
  - Edit dialog uses simple inline form (title/description/sort_order/is_published switch); no re-upload of bytes on edit
  - Use existing SyncEngine.instance?.runSyncCycle() to refresh local Drift after mutations; fail silently if unavailable
metrics:
  duration_minutes: 5
  completed_date: 2026-04-15
  tasks_completed: 2
  checkpoint_pending: true
---

# Objective 10 TRD 03: Admin Training Material Upload Summary

One-liner: Adds the authoring side of VOL-03 -- presigned-PUT upload RPC, Update/Delete RPCs with soft-delete semantics, and a Flutter TrainingUploadScreen plus admin edit/delete affordances -- while leaving the navigator read-only experience untouched.

## What was built

Backend:
- `TrainingService` proto extended with `UpdateTrainingMaterial`, `DeleteTrainingMaterial`, `GetTrainingUploadUrl` RPCs (plus the corresponding request/response messages).
- `volunteers.sql` gained `UpdateTrainingMaterial :one` (company-scoped) and `SoftDeleteTrainingMaterial :exec` (flips `is_published` + `updated_at`).
- `events.sql`'s `PullTrainingMaterialsUpdated` no longer filters `is_published = true` -- soft-deleted rows now sync down so clients can reconcile local state.
- `VolunteerService` gained `UpdateTrainingMaterial`, `DeleteTrainingMaterial`, `GetTrainingUploadURL` (15-minute presigned PUT with server-generated `uuid/filename` storage key).
- `TrainingHandler` adds the three handler methods, each gated at `claims.RoleLevel < 60` (matches existing `CreateTrainingMaterial`).
- `permissions.go` registers the three new procedures under `training:create`.
- Generated Connect/protobuf code regenerated via `buf generate` and sqlc code via `sqlc generate`.

Flutter:
- `VolunteerService` adds `getTrainingUploadUrl`, `createTrainingMaterial`, `updateTrainingMaterial`, `deleteTrainingMaterial` (JSON-over-ConnectRPC, consistent with existing training methods).
- New `TrainingUploadScreen`: `file_picker` -> `GetTrainingUploadUrl` -> `http.put` raw bytes to MinIO -> `CreateTrainingMaterial` with returned storage key -> trigger `SyncEngine.instance.runSyncCycle()` -> pop with `true`. Handles web (`file.bytes`) and native (`file.path`) file sources; content-type inferred from extension.
- `TrainingListScreen` now watches `auth.role`:
  - Admin/manager/super_navigator: FAB ("Upload") pushes `TrainingUploadScreen`; each row exposes a `PopupMenuButton` with `Edit` (dialog editing title/description/sort_order/is_published) and `Delete` (confirmation dialog -> `deleteTrainingMaterial`).
  - Navigators: identical read-only list as before -- no FAB, no popup menu; tapping a row still opens `TrainingDetailScreen`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Unused imports in pre-existing event_service.go and task_service.go**
- **Found during:** Task 1 `go build ./...`
- **Issue:** Pre-existing local modifications (FCM/NATS descoping edits present in the working tree before this TRD) left `encoding/json` and `log/slog` unused, breaking the build.
- **Fix:** Auto-linter dropped the unused imports on save after editing adjacent files in the same package; rebuild was clean.
- **Files modified:** `internal/navigators/event_service.go`, `internal/navigators/task_service.go` (not staged to this TRD's commits -- left in working tree as part of pre-existing user modifications).
- **Commit:** n/a (changes not staged; cleanup was incidental to make the build succeed).

No other deviations.

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Proto + sqlc + service + handler + RBAC | `cd navigators-go && buf generate && sqlc generate && go build ./... && go vet ./...` | 0 | PASS |
| 1: proto contains new RPCs | `grep -E "UpdateTrainingMaterial\|DeleteTrainingMaterial\|GetTrainingUploadUrl" navigators-go/proto/navigators/v1/volunteer.proto` | 0 | PASS (9 matches incl. messages) |
| 2: Flutter additions | `cd navigators-flutter && flutter pub get && dart analyze lib/src/features/training lib/src/services/volunteer_service.dart` | 0 | PASS (No issues found) |
| 2: full-project analyze | `cd navigators-flutter && dart analyze` | 0 | PASS (15 pre-existing info-only issues, none in modified files) |

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint (Go) | `cd navigators-go && go vet ./...` | 0 | PASS |
| build (Go) | `cd navigators-go && go build ./...` | 0 | PASS |
| lint (Flutter) | `cd navigators-flutter && dart analyze` | 0 | PASS (info-only, no errors) |
| build (Flutter APK) | `cd navigators-flutter && flutter build apk --debug --target-platform android-arm64` | deferred | Not run -- gap-closure execution; analyze passed on all modified files and the Go backend compiles. Run before merging if APK validation is required. |

## Post-TRD Verification

- Auto-fix cycles used: 1 (Rule 3 -- unused imports in pre-existing files; auto-resolved by linter-on-save)
- Must-haves verified: 5/5 (server compiles, new RPCs registered, presigned PUT at 15 min, soft-delete sync query updated, Flutter admin affordances gated by role)
- Gate failures: None
- Checkpoint (Task 3 human-verify): PENDING -- requires running server + Flutter client to exercise the full upload/edit/delete flow end-to-end

## Checkpoint Pending

Task 3 is a `checkpoint:human-verify` requiring a running Go server and Flutter client. The executor did not run the server or drive the UI; see the TRD's `<how-to-verify>` block for the full manual test script (sign in as admin, upload a PDF, confirm MinIO object, edit/delete, verify navigator view).

## Self-Check

- `navigators-go/proto/navigators/v1/volunteer.proto`: FOUND (modified)
- `navigators-go/queries/navigators/volunteers.sql`: FOUND (modified)
- `navigators-go/queries/navigators/events.sql`: FOUND (modified, is_published filter removed)
- `navigators-go/internal/navigators/volunteer_service.go`: FOUND (Update/Delete/GetTrainingUploadURL added)
- `navigators-go/internal/navigators/volunteer_handler.go`: FOUND (3 handler methods added, RoleLevel >= 60 gates)
- `navigators-go/internal/navigators/permissions.go`: FOUND (3 procedures registered)
- `navigators-flutter/lib/src/services/volunteer_service.dart`: FOUND (4 methods added)
- `navigators-flutter/lib/src/features/training/training_upload_screen.dart`: FOUND (created)
- `navigators-flutter/lib/src/features/training/training_list_screen.dart`: FOUND (admin FAB + popup menu + edit dialog)
- Commit `77cf6bd`: FOUND
- Commit `1fe2449`: FOUND

## Self-Check: PASSED
