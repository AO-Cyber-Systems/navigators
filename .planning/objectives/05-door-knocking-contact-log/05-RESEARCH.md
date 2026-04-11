# Objective 5: Door Knocking + Contact Log - Research

**Researched:** 2026-04-10
**Domain:** Offline-first field canvassing (Flutter + Go), survey forms, contact timeline
**Confidence:** HIGH

## Summary

Objective 5 builds door knocking and contact logging on top of a mature existing foundation. Objectives 1-4 delivered: walk list generation with nearest-neighbor ordering (`walk_list.go`), walk list screen with map toggle (`walk_list_screen.dart`), Drift local database with encrypted SQLite, a full outbox-based sync system (`sync_operations` table, `PushSync`, `SyncService.PushSyncBatch`), and contact logs with basic outcome tracking (migration 009). The existing `ContactLogs` table already has `contactType`, `outcome`, and `notes` fields with sync support via `insertContactLogWithOutbox`.

The work divides into four layers: (1) enhance the walk list screen into an active canvassing workflow with door disposition recording, (2) build a configurable survey form system stored as JSON schema, (3) add voter notes with role-scoped visibility, and (4) create a unified contact timeline per voter. All new entity types follow the established pattern: Drift table + DAO with outbox transaction + server-side migration + PushSyncBatch entity handler + pull sync endpoint.

**Primary recommendation:** Extend the existing `contact_logs` table with `sentiment` and `door_status` columns; add new `survey_forms`, `survey_responses`, and `voter_notes` tables. Store survey form definitions as JSON schema in PostgreSQL `jsonb` column. Render forms dynamically in Flutter using the existing eden form widgets. Follow the exact outbox sync pattern already proven in `ContactLogDao.insertContactLogWithOutbox`.

<phase_requirements>
## Objective Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DOOR-01 | Navigator can view ordered walk list with map view | Walk list screen already exists with list/map toggle. Enhance with door status indicators and "knock next" navigation flow. |
| DOOR-02 | Navigator can record door status (not home/answered/refused/moved) | Add `door_status` column to contact_logs. Existing outcome field partially covers this but conflates disposition with support level. Separate concerns. |
| DOOR-03 | Admin can create configurable at-the-door survey forms | New `survey_forms` table with JSON schema definition. Admin UI for form builder. Render dynamically in Flutter. |
| DOOR-04 | Navigator can complete survey forms offline | New `survey_responses` table + DAO with outbox sync. Store responses as JSON blob keyed to form version. |
| DOOR-05 | System tracks door-knock attempts per voter with timestamp history | Contact logs already track per-voter with timestamps. Add query for attempt count and history view. |
| NOTE-01 | Navigator can add free-text notes to any voter | New `voter_notes` table separate from contact_logs. Notes are standalone, not tied to a contact event. |
| NOTE-02 | System maintains unified contact timeline per voter | Query across contact_logs, voter_notes, and survey_responses ordered by timestamp. EdenTimeline widget for display. |
| NOTE-03 | Note visibility follows role hierarchy | Add `visibility` column to voter_notes. Filter by role level in queries. Navigator=own, Super Nav=team, Admin=all. |
| NOTE-04 | Navigator can record voter sentiment | Add `sentiment` column to contact_logs (integer 1-5 scale). EdenRating widget for input. |
</phase_requirements>

## Standard Stack

### Core (Already in Project)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Drift | 2.x | Local SQLite ORM with reactive streams | Already used for voters, contact_logs, sync_operations |
| flutter_riverpod | 2.x | State management + DI | Already used throughout app |
| flutter_map | 7.x | Map display for walk list | Already used in walk_list_screen.dart |
| eden_ui_flutter | local | UI components (EdenTimeline, EdenRating, EdenForm, EdenBottomSheet, EdenActivityFeed) | Project UI library |
| eden_platform_flutter | local | Auth, platform shell | Already integrated |
| sqlc + pgx | latest | Go server SQL generation | Already used for all server queries |
| ConnectRPC | latest | Go RPC framework | Already used for all server endpoints |

### New Dependencies Required
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| uuid | 4.x | Client-generated UUIDs for offline entities | Already a transitive dep via existing code |

### No New Dependencies Needed

All requirements can be met with existing dependencies. The eden UI library provides `EdenTimeline`, `EdenRating`, `EdenActivityFeed`, `EdenForm`, `EdenFormWizard`, `EdenBottomSheet`, and `EdenStepper` -- sufficient for all UI needs.

