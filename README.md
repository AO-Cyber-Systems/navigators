# Navigators — MaineGOP Voter Outreach Platform

Empower MaineGOP grassroots volunteers ("Navigators") to systematically reach voters through door-knocking, text messaging, and phone calls — with full offline support for rural Maine, strict role-based access, and analytics to measure impact.

## Tech Stack

- **Backend:** Go ([eden-platform-go](https://github.com/justindonnaruma/eden-platform-go)) — ConnectRPC APIs, PostgreSQL/sqlc, JWT auth, RBAC
- **Frontend:** Flutter ([eden-ui-flutter](https://github.com/justindonnaruma/eden-ui-flutter)) — Web, iOS, Android from single codebase
- **Infrastructure:** Docker Compose, NATS (events/messaging), MinIO (file storage), Prometheus (metrics)
- **Maps:** Mapbox GL (Flutter plugin + tile server for offline)
- **SMS:** TBD — evaluating Twilio, Vonage, Bandwidth for P2P + A2P capabilities
- **Offline:** Isar local DB + background sync queue

## Roles & Permissions

| Role | Scope | Capabilities |
|------|-------|-------------|
| **MeGOP Admin** | Organization-wide | All operations. Manage users, upload voter files, draw turfs, view all analytics, configure SMS campaigns, manage budgets |
| **Super Navigator** | Team-scoped | Manage assigned Navigators, assign turfs/tasks, view team analytics, see all notes from their Navigators, create task lists |
| **Navigator** | Turf/assignment-scoped | View assigned voters, log door knocks, send P2P texts, initiate calls, add voter notes, complete tasks, work offline |

## Core Features

### 1. Voter Data Management
Import and manage voter data from Maine's CVR system and vendor sources (L2, etc.). Batch geocoding, merge/dedup, search & filter by district, party, voting frequency, geography, and custom tags.

### 2. Turf Management & Mapping
Full turf lifecycle: Admins draw polygon boundaries on interactive maps, assign turfs to Navigators, and track completion. Navigators download offline map tiles + voter data before heading out. Route optimization for efficient door-knocking. Geographic heat maps for contact density and support levels.

### 3. Outreach Tools
- **P2P Texting:** Human-initiated conversations for TCPA compliance. Templates with merge fields, conversation threading, opt-out handling.
- **A2P Broadcast:** Admin-created bulk SMS campaigns targeting voter segments. Requires 10DLC registration.
- **Click-to-Call:** Initiate calls via native dialer with post-call disposition logging and call scripts.
- **Door Knocking:** Offline-first walk lists with configurable at-the-door surveys and door status tracking.

### 4. Task Management
Create and assign tasks linked to voter lists, turfs, or specific voters. Auto-progress tracking based on voter contacts. Task types include contact lists, events, data entry, and custom. Notes visible up the role hierarchy (Navigator → Super Navigator → Admin).

### 5. Voter Notes & Contact History
Unified timeline of all interactions per voter (texts, calls, door knocks). Role-scoped visibility. Voter sentiment tracking over time (strong support → undecided → strong oppose).

### 6. Analytics & Reporting
Role-appropriate dashboards with key metrics: doors knocked, texts sent, calls made, contact rates, response rates, voter sentiment distribution. Geographic heat maps, time-series trends, and CSV/Excel export.

### 7. Volunteer Management
Onboarding flow with Maine Title 21-A data usage acknowledgment, availability scheduling, opt-in leaderboards, and in-app training materials.

### 8. Event Management
Create canvass events, phone banks, and community meetings. RSVP tracking, auto-turf assignment for canvass events, and check-in.

### 9. Push Notifications
Task reminders, new assignment alerts, sync status alerts, and campaign updates from Admins.

## Architecture

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

## Data Privacy & Compliance

- All voter data encrypted at rest (PostgreSQL + app-level for local DB)
- Audit trail for all voter data access
- Maine Title 21-A §196-A data usage acknowledgment required at onboarding
- Voter data export restricted to Admin role only
- No voter SSN, full DOB, or felony data stored (per Maine law)
- 10DLC registration required before A2P messaging
- TCPA compliance: P2P messages must be human-initiated
- Opt-out processing and quiet hours enforcement

## Development Phases

| Phase | Weeks | Focus |
|-------|-------|-------|
| **1. Foundation** | 1-4 | Project scaffolding, auth/RBAC, voter data import, basic UI |
| **2. Mapping & Turfs** | 5-8 | Mapbox integration, turf management, offline sync engine |
| **3. Outreach Tools** | 9-12 | SMS (P2P + A2P), click-to-call, door-knock logging |
| **4. Tasks & Collaboration** | 13-16 | Task management, voter notes, team dashboards, push notifications |
| **5. Analytics & Polish** | 17-20 | Full analytics, event management, onboarding, production hardening |

## License

Proprietary — MaineGOP
