# Objective 8: Tasks + Collaboration - Research

**Researched:** 2026-04-10
**Domain:** Task management, auto-progress tracking, push notifications (FCM), NATS event consumers
**Confidence:** HIGH

## Summary

Objective 8 adds two interconnected capabilities: (1) a task management system where Admins and Super Navigators create, assign, and track tasks linked to voters/turfs/lists, and (2) push notifications via Firebase Cloud Messaging (FCM) for task reminders, new assignments, and sync alerts.

The task system follows existing codebase patterns: PostgreSQL tables with sqlc queries, ConnectRPC service handlers, RBAC-gated endpoints, and Drift-based offline sync. The key new concept is auto-progress tracking (TASK-04), where a NATS JetStream consumer listens for contact_log events and updates task completion percentages. This mirrors the existing `SMSWorker` pattern -- a durable consumer on a JetStream stream with explicit ack.

Push notifications leverage the eden platform's existing `notification.Dispatcher` interface and `device_tokens` table (migration 008). The navigators project needs to: (a) implement the `Dispatcher` interface using Firebase Admin Go SDK (`firebase.google.com/go/v4/messaging`), (b) add `firebase_messaging` + `firebase_core` to the Flutter app for token retrieval and message handling, and (c) wire a NATS consumer that dispatches FCM messages when task events fire.

**Primary recommendation:** Implement tasks as a new `tasks` table with a polymorphic `linked_entity_type`/`linked_entity_id` pattern for linking to turfs/voters/lists. Use a dedicated NATS stream (`NAVIGATORS_TASKS`) with subjects for task events and progress updates. Implement FCM via the eden `notification.Dispatcher` interface with a Firebase Admin SDK backend. Emit NATS events on contact_log inserts (requires adding a publish call in `processContactLog`) that the task progress consumer uses to recalculate completion.

<phase_requirements>
## Objective Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TASK-01 | Admin/Super Nav can create tasks and assign to Navigators | `tasks` + `task_assignments` tables; ConnectRPC `TaskService` with RBAC at Manager level (60) for create/assign |
| TASK-02 | Tasks link to voter lists, turfs, or specific voters | Polymorphic `linked_entity_type` enum ('turf', 'voter', 'voter_list') + `linked_entity_id` on tasks table; `task_voters` junction table for list-type tasks |
| TASK-03 | Tasks have types, due dates, priority | `task_type` enum ('contact_list', 'event', 'data_entry', 'custom'), `due_date TIMESTAMPTZ`, `priority` enum ('low', 'medium', 'high', 'urgent') on tasks table |
| TASK-04 | System auto-updates task progress based on linked voter contacts | NATS consumer on `navigators.contact_log.created` subject; recalculates `completed_count / total_count` for linked tasks; updates `tasks.progress_pct` |
| TASK-05 | Navigator can add notes to tasks | `task_notes` table with `visibility` matching existing `voter_notes` pattern ('team', 'org'); synced via existing PullSync/PushSync |
| PUSH-01 | Push notifications for task reminders (upcoming due dates) | Cron-like NATS timer or Go ticker that queries tasks with `due_date` within 24h; dispatches FCM via eden `notification.Dispatcher` |
| PUSH-02 | Push notifications for new turf/task assignments | NATS event on task/turf assignment; FCM consumer sends to assignee's device tokens |
| PUSH-03 | Alert Navigator when unsynced data exists and connectivity available | Flutter-side: check `sync_operations` outbox count on connectivity change; show local notification via `flutter_local_notifications` -- no server FCM needed |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `firebase.google.com/go/v4` | latest (v4.x) | Firebase Admin SDK for Go | Official Google SDK; provides `messaging.Client` for FCM send |
| `firebase.google.com/go/v4/messaging` | (part of above) | FCM message construction and dispatch | Typed `Message`, `MulticastMessage`, `Notification` structs |
| `firebase_core` | ^3.x | Firebase initialization in Flutter | Required foundation for all Firebase Flutter plugins |
| `firebase_messaging` | ^15.x | FCM token retrieval and message handling in Flutter | Official FlutterFire plugin; handles foreground/background/terminated states |
| `flutter_local_notifications` | ^18.x | Display foreground notifications + PUSH-03 local alerts | Standard Flutter library for showing OS notifications when app is in foreground |
| `github.com/nats-io/nats.go` | v1.50.0 (already in go.mod) | Event streaming for task progress + notification dispatch | Existing project dependency; JetStream provides durable consumers |
| `connectrpc.com/connect` | v1.19.1 (already in go.mod) | RPC handlers for TaskService | Existing project pattern |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `google.golang.org/api/option` | (transitive via firebase) | Service account credential loading | Firebase Admin SDK initialization with `GOOGLE_APPLICATION_CREDENTIALS` |
| `drift` | ^2.32.1 (already in pubspec) | Local SQLite for task offline storage | Existing offline pattern; add `tasks`, `task_assignments`, `task_notes` tables |
| `workmanager` | ^0.9.0+3 (already in pubspec) | Background task reminder checks | Already used for periodic sync; can check pending notifications |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| FCM | OneSignal | FCM is free, official, eden already has `device_tokens` table and `Dispatcher` interface |
| NATS event-driven progress | Database polling | NATS already in project; event-driven is real-time vs polling delay |
| Polymorphic linked entity | Separate FK columns | Polymorphic is cleaner; separate nullables would need 3 nullable FK columns |

