# Requirements: Navigators

**Defined:** 2026-04-10
**Core Value:** Navigators can go into the field with a complete voter list, map, and outreach tools — work entirely offline in rural Maine — and have every interaction automatically sync back to give leadership real-time visibility into grassroots organizing efforts.

## v1 Requirements

Requirements for initial release. Each maps to roadmap objectives.

### Authentication & RBAC

- [x] **AUTH-01**: User can sign up with email and password
- [x] **AUTH-02**: User can log in and stay logged in across sessions (JWT refresh)
- [x] **AUTH-03**: User can reset password via email link
- [x] **AUTH-04**: User session times out after inactivity and can be revoked by Admin
- [x] **AUTH-05**: Admin can create and manage user accounts with role assignment
- [x] **AUTH-06**: System enforces strict RBAC — Admin (org-wide), Super Navigator (team-scoped), Navigator (turf-scoped)
- [x] **AUTH-07**: Navigator can only access voters in their assigned turfs
- [x] **AUTH-08**: Super Navigator can view all data from their assigned Navigators
- [x] **AUTH-09**: Audit trail logs all voter data access (who viewed/modified what, when)

### Voter Data Management

- [x] **VOTER-01**: Admin can upload Maine CVR pipe-delimited voter files
- [x] **VOTER-02**: Admin can upload L2/vendor CSV voter files
- [x] **VOTER-03**: System merges/deduplicates voters across sources by name + address + YOB
- [x] **VOTER-04**: System batch geocodes voter addresses using Census API (primary) + Google (overflow)
- [x] **VOTER-05**: User can view full voter profile (name, address, YOB, party enrollment, voting history, electoral districts, registration date, status)
- [x] **VOTER-06**: User can search voters by name, address, or voter ID
- [x] **VOTER-07**: User can filter voters by district, party, voting frequency, status, geography, custom tags
- [x] **VOTER-08**: Admin can create and manage voter tags (e.g., "priority voter", "supporter")
- [x] **VOTER-09**: System maintains global suppression list (opt-outs) that gates all outreach
- [x] **VOTER-10**: No prohibited data fields stored (SSN, full DOB, felony info per Maine law)

### Turf Management & Mapping

- [x] **TURF-01**: Admin can draw turf polygon boundaries on interactive map
- [x] **TURF-02**: Admin can assign turfs to Navigators
- [x] **TURF-03**: System auto-populates voter list for each turf using PostGIS spatial queries
- [x] **TURF-04**: User can view voters as clustered pins on map
- [x] **TURF-05**: Navigator can download offline map tiles for assigned turf via FMTC
- [x] **TURF-06**: System generates route-optimized walk lists within turfs (nearest-neighbor)
- [x] **TURF-07**: System tracks turf completion progress (% voters contacted)
- [x] **TURF-08**: Admin can view geographic heat maps of contact density and support levels

### Offline & Sync

- [x] **SYNC-01**: Navigator can download turf data (voters, map tiles, tasks, scripts) before going into field
- [x] **SYNC-02**: All field interactions (door knocks, notes, dispositions) stored locally in Drift/SQLite
- [x] **SYNC-03**: Local voter data encrypted at rest via sqlcipher (AES-256)
- [x] **SYNC-04**: Background sync when connectivity available with operation-log pattern
- [x] **SYNC-05**: Conflict resolution via last-write-wins with server timestamps for concurrent edits
- [x] **SYNC-06**: Sync status indicator in UI — Navigator always knows what's synced vs pending
- [x] **SYNC-07**: Forced sync on app open when online

### SMS Messaging

- [x] **SMS-01**: Navigator can send personalized P2P text to a voter (human-initiated, TCPA compliant)
- [x] **SMS-02**: Full conversation threading — view all messages exchanged with a voter
- [x] **SMS-03**: Admin can create message templates with merge fields (voter name, district, etc.)
- [x] **SMS-04**: Admin can create A2P broadcast campaigns targeting voter segments
- [x] **SMS-05**: System automatically processes STOP/opt-out keywords and updates suppression list
- [x] **SMS-06**: System enforces quiet hours (no texts before 8am or after 9pm local time)
- [x] **SMS-07**: System supports 10DLC registration flow for A2P messaging
- [x] **SMS-08**: System tracks message delivery status via provider webhooks

### Phone Calls

