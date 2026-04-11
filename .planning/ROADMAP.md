# Roadmap: Navigators

## Overview

10 objectives | 74 requirements mapped | Coverage: 100%

Navigators goes from foundation to field-ready in 10 objectives. The first four build the platform skeleton: auth, voter data, turf maps, and the offline sync engine that makes everything work in rural Maine. Objectives 5-7 deliver the three outreach channels (doors, texts, calls) on top of that foundation. Objectives 8-10 add coordination, measurement, and volunteer management. The dependency graph is strict through Objective 4; later objectives have more flexibility.

## Objectives

- [x] **Objective 1: Foundation + Auth** - Backend skeleton with auth, RBAC, audit logging, and infrastructure services
- [x] **Objective 2: Voter Data Pipeline** - Import, geocode, deduplicate, search, and display voter records
- [x] **Objective 3: Turf Management + Maps** - Draw turfs, assign Navigators, display voters on interactive maps
- [x] **Objective 4: Offline Sync Engine** - Download, work offline, and sync back with conflict resolution
- [x] **Objective 5: Door Knocking + Contact Log** - Walk lists, at-the-door surveys, notes, and unified contact timeline
- [x] **Objective 6: SMS Integration** - P2P texting, A2P broadcasts, templates, opt-out handling, and 10DLC
- [x] **Objective 7: Phone Calls + Scripts** - Click-to-call, post-call dispositions, and call scripts
- [ ] **Objective 8: Tasks + Collaboration** - Task CRUD, auto-progress, push notifications
- [ ] **Objective 9: Analytics + Dashboards** - Per-role dashboards, heat maps, metrics, and data export
- [ ] **Objective 10: Volunteer Management + Events** - Onboarding flow, events, leaderboards, training materials

## Objective Details

### Objective 1: Foundation + Auth
**Goal**: Users can authenticate, and the system enforces role-based access control across all data
**Depends on**: Nothing
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, AUTH-06, AUTH-07, AUTH-08, AUTH-09
**Success Criteria** (what must be TRUE):
  1. User can sign up, log in, stay logged in across sessions, and reset a forgotten password
  2. Admin can create user accounts and assign roles (Admin, Super Navigator, Navigator)
  3. Navigator can only see voters in their assigned turfs; Super Navigator sees their team; Admin sees everything
  4. Every voter data access is recorded in an audit trail visible to Admins
  5. Inactive sessions time out and Admins can revoke any session
**TRDs:** 3 plans in 3 waves

Jobs:
- [ ] 01-01: Project scaffold + Docker Compose + Justfile + Flutter app shell
- [ ] 01-02: Auth + RBAC + permission matrix + admin user mgmt + password reset + sessions
- [ ] 01-03: Domain schema (turfs/teams/audit) + turf-scoped filtering + audit viewer

### Objective 2: Voter Data Pipeline
**Goal**: Admins can import voter files and all users can search, filter, and view complete voter profiles
**Depends on**: Objective 1
**Requirements**: VOTER-01, VOTER-02, VOTER-03, VOTER-04, VOTER-05, VOTER-06, VOTER-07, VOTER-08, VOTER-09, VOTER-10
**Success Criteria** (what must be TRUE):
  1. Admin can upload Maine CVR and L2 voter files and see an import report with success/error counts
  2. System geocodes voter addresses and voters appear as plottable points (lat/lng populated)
  3. User can search voters by name, address, or voter ID and filter by district, party, voting frequency, tags, and geography
  4. Full voter profile displays name, address, YOB, party enrollment, voting history, districts, registration date, and status
  5. System maintains a global suppression list and no prohibited fields (SSN, full DOB, felony info) are stored
**TRDs:** 3 plans in 3 waves

Jobs:
- [ ] 02-01-TRD.md — Voter data model + import pipeline (CVR + L2 parsers, staging, dedup merge)
- [ ] 02-02-TRD.md — Geocoding + voter search/filter + tags
- [ ] 02-03-TRD.md — Voter profile + suppression list + Flutter UI

### Objective 3: Turf Management + Maps
**Goal**: Admins can draw turf boundaries on a map, assign them to Navigators, and voters appear as clustered pins within turfs
**Depends on**: Objective 2
**Requirements**: TURF-01, TURF-02, TURF-03, TURF-04, TURF-05, TURF-06, TURF-07, TURF-08
**Success Criteria** (what must be TRUE):
  1. Admin can draw polygon turf boundaries on an interactive map and assign turfs to Navigators
  2. System auto-populates the voter list for each turf via spatial queries and voters display as clustered pins
  3. Navigator can download offline map tiles for their assigned turf
  4. System generates route-optimized walk lists and tracks turf completion percentage
  5. Admin can view geographic heat maps of contact density and support levels