**Installation (Go):**
```bash
cd navigators-go && go get firebase.google.com/go/v4@latest
```

**Installation (Flutter):**
```bash
cd navigators-flutter
flutter pub add firebase_core firebase_messaging flutter_local_notifications
dart pub global activate flutterfire_cli
flutterfire configure  # links Firebase project, generates firebase_options.dart
```

## Architecture Patterns

### Recommended Project Structure

**Go Backend:**
```
navigators-go/
  internal/navigators/
    task_service.go          # Task CRUD + assignment logic
    task_handler.go          # ConnectRPC handler
    task_worker.go           # NATS consumer: progress tracking + notification dispatch
    notification_service.go  # FCM dispatcher implementing eden notification.Dispatcher
  migrations/navigators/
    015_tasks.up.sql          # tasks, task_assignments, task_voters, task_notes
  queries/navigators/
    tasks.sql                 # sqlc queries for task CRUD + progress
  proto/navigators/v1/
    task.proto                # TaskService RPC definitions
```

**Flutter Frontend:**
```
navigators-flutter/lib/src/
  database/tables/
    tasks.dart                # Drift table definition
    task_assignments.dart
    task_notes.dart
  database/daos/
    task_dao.dart             # Drift DAO for task queries
  services/
    task_service.dart         # Business logic + API calls
    notification_service.dart # FCM init, token management, message handling
  features/tasks/
    task_list_screen.dart     # Task inbox for Navigator
    task_detail_screen.dart   # Task detail with progress + notes
    task_create_screen.dart   # Admin/Super Nav task creation form
  sync/
    pull_sync.dart            # Extended: pull tasks, task_assignments, task_notes
    push_sync.dart            # Extended: push task_notes
```

### Pattern 1: Task Progress via NATS Event Consumer

**What:** When a contact_log is created (via PushSyncBatch or direct API), publish a NATS event. A durable consumer recalculates progress for any task linked to the contacted voter.

**When to use:** TASK-04 auto-progress tracking.

**Example (Go):**
```go
// In sync_service.go processContactLog(), after successful insert:
if s.js != nil {
    event := ContactLogCreatedEvent{
        CompanyID: companyID.String(),
        VoterID:   voterID.String(),
        TurfID:    turfID.String(),
        UserID:    userID.String(),
    }
    data, _ := json.Marshal(event)
    s.js.Publish(ctx, "navigators.contact_log.created", data)
}
```

```go
// In task_worker.go, consuming the event:
func (w *TaskWorker) processContactLogCreated(ctx context.Context, msg jetstream.Msg) error {
    var event ContactLogCreatedEvent
    json.Unmarshal(msg.Data(), &event)

    // Find all active tasks linked to this voter or their turf
    tasks, _ := w.queries.GetTasksLinkedToVoter(ctx, db.GetTasksLinkedToVoterParams{
        VoterID:   event.VoterID,
        TurfID:    event.TurfID,
        CompanyID: event.CompanyID,
    })

    for _, task := range tasks {
        // Recalculate progress: count contacts / total linked voters
        w.queries.RecalculateTaskProgress(ctx, task.ID)
    }
    return nil
}
```

### Pattern 2: FCM Push Notification Dispatch

**What:** Implement eden's `notification.Dispatcher` interface with Firebase Admin SDK. The task worker publishes notification events to NATS; a notification consumer dispatches via FCM.

**When to use:** PUSH-01, PUSH-02 (server-side push).