- [x] **CALL-01**: Navigator can initiate call to voter via native phone dialer (click-to-call)
- [x] **CALL-02**: Navigator completes post-call disposition form (answered/voicemail/no answer/refused)
- [x] **CALL-03**: Admin can create call scripts displayed to Navigator during calls
- [x] **CALL-04**: Call disposition includes voter sentiment and free-text notes

### Door Knocking

- [x] **DOOR-01**: Navigator can view ordered walk list for assigned turf with map view
- [x] **DOOR-02**: Navigator can record door status (not home/answered/refused/moved) per visit
- [x] **DOOR-03**: Admin can create configurable at-the-door survey forms
- [x] **DOOR-04**: Navigator can complete survey forms offline — data queued for sync
- [x] **DOOR-05**: System tracks door-knock attempts per voter with timestamp history

### Task Management

- [x] **TASK-01**: Admin/Super Navigator can create tasks and assign to Navigators
- [x] **TASK-02**: Tasks can be linked to voter lists, turfs, or specific voters
- [x] **TASK-03**: Tasks have types (contact list, event, data entry, custom), due dates, and priority
- [x] **TASK-04**: System auto-updates task progress based on linked voter contacts
- [x] **TASK-05**: Navigator can add notes to tasks (visible to their Super Navigator and Admin)

### Voter Notes & Contact History

- [x] **NOTE-01**: Navigator can add free-text notes to any voter after an interaction
- [x] **NOTE-02**: System maintains unified contact timeline per voter (texts, calls, door knocks)
- [x] **NOTE-03**: Note visibility follows role hierarchy — Navigator sees own; Super Nav sees team; Admin sees all
- [x] **NOTE-04**: Navigator can record voter sentiment (strong support → lean support → undecided → lean oppose → strong oppose)

### Analytics & Reporting

- [x] **ANLYT-01**: Navigator sees personal dashboard (my tasks, my stats, my assigned turfs)
- [x] **ANLYT-02**: Super Navigator sees team dashboard (performance metrics, task completion, turf coverage)
- [ ] **ANLYT-03**: Admin sees organization dashboard with geographic heat maps and trend analysis
- [x] **ANLYT-04**: System tracks key metrics: doors knocked, texts sent, calls made, contact rate, response rate, sentiment distribution
- [x] **ANLYT-05**: Admin can export any filtered dataset as CSV/Excel

### Volunteer Management

- [ ] **VOL-01**: New Navigator goes through onboarding flow: signup → Maine Title 21-A data usage acknowledgment → role assignment → training materials
- [ ] **VOL-02**: System provides opt-in leaderboards with engagement metrics to motivate volunteers
- [ ] **VOL-03**: In-app training materials and best practices guides

### Events

- [ ] **EVT-01**: Admin/Super Navigator can create events (canvass events, phone banks, community meetings)
- [ ] **EVT-02**: Navigators can RSVP to events with reminder notifications
- [ ] **EVT-03**: Navigators check in at events — system tracks attendance

### Push Notifications

- [x] **PUSH-01**: System sends push notifications for task reminders (upcoming due dates)
- [x] **PUSH-02**: System sends push notifications for new turf/task assignments
- [x] **PUSH-03**: System alerts Navigator when unsynced data exists and connectivity is available

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Auth

- **AUTH-10**: SSO/OIDC login for Admin users via Google/Microsoft
- **AUTH-11**: Two-factor authentication

### Advanced Outreach

- **SMS-09**: AI-suggested message personalization based on voter profile
- **CALL-05**: Power dialer — auto-dial next voter after disposition logged
- **CALL-06**: VoIP integration for in-app calling

### Advanced Analytics

- **ANLYT-06**: Predictive voter scoring based on contact history and sentiment
- **ANLYT-07**: A/B testing for message templates

### Advanced Volunteer

- **VOL-04**: Availability scheduling — Navigators indicate when they're available
- **VOL-05**: Automated turf assignment based on Navigator location/availability

## Out of Scope

| Feature | Reason |
|---------|--------|
| Fundraising/donation tracking | Not core to voter outreach mission |
| Social media integration | Focus on direct voter contact channels |
| Email campaigns | SMS and phone are primary channels for this audience |
| Voter registration | Focus is outreach to existing registered voters |
| NGP VAN/VoteBuilder integration | Greenfield system, no legacy integrations needed |
| Multi-tenancy for other state parties | Single-tenant for MaineGOP; can generalize later |
| AI voter scoring | Adds complexity without proven value in v1 |
| Real-time chat between Navigators | Task notes and push notifications sufficient for v1 |

