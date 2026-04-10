# Navigators — MaineGOP Voter Outreach Platform

## Vision
Empower MaineGOP grassroots volunteers ("Navigators") to systematically reach voters through door-knocking, text messaging, and phone calls — with full offline support for rural Maine, strict role-based access, and analytics to measure impact.

## Tech Stack
- **Backend:** Go (eden-platform-go) — ConnectRPC APIs, PostgreSQL/sqlc, JWT auth, RBAC
- **Frontend:** Flutter (eden-ui-flutter) — Web, iOS, Android from single codebase
- **Shared:** eden-platform-api-dart (generated proto clients), eden-platform-flutter (auth/platform shell)
- **Infrastructure:** Docker Compose, NATS (events/messaging), MinIO (file storage), Prometheus (metrics)
- **Maps:** Mapbox GL (Flutter plugin + tile server for offline)
- **SMS:** TBD — evaluate Twilio, Vonage, Bandwidth for P2P + A2P capabilities
- **Offline:** Hive/Isar local DB + background sync queue

## Roles & Permissions

| Role | Scope | Capabilities |
|------|-------|-------------|
| **MeGOP Admin** | Organization-wide | All operations. Manage users, upload voter files, draw turfs, view all analytics, configure SMS campaigns, manage budgets |
| **Super Navigator** | Team-scoped | Manage assigned Navigators, assign turfs/tasks, view team analytics, see all notes from their Navigators, create task lists |
| **Navigator** | Turf/assignment-scoped | View assigned voters, log door knocks, send P2P texts, initiate calls, add voter notes, complete tasks, work offline |

## Core Features

### 1. Voter Data Management
- **Import pipeline:** Parse Maine CVR pipe-delimited files + L2/vendor CSV files
- **Data model:** Voter profile with name, address (geocoded), YOB, party enrollment, voting history, electoral districts, registration date, status
- **Merge/dedup:** Match voters across sources by name + address + YOB
- **Geocoding:** Batch geocode addresses on import (Mapbox/Census geocoder)
- **Search & filter:** By district, party, voting frequency, status, geography, custom tags
- **Tagging:** Admin-defined tags (e.g., "priority voter", "contacted", "supporter")

### 2. Turf Management & Mapping
- **Turf drawing:** Admins draw polygon boundaries on map to define turfs
- **Turf assignment:** Assign turfs to Navigators with voter lists auto-populated
- **Offline maps:** Download Mapbox tiles + voter pins for assigned turf before going out
- **Route optimization:** Generate efficient walking routes within a turf
- **Turf progress:** Track % of voters contacted per turf, visualize on map
- **Heat maps:** Geographic visualization of contact density, support levels

### 3. Outreach Tools
#### Text Messaging (P2P + A2P)
- **P2P texting:** Navigator selects voter, opens conversation, sends personalized text. Human-initiated for TCPA compliance
- **A2P broadcast:** Admin creates campaign, targets voter segment, sends bulk text (requires 10DLC registration)
- **Templates:** Pre-approved message templates with merge fields (voter name, district, etc.)
- **Conversation threading:** Full conversation history per voter
- **Opt-out handling:** Automatic STOP/opt-out processing, isolated opt-out lists
- **Compliance:** 10DLC registration flow, consent tracking, quiet hours enforcement

#### Phone Calls
- **Click-to-call:** Navigator taps to initiate call via native dialer (no VoIP needed for v1)
- **Call logging:** Post-call disposition form (answered/voicemail/no answer, notes, voter sentiment)
- **Call scripts:** Admin-created scripts displayed during calls
- **Power dialer (future):** Auto-dial next voter after disposition logged

#### Door Knocking
- **Walk list:** Ordered list of voters in Navigator's turf with map view
- **At-the-door survey:** Configurable survey forms (support level, issues, etc.)
- **Door status:** Not home / answered / refused / moved — tracked per visit
- **Offline-first:** All door-knock data captured locally, syncs when online

### 4. Task Management
- **Task creation:** Super Navigators and Admins create tasks, assign to Navigators
- **Task types:** Contact list (call/text/knock these voters), Event (attend/organize), Data entry, Custom
- **Task linking:** Tasks linked to voter lists, turfs, or specific voters
- **Due dates & priority:** Deadline tracking with priority levels
- **Progress tracking:** Auto-progress based on linked voter contacts (e.g., "Contact 50 voters" updates as contacts are logged)
- **Notes on tasks:** Navigator notes visible to their Super Navigator
- **Task templates:** Reusable task blueprints for common operations

