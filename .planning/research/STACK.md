# Technology Stack: Domain-Specific Layers

**Project:** Navigators (MaineGOP Voter Outreach Platform)
**Researched:** 2026-04-10
**Base Platform:** eden-platform-go (Go/ConnectRPC/PostgreSQL/sqlc) + eden-ui-flutter (Flutter Web/iOS/Android)
**Scope:** Additional libraries, services, and integrations on top of the eden platform

---

## 1. SMS/Messaging Provider

### Recommendation: Twilio

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Twilio Programmable Messaging | Current | P2P + A2P SMS via 10DLC | Official Go SDK (`github.com/twilio/twilio-go`), mature political campaign support, best compliance tooling |
| Twilio Go SDK | Latest | Server-side SMS send/receive | First-party maintained, OpenAPI-generated, well-documented |

**Confidence:** HIGH

**Rationale:**
- Twilio has an official Go SDK (`twilio-go`) -- critical since the backend is Go. Bandwidth has NO Go SDK (PHP, C#, Node, Java, Ruby, Python only). This alone is decisive.
- Twilio's 10DLC registration tooling is the most mature for political use cases. Political campaigns require TCR registration + Campaign Verify ($95/2yr cycle) + political vetting.
- P2P texting (peer-to-peer, human-initiated) avoids A2P throughput limits for volunteer-driven outreach. A2P (application-to-person) handles automated reminders/alerts.

**Pricing (2025):**
- Outbound SMS: ~$0.0083/segment base + carrier surcharges (~$0.003-$0.005/msg)
- All-in cost: ~$0.012-$0.014/message
- 10DLC registration: $46 brand (one-time) + $15 campaign vetting + $1.50-$10/mo per campaign
- Long code: $1.15/month

**10DLC Compliance Requirements (Mandatory as of Feb 2025):**
- All A2P traffic on 10DLC numbers must be registered with The Campaign Registry (TCR)
- Unregistered traffic is now blocked by US carriers
- Political campaigns need "Political" special use case registration
- Non-501(c)(3/4/5/6) orgs need Political Vetting
- Registration takes 1-3 weeks

**Architecture Note:** Implement Twilio webhooks via ConnectRPC endpoints. Store message status callbacks for delivery tracking. Use Twilio Messaging Service (not raw phone numbers) for automatic number pool management.

### Alternatives Considered

| Alternative | Why Not |
|-------------|---------|
| Bandwidth | No Go SDK -- would require raw HTTP client or community wrapper. Pricing slightly lower ($0.004/msg base) but not worth the integration burden. |
| Vonage | No Go SDK. Less political campaign tooling. |
| Telnyx | Has a Go SDK but less mature political compliance tooling than Twilio. Consider if Twilio costs become prohibitive at scale. |

---

## 2. Mapping/GIS for Flutter

### Recommendation: flutter_map + FMTC (Flutter Map Tile Caching)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| flutter_map | ^8.2.2 | Map rendering (vector/raster) | Open-source, vendor-free, pure Flutter, excellent ecosystem |
| flutter_map_tile_caching (FMTC) | Latest | Offline tile download/cache | Purpose-built for flutter_map, bulk download, export/import stores, resume support |
| OpenStreetMap tiles | N/A | Base map tiles | Free, no API key, good coverage of rural Maine |

**Confidence:** HIGH

**Rationale:**
- **Offline-first is the #1 requirement.** Rural Maine = no connectivity. FMTC provides bulk tile download (1000+ tiles/sec), pause/resume, cross-device store export, and many-to-many tile-store relationships to reduce duplication.
- flutter_map is pure Dart/Flutter -- no native bridge issues, works on web+iOS+Android identically.
- Mapbox Flutter SDK charges for offline tile downloads separately from MAU pricing (offline tile requests are NOT included in MAU). For a political campaign downloading tiles for all of Maine at multiple zoom levels, this gets expensive fast.
- FMTC's store export feature lets HQ pre-download Maine tiles and push to field devices, keeping tile server costs at zero.

**Tile Strategy for Maine:**
- Pre-download OpenStreetMap tiles for all of Maine at zoom levels 10-17 (roads + houses visible)
- Maine is ~35,385 sq mi. At zoom 17, this is roughly 2-4GB of tiles -- manageable for modern devices
- Use FMTC bulk download at HQ on WiFi, then export stores to field devices
- Browse caching adds tiles for areas navigators visit that weren't pre-cached

**Key FMTC Features:**
- Bulk download with download recovery (resumes after crashes)
- Store export/import for sharing tile sets across devices
- Browse caching (no extra requests -- serves from cache on repeat visits)
- Many-to-many tile-store relationship reduces storage duplication

### Alternatives Considered

| Alternative | Why Not |
|-------------|---------|
| Mapbox Flutter SDK | Offline tiles billed per-request (not included in MAU). For a political campaign needing all of Maine offline, costs add up. Also proprietary SDK with complex licensing. |
| Google Maps Flutter | No offline tile support. Google Maps Flutter plugin has no offline mode. Dealbreaker. |
| MapLibre GL Flutter | Fork of old Mapbox GL Flutter. Less mature than flutter_map, native bridge adds complexity. Offline support exists but FMTC's tooling is superior. |

---

## 3. Offline-First Local Database for Flutter

### Recommendation: Drift (SQLite)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| drift | ^2.26.0 | Local SQLite ORM with type-safe queries | SQL power, compile-time safety, reactive streams, mature migrations |
| drift_flutter | ^0.2.4 | Flutter integration for Drift | Bundles up-to-date SQLite, isolate support |
| sqlcipher_flutter_libs | Latest | Database encryption | AES-256 full-database encryption for voter PII |

**Confidence:** HIGH

**Rationale:**
- **Voter data is PII.** Drift + sqlcipher provides industry-standard AES-256 full-database encryption. Isar and ObjectBox lack robust built-in encryption -- disqualifying for voter data.
- Drift uses SQLite under the hood, matching the PostgreSQL backend's relational model. Voter records, survey responses, and turf assignments are naturally relational. Same mental model on client and server.
- Compile-time query validation catches errors before runtime. Critical when 200+ navigators are collecting data offline.
- Reactive streams integrate cleanly with Flutter's state management (Riverpod/BLoC).
- Drift supports all platforms: Android, iOS, macOS, Windows, Linux, Web. The web backend uses sql.js (SQLite compiled to WASM).
- As of Drift 2.32.0+, no additional setup needed -- bundles SQLite automatically.

**Schema Strategy:**
- Mirror a subset of the PostgreSQL schema locally (voters in assigned turf, survey templates, task definitions)
- Use a `sync_queue` table for pending changes (survey responses, contact logs, status updates)
- Track `last_synced_at` per entity for delta sync
- Conflict resolution: last-write-wins with server as authority, but preserve all field submissions

### Alternatives Considered

| Alternative | Why Not |
|-------------|---------|
| Isar | **Abandoned by original author** (confirmed 2025). Community fork exists but uncertain future. No built-in encryption. NoSQL model doesn't match relational voter data well. |
| ObjectBox | Commercial license required for sync features. NoSQL model. Encryption is limited. Go SDK exists but we don't need client-server sync from the DB layer -- we have ConnectRPC. |
| Hive | Key-value only. No relational queries. No encryption. Not suitable for complex voter data with relationships. |
| sqflite | Lower-level than Drift. No type-safe queries, no reactive streams, no compile-time validation. Drift wraps SQLite better. |

---

## 4. Geocoding Service

### Recommendation: US Census Geocoder (batch) + Google Maps Geocoding API (real-time)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| US Census Geocoder API | Current | Batch geocoding of voter file imports | Free, handles 10K addresses/batch, includes census tract/block data |
| Google Maps Geocoding API | Current | Real-time single-address geocoding | High accuracy (~95%), 10K free/month, handles messy addresses well |

**Confidence:** HIGH

**Rationale:**
- **Two-tier strategy** optimizes cost. Voter file imports (100K-1M+ addresses from Maine CVR/L2) use the free Census Geocoder. Real-time lookups (manual address entry, address verification) use Google's higher-accuracy API.
- The Census Geocoder is completely free, handles 10K addresses per batch file, and returns census geographies (state, county, tract, block) -- useful for political turf analysis. For 1M voters, process in batches of 10K.
- Census Geocoder accuracy is ~85-90% for well-formatted US addresses. Maine voter files from CVR/L2 are pre-formatted, so hit rates will be good.
- Google Maps Geocoding API at $0.005/request with 10K free/month handles the long tail: addresses Census couldn't match, manually entered addresses, address corrections.
- Run geocoding server-side in Go. Both APIs are simple HTTP -- no SDK needed.

**Batch Processing Architecture (Go backend):**
1. Import voter CSV from Maine CVR/L2
2. Batch into 10K-address chunks
3. Submit to Census Geocoder API (free, rate-limited)
4. Addresses that fail Census -> queue for Google Geocoding API
5. Store lat/lng in PostgreSQL alongside voter records
6. Push geocoded voters to assigned turfs for offline sync

### Alternatives Considered

| Alternative | Why Not |
|-------------|---------|
| Google only | At $0.005/request, 1M voters = $5,000. Census Geocoder handles 85-90% for free. |
| Nominatim (self-hosted) | ~70% accuracy vs Google's ~95%. For voter addresses that must map to correct precincts/districts, accuracy matters. Maintenance burden of hosting. |
| Mapbox Geocoding | No batch API. Per-request pricing similar to Google. No advantage. |

---

## 5. Push Notifications

### Recommendation: Firebase Cloud Messaging (FCM)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| firebase_messaging | Latest | Push notifications (iOS/Android/Web) | Free, cross-platform, Flutter-native integration, handles all 3 platforms |
| firebase_core | Latest | Firebase initialization | Required base dependency |
| flutter_local_notifications | Latest | Local notification display | Rich notification UI, scheduling, actions |

**Confidence:** HIGH

**Rationale:**
- FCM is free with no message limits. For a political campaign with 200+ navigators, cost matters.
- Flutter has first-party FCM support via `firebase_messaging` package. Setup is well-documented for all three targets (Web, iOS, Android).
- Web push requires VAPID keys + service worker (`firebase-messaging-sw.js`). iOS requires APNs certificate. Android works out of the box.
- FCM handles the hard parts: device token management, platform-specific delivery (APNs for iOS, FCM for Android, Web Push for browsers).
- Send notifications from Go backend via Firebase Admin SDK for Go (`firebase.google.com/go/v4`).

**Use Cases:**
- New task assignments pushed to navigators
- Turf reassignment notifications
- Campaign-wide announcements
- Survey deadline reminders
- Sync completion confirmations

**Architecture:**
- Go backend sends via Firebase Admin SDK (supports Go natively)
- Store FCM device tokens per user in PostgreSQL
- Topic-based messaging for role-based broadcasts (e.g., all navigators in a region)
- Data messages (not notification messages) for background processing

### Alternatives Considered

| Alternative | Why Not |
|-------------|---------|
| OneSignal | Free tier limited. Adds another vendor. FCM is already needed for Android. |
| Custom APNs/FCM | Reinventing the wheel. Firebase Admin SDK abstracts this cleanly. |
| Pusher/Ably | Overkill for push notifications. Better for real-time data sync, which we handle via ConnectRPC. |

---

## 6. Route Optimization (Walk Lists)

### Recommendation: Server-side Go implementation using nearest-neighbor heuristic + Mapbox Optimization API for premium routes

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Custom Go TSP solver | N/A | Basic walk list ordering (nearest-neighbor) | Fast, free, runs offline, good enough for 20-50 door routes |
| Mapbox Optimization API v1 | Current | Optimized multi-stop walking routes | Walking profile support, up to 12 waypoints/request, integrates with existing Mapbox tile infrastructure |

**Confidence:** MEDIUM

**Rationale:**
- **Two-tier approach.** Most door-knocking routes are 20-50 houses in a neighborhood. A simple nearest-neighbor algorithm in Go produces routes that are 80-90% optimal -- good enough when a human is walking and can see the next house.
- For premium route optimization (large turfs, driving between clusters), use Mapbox Optimization API which solves TSP with walking/driving profiles.
- Google OR-Tools is powerful but is a C++ library with Python/Java/C# bindings -- no Go support. Would require a sidecar service or subprocess.
- OSRM (self-hosted) is excellent but requires 50GB+ RAM for US road data. Overkill for this use case.

**Walk List Algorithm (Go, runs on server):**
1. Select voters in turf polygon
2. Cluster by street/block using geohash proximity
3. Order within cluster using nearest-neighbor (Haversine distance)
4. Generate walking directions between clusters via Mapbox Directions API (walking profile)
5. Push ordered list to navigator's device for offline use

**Offline Consideration:** Route ordering is computed server-side and synced to device. Navigator sees an ordered list with a map showing waypoints. No real-time routing needed offline -- just follow the list.

### Alternatives Considered

| Alternative | Why Not |
|-------------|---------|
| Google OR-Tools | No Go bindings. Would need Python sidecar. Architectural complexity not justified for walk-list-sized problems. |
| OSRM (self-hosted) | 50GB+ RAM for US data. Massive infrastructure for a feature that nearest-neighbor handles adequately. |
| Valhalla | Similar to OSRM -- powerful but heavy infrastructure. No Go SDK. |
| Third-party canvassing APIs (Ecanvasser, WalkLists) | Vendor lock-in. These are full platforms, not APIs. Can't integrate routing alone. |

---

## 7. Background Sync & Offline-First Patterns

### Recommendation: workmanager + connectivity_plus + custom sync engine

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| workmanager | Latest | Background task scheduling | Persists across app restarts, platform-native (WorkManager/BGTaskScheduler) |
| connectivity_plus | Latest | Network status monitoring | Detects online/offline transitions, triggers sync |
| Custom sync engine | N/A | Manages sync queue, conflict resolution | Application-specific logic for voter data sync |

**Confidence:** HIGH

**Rationale:**
- Flutter's official architecture docs recommend this pattern for offline-first apps.
- `workmanager` uses Android's WorkManager and iOS's BGTaskScheduler -- both are platform-blessed APIs that handle battery optimization, retry with backoff, and network constraints.
- The sync engine pattern: local writes go to Drift DB -> changes queued in `sync_queue` table -> workmanager periodically attempts sync -> ConnectRPC calls to backend -> server confirms -> dequeue.

**Sync Architecture:**

```
[User Action] -> [Drift Local DB] -> [sync_queue table]
                                          |
                              [workmanager periodic task]
                                          |
                              [connectivity_plus check]
                                          |
                              [ConnectRPC batch sync call]
                                          |
                              [Server processes + responds]
                                          |
                              [Dequeue synced items]
                              [Pull server changes]
                              [Update local DB]
```

**Key Design Decisions:**
- **Sync queue in Drift:** Each pending change stored with entity type, entity ID, operation (create/update/delete), payload, timestamp, retry count
- **Conflict resolution:** Last-write-wins with server timestamp authority. All field submissions preserved (never discard a navigator's work). Conflicts flagged for admin review.
- **Delta sync:** Track `last_synced_at` per entity type. Pull only changes since last sync.
- **Batch sync:** Bundle multiple changes per ConnectRPC call. Reduces round trips on slow rural connections.
- **Retry with exponential backoff:** Failed syncs retry at increasing intervals. workmanager handles this natively with constraints (require network).
- **Sync priority:** Survey responses > contact logs > status updates > analytics events

**workmanager Configuration:**
```dart
Workmanager().registerPeriodicTask(
  "sync-task",
  "backgroundSync",
  frequency: Duration(minutes: 15),
  constraints: Constraints(
    networkType: NetworkType.connected,
  ),
  backoffPolicy: BackoffPolicy.exponential,
);
```

---

## Complete Additional Dependencies

### Flutter (pubspec.yaml additions)

```yaml
dependencies:
  # Maps & GIS
  flutter_map: ^8.2.2
  flutter_map_tile_caching: # latest
  latlong2: ^0.9.0

  # Local Database
  drift: ^2.26.0
  drift_flutter: ^0.2.4
  sqlcipher_flutter_libs: # latest

  # Push Notifications
  firebase_core: # latest
  firebase_messaging: # latest
  flutter_local_notifications: # latest

  # Background Sync
  workmanager: # latest
  connectivity_plus: # latest

dev_dependencies:
  drift_dev: ^2.26.0
  build_runner: # latest
```

### Go Backend (go.sum additions)

```bash
# SMS
go get github.com/twilio/twilio-go

# Push Notifications
go get firebase.google.com/go/v4

# Geocoding - HTTP calls, no SDK needed
# Census Geocoder API: geocoding.geo.census.gov
# Google Geocoding API: maps.googleapis.com
```

---

## Cost Projections (Pilot: 200 Navigators, 100K Voters)

| Service | Monthly Cost | Notes |
|---------|-------------|-------|
| Twilio SMS (10K msgs/mo) | ~$120-140 | $0.012-0.014/msg all-in |
| Twilio 10DLC | ~$12 | $1.50/mo/campaign + number |
| Google Geocoding (overflow) | ~$0 | 10K free/month covers overflow from Census |
| Census Geocoder | $0 | Free, unlimited |
| Firebase (FCM) | $0 | Free, no limits |
| OpenStreetMap tiles | $0 | Free, self-cached via FMTC |
| Mapbox Optimization API | ~$0-50 | Optional, for premium route optimization |
| **Total** | **~$135-200/mo** | Excluding base infrastructure |

At scale (1M voters, 50K msgs/mo): ~$650-750/mo for domain-specific services.

---

## Sources

### SMS/Messaging
- [Twilio Go SDK](https://github.com/twilio/twilio-go)
- [Twilio A2P 10DLC](https://www.twilio.com/docs/messaging/compliance/a2p-10dlc)
- [10DLC 2025 Registration](https://callhub.io/blog/compliance/10dlc-2025-registration-callhub/)
- [Twilio SMS Pricing US](https://www.twilio.com/en-us/sms/pricing/us)

### Maps/GIS
- [flutter_map pub.dev](https://pub.dev/packages/flutter_map)
- [FMTC Documentation](https://fmtc.jaffaketchup.dev/)
- [Mapbox Flutter Offline Pricing](https://docs.mapbox.com/flutter/maps/guides/pricing/)
- [Mapbox Optimization API v2](https://docs.mapbox.com/api/navigation/optimization/)

### Local Database
- [Drift Documentation](https://drift.simonbinder.eu/)
- [Drift pub.dev](https://pub.dev/packages/drift)
- [Flutter DB Comparison 2025](https://greenrobot.org/database/flutter-databases-overview/)
- [Isar Abandoned Status](https://github.com/isar/isar/issues)

### Geocoding
- [US Census Geocoder API](https://geocoding.geo.census.gov/geocoder/Geocoding_Services_API.html)
- [Google Geocoding Pricing](https://developers.google.com/maps/documentation/geocoding/usage-and-billing)

### Push Notifications
- [Firebase Cloud Messaging Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)

### Route Optimization
- [Google OR-Tools Routing](https://developers.google.com/optimization/routing)
- [OSRM API](https://project-osrm.org/docs/v5.24.0/api/)

### Background Sync
- [Flutter Offline-First Architecture](https://docs.flutter.dev/app-architecture/design-patterns/offline-first)
- [workmanager Pattern](https://medium.com/@dhruvmanavadaria/building-offline-auto-sync-in-flutter-with-background-services-using-workmanager-13f5bc94023d)
