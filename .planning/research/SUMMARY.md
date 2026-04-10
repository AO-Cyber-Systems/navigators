# Project Research Summary

**Project:** Navigators (MaineGOP Voter Outreach Platform)
**Domain:** Political field organizing — canvassing, SMS, phone banking, offline-first mobile
**Researched:** 2026-04-10
**Confidence:** HIGH

## Executive Summary

Navigators is a political field organizing platform built on eden-platform-go (Go/ConnectRPC/PostgreSQL) and eden-ui-flutter (Flutter). The research converges on one defining architectural requirement: the platform must work genuinely offline in rural Maine, where cell coverage is unreliable for hours at a time. This is not a convenience feature — it is the foundational constraint that shapes every technical decision. flutter_map + FMTC for offline maps, Drift + sqlcipher for encrypted local storage, and a push/pull sync engine with server-side conflict resolution are the non-negotiable architectural choices. Everything else flows from this.

The competitive positioning is clear: existing tools for GOP campaigns (Vottiv, Campaign Knock, PDI) each cover part of the problem, but none unify offline canvassing, P2P texting, and click-to-call with deep Maine CVR data integration. Navigators' unique position is purpose-built for MaineGOP grassroots organizing with genuine offline-first architecture, unified multi-channel outreach, and native support for Maine CVR and L2 voter file formats.

The primary risks are legal (TCPA liability from SMS misuse, Maine Title 21-A voter data restrictions), operational (10DLC registration gating all SMS launch — 15-30 day delay with no expedited option), and technical (offline sync conflicts, tile storage scaling, map performance at 100K+ voter pins). The mitigation strategy is: start 10DLC registration immediately before writing any SMS code, scope turf assignments to individual navigators to minimize sync conflicts by design, and use vector tiles scoped per turf (not all of Maine) to keep download sizes manageable.

---

## Key Findings

### Recommended Stack

The eden-platform-go backend is extended with Twilio (the only SMS provider with a first-party Go SDK — decisive given Go is non-negotiable), Firebase Admin SDK for push notifications (free, cross-platform, Go-native), and a two-tier geocoding strategy (US Census Geocoder batch for free voter file imports + Google Maps API for real-time fallback). The Flutter app adds flutter_map + FMTC for offline-capable maps, Drift + sqlcipher for AES-256 encrypted local SQLite (Isar was abandoned by its author in 2025 — do not use it), and workmanager + connectivity_plus for background sync. Pilot infrastructure costs are approximately $135-200/month total for domain-specific services, scaling to ~$650-750/month at 1M voters.

**Core technologies:**
- **Twilio (Go SDK):** P2P + A2P SMS — only SMS provider with a first-party Go SDK; best political 10DLC compliance tooling
- **flutter_map + FMTC:** Offline maps — pure Flutter, no native bridge, FMTC provides per-turf tile export/import; Mapbox offline billing is per-tile-request and prohibitive
- **Drift + sqlcipher:** Local encrypted database — AES-256 encryption for voter PII; Isar abandoned in 2025, ObjectBox requires commercial license for sync; Drift matches the PostgreSQL relational model
- **Firebase FCM + Go Admin SDK:** Push notifications — free, no message limits, first-party Go and Flutter support
- **US Census Geocoder + Google Maps:** Geocoding — Census is free for 85-90% of addresses; Google fallback handles remainder at $0.005/request
- **workmanager + connectivity_plus:** Background sync — platform-native scheduling, handles battery constraints and exponential backoff
- **PostGIS:** Spatial queries for turf-voter containment — GiST indexes make ST_Contains fast at 1M+ voters
- **NATS JetStream:** Async event processing — transactional outbox pattern for SMS webhooks and voter import pipeline

### Expected Features

Research surveyed 10 competitor platforms (MiniVAN/NGP VAN, Hustle, GetThru, Reach, Campaign Knock, Qomon, PDI, Ecanvasser, Vottiv, CallHub).

**Must have (table stakes) — missing any of these kills volunteer adoption:**
- Walk list generation with map view of voter pins in assigned turf
- Genuine offline mode: download voters + map tiles before going out, sync on reconnect
- Configurable door-knock surveys with branching scripts and door disposition tracking
- Per-voter notes with voice-to-text at the door
- P2P texting with templates, opt-out handling (STOP), and conversation threading
- Click-to-call with post-call disposition logging and script display
- Role-based access: Admin, Super Navigator, Navigator
- Real-time canvassing dashboard (doors knocked, contact rate, survey results)
- Turf drawing, assignment to navigators, and completion visualization

