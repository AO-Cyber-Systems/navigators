# Architecture Patterns

**Domain:** Political voter outreach platform (canvassing, SMS, calls, offline-first)
**Researched:** 2026-04-10

## Recommended Architecture

Navigators is a **modular monolith** inside `eden-platform-go` with domain-separated packages that communicate through well-defined internal interfaces and NATS events. This is NOT microservices -- it is a single Go binary with logical service boundaries that can be extracted later if needed.

```
                    +-----------------------------------------+
                    |         Flutter App (Web/iOS/Android)    |
                    |  +----------+  +-------+  +-----------+ |
                    |  | Riverpod |  | Isar  |  | Mapbox GL | |
                    |  | State    |  | Local |  | + MBTiles | |
                    |  +----+-----+  +---+---+  +-----+-----+ |
                    |       |            |            |         |
                    |       +------+-----+            |         |
                    |              |                   |         |
                    |         Sync Engine              |         |
                    +-------------|-------------------|---------+
                                  | ConnectRPC (H2)   | HTTPS
                    +-------------|-------------------|---------+
                    |        API Layer (ConnectRPC)    |         |
                    |   Auth Interceptor (JWT + RBAC)  |         |
                    +-------------|-------------------|---------+
                    |                                           |
                    |          eden-platform-go                 |
                    |  (Modular Monolith -- domain packages)    |
                    |                                           |
                    |  +----------+  +----------+  +--------+  |
                    |  | voter/   |  | turf/    |  | outreach| |
                    |  | import   |  | spatial  |  | sms     | |
                    |  | search   |  | assign   |  | call    | |
                    |  | tag      |  | offline  |  | canvass | |
                    |  +----------+  +----------+  +--------+  |
                    |                                           |
                    |  +----------+  +----------+  +--------+  |
                    |  | task/    |  | analytics/| | sync/  |  |
                    |  | assign   |  | rollup   |  | engine |  |
                    |  | progress |  | export   |  | delta  |  |
                    |  +----------+  +----------+  +--------+  |
                    |                                           |
                    |  +----------+  +----------+  +--------+  |
                    |  | event/   |  | notify/  |  | audit/ |  |
                    |  | manage   |  | push     |  | log    |  |
                    |  | rsvp     |  | dispatch |  | trail  |  |
                    |  +----------+  +----------+  +--------+  |
                    |       |            |             |        |
                    +-------|------------|-------------|--------+
                            |            |             |
              +-------------+--+---------+--+----------+--+
              |                 |            |             |
     +--------v---+   +---------v--+  +------v----+  +----v------+
     | PostgreSQL |   |   NATS     |  |  MinIO    |  | External  |
     | + PostGIS  |   | JetStream  |  | (files,   |  | Services  |
     | (primary   |   | (events,   |  |  tiles)   |  | (SMS,     |
     |  store)    |   |  sync)     |  |           |  |  Geocode, |
     +------------+   +------------+  +-----------+  |  Mapbox)  |
                                                     +-----------+
```

### Why Modular Monolith, Not Microservices

1. **Team size:** Likely 1-3 developers. Microservices overhead (service discovery, distributed tracing, deploy pipelines per service) is unjustified.
2. **Shared data:** Voter, turf, and contact data are deeply interrelated. Cross-service joins would be constant in microservices.
3. **Deployment simplicity:** Single binary deploys to a single server or small cluster. Docker Compose is the target infrastructure.
4. **Future extraction path:** Domain packages with clean interfaces can be extracted to separate services if scale demands it (unlikely at 1M voters).

---

## 1. Service Decomposition (Domain Packages)

Each domain package owns its own sqlc queries, proto service definition, and NATS event publishing. Packages communicate through Go interfaces, not network calls.

### Core Domain Packages

