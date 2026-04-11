# Objective 7: Phone Calls + Scripts - Research

**Researched:** 2026-04-10
**Domain:** Flutter click-to-call, call scripts, post-call disposition logging
**Confidence:** HIGH

## Summary

Objective 7 adds phone calling capability to the Navigators app. This is a straightforward objective that leverages the native phone dialer (no VoIP) via the `url_launcher` package already in the project. The primary work involves: (1) launching calls via `tel:` URI scheme, (2) a new call script model (admin-created, synced to devices like survey forms), (3) a post-call disposition flow modeled directly after the existing door knock disposition pattern, and (4) integration with the unified contact timeline which already handles `phone` contact type entries.

The existing codebase provides strong patterns to follow. The `ContactLogs` table already supports `contactType: 'phone'`, the timeline service already renders phone entries with a blue phone icon, and the outbox sync pattern is well-established. The main new work is the call script data model, a call-in-progress screen showing the script, and the disposition form UI.

**Primary recommendation:** Model the phone call flow after `DoorKnockScreen` -- a stepped flow of disposition -> sentiment -> notes, using `contactType: 'phone'` with phone-specific disposition values (answered, voicemail, no_answer, refused, busy). Use a manual "I'm done with the call" button rather than a phone state detection plugin (avoids permissions complexity and unreliable third-party plugins). Call scripts follow the same admin-created, pull-synced pattern as `SurveyForms`.

<phase_requirements>
## Objective Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CALL-01 | Navigator can initiate call to voter via native phone dialer (click-to-call) | url_launcher already in pubspec (v6.3.0), tel: scheme via `launchUrl(Uri.parse('tel:$phone'))`, walk_list_screen.dart shows existing launchUrl pattern |
| CALL-02 | Navigator completes post-call disposition form (answered/voicemail/no answer/refused) | Follows DoorKnockScreen stepped-flow pattern exactly; new CallDisposition enum with phone-specific values; reuses sentiment widget (EdenRating) and NoteInputWidget |
| CALL-03 | Admin can create call scripts displayed to Navigator during calls | New call_scripts table (mirrors survey_forms pattern), pull-synced via SyncService, displayed on call-in-progress screen with voter context interpolation |
| CALL-04 | Call disposition includes voter sentiment and free-text notes | ContactLogs table already has sentiment (1-5) and notes columns; reuse existing EdenRating and NoteInputWidget components |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| url_launcher | ^6.3.0 | Launch tel: URI to native dialer | Already in project, official Flutter team package |
| drift | ^2.32.1 | Local DB for call scripts + contact logs | Already in project, powers all offline storage |
| flutter_riverpod | ^2.6.1 | State management for call flow | Already in project, all services use this pattern |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| eden_ui_flutter | local | EdenRating, EdenBadge, EdenAlert, EdenEmptyState | All UI components throughout call flow |

### NOT Needed
| Library | Why Not |
|---------|---------|
| flutter_phone_call_state | Adds Android/iOS permissions (READ_PHONE_STATE), unreliable across devices, third-party maintenance risk. Manual "call ended" button is simpler and more reliable. |
| phone_state | Same issues as above. Not worth the permissions overhead for this use case. |
| Any VoIP SDK | Out of scope per requirements. CALL-05/CALL-06 (power dialer, VoIP) are deferred to Advanced Outreach. |

## Architecture Patterns

### Recommended Project Structure
```
navigators-flutter/lib/src/
  features/
    phone_calls/
      phone_call_screen.dart        # Main call flow (script + disposition)
      call_disposition_sheet.dart    # 2x2 grid of phone dispositions
      call_script_widget.dart        # Renders script with voter context
  services/
    phone_call_service.dart          # Business logic (mirrors door_knock_service.dart)
  database/
    tables/
      call_scripts.dart              # Drift table definition
    daos/
      call_script_dao.dart           # CRUD + sync for call scripts

navigators-go/
  migrations/navigators/
    014_phone_calls.up.sql           # call_scripts table + call_status column on contact_logs
    014_phone_calls.down.sql
  proto/navigators/v1/
    sync.proto                       # Add PullCallScripts RPC + SyncCallScript message
```

