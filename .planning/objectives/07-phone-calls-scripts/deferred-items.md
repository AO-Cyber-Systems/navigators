# Deferred Items -- Discovered during 07-03 execution

Pre-existing build errors in unrelated files (NOT caused by 07-03 changes):

1. `internal/navigators/volunteer_handler.go:163` -- TrainingHandler missing DeleteTrainingMaterial method (from prior objective gap-closure WIP)
2. `internal/navigators/event_service.go:202` -- undefined `eventRSVPSubject` (from prior objective gap-closure WIP)
3. `internal/navigators/task_service.go:179,185` -- undefined `TaskAssignedEvent`, `taskAssignedSubject` (from prior objective gap-closure WIP)

These live in separate TRD scopes (events, tasks, training gap closures: 08-04, 10-03) and are out of scope for 07-03 (call scripts). The call_script_handler.go, call_script_service.go, permissions.go, and main.go changes for 07-03 compile cleanly in isolation.