| Package | Responsibility | Key Entities | Depends On |
|---------|---------------|--------------|------------|
| `voter` | Voter data lifecycle: import, merge/dedup, search, filter, tag | Voter, VoterTag, VoterHistory, ImportJob | PostGIS, MinIO |
| `turf` | Spatial boundaries, assignment, walk lists, offline tile packages | Turf, TurfAssignment, WalkList | PostGIS, voter |
| `outreach` | All voter contact channels: SMS, calls, door knocks | Conversation, Message, CallLog, DoorKnock, Survey, SurveyResponse | voter, sms provider |
| `task` | Task creation, assignment, progress tracking | Task, TaskAssignment, TaskTemplate | voter, turf |
| `sync` | Offline data packaging, delta sync, conflict resolution | SyncCheckpoint, SyncDelta, ConflictLog | voter, turf, outreach, task |
| `analytics` | Metric rollups, dashboards, export | MetricSnapshot, Report | voter, outreach, task |
| `event` | Volunteer events: canvass parties, phone banks | Event, EventRSVP, EventTurf | turf |
| `notify` | Push notifications, in-app alerts | Notification, NotificationPreference | FCM/APNs |
| `audit` | Immutable access/change log for compliance | AuditEntry | all packages |

### Cross-Cutting Concerns (Not Domain Packages)

| Concern | Implementation |
|---------|---------------|
| Auth/RBAC | ConnectRPC interceptor, JWT validation, role-based filtering. Already exists in eden-platform-go. |
| SMS Provider | `sms.Provider` interface behind outreach package. Concrete implementations: Twilio, Bandwidth. |
| Geocoding | `geo.Geocoder` interface. Implementations: Mapbox Geocoding API, Census Geocoder (free fallback). |
| File Storage | MinIO client shared via dependency injection. |

---

## 2. Data Model

### Entity Relationship Diagram (Core)

```
Organization (1)
  |
  +-- User (N) [role: admin | super_navigator | navigator]
  |     |
  |     +-- TeamMembership (super_nav -> navigators)
  |
  +-- ImportJob (N)
  |     |
  |     +-- ImportRow (N) [raw parsed rows]
  |
  +-- Voter (N)
  |     |-- voter_id (state-issued, PK for dedup)
  |     |-- name, address, yob, party, status
  |     |-- location (PostGIS POINT, from geocoding)
  |     |-- registration_date, voting_history (JSONB)
  |     |-- electoral_districts (JSONB: senate, house, county, town)
  |     |
  |     +-- VoterTag (N) [admin-defined tags]
  |     +-- ContactLog (N) [unified interaction timeline]
  |     |     |-- type: sms | call | door_knock
  |     |     |-- user_id (who contacted)
  |     |     |-- sentiment (5-point scale)
  |     |     |-- notes (text)
  |     |     |-- created_at, synced_at
  |     |     |-- source_id -> Message | CallLog | DoorKnock
  |     |
  |     +-- Conversation (N) [SMS threads]
  |           |-- phone_number
  |           +-- Message (N) [inbound + outbound]
  |                 |-- direction: inbound | outbound
  |                 |-- status: queued | sent | delivered | failed
  |                 |-- provider_message_id
  |
  +-- Turf (N)
  |     |-- boundary (PostGIS POLYGON)
  |     |-- name, description
  |     |-- status: draft | active | completed
  |     |
  |     +-- TurfAssignment (N)
  |     |     |-- user_id (navigator)
  |     |     |-- assigned_by (super_nav or admin)
  |     |     |-- status: active | completed | revoked
  |     |
  |     +-- TurfVoter (N) [materialized: voters within boundary]
  |           |-- voter_id, turf_id
  |           |-- walk_order (optimized route position)
  |
  +-- Task (N)
  |     |-- type: contact_list | event | data_entry | custom
  |     |-- title, description, due_date, priority
  |     |-- created_by, assigned_to
  |     |-- linked_turf_id, linked_voter_ids (JSONB)
  |     |-- progress_current, progress_target
  |     |-- status: pending | in_progress | completed
  |
  +-- Survey (N) [configurable door-knock forms]
  |     |-- name, questions (JSONB)
  |     +-- SurveyResponse (N)
  |           |-- voter_id, user_id
  |           |-- answers (JSONB)
  |
  +-- Event (N)
  |     |-- type: canvass | phone_bank | meeting
  |     |-- date, location, description
  |     +-- EventRSVP (N)
  |
  +-- MessageTemplate (N) [SMS templates with merge fields]
  |     |-- body (with {{voter_name}}, {{district}}, etc.)
  |     |-- approved_by, campaign_id
  |
  +-- Campaign (N) [A2P broadcast campaigns]
        |-- name, target_segment (filter criteria JSONB)
        |-- template_id, status: draft | sending | completed
        |-- stats: sent, delivered, failed, opted_out
```