## Architecture Patterns

### Recommended Project Structure
```
navigators-flutter/lib/src/
  database/
    tables/
      contact_logs.dart        # MODIFY: add door_status, sentiment columns
      survey_forms.dart        # NEW: survey form definitions (JSON schema)
      survey_responses.dart    # NEW: completed survey responses
      voter_notes.dart         # NEW: free-text notes with visibility
    daos/
      contact_log_dao.dart     # MODIFY: add queries for door knock history
      survey_dao.dart          # NEW: form CRUD + response storage
      voter_note_dao.dart      # NEW: notes CRUD with role filtering
  features/
    door_knocking/
      door_knock_screen.dart       # NEW: at-the-door interaction screen
      door_disposition_sheet.dart  # NEW: bottom sheet for quick door status
      survey_form_renderer.dart    # NEW: dynamic form from JSON schema
      contact_timeline_widget.dart # NEW: unified timeline per voter
    voters/
      voter_detail_screen.dart     # MODIFY: add timeline tab, notes, sentiment
  services/
    door_knock_service.dart        # NEW: business logic for canvassing workflow

navigators-go/
  migrations/navigators/
    012_door_knocking.up.sql       # NEW: door_status, sentiment on contact_logs; survey tables; voter_notes
  internal/
    navigators/
      survey_service.go            # NEW: survey form CRUD
      voter_notes_service.go       # NEW: notes with visibility filtering
      sync_service.go              # MODIFY: add survey_response and voter_note entity handlers
    db/
      survey_forms.sql             # NEW: sqlc queries
      voter_notes.sql              # NEW: sqlc queries
```

### Pattern 1: Outbox Sync for New Entity Types
**What:** Every new offline-writable entity follows the same pattern as ContactLog
**When to use:** For survey_responses and voter_notes -- any data created offline

The existing pattern (proven, working):
```dart
// In the DAO:
Future<void> insertWithOutbox(
  SurveyResponsesCompanion response,
  SyncDao syncDao,
) async {
  await syncDao.writeWithOutbox(
    attachedDatabase,
    dataWrite: () async {
      await into(surveyResponses).insert(response);
    },
    entityType: 'survey_response',
    entityId: response.id.value,
    operationType: 'create',
    payload: {
      'id': response.id.value,
      'voter_id': response.voterId.value,
      'form_id': response.formId.value,
      'turf_id': response.turfId.value,
      'responses': response.responsesJson.value,
      'created_at': response.createdAt.value.toIso8601String(),
    },
  );
}
```

Server-side handler in `SyncService.PushSyncBatch` switch:
```go
case "survey_response":
    err = s.processSurveyResponse(ctx, companyID, userID, op)
case "voter_note":
    err = s.processVoterNote(ctx, companyID, userID, op)
```

### Pattern 2: JSON Schema Survey Forms
**What:** Store survey form definitions as JSON in a `jsonb` column. Render dynamically in Flutter.
**When to use:** DOOR-03 configurable survey forms

```json
{
  "version": 1,
  "title": "Voter Contact Survey",
  "fields": [
    {
      "id": "support_level",
      "type": "single_select",
      "label": "Support Level",
      "required": true,
      "options": [
        {"value": "strong_support", "label": "Strong Support"},
        {"value": "lean_support", "label": "Lean Support"},
        {"value": "undecided", "label": "Undecided"},
        {"value": "lean_oppose", "label": "Lean Oppose"},
        {"value": "strong_oppose", "label": "Strong Oppose"}
      ]
    },
    {
      "id": "issues",
      "type": "multi_select",
      "label": "Top Issues",
      "required": false,
      "options": [
        {"value": "economy", "label": "Economy"},
        {"value": "education", "label": "Education"},
        {"value": "healthcare", "label": "Healthcare"}
      ]
    },
    {
      "id": "notes",
      "type": "text",
      "label": "Additional Notes",
      "required": false,
      "maxLength": 500
    }
  ]
}
```

Field types to support: `single_select`, `multi_select`, `text`, `number`, `boolean`. Branching logic deferred (not in requirements, adds significant complexity).

### Pattern 3: Role-Scoped Visibility for Notes
**What:** Filter notes by role hierarchy using existing RBAC levels
**When to use:** NOTE-03