### Pattern 1: Phone Call Flow (mirrors DoorKnockScreen)
**What:** Stepped flow: initiate call -> show script during call -> disposition -> sentiment -> notes -> save
**When to use:** When navigator taps "Call" on a voter
**Flow:**
```
1. Navigator taps phone number / call button on voter detail or walk list
2. App launches tel: URI -> native dialer opens
3. App shows PhoneCallScreen with call script + voter context
4. Navigator reads script while on call
5. Navigator taps "Call Ended" button when done
6. Disposition step: answered / voicemail / no_answer / refused / busy
7. If answered: sentiment (1-5) -> notes -> save
8. If not answered: quick-save and pop (same as door knock non-answer pattern)
```

### Pattern 2: Call Script Model (mirrors SurveyForms)
**What:** Admin-created scripts stored as structured content, pull-synced to devices
**When to use:** Displaying talking points during a call
**Schema concept:**
```dart
class CallScripts extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get title => text()();           // e.g., "General Voter Outreach"
  TextColumn get content => text()();         // Markdown or structured JSON
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### Pattern 3: Contact Log Reuse
**What:** Phone calls write to the same `contact_logs` table with `contactType: 'phone'`
**Why:** The timeline service already handles `phone` type entries. No new tables needed for the log itself.
**Key difference from door knock:** Uses `call_status` instead of `door_status` for phone-specific dispositions.

### Pattern 4: Voter Context in Script
**What:** Display voter-relevant info alongside the script (name, party, last contact, sentiment history)
**Implementation:** The PhoneCallScreen receives voterId, loads voter data via existing `voterDetailProvider`, and renders context cards above/alongside the script text.

### Anti-Patterns to Avoid
- **Phone state detection plugin:** Adds READ_PHONE_STATE permission on Android, requires background service, unreliable on iOS. A manual "Call Ended" button is simpler and works 100% of the time.
- **Blocking UI until call ends:** The native dialer takes focus; when the user returns to the app, the script screen should still be visible. Don't try to detect the exact moment the call ends.
- **Separate call log table:** Don't create a new table for phone call logs. The `contact_logs` table already supports `contactType: 'phone'` with sentiment and notes. Add a `call_status` column for phone-specific disposition values.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Phone dialing | Custom telephony integration | `url_launcher` tel: scheme | Native dialer handles all carrier/permission complexity |
| Offline sync | Custom sync for call data | Existing outbox pattern (SyncDao.writeWithOutbox) | Already battle-tested for door knocks, notes, surveys |
| Sentiment capture | Custom rating widget | Existing EdenRating widget | Already used in door knock flow, consistent UX |
| Note input | Custom text field | Existing NoteInputWidget | Already handles visibility toggle (private/team/org) |
| Timeline rendering | Custom phone call timeline | Existing TimelineService._contactLogToTimeline | Already maps `contactType: 'phone'` to blue phone icon |

**Key insight:** 80% of this objective is reusing existing patterns. The door knock flow is nearly identical -- the main difference is the call script display and phone-specific disposition values.

## Common Pitfalls

### Pitfall 1: tel: URI Not Working on Simulators
**What goes wrong:** `canLaunchUrl` returns false on iOS Simulator (no Phone app)
**Why it happens:** iOS simulators don't have a phone app installed
**How to avoid:** Test on physical devices. In dev, skip the `canLaunchUrl` check or show a snackbar explaining simulator limitation. Don't gate the disposition flow on successful call launch.
**Warning signs:** Tests pass on simulator but fail to launch calls

### Pitfall 2: Android Intent Visibility (API 30+)
**What goes wrong:** `canLaunchUrl` returns false on Android 11+ even when phone app exists
**Why it happens:** Android package visibility restrictions require declaring queried schemes
**How to avoid:** Add `<queries><intent><action android:name="android.intent.action.DIAL" /><data android:scheme="tel" /></intent></queries>` to AndroidManifest.xml
**Warning signs:** Works on older Android, fails on Android 11+

### Pitfall 3: Empty Phone Numbers
**What goes wrong:** App launches tel: with empty string, native dialer opens with no number
**Why it happens:** Not all voters have phone numbers in the data
**How to avoid:** Disable/hide the call button when `voter.phone` is empty. Show "No phone number available" state.
**Warning signs:** Call button visible for voters without phone data

### Pitfall 4: Call Script Not Synced
**What goes wrong:** Navigator goes to call a voter but no script is available (offline, not yet synced)
**Why it happens:** Call scripts are admin-created and pull-synced. If sync hasn't run, scripts may not be on device.
**How to avoid:** Handle null script gracefully (show "No script available" with option to proceed without script). Include call scripts in the sync manifest check.
**Warning signs:** First-time users see blank script screen

### Pitfall 5: Losing Call Context on App Resume
**What goes wrong:** User makes call, native dialer takes focus, when they return to the app the call screen state is lost
**Why it happens:** Flutter app lifecycle -- app may be paused/stopped while native dialer is active
**How to avoid:** PhoneCallScreen should persist its state. The screen stays in the navigation stack. Use `WidgetsBindingObserver` if needed to detect app resume and restore state.
**Warning signs:** User returns from call and sees the previous screen instead of the script/disposition flow

## Code Examples

### Launching a Phone Call
```dart
// Source: Existing pattern in walk_list_screen.dart (line 184-186)
import 'package:url_launcher/url_launcher.dart';