**Example (Go):**
```go
// notification_service.go
type FCMDispatcher struct {
    client *messaging.Client
    store  notification.NotificationStore
}

func NewFCMDispatcher(app *firebase.App, store notification.NotificationStore) (*FCMDispatcher, error) {
    ctx := context.Background()
    client, err := app.Messaging(ctx)
    if err != nil {
        return nil, fmt.Errorf("create FCM client: %w", err)
    }
    return &FCMDispatcher{client: client, store: store}, nil
}

func (d *FCMDispatcher) SendPush(ctx context.Context, tokens []notification.DeviceTokenRecord, title, body string, data map[string]string) error {
    if len(tokens) == 0 {
        return nil
    }
    tokenStrings := make([]string, len(tokens))
    for i, t := range tokens {
        tokenStrings[i] = t.Token
    }
    msg := &messaging.MulticastMessage{
        Notification: &messaging.Notification{Title: title, Body: body},
        Data:         data,
        Tokens:       tokenStrings,
    }
    br, err := d.client.SendEachForMulticast(ctx, msg)
    if err != nil {
        return fmt.Errorf("FCM multicast: %w", err)
    }
    // Clean up invalid tokens
    if br.FailureCount > 0 {
        for i, resp := range br.Responses {
            if !resp.Success && messaging.IsRegistrationTokenNotRegistered(resp.Error) {
                d.store.DeleteDeviceToken(ctx, tokenStrings[i], tokens[i].UserID)
            }
        }
    }
    return nil
}

func (d *FCMDispatcher) IsEnabled() bool { return d.client != nil }
```

### Pattern 3: Flutter FCM Token Registration

**What:** On app start, get FCM token and register with server. Listen for token refresh.

**When to use:** All push notification features.

**Example (Dart):**
```dart
// notification_service.dart
class NotificationService {
  Future<void> initialize() async {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);

      FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
    }

    // Foreground message handling
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background handler (registered in main.dart as top-level function)
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Handle notification tap (app was terminated)
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);

    // Handle notification tap (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  Future<void> _registerToken(String token) async {
    // POST to server: register device token for current user
    await _apiClient.registerDeviceToken(token, Platform.isIOS ? 'ios' : 'android');
  }
}
```

### Pattern 4: PUSH-03 Local Sync Alert (No Server FCM)

**What:** PUSH-03 is entirely client-side. When connectivity resumes and the outbox has pending operations, show a local notification prompting the user to sync.

**When to use:** PUSH-03 specifically.

**Example (Dart):**
```dart
// In sync_scheduler.dart, on connectivity change:
if (_wasDisconnected && isConnected) {
  _wasDisconnected = false;
  final pendingCount = await db.syncDao.getPendingCount();
  if (pendingCount > 0) {
    await _showLocalNotification(
      'Data Ready to Sync',
      '$pendingCount changes waiting to upload',
    );
  }
  // Then trigger sync as before
  await SyncEngine.instance?.runSyncCycle();
}
```

### Anti-Patterns to Avoid
- **Polling for task progress:** Do not poll the database on a timer to check if voters have been contacted. Use NATS events from contact_log creation. The SMS worker already proves this pattern works.
- **FCM for PUSH-03:** Do not send a server push just to tell the client it has local unsynced data. The client already knows -- check the outbox.
- **Storing FCM tokens in navigators tables:** Use the eden `device_tokens` table that already exists. Do not create a duplicate.
- **Single-device token assumption:** Users may have multiple devices (phone + tablet). Always send to ALL tokens for a user via `SendEachForMulticast`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| FCM message dispatch | Custom HTTP calls to FCM API | `firebase.google.com/go/v4/messaging` | Token validation, retry logic, error classification (expired tokens vs. server errors), multicast batching |
| Device token storage | Custom `fcm_tokens` table in navigators | Eden `device_tokens` table + `notification.NotificationStore` | Already exists in eden migration 008; queries already generated |
| Token lifecycle | Manual token expiry tracking | FCM SDK response + `IsRegistrationTokenNotRegistered` | Firebase handles token rotation; SDK tells you which tokens are dead |
| Foreground notification display | Custom overlay widget | `flutter_local_notifications` | OS-native notification tray, badge counts, sound, vibration |
| Background message handler | Custom isolate management | `firebase_messaging` + `@pragma('vm:entry-point')` | Flutter framework handles isolate creation, Firebase SDK handles delivery |

**Key insight:** The eden platform already did the hard work -- `device_tokens` table, `NotificationStore` interface, `Dispatcher` interface. The navigators project just needs to wire the Firebase implementation and add the token registration RPC.

## Common Pitfalls