```sql
-- Server-side query: filter by visibility
SELECT * FROM voter_notes
WHERE voter_id = $1
  AND company_id = $2
  AND (
    -- Admin sees all
    $3 >= 80
    -- Super Nav sees own team
    OR ($3 >= 60 AND user_id IN (SELECT navigator_id FROM team_assignments WHERE super_navigator_id = $4))
    -- Navigator sees own
    OR user_id = $4
  )
ORDER BY created_at DESC;
```

Flutter-side: pull sync already scopes by turf. For notes, add a `PullVoterNotes` endpoint that filters by role.

### Pattern 4: Unified Contact Timeline
**What:** Merge contact_logs + voter_notes + survey_responses into a single chronological view
**When to use:** NOTE-02

```dart
// In Flutter: merge multiple streams into a single timeline
class TimelineEntry {
  final String id;
  final String type; // 'door_knock', 'note', 'survey', 'phone', 'text'
  final DateTime timestamp;
  final String actorName;
  final String summary;
  final Map<String, dynamic>? details;
}

// Query each table, merge, sort by timestamp
Stream<List<TimelineEntry>> watchVoterTimeline(String voterId) {
  // Combine contact logs + notes + survey responses
  // Use Drift's custom select or combine streams with Rx
}
```

Display using `EdenTimeline` widget (title, body, datetime, icon, iconColor per entry type).

### Anti-Patterns to Avoid
- **Putting survey responses in contact_logs.notes:** Structured survey data must be queryable. Use a separate `survey_responses` table with JSON responses column.
- **Creating a single monolithic "interaction" table:** Keep contact_logs, voter_notes, and survey_responses separate. They have different schemas, different sync behavior, and different access patterns. Unify at the query/view layer only.
- **Storing door disposition as a new table:** Door status is a property of a contact log entry (type=door_knock). Add `door_status` column to existing `contact_logs` table.
- **Building a custom form renderer from scratch:** Use Eden's `EdenForm` and `EdenSelect`/`EdenInput` widgets. Map JSON schema field types to Eden widgets.
- **Complex branching logic in v1:** Requirements say "configurable forms" not "conditional logic forms". Keep field definitions flat. Branching can be added later via `show_if` conditions in the JSON schema.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Timeline display | Custom timeline widget | `EdenTimeline` from eden-ui-flutter | Already styled, handles date grouping, icons, colors |
| Sentiment rating | Custom star/scale widget | `EdenRating` from eden-ui-flutter | Handles accessibility, half-stars, size variants |
| Activity feed | Custom feed with grouping | `EdenActivityFeed` from eden-ui-flutter | Date grouping, type filters, pagination, mention support |
| Bottom sheet for disposition | Custom modal | `EdenBottomSheet.show()` | Drag handle, title bar, actions row, proper sizing |
| Form validation | Manual validation logic | `EdenValidators.compose()` | Required, minLength, maxLength, pattern all built-in |
| Multi-step form | Custom page view | `EdenFormWizard` | Step indicators, validation, animated transitions |
| Offline sync outbox | New sync mechanism | Existing `SyncDao.writeWithOutbox()` | Proven pattern, handles transactions, already integrated |
| UUID generation | Custom ID scheme | `uuid` package (already in project) | Standard, collision-resistant client IDs |

**Key insight:** The eden UI library has an exceptionally rich widget set. Nearly every UI component needed (timeline, rating, activity feed, form wizard, bottom sheet) already exists. The sync infrastructure is fully built. This objective is primarily about data modeling and wiring, not infrastructure.

## Common Pitfalls

### Pitfall 1: Conflating Door Status with Voter Outcome
**What goes wrong:** The existing `contact_logs.outcome` field mixes door-level dispositions (`not_home`, `refused`, `moved`) with voter sentiment (`support`, `oppose`, `undecided`). This makes analytics queries ambiguous -- is "not_home" an outcome or a non-contact?
**Why it happens:** The original schema was designed before the door knocking workflow was fully specified.
**How to avoid:** Add a separate `door_status` column for the door-level result. Keep `outcome` for actual voter interaction results. Only populate `outcome` when `door_status` is `answered`.
**Warning signs:** Analytics queries that filter `WHERE outcome != 'not_home'` to get real contacts.

