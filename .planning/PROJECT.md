# Navigators

## What This Is

A cross-platform voter outreach platform for MaineGOP that empowers grassroots volunteers ("Navigators") to systematically reach voters through door-knocking, text messaging, and phone calls. Built on eden-platform-go and eden-ui-flutter, it delivers full offline support for rural Maine, strict role-based access control, and analytics to measure organizing impact.

## Core Value

Navigators can go into the field with a complete voter list, map, and outreach tools — work entirely offline in rural Maine — and have every interaction automatically sync back to give leadership real-time visibility into grassroots organizing efforts.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Import and manage voter data from Maine CVR and vendor sources (L2)
- [ ] Geocode voter addresses for map display
- [ ] Search, filter, and sort voters by district, party, voting history, geography, tags
- [ ] Full voter profiles with party enrollment, voting history, registration date
- [ ] Admin draws turf polygon boundaries on interactive maps
- [ ] Assign turfs to Navigators with auto-populated voter lists
- [ ] Download offline map tiles + voter data for assigned turfs
- [ ] Route optimization for efficient door-knocking within turfs
- [ ] Track turf completion progress with visualization
- [ ] P2P texting with human-initiated conversations (TCPA compliant)
- [ ] A2P broadcast SMS campaigns with 10DLC registration
- [ ] Message templates with merge fields
- [ ] Opt-out handling and quiet hours enforcement
- [ ] Click-to-call via native dialer with post-call disposition logging
- [ ] Call scripts displayed during calls
- [ ] Offline-first door-knock data capture with configurable surveys
- [ ] Task creation, assignment, and linking to voter lists/turfs/voters
- [ ] Auto-progress tracking based on voter contacts
- [ ] Per-voter notes with role-scoped visibility (Navigator → Super Nav → Admin)
- [ ] Unified voter contact timeline (texts, calls, door knocks)
- [ ] Voter sentiment tracking over time
- [ ] Navigator personal dashboard with stats and assigned turfs
- [ ] Super Navigator team dashboard with performance metrics
- [ ] Admin dashboard with geographic heat maps and trend analysis
- [ ] CSV/Excel data export (Admin only)
- [ ] Push notifications (task reminders, assignments, sync alerts)
- [ ] Volunteer onboarding flow with Maine Title 21-A data usage acknowledgment
- [ ] Event management (canvass events, phone banks, RSVP, check-in)
- [ ] Strict RBAC: Admin (org-wide), Super Navigator (team-scoped), Navigator (turf-scoped)
- [ ] Full offline sync engine with conflict resolution
- [ ] Audit trail for all voter data access

### Out of Scope

- VoIP/power dialer — Native dialer sufficient for v1, power dialer is v2+
- Fundraising/donation tracking — Not core to voter outreach mission
- Social media integration — Focus on direct voter contact channels
- Email campaigns — SMS and phone are the primary channels for this audience
- Voter registration — Focus is outreach to existing registered voters
- Integration with NGP VAN/VoteBuilder — Greenfield system, no legacy integrations needed

## Context

- **Platform:** eden-platform-go (Go backend with ConnectRPC, PostgreSQL/sqlc, JWT auth, RBAC) + eden-ui-flutter (Flutter cross-platform for Web, iOS, Android)
- **Eden libs:** Located at /Users/justin/dev/eden-libs/ — provides auth, RBAC, company model, audit logging, webhooks, ConnectRPC infrastructure out of the box
- **Voter data:** Maine CVR system exports pipe-delimited text files. Political parties can access: name, residence/mailing address, YOB, party enrollment, voting history, electoral districts, registration date, voter status. Governed by Maine Title 21-A §196-A.
- **SMS landscape:** 10DLC registration mandatory since Feb 2025. P2P texting has stronger TCPA protection (human-initiated). Will evaluate Twilio, Vonage, Bandwidth during implementation.
- **Geography:** Maine is heavily rural. Offline support is critical — many areas have limited/no cellular data. Navigators need to download everything before going into the field.
- **Scale:** Pilot with <50 Navigators and subset of voter file, architect for full state (1M+ voters, 200+ Navigators).

## Constraints

- **Tech stack:** eden-platform-go + eden-ui-flutter — must consume shared eden-libs
- **Offline:** Full offline capability required for rural Maine — not optional
- **Compliance:** Maine Title 21-A §196-A governs all voter data usage — audit trails mandatory
- **SMS compliance:** 10DLC registration required before A2P messaging; TCPA governs P2P
- **Cross-platform:** Must work equally well on Web, iOS, and Android from single Flutter codebase
- **Data privacy:** Voter data encrypted at rest, role-scoped access, no export for non-Admins

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| eden-platform-go + eden-ui-flutter | Existing proven stack, shared libs provide auth/RBAC/audit out of box | — Pending |
| Flutter for all platforms | Single codebase for Web/iOS/Android, good offline/map support | — Pending |
| Mapbox GL for mapping | Best Flutter plugin ecosystem, offline tile support, geocoding API | — Pending |
| Isar for offline DB | Fast local DB for Flutter with sync capabilities | — Pending |
| P2P + A2P SMS dual approach | P2P for personal outreach (TCPA safe), A2P for broadcasts (requires 10DLC) | — Pending |
| Strict role-based data scoping | Navigator sees only assigned turf — legal compliance + need-to-know principle | — Pending |
| Full offline-first architecture | Rural Maine has poor connectivity — field work cannot depend on signal | — Pending |

---
*Last updated: 2026-04-10 after initialization*
