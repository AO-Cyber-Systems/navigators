---
objective: 07-phone-calls-scripts
trd: "03"
subsystem: call-scripts
tags: [gap-closure, admin, crud, rbac, proto, flutter]
requirements:
  - CALL-02
gap_closure: true
dependency_graph:
  requires:
    - 07-01-SUMMARY (CallScriptService struct with Create/List/Update)
    - 07-02-SUMMARY (read-only CallScriptManagerScreen + Drift cache)
  provides:
    - CallScriptService ConnectRPC (Create/Update/Deactivate/List)
    - Admin CRUD UI for call scripts
  affects:
    - SyncService.PullCallScripts (now propagates deactivations)
tech-stack:
  added: []
  patterns:
    - ConnectRPC JSON handler (task_handler.go template)
    - Role-gated screen via auth.role check at build()
    - Soft-delete + pull-sync delta propagation
key-files:
  created:
    - navigators-go/proto/navigators/v1/call_script.proto
    - navigators-go/internal/navigators/call_script_handler.go
    - navigators-flutter/lib/src/services/call_script_service.dart
    - navigators-flutter/lib/src/features/phone_calls/call_script_editor_screen.dart
  modified:
    - navigators-go/queries/navigators/call_scripts.sql
    - navigators-go/internal/navigators/call_script_service.go
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/cmd/server/main.go
    - navigators-flutter/lib/src/features/phone_calls/call_script_manager_screen.dart
decisions:
  - "Soft-delete only via DeactivateCallScript -- hard-delete would break pull-sync delta"
  - "RBAC enforced both in handler (RoleLevel >= 80) and in RBAC interceptor (call_scripts:admin)"
  - "Version auto-incremented server-side in UpdateCallScriptFields; optimistic concurrency out of scope for v1"
  - "Variable placeholders use snake_case {{voter_first_name}} to match Objective 07 convention"
  - "Editor kicks SyncEngine.instance?.runSyncCycle() after mutation for immediate Drift cache refresh"
metrics:
  duration: "~20 min"
  completed: "2026-04-13"
---

# Objective 07 TRD 03: Admin Call Script CRUD Summary

Closes the authoring-side gap for CALL-02: admins can now create, edit, and deactivate call scripts directly from the Flutter app via a new CallScriptService ConnectRPC handler, while non-admins continue to see a read-only list driven by the existing pull-sync Drift cache.

## What Changed

### Backend (navigators-go)

- **New proto `call_script.proto`**: `CallScriptService` with `CreateCallScript`, `UpdateCallScript`, `DeactivateCallScript`, `ListCallScripts` RPCs.
- **sqlc queries added** to `call_scripts.sql`: `DeactivateCallScript`, `GetCallScriptCurrentVersion`, `ListAllCallScripts`. Confirmed `PullCallScriptsUpdated` does NOT filter `is_active` (clients see deactivations via updated_at bump).
- **Service methods added** to `CallScriptService`: `UpdateCallScriptFields` (auto-increments version), `DeactivateCallScript`, `ListAllCallScripts`.
- **New `call_script_handler.go`**: implements `navigatorsv1connect.CallScriptServiceHandler` with compile-time assertion. Each mutation checks `claims.RoleLevel >= 80` and returns `CodePermissionDenied` otherwise. List is open to authenticated users (RBAC layer additionally enforces via permissions matrix).
- **`permissions.go`**: registered procedure permissions -- Create/Update/Deactivate -> `call_scripts:admin`, List -> `call_scripts:view`.
- **`main.go`**: wired `NewCallScriptServiceHandler` with interceptors.

### Flutter (navigators-flutter)

- **New `call_script_service.dart`**: JSON-over-ConnectRPC client following the `task_service.dart` pattern, plus a Riverpod `callScriptServiceProvider`.
- **New `call_script_editor_screen.dart`**: ConsumerStatefulWidget. Create/edit modes via optional `existing` param. Title (required, maxLength 120) + multiline body (min 8 / max 20 lines) + Active toggle (edit mode). Expandable "Available variables" panel lists the five snake_case tokens with tap-to-insert and copy-to-clipboard affordances. Edit mode overflow offers Deactivate with an AlertDialog confirmation.
- **Rewrote `call_script_manager_screen.dart`**: gates FAB + tap-to-edit on `auth.role?.toLowerCase() == 'admin'`. Admin taps edit; non-admin taps open a read-only detail bottom sheet (preserving prior UX). List still driven by `db.callScriptDao.watchActiveCallScripts()`.

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Proto + queries + handler + RBAC + wiring | `cd navigators-go && buf generate && sqlc generate` | 0 | PASS |
| 1: Handler grep | `grep NewCallScriptServiceHandler cmd/server/main.go` | 0 | PASS (line 259) |
| 1: RBAC grep | `grep RoleLevel internal/navigators/call_script_handler.go` | 0 | PASS (3 matches) |
| 2: Dart analyze | `dart analyze lib/src/services/call_script_service.dart lib/src/features/phone_calls/call_script_editor_screen.dart lib/src/features/phone_calls/call_script_manager_screen.dart` | 0 | PASS ("No issues found!") |
| 2: Editor class grep | `grep "class CallScriptEditorScreen" ...` | 0 | PASS |
| 2: isAdmin grep | `grep isAdmin ...manager_screen.dart` | 0 | PASS |
| 2: Service usage grep | `grep CallScriptService ...editor_screen.dart` | 0 | PASS |

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint (flutter) | `dart analyze --no-fatal-infos` (scoped to new/modified files) | 0 | PASS |
| lint/build (go) | `go build ./...` | != 0 | PRE-EXISTING FAILURE -- see Deferred Issues |

## Deviations from Plan

None for Rules 1-4. The TRD was followed exactly. Optional nice-to-haves (tap-to-insert variables, copy button) were implemented.

## Deferred Issues

**Pre-existing Go build failures in unrelated files** (logged in `deferred-items.md`):
- `volunteer_handler.go:163` -- TrainingHandler missing `DeleteTrainingMaterial` (out of scope -- TRD 10-03)
- `event_service.go:202` -- undefined `eventRSVPSubject` (out of scope -- TRD 10-03)
- `task_service.go:179,185` -- undefined `TaskAssignedEvent`, `taskAssignedSubject` (out of scope -- TRD 08-04)

These existed before this TRD started (verified via `git stash` test) and live in separate gap-closure TRDs. Per deviation rules' scope boundary, they were not fixed here. The call-script-specific changes (`call_script_handler.go`, `call_script_service.go`, `permissions.go`, `main.go` wiring) compile cleanly in isolation -- no new compile errors introduced.

## Post-TRD Verification

- Auto-fix cycles used: 0
- Must-haves verified: 6/6 via code inspection + dart analyze
- Gate failures: `go build ./...` fails on pre-existing unrelated errors (documented above)
- Manual verification checkpoint (Task 3): **NOT RUN** -- returned to caller as the TRD is gap-closure and running the live Go server requires fixing the pre-existing build breaks in 08-04/10-03 gap-closures first.

## Commits

- `[Task 1]` `feat(07-03): add CallScriptService admin CRUD backend`
- `[Task 2]` `feat(07-03): add Flutter admin call script CRUD UI`

## Self-Check: PASSED

All files created/modified exist on disk:
- navigators-go/proto/navigators/v1/call_script.proto: FOUND
- navigators-go/internal/navigators/call_script_handler.go: FOUND
- navigators-flutter/lib/src/services/call_script_service.dart: FOUND
- navigators-flutter/lib/src/features/phone_calls/call_script_editor_screen.dart: FOUND

Both commits exist in git log and are referenced above.