### Pitfall 2: Survey Form Schema Versioning
**What goes wrong:** Admin updates a survey form, but offline Navigators still have the old version cached. Their responses don't match the new schema. Or worse, responses reference deleted field IDs.
**Why it happens:** Survey forms are synced to devices but can change server-side between syncs.
**How to avoid:** Version survey forms. Responses store the `form_version` they were collected against. Never delete old form versions -- mark as inactive. Sync pulls the latest active form version.
**Warning signs:** Survey responses with field IDs that don't match any form definition.

### Pitfall 3: Drift Schema Migration Complexity
**What goes wrong:** Adding columns to the existing `ContactLogs` Drift table requires a schema migration in both PostgreSQL (server) and SQLite (client). Forgetting either causes crashes.
**Why it happens:** Dual-database architecture (PostgreSQL server + SQLite client).
**How to avoid:** Always create migrations in pairs. Server: `012_door_knocking.up.sql`. Client: increment `schemaVersion` in `database.dart` and add migration step in `onUpgrade`. Test both migration paths.
**Warning signs:** App crashes on startup after update with "no such column" SQLite errors.

### Pitfall 4: Note Visibility Leaking Through Sync
**What goes wrong:** All notes sync to all devices in the turf, exposing notes that should be role-restricted.
**Why it happens:** Pull sync is turf-scoped, not role-scoped.
**How to avoid:** Server-side `PullVoterNotes` endpoint MUST filter by role before returning. The client never receives notes it shouldn't see. Don't rely on client-side filtering for security.
**Warning signs:** Navigator device contains notes from other navigators in SQLite.

### Pitfall 5: Walk List Screen Becoming Overloaded
**What goes wrong:** Cramming door disposition, survey form, notes, timeline, and navigation all into `walk_list_screen.dart` creates a 1000+ line unmaintainable widget.
**Why it happens:** Walk list is the natural entry point for canvassing, tempting to add everything there.
**How to avoid:** Walk list screen shows the ordered list with status indicators. Tapping a voter opens a dedicated `door_knock_screen.dart` that handles the full interaction flow (disposition -> survey -> notes -> save). Use bottom sheets for quick actions.
**Warning signs:** Walk list screen file exceeds 400 lines.

### Pitfall 6: Survey Form Renderer Performance
**What goes wrong:** Rendering a survey form with 20+ fields in a bottom sheet or modal causes jank, especially on older Android devices.
**Why it happens:** Building all form fields eagerly in a Column.
**How to avoid:** Use `ListView.builder` for form fields. Consider `EdenFormWizard` for multi-step surveys (group related fields into steps). Keep individual survey forms to 10-15 fields max (admin guidance).
**Warning signs:** Frame drops when opening survey form on low-end devices.

## Code Examples

### Door Knock Contact Log with Outbox (Drift + Sync)
```dart
// Extends existing ContactLogDao pattern
Future<void> recordDoorKnock({
  required String voterId,
  required String turfId,
  required String userId,
  required String doorStatus, // 'answered', 'not_home', 'refused', 'moved'
  String? outcome, // only when doorStatus == 'answered'
  int? sentiment, // 1-5 scale, only when answered
  String notes = '',
}) async {
  final id = const Uuid().v4();
  final now = DateTime.now();
  
  final log = ContactLogsCompanion(
    id: Value(id),
    voterId: Value(voterId),
    turfId: Value(turfId),
    userId: Value(userId),
    contactType: const Value('door_knock'),
    doorStatus: Value(doorStatus),
    outcome: Value(outcome ?? ''),
    sentiment: Value(sentiment),
    notes: Value(notes),
    createdAt: Value(now),
  );
  
  await contactLogDao.insertContactLogWithOutbox(log, syncDao);
}
```

### Survey Form Schema (PostgreSQL)
```sql
CREATE TABLE survey_forms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    schema JSONB NOT NULL,  -- JSON schema defining fields
    version INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE survey_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    form_id UUID NOT NULL REFERENCES survey_forms(id),
    form_version INT NOT NULL,
    voter_id UUID NOT NULL REFERENCES voters(id),
    user_id UUID NOT NULL REFERENCES users(id),
    turf_id UUID REFERENCES turfs(id),
    contact_log_id UUID REFERENCES contact_logs(id), -- links response to the door knock
    responses JSONB NOT NULL,  -- {"field_id": "value", ...}
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_survey_responses_voter ON survey_responses (voter_id);
CREATE INDEX idx_survey_responses_form ON survey_responses (form_id);
```

