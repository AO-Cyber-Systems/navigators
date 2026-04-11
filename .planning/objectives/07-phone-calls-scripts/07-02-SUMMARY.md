---
objective: 07-phone-calls-scripts
job: "02"
subsystem: ui
tags: [flutter, phone, url-launcher, riverpod, drift, offline-first]

# Dependency graph
requires:
  - objective: 07-phone-calls-scripts/07-01
    provides: "CallScript Drift table, CallScriptDao, pull sync for call scripts, door_status CHECK extension"
  - objective: 05-door-knocking
    provides: "DoorKnockScreen pattern, DoorDispositionSheet pattern, DoorKnockService pattern, NoteInputWidget, EdenRating"
provides:
  - "PhoneCallScreen with full call flow (dialer launch, script display, disposition, sentiment, notes)"
  - "CallDispositionSheet with 5 phone-specific dispositions"
  - "CallScriptWidget with {{voter.*}} variable interpolation"
  - "PhoneCallService for saving phone call sessions via outbox sync"
  - "CallScriptManagerScreen for admin script viewing"
  - "Voter detail call button integration"
  - "Timeline phone-specific disposition labels"
affects: [08-reporting-analytics, voter-detail]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Phone call screen mirrors door knock step-based flow with calling step prepended"
    - "tel: URI scheme via url_launcher for click-to-call"
    - "Script variable interpolation via simple string replacement"

key-files:
  created:
    - "navigators-flutter/lib/src/features/phone_calls/phone_call_screen.dart"
    - "navigators-flutter/lib/src/features/phone_calls/call_disposition_sheet.dart"
    - "navigators-flutter/lib/src/features/phone_calls/call_script_widget.dart"
    - "navigators-flutter/lib/src/features/phone_calls/call_script_manager_screen.dart"
    - "navigators-flutter/lib/src/services/phone_call_service.dart"
  modified:
    - "navigators-flutter/android/app/src/main/AndroidManifest.xml"
    - "navigators-flutter/lib/src/features/voters/voter_detail_screen.dart"
    - "navigators-flutter/lib/src/services/timeline_service.dart"

key-decisions:
  - "CallScriptManagerScreen is read-only (view synced scripts) since no ConnectRPC handler exists for create/update yet"
  - "Phone call screen launches dialer immediately on open, does not gate flow on dialer success"
  - "Phone flow has 4 steps (calling, disposition, sentiment, notes) vs door knock 4 (disposition, sentiment, survey, notes)"

patterns-established:
  - "Phone call flow pattern: launch dialer -> show script -> Call Ended button -> disposition -> save"
  - "Script variable interpolation: {{voter.firstName}} etc via simple replaceAll"

requirements-completed: [CALL-01, CALL-02, CALL-04]

# Verification evidence
verification:
  gates_defined: 1
  gates_passed: 1
  auto_fix_cycles: 0
  tdd_evidence: false
  test_pairing: false

# Metrics
duration: 7min
completed: 2026-04-11
---

# Objective 7 TRD 02: Flutter Call UI + Script Display + Disposition Summary

**Phone call screen with click-to-call dialer launch, script display with voter variable interpolation, 5-option disposition flow, and timeline integration**

## Performance

- **Duration:** 7 min
- **Started:** 2026-04-11T17:48:14Z
- **Completed:** 2026-04-11T17:55:16Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- PhoneCallScreen with full flow: launch dialer via tel: URI, script display during call, Call Ended button, disposition, sentiment, notes, save
- CallDispositionSheet with 5 phone-specific dispositions (answered, voicemail, no_answer, refused, busy) in 2-column grid
- CallScriptWidget rendering scripts with {{voter.firstName}}, {{voter.lastName}}, {{voter.party}}, {{voter.address}} interpolation
- PhoneCallService saving phone call sessions to contact_logs with outbox sync (contactType: 'phone')
- Voter detail screen phone IconButton navigating to PhoneCallScreen when voter has phone number
- Timeline enhanced with phone-specific disposition labels and colors
- CallScriptManagerScreen for admin viewing of synced scripts with detail bottom sheet
- AndroidManifest.xml updated with tel: intent query for Android 11+

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: PhoneCallService, CallDisposition, AndroidManifest, call script widget | `cd navigators-flutter && dart analyze lib/src/services/phone_call_service.dart lib/src/features/phone_calls/call_disposition_sheet.dart lib/src/features/phone_calls/call_script_widget.dart` | 0 | PASS |
| 2: PhoneCallScreen, call script manager, voter detail integration, timeline enhancement | `cd navigators-flutter && dart analyze lib/src/features/phone_calls/phone_call_screen.dart lib/src/features/phone_calls/call_script_manager_screen.dart lib/src/features/voters/voter_detail_screen.dart lib/src/services/timeline_service.dart` | 0 | PASS |