**Should have (competitive differentiators):**
- Unified contact timeline — all channels (door, text, call) on one voter profile; few competitors do this well
- Anti-cheating / canvass verification via GPS breadcrumbs
- Geographic heat maps of survey results by precinct/turf
- Smart task assignment — auto-create follow-ups based on canvass outcomes
- A2P broadcast SMS — having both P2P and A2P in one platform is rare
- Event management with volunteer RSVP and auto-turf-assignment at events
- Voter sentiment tracking over multiple contacts

**Defer to v2+:**
- VoIP / predictive dialer (requires SIP infrastructure, AMD, per-minute costs)
- AI-powered voter scoring (need baseline data first)
- Multi-tenant SaaS (single-org deployment for MaineGOP pilot)
- Email campaigns, fundraising, social media, direct mail
- Complex workflow automation, gamification, NGP VAN integration

### Architecture Approach

Navigators is a modular monolith inside eden-platform-go — a single Go binary with domain-separated packages (voter, turf, outreach, task, sync, analytics, event, notify, audit) communicating through Go interfaces and NATS JetStream events. This is the right call for a 1-3 developer team: microservices overhead is unjustified, voter/turf/contact data is deeply interrelated, and domain packages have clean enough interfaces to extract later if scale demands it. Each package follows Repository + Service + Handler structure; NATS + transactional outbox handles async processing; scoped data access (all queries pass turf IDs derived from RBAC JWT) enforces privacy by construction.

**Major components:**
1. **voter package** — CVR/L2 import pipeline (streaming parse → Census geocode batch → Google fallback → dedup/upsert), voter search, tags, contact log as unified timeline
2. **turf package** — PostGIS polygon CRUD, ST_Contains materialization of turf_voters, walk list generation (nearest-neighbor + optional Mapbox Optimization), offline tile packaging per turf
3. **sync package** — Push/pull protocol over ConnectRPC, operation log with server-side conflict resolution, delta sync by cursor per user, scoped to assigned turfs only
4. **outreach package** — Door knocks, call logs, SMS conversations; sms.Provider interface with Twilio implementation; webhook → NATS → consumer pattern; global opt-out suppression table
5. **task package** — Assignment, auto-progress tracking from contact events, push notifications via FCM
6. **analytics package** — Pre-computed rollups via NATS consumers, dashboards, CSV export with audit trail
7. **Flutter app** — Drift local DB mirroring turf-scoped voter subset; flutter_map for offline vector tiles; workmanager for background sync; Riverpod state management

### Critical Pitfalls

1. **10DLC registration takes 15-30+ days and blocks all A2P SMS** — Start registration in week 1 before writing any SMS code. Budget 30 days minimum. P2P texting (human-initiated, one message at a time) does not require 10DLC and can bridge the gap.

2. **TCPA liability from blurring P2P and A2P** — Each P2P message must require genuine human action; no pre-loaded auto-send queues. Implement a global suppression table checked before every send. Get legal review of the texting UX before building it. TCPA violations are $500-$1,500 per message with class-action exposure.

3. **Offline sync conflicts corrupt canvassing data** — Design turf assignment one-to-one (each turf to one navigator) to prevent concurrent edits by design. Use append-only contact logs. Last-write-wins only for survey responses on the same voter/navigator. Server is always authoritative.

4. **Map tile storage explodes device storage** — Do not download all of Maine at zoom 14-17 (46GB raster). Use vector tiles (MBTiles format, 5-10x smaller), scoped per assigned turf. A typical 5 sq mi rural turf requires 5-15MB at zoom 12-18.

5. **Voter file import errors at scale** — Maine CVR and L2 arrive in different formats with no universal voter ID. Use a staging-table approach: parse → validate → geocode → dedup → promote. Generate an import report. Design for incremental re-imports from day one. Legal review of Maine Title 21-A Section 196-A before exposing any voter data.

6. **Map rendering freezes at 100K+ voter pins** — Implement marker clustering (aggregated counts at low zoom, individual pins at high zoom). Viewport-based loading. Canvas-based markers. Spatial index in local SQLite. Test with production-scale data on low-end devices throughout development.