### 5. Voter Notes & Contact History
- **Per-voter notes:** Navigators add free-text notes after interactions
- **Contact log:** Unified timeline of all interactions (texts, calls, door knocks) per voter
- **Visibility rules:** Navigator sees own notes; Super Navigator sees all notes from their team; Admin sees everything
- **Voter sentiment:** Track support level over time (strong support → lean support → undecided → lean oppose → strong oppose)

### 6. Analytics & Reporting
- **Navigator dashboard:** My tasks, my stats, my assigned turfs
- **Super Navigator dashboard:** Team performance, task completion rates, turf coverage
- **Admin dashboard:** Organization-wide metrics, geographic heat maps, trend analysis
- **Key metrics:** Doors knocked, texts sent, calls made, contact rate, response rate, voter sentiment distribution
- **Export:** CSV/Excel export of any filtered data set
- **Time-series trends:** Track metrics over configurable time periods

## Additional Features (Research-Informed)

### 7. Volunteer Management
- **Onboarding flow:** Navigator signup → data usage acknowledgment (Maine law compliance) → role assignment → training materials
- **Availability scheduling:** Navigators indicate when they're available for outreach
- **Leaderboards:** Gamified engagement metrics (opt-in) to motivate volunteers
- **Training materials:** In-app guides and best practices

### 8. Event Management
- **Event creation:** Canvass events, phone banks, community meetings
- **RSVP tracking:** Navigator sign-ups with reminder notifications
- **Event turfs:** Auto-assign turfs for canvass events
- **Check-in:** Navigators check in at events, track attendance

### 9. Push Notifications
- **Task reminders:** Upcoming due dates, unfinished tasks
- **New assignments:** Turf or task assignments
- **Sync alerts:** "You have unsynced data — connect to upload"
- **Campaign updates:** Admin broadcasts to Navigator teams

## Data Architecture

### Offline Sync Strategy
1. Navigator downloads turf data (voters, map tiles, tasks, scripts) before going out
2. All interactions stored locally in Isar/Hive DB
3. Background sync when connectivity available — conflict resolution via last-write-wins with server timestamps
4. Sync status indicator in UI — Navigator always knows what's synced and what's pending
5. Forced sync on app open when online

### Data Privacy & Compliance
- All voter data encrypted at rest (PostgreSQL TDE + app-level for local DB)
- Audit trail for all voter data access (who viewed/modified what, when)
- Data usage acknowledgment required at onboarding (Maine Title 21-A §196-A)
- Voter data cannot be exported by Navigators — only Admins
- Session timeout and device management for lost/stolen phones
- No voter SSN, full DOB, or felony data stored (per Maine law restrictions)

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                   Flutter Apps                       │
│            (Web / iOS / Android)                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ eden-ui  │  │ Offline  │  │  Mapbox GL       │  │
│  │ flutter  │  │ DB (Isar)│  │  + Offline Tiles │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
│            │         │              │                │
│            └────┬────┘              │                │
│                 │ Sync Engine       │                │
└─────────────────┼───────────────────┼────────────────┘
                  │ ConnectRPC        │