### Pitfall 1: FCM Token Not Available on iOS Without APNS
**What goes wrong:** `getToken()` returns null on iOS because APNS token hasn't been provisioned.
**Why it happens:** FCM on iOS requires a valid APNS token first. Simulators don't have APNS.
**How to avoid:** Check `getAPNSToken()` before calling `getToken()`. Only test push on physical iOS devices. Add retry with delay if APNS token isn't ready yet.
**Warning signs:** Token is always null on iOS simulator.

### Pitfall 2: Background Handler Must Be Top-Level
**What goes wrong:** `onBackgroundMessage` handler crashes or is never called.
**Why it happens:** Flutter runs the background handler in a separate isolate. It cannot reference instance variables, closures, or non-top-level functions.
**How to avoid:** Annotate with `@pragma('vm:entry-point')` and ensure it's a top-level function. Call `Firebase.initializeApp()` inside the handler since it's a fresh isolate.
**Warning signs:** Works in foreground, never fires in background.

### Pitfall 3: Progress Calculation Race Conditions
**What goes wrong:** Multiple simultaneous contact_log events for the same task cause incorrect progress counts.
**Why it happens:** Two NATS messages processed concurrently both read stale progress values.
**How to avoid:** Use a SQL-based recalculation (`UPDATE tasks SET progress_pct = (SELECT count... )`) rather than increment/decrement. The SQL query is always correct regardless of concurrency.
**Warning signs:** Progress percentage occasionally jumps or goes backward.

### Pitfall 4: Firebase Service Account Credentials in Production
**What goes wrong:** FCM fails with authentication errors in production.
**Why it happens:** `GOOGLE_APPLICATION_CREDENTIALS` env var not set, or service account JSON not deployed.
**How to avoid:** Add `GOOGLE_APPLICATION_CREDENTIALS` to deployment config pointing to service account key file. For containerized deployments, mount the key as a secret.
**Warning signs:** FCM works locally but fails in CI/staging/prod.

### Pitfall 5: Stale FCM Tokens Causing Send Failures
**What goes wrong:** FCM returns errors for tokens that are no longer valid (user uninstalled app, switched devices).
**Why it happens:** Tokens are registered but never cleaned up.
**How to avoid:** After every `SendEachForMulticast`, iterate `BatchResponse.Responses` and delete tokens where `messaging.IsRegistrationTokenNotRegistered(err)` is true.
**Warning signs:** Growing failure count in FCM sends over time.

## Code Examples

### Database Schema: Tasks (migration 015)
```sql
-- Source: Designed based on existing codebase patterns (contact_logs, turf_assignments)

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

-- For contact_list tasks: the set of voters to contact
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
```

### Progress Recalculation Query
```sql
-- Source: Pattern based on existing campaign completion check in sms_worker.go

-- name: RecalculateTaskProgress :exec
UPDATE tasks SET
    completed_count = sub.contacted,
    progress_pct = CASE WHEN sub.total = 0 THEN 0 ELSE (sub.contacted * 100 / sub.total) END,
    status = CASE WHEN sub.contacted >= sub.total AND sub.total > 0 THEN 'completed' ELSE status END,
    updated_at = now()
FROM (
    SELECT task_id, count(*) AS total, count(*) FILTER (WHERE is_contacted) AS contacted
    FROM task_voters WHERE task_id = $1 GROUP BY task_id
) sub
WHERE tasks.id = sub.task_id AND tasks.id = $1;
```

### Firebase Admin SDK Initialization (Go)
```go
// Source: https://firebase.google.com/docs/admin/setup
// In main.go, after NATS setup:

import (
    firebase "firebase.google.com/go/v4"
    "google.golang.org/api/option"
)

// Firebase init (GOOGLE_APPLICATION_CREDENTIALS env var must be set)
firebaseApp, err := firebase.NewApp(ctx, nil)
if err != nil {
    slog.Warn("Firebase init failed, push notifications disabled", "error", err)
}

var fcmDispatcher *navpkg.FCMDispatcher
if firebaseApp != nil {
    fcmDispatcher, err = navpkg.NewFCMDispatcher(firebaseApp, pgBackend.DeviceTokenStore())
    if err != nil {
        slog.Warn("FCM dispatcher init failed", "error", err)
    }
}
```

### NATS Stream Setup for Tasks
```go
// Source: Pattern from sms_worker.go

const (
    taskStreamName          = "NAVIGATORS_TASKS"
    contactLogCreatedSubject = "navigators.contact_log.created"
    taskAssignedSubject      = "navigators.task.assigned"
    taskReminderSubject      = "navigators.task.reminder"
)

// In TaskWorker.Start():
_, err := w.js.CreateOrUpdateStream(ctx, jetstream.StreamConfig{
    Name:     taskStreamName,
    Subjects: []string{"navigators.task.>", "navigators.contact_log.>"},
    Storage:  jetstream.FileStorage,
})
```