Future<void> _initiateCall(String phoneNumber) async {
  final uri = Uri.parse('tel:$phoneNumber');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    // Show error - no phone app available (simulator or tablet)
  }
}
```

### Phone Call Disposition Enum
```dart
// Mirrors DoorDisposition pattern from door_disposition_sheet.dart
enum CallDisposition {
  answered('answered', 'Answered', Icons.phone_in_talk, Colors.green),
  voicemail('voicemail', 'Voicemail', Icons.voicemail, Colors.blue),
  noAnswer('no_answer', 'No Answer', Icons.phone_missed, Colors.grey),
  refused('refused', 'Refused', Icons.phone_disabled, Colors.red),
  busy('busy', 'Busy', Icons.phone_locked, Colors.orange);

  const CallDisposition(this.value, this.label, this.icon, this.color);

  final String value;
  final String label;
  final IconData icon;
  final Color color;
}
```

### Saving Phone Call Contact Log (follows door knock service pattern)
```dart
// Source: Mirrors door_knock_service.dart saveDoorKnockSession pattern
await _db.contactLogDao.insertContactLogWithOutbox(
  ContactLogsCompanion(
    id: Value(contactLogId),
    voterId: Value(session.voterId),
    turfId: Value(session.turfId),
    userId: Value(_userId),
    contactType: const Value('phone'),
    outcome: Value(_callStatusToOutcome(session.callStatus)),
    notes: Value(session.notes),
    doorStatus: Value(session.callStatus), // Reuse column or add call_status
    sentiment: Value(session.sentiment),
    createdAt: Value(now),
  ),
  syncDao,
);
```

### Migration: Call Scripts Table + Call Status
```sql
-- 014_phone_calls.up.sql
-- Call scripts table (admin-created, pull-synced to devices)
CREATE TABLE call_scripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    title TEXT NOT NULL,
    content TEXT NOT NULL DEFAULT '',
    version INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_call_scripts_company ON call_scripts (company_id, is_active);

-- Extend contact_logs door_status CHECK to include phone-specific values
-- (or add a separate call_status column)
ALTER TABLE contact_logs DROP CONSTRAINT IF EXISTS contact_logs_door_status_check;
ALTER TABLE contact_logs ADD CONSTRAINT contact_logs_door_status_check
    CHECK (door_status IN ('', 'answered', 'not_home', 'refused', 'moved', 'inaccessible',
                           'voicemail', 'no_answer', 'busy'));