**TRDs:** 3 plans in 3 waves

Jobs:
- [ ] 03-01-TRD.md — Spatial queries + turf CRUD with GeoJSON boundaries + contact logs + walk list + stats
- [ ] 03-02-TRD.md — Flutter map + polygon drawing + voter pins + clustering + turf assignment UI
- [ ] 03-03-TRD.md — Offline tiles (FMTC) + heat maps + walk list UI + turf completion dashboard

### Objective 4: Offline Sync Engine
**Goal**: Navigators can download everything they need, work entirely offline in the field, and have data sync back automatically when connectivity returns
**Depends on**: Objective 3
**Requirements**: SYNC-01, SYNC-02, SYNC-03, SYNC-04, SYNC-05, SYNC-06, SYNC-07
**Success Criteria** (what must be TRUE):
  1. Navigator can download turf data (voters, map tiles, tasks, scripts) into an encrypted local database before going into the field
  2. All field interactions are stored locally and persist through app restarts without data loss
  3. Background sync pushes local changes to the server when connectivity is available, with conflict resolution for concurrent edits
  4. Sync status indicator shows the Navigator exactly what is synced vs pending at all times
  5. App forces sync on open when online; local voter data is encrypted at rest with AES-256
**TRDs:** 3 plans in 3 waves

Jobs:
- [ ] 04-01-TRD.md — Drift local DB + encryption + tables + DAOs + server pull sync endpoints
- [ ] 04-02-TRD.md — Operation log + push sync engine + conflict resolution + background scheduling
- [ ] 04-03-TRD.md — Sync status UI + forced sync + offline-first screens + turf reassignment

### Objective 5: Door Knocking + Contact Log
**Goal**: Navigators can walk their turf with an ordered list, knock doors, record survey responses and notes offline, and see a unified contact timeline per voter
**Depends on**: Objective 4
**Requirements**: DOOR-01, DOOR-02, DOOR-03, DOOR-04, DOOR-05, NOTE-01, NOTE-02, NOTE-03, NOTE-04
**Success Criteria** (what must be TRUE):
  1. Navigator sees an ordered walk list for their turf with map view and can navigate door-to-door
  2. Navigator can record door status, complete configurable survey forms, and log voter sentiment -- all while offline
  3. Navigator can add free-text notes to any voter; notes follow role-scoped visibility (own notes, team notes, all notes)
  4. Each voter profile shows a unified contact timeline of all interactions (door knocks, texts, calls) with timestamps
  5. System tracks door-knock attempts per voter with full timestamp history
**TRDs:** 3 plans in 3 waves

Jobs:
- [ ] 05-01-TRD.md — Door knock backend + survey forms + notes (migration, Go services, sync, Drift tables/DAOs)
- [ ] 05-02-TRD.md — At-the-door UI + walk list enhancement (door knock screen, survey renderer, pull sync)
- [ ] 05-03-TRD.md — Contact timeline + voter profile enhancement (timeline widget, notes tab, sentiment history)

### Objective 6: SMS Integration
**Goal**: Navigators can send personalized texts to voters, Admins can run broadcast campaigns, and the system handles opt-outs and compliance automatically
**Depends on**: Objective 1
**Requirements**: SMS-01, SMS-02, SMS-03, SMS-04, SMS-05, SMS-06, SMS-07, SMS-08
**Success Criteria** (what must be TRUE):
  1. Navigator can send a P2P text to a voter with human-initiated send and view the full conversation thread
  2. Admin can create message templates with merge fields and launch A2P broadcast campaigns targeting voter segments
  3. System automatically processes STOP/opt-out keywords within seconds and updates the global suppression list
  4. System enforces quiet hours (no texts before 8am or after 9pm) and tracks delivery status via provider webhooks
  5. System supports 10DLC registration flow and gates A2P messaging on registration status
**TRDs:** 3 plans in 3 waves

Jobs:
- [ ] 06-01-TRD.md — SMS data model + Twilio provider + P2P texting + webhooks + NATS workers + opt-out processing
- [ ] 06-02-TRD.md — Message templates + A2P broadcast campaigns + 10DLC gating + campaign batch worker
- [ ] 06-03-TRD.md — Flutter SMS UI (conversations, compose, templates, campaigns) + app navigation

> **Parallel opportunity:** Objective 6 depends on Objective 1 (auth, RBAC, suppression list), NOT on Objectives 2-5.
> SMS does not require turf management or offline sync to function. Objectives 5 and 6 can execute
> in parallel via `/df:workstreams` once Objective 4 and Objective 1 are complete respectively.
> Objective 7 is the join point that benefits from both outreach channels existing.