### Token Registration RPC Endpoint
```go
// In a DeviceTokenHandler or extend AdminHandler:
func (h *Handler) RegisterDeviceToken(ctx context.Context, req *connect.Request[...]) (...) {
    userID, _ := server.ExtractUserID(ctx)
    // Use eden's CreateDeviceToken query
    err := h.queries.CreateDeviceToken(ctx, db.CreateDeviceTokenParams{
        UserID:   userID,
        Token:    req.Msg.Token,
        Platform: req.Msg.Platform,
    })
    // ...
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| FCM legacy HTTP API | FCM HTTP v1 API | 2024 | Legacy deprecated June 2024; Admin SDK uses v1 automatically |
| `Send()` for batch | `SendEach()` / `SendEachForMulticast()` | 2024 | `SendAll()` and `SendMulticast()` deprecated; replaced by `SendEach` variants |
| `firebase_messaging` auto-init | Explicit `requestPermission()` | 2023+ | iOS requires explicit permission request; Android 13+ requires runtime permission |

**Deprecated/outdated:**
- `messaging.Client.SendAll()` -- use `SendEach()` instead
- `messaging.Client.SendMulticast()` -- use `SendEachForMulticast()` instead
- FCM legacy server key -- use service account credentials with Admin SDK

## Open Questions

1. **Eden `DeviceTokenStore` accessor**
   - What we know: Eden has `device_tokens` migration, sqlc queries, and `notification.NotificationStore` interface
   - What's unclear: Whether `pgBackend` exposes a `DeviceTokenStore()` method or if navigators needs to call the generated sqlc queries directly
   - Recommendation: Check eden `pgstore.Backend` methods. If no accessor exists, call eden's generated `db.Queries` directly for device token operations, or add an accessor to eden

2. **Firebase project configuration**
   - What we know: Need a Firebase project with FCM enabled, service account key JSON
   - What's unclear: Whether a Firebase project already exists for the Navigators app
   - Recommendation: Create Firebase project during implementation if needed; configure `flutterfire configure` to generate `firebase_options.dart`

3. **Task sync to offline devices**
   - What we know: Tasks need to be available offline for Navigators to see their assignments
   - What's unclear: Whether tasks should use the existing PullSync cursor pattern or a separate sync mechanism
   - Recommendation: Extend existing PullSync with `PullTasks` and `PullTaskNotes` RPCs, matching the existing `PullSurveyForms`/`PullVoterNotes` pattern exactly

## Sources

### Primary (HIGH confidence)
- `firebase.google.com/go/v4/messaging` - Go SDK struct definitions, Send/SendEach/SendEachForMulticast APIs verified via pkg.go.dev
- Firebase official docs: [Send messages with Admin SDK](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk) - Go code examples
- Firebase official docs: [Flutter FCM setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started) - token retrieval, permissions
- Firebase official docs: [Receive messages in Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages) - foreground/background handlers
- Eden platform codebase: `platform/notification/notification.go` - `Dispatcher` and `NotificationStore` interfaces
- Eden platform codebase: `migrations/platform/008_device_tokens.up.sql` - device_tokens table schema
- Eden platform codebase: `queries/platform/device_tokens.sql` - CreateDeviceToken, GetDeviceTokens, DeleteDeviceToken queries
- Navigators codebase: `internal/navigators/sms_worker.go` - NATS JetStream consumer pattern (stream creation, durable consumers, ack/nak)
- Navigators codebase: `internal/navigators/sync_service.go` - PushSyncBatch processing, contact_log entity handling
- Navigators codebase: `internal/navigators/permissions.go` - RBAC matrix pattern, procedure permission mapping

### Secondary (MEDIUM confidence)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) - pub.dev listing, community standard for local notifications
- [FlutterFire Notifications docs](https://firebase.flutter.dev/docs/messaging/notifications/) - foreground display recommendations

### Tertiary (LOW confidence)
- None -- all findings verified against official docs or existing codebase

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Firebase Admin SDK and flutter packages well-documented; eden platform already provides device_tokens infrastructure
- Architecture: HIGH - Task patterns directly mirror existing SMS worker, contact_logs, and sync service patterns in the codebase
- Pitfalls: HIGH - FCM token lifecycle and background handler constraints are well-documented in official docs; progress race condition is a standard DB pattern
- Push notifications: HIGH - Eden platform already has interfaces; Firebase Admin Go SDK is stable and official

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (stable domain -- FCM and NATS are mature)