### Voter Notes Table (PostgreSQL)
```sql
CREATE TABLE voter_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    voter_id UUID NOT NULL REFERENCES voters(id),
    user_id UUID NOT NULL REFERENCES users(id),
    turf_id UUID REFERENCES turfs(id),
    content TEXT NOT NULL,
    visibility TEXT NOT NULL DEFAULT 'team' CHECK (visibility IN ('private', 'team', 'org')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_voter_notes_voter ON voter_notes (voter_id);
CREATE INDEX idx_voter_notes_company ON voter_notes (company_id, created_at DESC);
```

### Contact Log Schema Changes (PostgreSQL Migration)
```sql
-- Add door_status and sentiment to existing contact_logs table
ALTER TABLE contact_logs 
    ADD COLUMN door_status TEXT NOT NULL DEFAULT '' 
        CHECK (door_status IN ('', 'answered', 'not_home', 'refused', 'moved', 'inaccessible'));

ALTER TABLE contact_logs 
    ADD COLUMN sentiment INT CHECK (sentiment IS NULL OR (sentiment >= 1 AND sentiment <= 5));
```

### Drift Table Definitions (Flutter)
```dart
// survey_forms.dart
class SurveyForms extends Table {
  TextColumn get id => text()();
  TextColumn get companyId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get schema => text()(); // JSON string
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// survey_responses.dart
class SurveyResponses extends Table {
  TextColumn get id => text()();
  TextColumn get formId => text()();
  IntColumn get formVersion => integer()();
  TextColumn get voterId => text()();
  TextColumn get userId => text()();
  TextColumn get turfId => text()();
  TextColumn get contactLogId => text().nullable()();
  TextColumn get responsesJson => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// voter_notes.dart
class VoterNotes extends Table {
  TextColumn get id => text()();
  TextColumn get voterId => text()();
  TextColumn get userId => text()();
  TextColumn get turfId => text()();
  TextColumn get content => text()();
  TextColumn get visibility => text().withDefault(const Constant('team'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### Dynamic Survey Form Renderer
```dart
/// Renders a survey form from JSON schema.
/// Maps field types to Eden UI widgets.
Widget buildSurveyField(Map<String, dynamic> field) {
  switch (field['type']) {
    case 'single_select':
      return EdenSelect(
        label: field['label'],
        options: (field['options'] as List).map((o) => 
          EdenSelectOption(value: o['value'], label: o['label'])
        ).toList(),
        onChanged: (value) => _responses[field['id']] = value,
      );
    case 'multi_select':
      return EdenMultiSelect(
        label: field['label'],
        options: (field['options'] as List).map((o) =>
          EdenSelectOption(value: o['value'], label: o['label'])
        ).toList(),
        onChanged: (values) => _responses[field['id']] = values,
      );
    case 'text':
      return EdenInput(
        label: field['label'],
        maxLength: field['maxLength'],
        onChanged: (value) => _responses[field['id']] = value,
      );
    case 'number':
      return EdenInput(
        label: field['label'],
        keyboardType: TextInputType.number,
        onChanged: (value) => _responses[field['id']] = value,
      );
    case 'boolean':
      return EdenToggle(
        label: field['label'],
        onChanged: (value) => _responses[field['id']] = value,
      );
    default:
      return const SizedBox.shrink();
  }
}
```

### Unified Timeline Query
```dart
/// Watch all interactions for a voter, merged into timeline entries.
Stream<List<TimelineEntry>> watchVoterTimeline(String voterId) {
  final contactStream = contactLogDao.watchContactLogsForVoter(voterId);
  final noteStream = voterNoteDao.watchNotesForVoter(voterId);
  // survey responses loaded eagerly since they're less frequent
  
  return Rx.combineLatest2(contactStream, noteStream, (contacts, notes) {
    final entries = <TimelineEntry>[
      ...contacts.map((c) => TimelineEntry(
        id: c.id,
        type: c.contactType,
        timestamp: c.createdAt,
        summary: _contactSummary(c),
        icon: _contactIcon(c.contactType),
      )),
      ...notes.map((n) => TimelineEntry(
        id: n.id,
        type: 'note',
        timestamp: n.createdAt,
        summary: n.content,
        icon: Icons.note,
      )),
    ];
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  });
}
```

### Door Knock Screen Flow (At-the-Door UX)
```
Walk List Screen
  |-- Tap voter -> Door Knock Screen
      |
      |-- Step 1: Door Disposition (bottom sheet, 4 big buttons)
      |   [Not Home] [Answered] [Refused] [Moved]
      |
      |-- If "Not Home" or "Refused" or "Moved":
      |   Quick save + advance to next voter in walk list
      |
      |-- If "Answered" -> Step 2: Quick Assessment
      |   Sentiment: [1] [2] [3] [4] [5] (EdenRating)
      |   
      |-- Step 3: Survey Form (if active survey assigned)
      |   Dynamic form from JSON schema
      |
      |-- Step 4: Notes (optional free text)
      |
      |-- Save All -> Return to walk list, auto-advance to next voter
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single outcome field mixing door status + sentiment | Separate door_status, outcome, and sentiment columns | This objective | Clean analytics, proper funnel tracking |
| Contact logs as only interaction record | Separate notes + survey responses + contact logs unified in timeline | This objective | Richer per-voter history |
| Static survey questions hardcoded in app | JSON schema survey forms configurable by admin | This objective | Campaigns can customize without app updates |