## Traceability

| Requirement | Objective | Status |
|-------------|-----------|--------|
| AUTH-01 | Objective 1 | Complete |
| AUTH-02 | Objective 1 | Complete |
| AUTH-03 | Objective 1 | Complete |
| AUTH-04 | Objective 1 | Complete |
| AUTH-05 | Objective 1 | Complete |
| AUTH-06 | Objective 1 | Complete |
| AUTH-07 | Objective 1 | Complete |
| AUTH-08 | Objective 1 | Complete |
| AUTH-09 | Objective 1 | Complete |
| VOTER-01 | Objective 2 | Complete |
| VOTER-02 | Objective 2 | Complete |
| VOTER-03 | Objective 2 | Complete |
| VOTER-04 | Objective 2 | Complete |
| VOTER-05 | Objective 2 | Complete |
| VOTER-06 | Objective 2 | Complete |
| VOTER-07 | Objective 2 | Complete |
| VOTER-08 | Objective 2 | Complete |
| VOTER-09 | Objective 2 | Complete |
| VOTER-10 | Objective 2 | Complete |
| TURF-01 | Objective 3 | Complete |
| TURF-02 | Objective 3 | Complete |
| TURF-03 | Objective 3 | Complete |
| TURF-04 | Objective 3 | Complete |
| TURF-05 | Objective 3 | Complete |
| TURF-06 | Objective 3 | Complete |
| TURF-07 | Objective 3 | Complete |
| TURF-08 | Objective 3 | Complete |
| SYNC-01 | Objective 4 | Complete |
| SYNC-02 | Objective 4 | Complete |
| SYNC-03 | Objective 4 | Complete |
| SYNC-04 | Objective 4 | Complete |
| SYNC-05 | Objective 4 | Complete |
| SYNC-06 | Objective 4 | Complete |
| SYNC-07 | Objective 4 | Complete |
| DOOR-01 | Objective 5 | Complete |
| DOOR-02 | Objective 5 | Complete |
| DOOR-03 | Objective 5 | Complete |
| DOOR-04 | Objective 5 | Complete |
| DOOR-05 | Objective 5 | Complete |
| NOTE-01 | Objective 5 | Complete |
| NOTE-02 | Objective 5 | Complete |
| NOTE-03 | Objective 5 | Complete |
| NOTE-04 | Objective 5 | Complete |
| SMS-01 | Objective 6 | Complete |
| SMS-02 | Objective 6 | Complete |
| SMS-03 | Objective 6 | Complete |
| SMS-04 | Objective 6 | Complete |
| SMS-05 | Objective 6 | Complete |
| SMS-06 | Objective 6 | Complete |
| SMS-07 | Objective 6 | Complete |
| SMS-08 | Objective 6 | Complete |
| CALL-01 | Objective 7 | Complete |
| CALL-02 | Objective 7 | Complete |
| CALL-03 | Objective 7 | Complete |
| CALL-04 | Objective 7 | Complete |
| TASK-01 | Objective 8 | Complete |
| TASK-02 | Objective 8 | Complete |
| TASK-03 | Objective 8 | Complete |
| TASK-04 | Objective 8 | Complete |
| TASK-05 | Objective 8 | Complete |
| PUSH-01 | Objective 8 | Complete |
| PUSH-02 | Objective 8 | Complete |
| PUSH-03 | Objective 8 | Complete |
| ANLYT-01 | Objective 9 | Complete |
| ANLYT-02 | Objective 9 | Complete |
| ANLYT-03 | Objective 9 | Pending |
| ANLYT-04 | Objective 9 | Complete |
| ANLYT-05 | Objective 9 | Complete |
| VOL-01 | Objective 10 | Pending |
| VOL-02 | Objective 10 | Pending |
| VOL-03 | Objective 10 | Pending |
| EVT-01 | Objective 10 | Pending |
| EVT-02 | Objective 10 | Pending |
| EVT-03 | Objective 10 | Pending |

**Coverage:**
- v1 requirements: 74 total
- Mapped to objectives: 74
- Unmapped: 0

---
*Requirements defined: 2026-04-10*
*Last updated: 2026-04-10 after roadmap creation*