┌─────────────────┼───────────────────┼────────────────┐
│                 │ API Gateway       │                │
│  ┌──────────────▼───────────────────▼─────────────┐  │
│  │          eden-platform-go                       │  │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐  │  │
│  │  │ Auth/  │ │ Voter  │ │ Turf/  │ │ Outreach│  │  │
│  │  │ RBAC   │ │ Mgmt   │ │ Map    │ │ (SMS/  │  │  │
│  │  │        │ │        │ │        │ │  Call)  │  │  │
│  │  └────────┘ └────────┘ └────────┘ └────────┘  │  │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐  │  │
│  │  │ Task   │ │Analytics│ │ Event  │ │ Sync   │  │  │
│  │  │ Mgmt   │ │        │ │ Mgmt   │ │ Engine │  │  │
│  │  └────────┘ └────────┘ └────────┘ └────────┘  │  │
│  └─────────────────────────────────────────────────┘  │
│           │           │           │                   │
│  ┌────────▼──┐  ┌─────▼────┐  ┌──▼────────┐         │
│  │ PostgreSQL│  │  NATS    │  │  MinIO    │         │
│  │ (primary) │  │ (events) │  │ (files)   │         │
│  └───────────┘  └──────────┘  └───────────┘         │
│           │                                          │
│  ┌────────▼──────────┐  ┌──────────────────┐        │
│  │ SMS Provider      │  │ Geocoding Service│        │
│  │ (Twilio/Vonage)   │  │ (Mapbox/Census)  │        │
│  └───────────────────┘  └──────────────────┘        │
└──────────────────────────────────────────────────────┘
```

## Development Phases

### Phase 1: Foundation (Weeks 1-4)
**Goal:** Working app shell with auth, voter data import, and basic voter list views.

- [ ] Project scaffolding (Go service + Flutter app consuming eden-libs)
- [ ] Proto definitions for all services (voter, turf, task, outreach, analytics)
- [ ] Database schema + migrations (voters, turfs, tasks, contacts, notes)
- [ ] Voter file import pipeline (CVR parser + L2 parser + merge/dedup)
- [ ] Batch geocoding service
- [ ] Voter list UI with search, filter, sort
- [ ] Role setup (Admin, Super Navigator, Navigator) in eden RBAC
- [ ] Basic voter profile view

### Phase 2: Mapping & Turfs (Weeks 5-8)
**Goal:** Full turf management with offline map support.

- [ ] Mapbox GL integration in Flutter (web + mobile)
- [ ] Voter pins on map (clustered at zoom levels)
- [ ] Turf polygon drawing tool (admin)
- [ ] Turf assignment to Navigators
- [ ] Offline tile download for assigned turfs
- [ ] Walk list generation with route optimization
- [ ] Turf progress tracking and visualization
- [ ] Offline data sync engine (Isar local DB + background sync)

### Phase 3: Outreach Tools (Weeks 9-12)
**Goal:** P2P texting, broadcast SMS, click-to-call, door-knock logging.

- [ ] SMS provider integration (evaluate + implement)
- [ ] 10DLC registration flow
- [ ] P2P texting UI (conversation view per voter)
- [ ] Message templates with merge fields
- [ ] A2P broadcast campaign builder
- [ ] Opt-out handling + compliance engine
- [ ] Click-to-call with post-call disposition
- [ ] Call scripts display
- [ ] Door-knock survey forms (configurable)
- [ ] Offline door-knock data capture

### Phase 4: Tasks & Collaboration (Weeks 13-16)
**Goal:** Task management, voter notes, team coordination.

- [ ] Task CRUD with assignment and linking
- [ ] Task types (contact list, event, custom)
- [ ] Auto-progress tracking based on voter contacts
- [ ] Per-voter notes with role-scoped visibility
- [ ] Unified voter contact timeline
- [ ] Voter sentiment tracking
- [ ] Super Navigator team dashboard
- [ ] Push notifications (task reminders, new assignments, sync alerts)

### Phase 5: Analytics & Polish (Weeks 17-20)
**Goal:** Full analytics, event management, production hardening.

- [ ] Navigator personal dashboard
- [ ] Super Navigator team analytics
- [ ] Admin organization dashboard with geographic heat maps
- [ ] Time-series trend analysis
- [ ] Data export (CSV/Excel)
- [ ] Event management (create, RSVP, check-in)
- [ ] Volunteer onboarding flow with legal acknowledgment
- [ ] Leaderboards (opt-in)
- [ ] Performance optimization and load testing
- [ ] Security audit (OWASP, data privacy, audit trail verification)
- [ ] App Store / Play Store submission prep

## SMS Provider Evaluation Criteria

| Criteria | Twilio | Vonage | Bandwidth |
|----------|--------|--------|-----------|
| 10DLC registration | Built-in | Built-in | Built-in |
| P2P texting support | Yes (Conversations API) | Yes | Yes |
| A2P broadcast | Yes | Yes | Yes |
| Political campaign experience | Strong | Moderate | Strong |
| Opt-out management | Built-in | Built-in | Built-in |
| Pricing model | Per-message + carrier fees | Per-message + carrier fees | Per-message (owns network) |
| Flutter SDK | Community packages | Community packages | REST API only |
| Quiet hours API | Manual implementation | Manual implementation | Manual implementation |

**Recommendation:** Evaluate during Phase 3. Twilio has the most mature ecosystem but Bandwidth may offer cost advantages at scale since they own carrier infrastructure.

## Compliance Checklist

- [ ] Maine Title 21-A §196-A data usage acknowledgment in onboarding
- [ ] Voter data access audit trail
- [ ] 10DLC brand + campaign registration before any A2P messaging
- [ ] TCPA compliance: P2P messages must be human-initiated
- [ ] Opt-out processing within legally required timeframes
- [ ] Quiet hours enforcement (no texts before 8am or after 9pm local)
- [ ] Data retention policy (purge voter data on Navigator offboarding)
- [ ] Device security (remote wipe capability for lost devices, session timeout)
- [ ] No prohibited data fields stored (SSN, full DOB, felony info)
- [ ] Annual compliance review process