### Key Database Design Decisions

**PostGIS for spatial operations.** Store voter locations as `geography(POINT, 4326)` and turf boundaries as `geography(POLYGON, 4326)`. Use `ST_Contains(turf.boundary, voter.location)` to materialize `turf_voters` when a turf is created or updated. Spatial index (GiST) makes point-in-polygon queries fast even at 1M+ voters.

**JSONB for semi-structured data.** Voting history, electoral districts, survey questions/answers, and campaign target segments are best stored as JSONB. They vary by source and evolve over time. Avoid over-normalizing these into dozens of lookup tables.

**Materialized turf_voters table.** When an admin draws/edits a turf polygon, run `ST_Contains` to populate `turf_voters`. This avoids expensive spatial joins on every walk list request. Refresh on turf boundary change or voter import.

**ContactLog as unified timeline.** Instead of querying messages + call_logs + door_knocks separately, `contact_log` is the single timeline table with a `type` discriminator and `source_id` FK pointing to the detail record. This simplifies the voter profile view and analytics rollups.

**Soft deletes with `deleted_at`.** Voter data and contact history must be auditable. Never hard-delete voter records.

### Schema Versioning

Use `golang-migrate/migrate` for PostgreSQL migrations. Each domain package owns its migration files in `migrations/{package}/`. Run all migrations in a single sequence at startup.

---

## 3. Offline Sync Architecture

This is the hardest technical challenge in the system. Rural Maine means extended offline periods (hours, not seconds).

### Architecture: Operation Log with Server-Side Resolution

Do NOT use CRDTs. They add complexity disproportionate to this use case. Navigators primarily **append** data (contact logs, notes, survey responses, door knocks) rather than edit shared mutable state. The conflict surface is small.

```
+------------------+          +------------------+          +------------------+
|   Flutter App    |          |   Sync Engine    |          |   PostgreSQL     |
|                  |          |   (Go server)    |          |                  |
|  Local Isar DB   |  push    |                  |  write   |                  |
|  +------------+  |--------->|  Validate        |--------->|  contact_logs    |
|  | op_queue   |  |  ops[]   |  Resolve         |          |  door_knocks     |
|  | (pending)  |  |          |  conflicts       |          |  notes           |
|  +------------+  |          |  Apply           |          |  ...             |
|                  |  pull     |                  |  read    |                  |
|  +------------+  |<---------|  Compute delta   |<---------|  sync_cursors    |
|  | local data |  |  delta   |  since cursor    |          |  (per user)      |
|  +------------+  |          |                  |          |                  |
+------------------+          +------------------+          +------------------+
```

### Sync Protocol

**Push (client to server):**
1. Client collects all pending operations from `op_queue` (ordered by local timestamp)
2. Each operation is a typed envelope: `{type: "contact_log", action: "create", payload: {...}, local_id: "uuid", client_timestamp: ...}`
3. Client sends batch to `SyncService.Push(ops []SyncOp)` via ConnectRPC
4. Server validates each op (RBAC check, data integrity), applies to DB, returns `{accepted: [...], rejected: [...], conflicts: [...]}`
5. Client marks accepted ops as synced, surfaces rejected/conflict ops to UI if needed

**Pull (server to client):**
1. Client sends `SyncService.Pull(cursor: last_sync_timestamp, scopes: [turf_ids])` 
2. Server computes delta: all records modified since cursor within the user's assigned turfs
3. Returns delta payload: voters (updated/new), contact logs from other navigators, task changes, turf boundary changes
4. Client applies delta to local Isar DB, updates cursor

**Conflict Resolution Strategy:**