```

**Design decision -- door_status reuse vs. new column:** The `door_status` column name is door-knock-specific, but it already functions as a "sub-disposition" field. Two options:
1. **Reuse door_status** -- simpler, no schema change on local Drift table, just extend the CHECK constraint. Timeline and outbox already handle it.
2. **Add call_status column** -- cleaner semantically but requires Drift table change, DAO update, outbox payload update, sync proto update.

**Recommendation:** Rename approach -- add a migration that renames `door_status` to `interaction_status` (or just reuse `door_status` as-is for pragmatism, since it's an internal field name). The simplest path is to reuse `door_status` with the extended CHECK constraint. The column name is an internal detail that doesn't surface in the UI.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phone state detection plugins | Manual "call ended" button | Industry trend | Avoids permissions, works reliably across all devices |
| VoIP in-app calling | Native dialer via tel: scheme | N/A for this scope | CALL-05/CALL-06 deferred to future objective |
| Custom call script formats | Simple text/markdown + voter variable interpolation | N/A | Keep it simple; rich script editors are premature |

**Deprecated/outdated:**
- `phone_state` plugin: Last meaningful update was 2025, sparse maintenance, Android-only reliability
- `flutter_phone_call_state`: Works but adds unnecessary complexity for this use case

## Open Questions

1. **Call script content format**
   - What we know: Survey forms use JSON schema. Call scripts are simpler -- mostly text with optional sections.
   - What's unclear: Should scripts support variable interpolation (e.g., "Hello {{voter.firstName}}")? Should they have sections/steps or be a single block of text?
   - Recommendation: Start with plain text content with simple `{{variable}}` interpolation for voter fields. Can add structured sections later if needed.

2. **door_status column reuse vs. new column**
   - What we know: `door_status` column works as a sub-disposition field for any contact type
   - What's unclear: Whether future contact types will also need sub-dispositions
   - Recommendation: Reuse `door_status` as-is. The column name is internal. Extending the CHECK constraint is the simplest path. If it becomes a problem later, a rename migration is trivial.

3. **Admin UI for call script creation**
   - What we know: Survey forms have admin creation (Objective 5). Call scripts need similar admin CRUD.
   - What's unclear: Whether admin UI should be in this objective or deferred
   - Recommendation: Include basic admin CRUD for call scripts in this objective (CALL-03 explicitly requires it). Follow the survey form admin pattern.

## Sources

### Primary (HIGH confidence)
- Existing codebase: `door_knock_screen.dart`, `door_knock_service.dart`, `door_disposition_sheet.dart` -- direct patterns to follow
- Existing codebase: `contact_logs.dart` table -- already supports `contactType: 'phone'`
- Existing codebase: `timeline_service.dart` -- already renders phone entries (line 77-79)
- Existing codebase: `sync_dao.dart` -- `writeWithOutbox` pattern for offline-first writes
- Existing codebase: `survey_forms.dart` -- pattern for admin-created, pull-synced content
- Existing codebase: `walk_list_screen.dart` -- existing `url_launcher` usage pattern (line 3, 184-186)
- pubspec.yaml: `url_launcher: ^6.3.0` already present

### Secondary (MEDIUM confidence)
- [url_launcher pub.dev](https://pub.dev/packages/url_launcher) -- tel: scheme documentation, platform configuration requirements
- [Flutter phone call state plugins](https://pub.dev/packages/flutter_phone_call_state) -- evaluated and rejected in favor of manual button

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all libraries already in project, no new dependencies needed
- Architecture: HIGH - directly mirrors existing door knock patterns in the codebase
- Pitfalls: HIGH - tel: scheme behavior is well-documented, main risks are platform-config and empty data issues
- Call script model: MEDIUM - new data model, but follows established survey_forms pattern closely

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (stable domain, no fast-moving dependencies)