7. **Sync storms when all navigators reconnect simultaneously** — Add random 0-60 second jitter before sync on connectivity resume. Exponential backoff with jitter on retries. Batch all queued operations into a single ConnectRPC call per sync. Load test with 200 concurrent sync sessions.

---

## Implications for Roadmap

Research from all four dimensions converges on the same 8-objective build order. The dependency graph is strict for the first four objectives; later objectives have more flexibility.

### Objective 1: Foundation + Auth
**Rationale:** Everything depends on this. PostgreSQL + PostGIS schema, RBAC with permission+scope model (design for 5-6 role variants from the start, not just 3), NATS JetStream stream setup, MinIO, proto service definitions, global suppression table, audit logging table, event outbox table, CI/CD. Cannot be parallelized with anything else.
**Delivers:** Runnable service skeleton with auth, scoped data access patterns, migration tooling, global suppression list schema
**Addresses:** RBAC for Admin / Super Navigator / Navigator + turf-level scope
**Avoids:** Pitfall 15 (RBAC complexity grows if scope isn't designed upfront), Pitfall 17 (Maine Title 21-A audit requirements), Pitfall 8 (suppression list must exist before any SMS feature is built)

### Objective 2: Voter Data Pipeline
**Rationale:** All other features reference voters. Data model decisions here (JSONB for voting history, PostGIS POINT for location, state voter ID as dedup key, contact_log as unified timeline) propagate everywhere. Must design for incremental re-imports, not just initial bulk load.
**Delivers:** CVR/L2 import with staging table, Census + Google two-tier geocoding, voter search/filter scoped to org, voter profile with contact log schema, import job tracking UI for admins
**Uses:** Census Geocoder (free batch), Google Maps API (fallback), PostgreSQL COPY for bulk insert, MinIO for original file storage
**Avoids:** Pitfall 4 (dedup failures, format mismatch), Pitfall 16 (geocoding rate limits and costs), Pitfall 17 (legal review gates this objective before any voter data is exposed), Pitfall 11 (data staleness — freshness tracking from day one)

### Objective 3: Turf Management + Maps
**Rationale:** Required before offline, canvassing, and all turf-scoped features. PostGIS spatial operations and materialized turf_voters are foundational to both the offline sync scope and walk list generation. Tile format decision (vector, not raster) must be made here.
**Delivers:** Turf polygon CRUD with PostGIS, ST_Contains materialization of turf_voters, flutter_map integration with vector tiles, voter pins with clustering, turf assignment to navigators, polygon simplification (Douglas-Peucker), per-turf tile download sizing
**Uses:** flutter_map ^8.2.2, FMTC, PostGIS ST_Contains, GiST spatial indexes
**Avoids:** Pitfall 5 (tile storage — vector tiles scoped per turf, not all of Maine), Pitfall 6 (pin rendering — clustering + viewport loading required in this objective), Pitfall 13 (polygon complexity — simplification built in)

### Objective 4: Offline Sync Engine
**Rationale:** Must ship before any field-facing outreach tools. This is the riskiest technical objective and must be validated before canvassing or SMS is built on top of it. "Works offline" is a hard requirement, not a feature enhancement.
**Delivers:** Drift + sqlcipher local DB schema, push/pull sync protocol over ConnectRPC, conflict resolution rules (append-only contacts, last-write-wins surveys, server authority), jitter on reconnect, sync status UI, offline data package download (voters + tasks + surveys + map tiles)
**Uses:** drift ^2.26.0, drift_flutter, sqlcipher_flutter_libs, workmanager, connectivity_plus, FMTC
**Avoids:** Pitfall 3 (conflict corruption — turf scoping + append-only semantics), Pitfall 7 (sync storms — jitter + batch sync required; load testing is acceptance criteria for this objective)

### Objective 5: Door Knocking + Contact Log
**Rationale:** Simplest outreach channel — no external provider dependency. Validates the offline sync engine under real field conditions. The canvassing workflow is the core product loop that volunteers will use most.
**Delivers:** Walk list generation (nearest-neighbor ordering), at-the-door survey flow with branching scripts, door disposition logging, per-voter notes with voice-to-text, unified contact timeline on voter profile, GPS location tracking (distance-based, not continuous), data freshness indicators
**Avoids:** Pitfall 10 (battery drain — distance-based GPS, pause sync below 20% battery), Pitfall 9 (onboarding friction — "parking lot test": download to first door knock in under 5 minutes), Pitfall 11 (data staleness — freshness indicators), Pitfall 18 (volunteer turnover — structured dispositions, not free-text only)

### Objective 6: SMS Integration
**Rationale:** Higher external complexity than door knocking (provider contract, 10DLC registration, webhook infrastructure, TCPA compliance). 10DLC registration initiated in Objective 1's first week should be approved by the time this objective begins. SMS also benefits from having suppression list, audit logging, and contact model established.
**Delivers:** Twilio provider abstraction, P2P texting with per-message human-send enforcement, conversation threading, message templates with merge fields, quiet hours enforcement (8am-9pm ET), opt-out processing via webhook (<5 seconds from STOP to suppression), delivery status tracking, A2P broadcast campaigns with 10DLC gating
**Uses:** github.com/twilio/twilio-go, NATS webhook→consumer pattern, global suppression table from Objective 1
**Avoids:** Pitfall 1 (10DLC delays — registration started week 1), Pitfall 2 (TCPA P2P/A2P confusion — separate code paths, legal review of UX), Pitfall 8 (opt-out mishandling — suppression check before every send), Pitfall 12 (carrier filtering — delivery monitoring, avoid spam keywords in templates)

### Objective 7: Tasks + Collaboration
**Rationale:** Coordination layer that needs outreach data to be meaningful. Task auto-progress requires contact logs flowing from Objective 5. Push notifications require FCM tokens from a functioning mobile app.
**Delivers:** Task CRUD with assignment to navigators, auto-progress from contact events via NATS consumers, team dashboards (doors knocked, contact rate, survey results per navigator), push notifications for new assignments and deadlines, event management with RSVP and auto-turf-assignment
**Uses:** firebase_messaging, firebase.google.com/go/v4 Admin SDK, NATS task.progress consumers

### Objective 8: Analytics + Polish
**Rationale:** Reporting on data from all prior objectives. Map tile packager (pre-generating per-turf MBTiles on turf assignment) can ship here or be folded into Objective 3. Volunteer onboarding polish, heat maps, and CSV export are additive.
**Delivers:** Real-time admin dashboard, geographic heat maps of support by precinct/turf, CSV export with audit trail, volunteer onboarding flow with invite-link pre-configuration, per-turf MBTiles background packager, anti-cheating GPS breadcrumb verification
**Uses:** FMTC for final tile packaging, analytics rollups from NATS consumers

### Objective Ordering Rationale

- Objectives 1-3 are strictly sequential: schema must exist before voter data, voter data must exist before spatial turf operations.
- Objective 4 (offline sync) must come before any field tools because "works offline" is a prerequisite, not an enhancement. Building canvassing or SMS on an unvalidated sync engine creates rework.
- Objective 5 (door knocking) comes before SMS: no external provider dependency, exercises sync under real conditions, lower legal risk, faster to build.
- Objective 6 (SMS) is deferred intentionally: 10DLC registration initiated at project start buys the 15-30 days needed. SMS has the highest legal risk and benefits from established suppression list, audit logging, and contact model.
- Objectives 7-8 are additive and can be time-boxed under election-cycle pressure without breaking the core field workflow.

### Research Flags

**Needs deeper research during planning:**
- **Objective 4 (Offline Sync):** The specific ConnectRPC streaming patterns for sync, handling of large delta payloads, and binary proto compression for rural low-bandwidth conditions need validation with the eden-platform-go team. MEDIUM confidence sources only.
- **Objective 6 (SMS / 10DLC):** 10DLC registration process for a non-501(c) state party organization (MaineGOP) with Twilio needs validation with Twilio's political compliance team before this objective begins.
- **Objective 3 (Maps — tile architecture):** ARCHITECTURE.md references Mapbox GL + MBTiles server-side packager. STACK.md recommends flutter_map + OpenStreetMap + FMTC. These are compatible but the tile packaging workflow needs validation before committing to the tile serving architecture.

**Standard patterns (can proceed without research-objective):**
- **Objective 1 (Foundation):** eden-platform-go already provides schema migration, RBAC, and ConnectRPC patterns.
- **Objective 2 (Voter Import):** Staging-table import, Census Geocoder batch API, and PostgreSQL COPY are well-documented patterns.
- **Objective 5 (Door Knocking):** Form-based data capture with offline-first local write is straightforward once the sync engine exists.
- **Objective 7 (Tasks):** Firebase FCM with Go Admin SDK is well-documented with official examples.
- **Objective 8 (Analytics):** NATS consumer rollups and CSV export are standard patterns.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All primary recommendations backed by official docs. One internal inconsistency: ARCHITECTURE.md references Isar (abandoned in 2025) — Drift is correct per STACK.md. |
| Features | HIGH | Competitive analysis across 10 platforms. Table stakes confirmed across multiple sources. Feature/anti-feature recommendations are well-grounded in competitor analysis. |
| Architecture | MEDIUM | Modular monolith and PostGIS spatial design are HIGH confidence. Offline sync protocol specifics are MEDIUM (community sources). ARCHITECTURE.md diagrams reference Isar — substitute Drift. |
| Pitfalls | HIGH | Legal pitfalls (TCPA, 10DLC, Maine Title 21-A) backed by primary legal/regulatory sources. Technical pitfalls backed by concrete calculations and established patterns. |

**Overall confidence:** HIGH

### Gaps to Address

- **Isar vs Drift inconsistency:** ARCHITECTURE.md sync diagrams reference "Isar Local DB." Isar was abandoned in 2025. All implementation uses Drift. The diagrams are conceptually correct — substitute Drift for Isar everywhere.
- **Mapbox vs flutter_map tile serving:** ARCHITECTURE.md describes Mapbox GL + MBTiles packager; STACK.md recommends flutter_map + OpenStreetMap + FMTC. These are compatible but validate the per-turf tile packaging workflow before Objective 3 design begins.
- **Maine CVR exact format:** Research references Maine CVR pipe-delimited format but does not include the exact field list. Obtain the CVR data dictionary from MaineGOP before designing the import schema in Objective 2.
- **Route optimization confidence:** Rated MEDIUM. Nearest-neighbor heuristic is adequate for 20-50 door routes in v1. Add Mapbox Optimization API only if field feedback indicates walk route quality is a real problem.
- **10DLC political registration specifics:** The exact registration pathway for a state Republican party committee with Twilio/TCR needs validation. Start this conversation in week 1 of the project.

---

## Sources

### Primary (HIGH confidence)
- Twilio Go SDK (github.com/twilio/twilio-go) — SMS provider selection
- Twilio A2P 10DLC compliance docs — 10DLC registration requirements
- flutter_map pub.dev (^8.2.2) — map rendering choice
- FMTC documentation (fmtc.jaffaketchup.dev) — offline tile strategy
- Drift documentation (drift.simonbinder.eu) — local database choice
- PostGIS official docs — spatial query patterns
- Firebase Cloud Messaging Flutter docs — push notification setup
- NGP VAN MiniVAN documentation — competitive feature baseline
- Maine Legislature Title 21-A Section 196-A — voter data legal constraints
- Twilio webhooks in Go (official blog) — webhook processing pattern
- NATS JetStream consumers documentation (official) — event streaming patterns
- PostgreSQL COPY for bulk imports — import pipeline performance

### Secondary (MEDIUM confidence)
- Offline-first sync architecture patterns (sachith.co.uk, 2026) — sync protocol design
- Flutter offline-first architecture with conflict resolution (dev.to) — Flutter sync patterns
- NATS JetStream patterns for Go microservices (dasroot.net, 2026) — event consumer patterns
- MBTiles offline map architecture (Medium) — tile packaging approach
- Qomon, Vottiv, Ecanvasser, Reach, Campaign Knock feature docs — competitive feature analysis
- 2025 Political Texting Compliance Guide (politicalcomms.com) — TCPA compliance
- Wiley Law TCPA political campaign analysis — legal risk assessment

### Tertiary (LOW confidence / inferred)
- Route optimization via nearest-neighbor heuristic — standard algorithm, no specific political canvassing source
- Tile storage size estimates for Maine — calculated from known tile density formulas, not measured
- Battery drain estimates (13-38% per hour for GPS) — hardware benchmark studies, varies by device

---
*Research completed: 2026-04-10*
*Ready for roadmap: yes*