| Data Type | Strategy | Rationale |
|-----------|----------|-----------|
| Contact logs (door knocks, calls, SMS) | **Append-only, no conflicts** | Each contact is unique. Two navigators knocking the same door = two valid contact logs. |
| Voter notes | **Append-only, no conflicts** | Notes are per-navigator. Never overwritten. |
| Survey responses | **Last-write-wins by server timestamp** | If same navigator re-surveys same voter, latest response wins. |
| Voter tags | **Union merge** | If admin adds tag A and navigator adds tag B offline, both apply. Tag removal is explicit. |
| Task status | **State machine with server authority** | Client proposes state transition. Server validates (e.g., can't complete already-completed task). |
| Voter core data | **Server authoritative, read-only on client** | Navigators never edit voter name/address/party. Only admins via import pipeline. |

**Sync Scoping:**
Navigators only sync data for their assigned turfs. This is critical for both privacy (RBAC) and performance. A navigator with 2 turfs of 500 voters each syncs ~1000 voter records, not 1M.

### Initial Offline Package

Before heading out, a navigator downloads:
1. **Voter data** for assigned turfs (names, addresses, locations, contact history, tags)
2. **Map tiles** as MBTiles for the turf bounding box (see section 7)
3. **Tasks** assigned to this navigator
4. **Survey forms** and message templates
5. **Scripts** for calls and door knocks

This is a single `SyncService.PrepareOfflinePackage(turf_ids)` call that returns a structured payload. Target: < 30 seconds for 1000 voters + map tiles on 4G.

---

## 4. Event-Driven Patterns (NATS JetStream)

### Stream Design

Use NATS JetStream with durable consumers for reliable at-least-once delivery. All consumers must be idempotent.

```
Stream: NAVIGATORS
  Subjects:
    voter.imported           -- batch import completed
    voter.geocoded           -- voter address geocoded
    voter.tagged             -- tag added/removed
    turf.created             -- new turf polygon saved
    turf.assigned            -- turf assigned to navigator
    turf.voters.materialized -- turf_voters table populated
    contact.logged           -- any voter contact (door/sms/call)
    contact.synced           -- offline contact synced to server
    sms.outbound.queued      -- SMS ready to send
    sms.outbound.sent        -- SMS sent to provider
    sms.delivery.updated     -- delivery receipt from provider
    sms.inbound.received     -- inbound SMS from voter
    task.created             -- new task
    task.assigned            -- task assigned to navigator
    task.progress.updated    -- auto-progress from contact events
    task.completed           -- task marked complete
    campaign.started         -- A2P broadcast initiated
    campaign.completed       -- all messages in campaign sent
    sync.push.completed      -- navigator pushed offline data
    audit.entry              -- any auditable action
```

### Key Event Flows

**Voter Import Flow:**
```
Admin uploads file
  -> ImportJob created (DB)
  -> Background worker: parse rows, batch geocode
  -> voter.imported (per batch of 1000)
  -> Consumer: deduplicate against existing voters
  -> voter.geocoded (per batch)
  -> Consumer: refresh turf_voters for affected turfs
  -> turf.voters.materialized
  -> Consumer: notify assigned navigators of new voters in their turfs
```

**Contact Logged Flow:**
```
Navigator logs door knock (offline, then synced)
  -> contact.synced
  -> Consumer: update task progress (if contact linked to task)
  -> task.progress.updated
  -> Consumer: update analytics rollups
  -> Consumer: update turf progress (% contacted)
  -> Consumer: write audit entry
```

**SMS Outbound Flow:**
```
Navigator sends P2P text
  -> sms.outbound.queued
  -> Consumer: call SMS provider API, rate-limited
  -> sms.outbound.sent
  -> Provider webhook: delivery receipt
  -> sms.delivery.updated
  -> Consumer: update message status in DB
  -> Consumer: update contact_log
```

### Consumer Patterns

- **Durable pull consumers** for all processing. Explicit ack after successful processing.
- **MaxDeliver: 5** with exponential backoff for retries.
- **Dead letter subject** (`NAVIGATORS.dlq.*`) for messages that fail all retries.
- **Nats-Msg-Id header** for deduplication on publish (prevents duplicate events during sync push retries).

---

## 5. File Processing Pipeline (Voter Import)

### Pipeline Architecture

```
                    MinIO                        PostgreSQL
                      ^                              ^
                      |                              |
Admin uploads    +----+----+    +----------+    +----+----+
CSV/pipe file -> | Stage 1 | -> | Stage 2  | -> | Stage 3 |
                 | Parse & | -> | Geocode  | -> | Merge & |
                 | Validate|    | (batch)  |    | Dedup   |
                 +---------+    +----------+    +---------+
                      |              |               |
                 import_rows    geocoded_rows    voters (upsert)
                 (temp table)   (temp table)    turf_voters
```

### Stage 1: Parse and Validate

- Accept Maine CVR pipe-delimited format and L2/vendor CSV format
- Parse in streaming fashion (not load entire file into memory)
- Validate each row: required fields, format checks, reject malformed rows
- Write valid rows to `import_rows` staging table using `COPY` protocol (PostgreSQL bulk insert)
- Store original file in MinIO for audit trail
- Emit `voter.import.stage1.complete` event

**Implementation:** Go `encoding/csv` reader with custom pipe delimiter. Stream rows in batches of 5000 using `pgx.CopyFrom`. Target: 100K rows parsed in < 10 seconds.

### Stage 2: Batch Geocode

- Read un-geocoded rows from staging table in batches of 100 (Mapbox batch limit)
- Call Mapbox Geocoding API (or Census Geocoder as free fallback for budget constraints)
- Rate limit: Mapbox allows 600 requests/minute on standard plan. 100K addresses = ~17 minutes at full rate.
- Write lat/lng back to staging table
- For addresses that fail geocoding, flag for manual review
- Emit `voter.import.stage2.complete` event

**Optimization:** Cache geocode results by normalized address. Many voters share addresses (apartments, group homes). Expect 10-20% cache hit rate reducing API calls.

### Stage 3: Merge and Deduplicate

- Match staging rows against existing voters by `(state_voter_id)` as primary key
- If state_voter_id matches: UPDATE existing voter (address change, party change, etc.)
- If no match by state_voter_id: check `(last_name, first_name, yob, zip)` for fuzzy match
- Insert new voters, update existing, log all changes to audit trail
- Refresh `turf_voters` for any turf whose boundary contains new/updated voter locations
- Emit `voter.imported` event with batch summary

**Import Job Tracking:**
```sql
CREATE TABLE import_jobs (
    id UUID PRIMARY KEY,
    file_name TEXT NOT NULL,
    file_path TEXT NOT NULL,  -- MinIO path
    format TEXT NOT NULL,     -- 'cvr_pipe' | 'l2_csv' | 'generic_csv'
    status TEXT NOT NULL,     -- 'parsing' | 'geocoding' | 'merging' | 'complete' | 'failed'
    total_rows INT,
    parsed_rows INT,
    geocoded_rows INT,
    merged_rows INT,
    new_voters INT,
    updated_voters INT,
    failed_rows INT,
    error_details JSONB,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);
```

---

## 6. SMS Integration Architecture

### Provider Abstraction

```go
// sms/provider.go
type Provider interface {
    SendMessage(ctx context.Context, req SendRequest) (SendResult, error)
    ParseWebhook(r *http.Request) (WebhookEvent, error)
    ValidateWebhookSignature(r *http.Request) error
}

type SendRequest struct {
    From    string
    To      string
    Body    string
    MediaURLs []string  // MMS
}

type SendResult struct {
    ProviderMessageID string
    Status            MessageStatus
    Cost              *decimal.Decimal
}

type WebhookEvent struct {
    Type              WebhookEventType  // delivery_receipt | inbound_message
    ProviderMessageID string
    Status            MessageStatus     // queued | sent | delivered | failed | undelivered
    From              string
    To                string
    Body              string            // for inbound
    ErrorCode         string
    Timestamp         time.Time
}
```

### Webhook Processing

```
SMS Provider (Twilio/Bandwidth)
  |
  | HTTP POST (webhook)
  v
+-------------------+
| Webhook Endpoint  |  -- Validate signature (HMAC-SHA256)
| /webhooks/sms     |  -- Parse to WebhookEvent
+--------+----------+  -- Return 200 OK immediately
         |
         | NATS publish
         v
+-------------------+
| sms.delivery.*    |  -- Durable consumer processes asynchronously
| sms.inbound.*     |  -- Update message status in DB
+-------------------+  -- For inbound: create contact_log, match to voter by phone
```

**Key design principle:** Webhook endpoint does minimal work. Validate signature, parse payload, publish to NATS, return 200. All heavy processing (DB writes, voter matching, opt-out processing) happens in NATS consumers. This prevents webhook timeouts and ensures reliable processing.

### Opt-Out Processing

Inbound messages are checked for opt-out keywords (STOP, UNSUBSCRIBE, CANCEL, etc.) before any other processing. Opt-out is immediate and irreversible (requires explicit opt-back-in). Maintain an `sms_opt_outs` table keyed by phone number.

### Quiet Hours

Enforce at the queue consumer level, not the API level. When an SMS is queued during quiet hours (before 8am or after 9pm ET), the NATS consumer holds it until the window opens. Use JetStream's `DeliverPolicy` with a NAK + delay pattern.

### 10DLC Compliance

Store 10DLC registration status per campaign. Block A2P sends until campaign registration is approved. P2P texting uses a different number pool (long codes) and does not require 10DLC.

---

## 7. Map Tile Serving (Offline)

### Architecture

```
+------------------+     +-----------------+     +------------------+
| Mapbox API       | --> | Tile Packager   | --> | MinIO            |
| (vector tiles)   |     | (Go worker)     |     | (MBTiles files)  |
+------------------+     +-----------------+     +------------------+
                                                        |
                                                        | download
                                                        v
                                                 +------------------+
                                                 | Flutter App      |
                                                 | Mapbox GL        |
                                                 | (offline source) |
                                                 +------------------+
```

### Tile Package Strategy

**Per-turf MBTiles files.** When a turf is created or assigned, a background worker generates an MBTiles package containing vector tiles for the turf's bounding box at zoom levels 12-18 (street-level detail needed for door-knocking).

**Tile Packager Worker:**
1. Receive `turf.assigned` event from NATS
2. Calculate bounding box from turf polygon (with 10% padding)
3. Fetch vector tiles from Mapbox Tiles API for zoom levels 12-18
4. Package into MBTiles (SQLite) format
5. Upload MBTiles file to MinIO at path `tiles/{turf_id}/{version}.mbtiles`
6. Emit `turf.tiles.ready` event

**Size estimates for Maine turfs:**
- Typical rural turf (5 sq mi): ~5-15 MB at zoom 12-18
- Typical urban turf (0.5 sq mi): ~2-5 MB at zoom 12-18
- Navigator with 3 turfs: ~15-45 MB total download

**Caching and versioning:** MBTiles files are versioned. When a turf boundary changes, generate a new version. Client checks version on sync and only re-downloads if changed.

### Mapbox GL Flutter Integration

Use `mapbox_maps_flutter` plugin. On mobile, configure offline tile source pointing to the downloaded MBTiles file. On web, use standard online tiles (web users are assumed to have connectivity).

### Alternative: Self-Hosted Tile Server

For cost control at scale, consider self-hosting OpenMapTiles with `tileserver-gl`. Download Maine state extract from OpenMapTiles (~200MB), serve tiles from the Go backend. Eliminates per-tile Mapbox API costs. Mapbox GL can render OpenMapTiles-compatible vector tiles with custom styles.

**Recommendation:** Start with Mapbox API for simplicity. Switch to self-hosted OpenMapTiles if tile API costs exceed budget at scale.

---

## 8. Component Dependencies and Build Order

### Dependency Graph

```
Layer 0 (Foundation):
  PostgreSQL + PostGIS schema
  Auth/RBAC (eden-platform-go existing)
  NATS JetStream setup
  MinIO setup
  Proto definitions (all services)

Layer 1 (Core Data):
  voter package (import, search, filter)
    depends on: schema, MinIO, PostGIS, geocoding
  audit package (logging)
    depends on: schema, NATS

Layer 2 (Spatial + Sync):
  turf package (boundaries, assignment, turf_voters materialization)
    depends on: voter, PostGIS
  sync package (offline packaging, delta sync, conflict resolution)
    depends on: voter, turf

Layer 3 (Outreach):
  outreach package (contact_log, door_knock, call_log)
    depends on: voter, turf, sync
  outreach/sms (provider abstraction, conversations, templates)
    depends on: outreach, NATS, sms provider

Layer 4 (Coordination):
  task package (create, assign, auto-progress)
    depends on: voter, turf, outreach (for progress tracking)
  event package (volunteer events, RSVP)
    depends on: turf, voter

Layer 5 (Intelligence):
  analytics package (rollups, dashboards, export)
    depends on: voter, outreach, task, turf
  notify package (push notifications)
    depends on: task, turf, sync

Layer 6 (Polish):
  Map tile packager (offline tiles)
    depends on: turf, MinIO, Mapbox API
  Volunteer onboarding flow
    depends on: auth, notify
  Leaderboards
    depends on: analytics
```

### Suggested Build Order (Objectives)

| Order | Objective | Key Deliverables | Rationale |
|-------|-----------|-----------------|-----------|
| 1 | **Foundation + Auth** | Schema, migrations, RBAC, proto defs, project scaffolding, CI/CD | Everything depends on this. Cannot parallelize. |
| 2 | **Voter Data Pipeline** | CVR/L2 import, geocoding, search/filter, voter profile, basic list UI | Core data entity. All other features reference voters. |
| 3 | **Turf Management + Maps** | Turf polygon CRUD, PostGIS spatial queries, turf_voters materialization, Mapbox GL integration, voter pins | Required before offline, door-knocking, and turf-scoped features. |
| 4 | **Offline Sync Engine** | Isar local DB, sync protocol (push/pull), offline data packaging, conflict resolution, sync status UI | Unlocks rural Maine usage. Must work before outreach tools are useful in the field. |
| 5 | **Door Knocking + Contact Log** | Walk lists, at-the-door surveys, door status tracking, unified contact timeline, voter notes, sentiment | Core canvassing feature. Exercises offline sync. Low external dependency (no SMS provider). |
| 6 | **SMS Integration** | Provider abstraction, P2P texting, conversation threading, webhook processing, opt-out, quiet hours, 10DLC | Higher complexity due to external provider. Needs working voter + contact infrastructure. |
| 7 | **Tasks + Collaboration** | Task CRUD, assignment, auto-progress, team dashboards, push notifications | Coordination layer. Needs outreach data flowing to track progress. |
| 8 | **Analytics + Events + Polish** | Dashboards, heat maps, export, event management, onboarding, leaderboards, offline map tiles | Reporting on data from all prior objectives. Map tile packager is a nice-to-have that can ship here. |

**Rationale for this order:**
- Objectives 1-3 are strictly sequential (schema -> data -> spatial).
- Objective 4 (offline sync) must come before field tools because "works offline" is a hard requirement, not a nice-to-have.
- Objective 5 (door knocking) is the simplest outreach channel -- no external provider dependency. It validates the offline sync engine in real usage.
- Objective 6 (SMS) has the most external complexity (provider contracts, 10DLC registration lead time, webhook infrastructure). Deferring it gives time for 10DLC registration which takes 2-4 weeks.
- Objectives 7-8 are additive layers that enhance but don't fundamentally change the core workflow.

---

## Patterns to Follow

### Pattern 1: Repository + Service + Handler

Each domain package follows this internal structure:

```
voter/
  handler.go      -- ConnectRPC handler (thin, delegates to service)
  service.go      -- Business logic, orchestration
  repository.go   -- Database access (wraps sqlc-generated code)
  events.go       -- NATS event publishing
  queries.sql     -- sqlc query definitions
  models.go       -- Domain types (if different from proto/sqlc generated)
```

**Handler** validates input, calls service, maps response. **Service** contains business logic, calls repository, publishes events. **Repository** wraps sqlc, handles transactions.

### Pattern 2: Transactional Outbox for Events

When a DB write and NATS publish must be atomic (e.g., creating a contact_log AND publishing `contact.logged`), use the outbox pattern:

1. Write the domain record AND an outbox record in the same DB transaction
2. Background poller reads unpublished outbox records, publishes to NATS, marks as published
3. This prevents lost events if NATS is temporarily down

```sql
CREATE TABLE event_outbox (
    id BIGSERIAL PRIMARY KEY,
    subject TEXT NOT NULL,       -- NATS subject
    payload JSONB NOT NULL,      -- event data
    published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_outbox_unpublished ON event_outbox(published) WHERE published = FALSE;
```

### Pattern 3: Scoped Data Access

Every query includes tenant/role scoping. Never return unscoped data.

```go
// Bad: returns all voters
func (r *Repository) ListVoters(ctx context.Context) ([]Voter, error)

// Good: returns voters within user's assigned turfs only
func (r *Repository) ListVoters(ctx context.Context, turfIDs []uuid.UUID) ([]Voter, error)
```

The RBAC interceptor extracts the user's role and scope from the JWT. Service layer uses this to determine which turf IDs to pass to the repository.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Client-Side Conflict Resolution

**What:** Letting the Flutter app decide how to merge conflicting data.
**Why bad:** Different app versions may resolve differently. Clients can be tampered with. Server loses authority over data integrity.
**Instead:** Client sends raw operations. Server resolves all conflicts. Client accepts server's resolution.

### Anti-Pattern 2: Synchronous SMS Sending

**What:** Sending SMS directly in the ConnectRPC handler (blocking the request until provider responds).
**Why bad:** SMS API calls take 200-500ms. Provider outages block the UI. No retry mechanism.
**Instead:** Queue via NATS. Return "queued" status immediately. Update status asynchronously via events.

### Anti-Pattern 3: Global Voter Search Without Scope

**What:** Allowing any user to search the entire 1M voter database.
**Why bad:** Performance at scale. Privacy violation (navigators should only see assigned turf voters). Compliance risk.
**Instead:** All voter queries are scoped to the user's assigned turfs. Admin search is scoped to organization but paginated with cursor-based pagination.

### Anti-Pattern 4: Storing Map Tiles in PostgreSQL

**What:** Saving MBTiles data in PostgreSQL BYTEA columns.
**Why bad:** Bloats the database. Tiles are static binary blobs. No need for transactional semantics.
**Instead:** Store in MinIO (object storage). Reference by URL in the turf record.

---

## Scalability Considerations

| Concern | Pilot (1K voters) | Scale (100K voters) | Full (1M+ voters) |
|---------|-------------------|---------------------|-------------------|
| Voter queries | Direct SQL, no caching | Add GIN index on JSONB fields, materialized views for common filters | Consider read replica, Elasticsearch for full-text search |
| Spatial queries | PostGIS on primary DB | GiST indexes sufficient | Partition voters by county/region |
| Offline sync | Full turf download | Delta sync critical | Compress payloads, binary proto format |
| SMS throughput | Single provider connection | Connection pooling, multiple numbers | Multiple provider accounts, round-robin |
| Analytics | Real-time queries | Pre-computed rollups in NATS consumers | TimescaleDB or materialized views with periodic refresh |
| Import pipeline | Single-threaded OK | Parallel geocoding workers | Partition import jobs, worker pool |

---

## Sources

- [Offline-first sync architecture patterns (2026)](https://www.sachith.co.uk/offline-sync-conflict-resolution-patterns-architecture-trade%E2%80%91offs-practical-guide-feb-19-2026/) - MEDIUM confidence
- [Flutter offline-first architecture with conflict resolution](https://dev.to/anurag_dev/implementing-offline-first-architecture-in-flutter-part-1-local-storage-with-conflict-resolution-4mdl) - MEDIUM confidence
- [NATS JetStream patterns for Go microservices](https://dasroot.net/posts/2026/02/building-event-driven-systems-go-nats/) - MEDIUM confidence
- [NATS JetStream exactly-once patterns](https://medium.com/@hadiyolworld007/nats-jetstream-playbook-exactly-once-minus-the-bloat-02fd9d5a051c) - MEDIUM confidence
- [PostGIS spatial queries and geofencing](https://postgis.net/docs/using_postgis_query.html) - HIGH confidence (official docs)
- [PostgreSQL COPY for bulk imports](https://infinum.com/the-capsized-eight/superfast-csv-imports-using-postgresqls-copy) - HIGH confidence
- [SMS webhook architecture patterns](https://hookdeck.com/webhooks/guides/webhook-infrastructure-guide) - MEDIUM confidence
- [Twilio webhooks in Go](https://www.twilio.com/en-us/blog/developers/community/receiving-and-processing-incoming-sms-with-twilio-webhooks-in-go) - HIGH confidence (official docs)
- [MBTiles offline map architecture](https://medium.com/@rao_/a-guide-to-offline-maps-map-tiles-and-mbtiles-for-beginners-7d412b837d25) - MEDIUM confidence
- [NGP VAN / MiniVAN canvassing architecture](https://www.ngpvan.com/blog/canvassing-with-minivan/) - HIGH confidence (industry standard reference)
- [NATS JetStream consumers documentation](https://docs.nats.io/nats-concepts/jetstream/consumers) - HIGH confidence (official docs)