## Open Questions

1. **Survey Form Builder Admin UI**
   - What we know: Admin needs to create/edit survey forms with configurable fields
   - What's unclear: Should this be a web-only admin feature or available in the Flutter app? The existing admin screens (import, user management) are in Flutter.
   - Recommendation: Build in Flutter since all admin features are already there. Use `EdenFormWizard` for the builder flow -- step 1: form metadata, step 2: add/arrange fields, step 3: preview.

2. **Survey Form Sync Direction**
   - What we know: Survey forms are created by admins on server. Navigators need them locally for offline use.
   - What's unclear: Should forms be pulled during turf download or as a separate sync entity?
   - Recommendation: Add survey forms to the pull sync as a new entity type (`PullSurveyForms` endpoint). Include in the standard sync cycle. Forms are small (< 10KB each) so bandwidth is not a concern.

3. **Contact Log Migration Backward Compatibility**
   - What we know: Adding columns to `contact_logs` requires both server and client migration
   - What's unclear: Are there existing contact logs in production that need default values?
   - Recommendation: Use `DEFAULT ''` for `door_status` and `NULL` for `sentiment` on existing rows. Old contact logs without door_status are valid -- they were created before the door knocking workflow existed.

4. **Note Visibility Defaults**
   - What we know: Three levels needed (private, team, org)
   - What's unclear: What should the default be for notes created during door knocking?
   - Recommendation: Default to `team` visibility -- Super Navigators need to see their team's field notes. Allow override to `private` for sensitive observations. `org` requires explicit selection.

## Sources

### Primary (HIGH confidence)
- Existing codebase analysis: `contact_logs.dart`, `contact_log_dao.dart`, `sync_service.go`, `push_sync.dart` -- verified patterns for offline sync
- Existing codebase: `walk_list_screen.dart` -- current walk list implementation, map toggle, offline-first loading
- Existing codebase: `permissions.go` -- RBAC role levels (Member=40, Manager=60, Admin=80)
- Existing codebase: `database.dart` -- Drift database setup, schema versioning, encryption
- Eden UI library: `eden_timeline.dart`, `eden_rating.dart`, `eden_activity_feed.dart`, `eden_form.dart`, `eden_form_wizard.dart`, `eden_bottom_sheet.dart` -- verified widget availability and APIs
- PostgreSQL migration 009 -- existing contact_logs schema with CHECK constraints

### Secondary (MEDIUM confidence)
- JSON schema approach for survey forms -- standard pattern used by Typeform, Google Forms, SurveyJS; well-proven for dynamic form rendering
- Door canvassing UX patterns -- based on industry standard (MiniVAN, Reach by L2, ThruTalk) quick-tap disposition flows

### Tertiary (LOW confidence)
- None -- all recommendations grounded in existing codebase patterns and established approaches

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- using only existing project dependencies and eden UI library
- Architecture: HIGH -- following exact patterns proven in Objectives 1-4 (outbox sync, Drift tables, ConnectRPC endpoints)
- Pitfalls: HIGH -- identified from direct codebase analysis of dual-database architecture and existing sync system
- Survey form design: MEDIUM -- JSON schema approach is well-established but specific field type needs may evolve during implementation

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (stable -- all based on existing codebase, no external dependency changes expected)