## Task Commits

Each task was committed atomically:

1. **Task 1: PhoneCallService, CallDisposition, AndroidManifest, call script widget** - `2a10c1e` (feat)
2. **Task 2: PhoneCallScreen, call script manager, voter detail integration, timeline enhancement** - `f2cc952` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-flutter && dart analyze` | 0 | PASS (0 errors; 12 pre-existing info/warnings in other files) |

## Post-TRD Verification

- **Auto-fix cycles used:** 0
- **Must-haves verified:** 5/5
- **Gate failures:** None

## Files Created/Modified
- `navigators-flutter/lib/src/features/phone_calls/phone_call_screen.dart` - Main call flow screen (calling, disposition, sentiment, notes steps)
- `navigators-flutter/lib/src/features/phone_calls/call_disposition_sheet.dart` - 5 phone dispositions in 2-column grid
- `navigators-flutter/lib/src/features/phone_calls/call_script_widget.dart` - Script display with voter variable interpolation
- `navigators-flutter/lib/src/features/phone_calls/call_script_manager_screen.dart` - Admin read-only script viewer
- `navigators-flutter/lib/src/services/phone_call_service.dart` - Phone call session save with outbox sync
- `navigators-flutter/android/app/src/main/AndroidManifest.xml` - Added tel: intent query
- `navigators-flutter/lib/src/features/voters/voter_detail_screen.dart` - Added phone IconButton in AppBar
- `navigators-flutter/lib/src/services/timeline_service.dart` - Phone disposition-specific labels and colors

## Decisions Made
- CallScriptManagerScreen is read-only (lists scripts synced from server) since no ConnectRPC handler exists for CreateCallScript/UpdateCallScript RPCs. Admin creates scripts server-side; they sync to devices via pull sync.
- Phone call screen launches dialer immediately on open via launchUrl, does not gate the rest of the flow on dialer success (canLaunchUrl fails on simulators)
- Phone flow has calling step (script display) before disposition, unlike door knock which starts at disposition
- Used crossAxisCount: 2 for disposition grid (5 items = 3 rows, last row has 1 centered card)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] CallScriptManagerScreen adapted to read-only**
- **Found during:** Task 2 (CallScriptManagerScreen)
- **Issue:** TRD specified using ConnectRPC calls for CreateCallScript/UpdateCallScript, but no RPC handler or proto definition exists for these methods
- **Fix:** Made the screen read-only, listing scripts from local DB (synced via pull sync) with detail bottom sheet for viewing full content
- **Files modified:** navigators-flutter/lib/src/features/phone_calls/call_script_manager_screen.dart
- **Verification:** dart analyze passes
- **Committed in:** f2cc952

---

**Total deviations:** 1 auto-fixed (1 blocking issue)
**Impact on plan:** Admin can view scripts but cannot create/edit from Flutter app until server RPC endpoints are added. Scripts are created server-side and sync to devices.

## Issues Encountered
None beyond the missing server RPC handler noted above.

## Next Objective Readiness
- Objective 07 complete: call scripts backend (TRD 01) and Flutter call UI (TRD 02) both done
- Phone call data flows through existing outbox sync pipeline
- Ready for Objective 08 (Reporting & Analytics)

---
*Objective: 07-phone-calls-scripts*
*Completed: 2026-04-11*