### Objective 7: Phone Calls + Scripts
**Goal**: Navigators can call voters from the app with scripts displayed during the call and log dispositions afterward
**Depends on**: Objective 5
**Requirements**: CALL-01, CALL-02, CALL-03, CALL-04
**Success Criteria** (what must be TRUE):
  1. Navigator can tap a voter's phone number to initiate a call via the native dialer
  2. Call script displays to the Navigator during the call with relevant voter context
  3. Navigator completes a post-call disposition form capturing outcome, sentiment, and free-text notes
  4. Call interactions appear in the voter's unified contact timeline
**TRDs:** 2 plans in 2 waves

Jobs:
- [ ] 07-01-TRD.md — Call scripts backend + phone call data layer (migration 014, CallScriptService, sync proto, Drift table/DAO)
- [ ] 07-02-TRD.md — Flutter call UI + script display + disposition (PhoneCallScreen, call script manager, voter detail integration, timeline)

### Objective 8: Tasks + Collaboration
**Goal**: Admins and Super Navigators can create and assign tasks that auto-track progress, and Navigators receive push notifications for assignments and reminders
**Depends on**: Objective 5
**Requirements**: TASK-01, TASK-02, TASK-03, TASK-04, TASK-05, PUSH-01, PUSH-02, PUSH-03
**Success Criteria** (what must be TRUE):
  1. Admin or Super Navigator can create tasks with types, due dates, and priority, and assign them to Navigators
  2. Tasks can be linked to voter lists, turfs, or specific voters, and progress auto-updates as linked voters are contacted
  3. Navigator can add notes to tasks visible to their Super Navigator and Admin
  4. System sends push notifications for task reminders, new assignments, and sync alerts
**TRDs:** 3 plans in 3 waves

Jobs:
- [ ] 08-01-TRD.md — Task data model + CRUD + assignment + notes + proto + Drift tables/DAO + pull sync
- [ ] 08-02-TRD.md — Auto-progress NATS worker + FCM dispatcher + push notifications + device token registration
- [ ] 08-03-TRD.md — Flutter task UI (list, detail, create) + Firebase Messaging + PUSH-03 sync alert + Tasks tab

### Objective 9: Analytics + Dashboards
**Goal**: Each role sees a dashboard tailored to their scope, and Admins can export data and view geographic analytics
**Depends on**: Objective 5, Objective 6
**Requirements**: ANLYT-01, ANLYT-02, ANLYT-03, ANLYT-04, ANLYT-05
**Success Criteria** (what must be TRUE):
  1. Navigator sees a personal dashboard with their tasks, stats, and assigned turfs
  2. Super Navigator sees a team dashboard with performance metrics, task completion, and turf coverage
  3. Admin sees an organization dashboard with geographic heat maps, trend analysis, and key metrics (doors knocked, texts sent, calls made, contact rate, sentiment distribution)
  4. Admin can export any filtered dataset as CSV or Excel
**TRDs:** 3 plans in 3 waves

Jobs:
- [ ] 09-01: TBD
- [ ] 09-02: TBD
- [ ] 09-03: TBD

### Objective 10: Volunteer Management + Events
**Goal**: New volunteers go through a compliant onboarding flow, events can be organized and tracked, and engagement features motivate participation
**Depends on**: Objective 1
**Requirements**: VOL-01, VOL-02, VOL-03, EVT-01, EVT-02, EVT-03
**Success Criteria** (what must be TRUE):
  1. New Navigator completes onboarding flow: signup, Maine Title 21-A data usage acknowledgment, role assignment, and training materials
  2. Admin or Super Navigator can create events (canvass events, phone banks) with Navigators RSVPing and checking in
  3. System tracks event attendance and provides opt-in leaderboards with engagement metrics
  4. In-app training materials and best practices guides are accessible to all Navigators
**TRDs:** 3 plans in 3 waves

Jobs:
- [ ] 10-01: TBD
- [ ] 10-02: TBD

## Progress

| Objective | Jobs Complete | Status | Completed |
|-----------|--------------|--------|-----------|
| 1. Foundation + Auth | 3/3 | Complete | 2026-04-10 |
| 2. Voter Data Pipeline | 0/3 | Not started | - |
| 3. Turf Management + Maps | 0/3 | Not started | - |
| 4. Offline Sync Engine | 0/3 | Not started | - |
| 5. Door Knocking + Contact Log | 0/3 | Not started | - |
| 6. SMS Integration | 0/3 | Not started | - |
| 7. Phone Calls + Scripts | 0/2 | Not started | - |
| 8. Tasks + Collaboration | 0/3 | Not started | - |
| 9. Analytics + Dashboards | 0/3 | Not started | - |
| 10. Volunteer Management + Events | 0/2 | Not started | - |

---
*Roadmap created: 2026-04-10*
*Last updated: 2026-04-11 — Objective 8 planned*
