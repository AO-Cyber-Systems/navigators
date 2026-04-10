# Domain Pitfalls

**Domain:** Political voter outreach / field organizing platform
**Project:** Navigators (MaineGOP)
**Researched:** 2026-04-10

---

## Critical Pitfalls

Mistakes that cause project failure, legal liability, or require full rewrites.

---

### Pitfall 1: 10DLC Registration Delays Kill Launch Timelines

**What goes wrong:** The team builds SMS features assuming they can register and start sending quickly. In reality, political campaign 10DLC registration requires brand vetting through specialized agents (Campaign Verify or Aegis), campaign registration with TCR, and carrier approval. This process takes 15+ days with NO expedited option. During election season surges, delays extend further. As of February 2025, all major US carriers block 100% of unregistered 10DLC traffic.

**Why it happens:** Developers treat 10DLC registration as a deployment task rather than a critical-path dependency. The registration process is opaque, with rejections requiring resubmission and restarting the clock.

**Consequences:** SMS features are built and tested but cannot be used in production. If launch coincides with an election cycle, the platform ships without its core outreach capability. Campaigns cannot wait -- they will use a competitor.

**Warning signs:**
- SMS development begins before 10DLC registration is initiated
- No dedicated compliance/registration owner on the team
- Timeline assumes registration completes in under 2 weeks

**Prevention:**
- Start 10DLC registration in the first week of the project, before writing any SMS code
- Register the brand AND at least one campaign use case (political/election) immediately
- Build SMS features against a sandbox/test environment while registration is pending
- Have a fallback plan: P2P texting (human-initiated, one-at-a-time) does not require 10DLC registration and can bridge the gap
- Budget 30 days minimum for full registration approval

**Objective mapping:** Must be addressed in the very first objective/milestone. Registration is a background process that gates all SMS work.

---

### Pitfall 2: TCPA Liability Exposure from Misunderstanding P2P vs A2P Distinction

**What goes wrong:** The platform blurs the line between P2P (peer-to-peer, human-initiated) and A2P (application-to-person, automated) texting. The FCC ruled that platforms requiring a human to "actively and affirmatively manually dial each recipient's number and transmit each message one at a time" are NOT autodialers under TCPA. But if the platform pre-loads recipient lists and lets volunteers tap "send" rapidly through a queue, carriers and courts may classify this as A2P. TCPA violations carry $500-$1,500 per message in damages.

**Why it happens:** The legal distinction is subtle and evolving. The June 2025 Supreme Court ruling (McLaughlin v. McKesson) eliminated mandatory deference to FCC interpretations, meaning courts can now independently interpret what constitutes an autodialer. Two federal courts issued directly contradictory rulings on the same day in July 2025 about whether DNC rules apply to texts.

**Consequences:** A single class action lawsuit can bankrupt a campaign or the platform operator. The Trump campaign faced two separate TCPA class actions in the 2024 cycle. Even winning costs hundreds of thousands in legal fees.

**Warning signs:**
- No legal review of the P2P texting workflow
- P2P interface allows sending faster than ~1 message per 3-5 seconds
- No clear audit trail showing human initiation of each message
- Opt-out requests not processed within legally required timeframes
- No distinction in the codebase between P2P and A2P message paths

**Prevention:**
- Design P2P texting to require genuine human action per message: volunteer reads the contact info, sees the message, and explicitly taps send for each individual message
- Implement mandatory per-message delay (carrier-friendly pacing)
- A2P messaging requires prior express consent -- build consent tracking into the data model from day one
- Process opt-out (STOP) replies within seconds, not minutes. Log every opt-out with timestamp
- Maintain a suppression list that is checked before every send, across both P2P and A2P channels
- Get legal review of the texting UX before building it
- Log everything: who sent, when, what human action triggered it, consent basis

**Objective mapping:** SMS objective must separate P2P and A2P as distinct features with different compliance requirements. Consent management and suppression lists belong in the data model objective.

---

### Pitfall 3: Offline Sync Conflicts Corrupt Canvassing Data

**What goes wrong:** Multiple volunteers canvass the same neighborhood. Both modify the same voter records offline (e.g., updating disposition, phone number, notes). When they sync, last-write-wins silently destroys the first volunteer's work. Alternatively, merge conflicts produce confusing states that field organizers cannot resolve. The worst case: a volunteer marks a voter as "contacted/supportive" while another marks them "not home" -- the wrong resolution changes outreach strategy.

**Why it happens:** True offline-first conflict resolution is one of the hardest problems in distributed systems. Teams either oversimplify (last-write-wins) or over-engineer (full CRDT implementation) without considering the specific domain semantics of voter outreach data.

**Consequences:** Lost canvassing data means wasted volunteer hours. Incorrect voter dispositions lead to misallocated resources. Volunteers lose trust in the platform when their work disappears.

**Warning signs:**
- Sync strategy is "we'll figure it out later"
- No conflict resolution UX designed
- Using simple timestamp-based last-write-wins without field-level granularity
- No offline testing with concurrent edits to same records

**Prevention:**
- Design field-level merge, not record-level. If Volunteer A updates phone number and Volunteer B updates disposition, both changes should be preserved
- For true conflicts on the same field, use domain-aware rules: latest canvass disposition wins (because it is the most recent contact), but notes should be appended, not replaced
- Assign turfs to individual volunteers so concurrent edits to the same voter are rare by design. This is the single most effective mitigation
- Build a conflict queue for the rare cases that do occur, letting field organizers resolve them
- Track sync metadata: device ID, timestamp, volunteer ID, and field-level change vectors
- Test sync extensively with airplane-mode scenarios before field deployment

**Objective mapping:** Turf assignment (preventing conflicts by design) should come before or alongside offline sync. The sync engine needs a dedicated objective with conflict resolution as a core requirement, not an afterthought.

---

### Pitfall 4: Voter File Import Is Harder Than It Looks

**What goes wrong:** Maine's CVR (Central Voter Registration) data and L2 commercial data arrive in different formats with different schemas, different address formats, different name conventions, and different ID systems. A naive import creates duplicates (same voter from CVR and L2 treated as two people), loses data (fields that don't map), or corrupts addresses (geocoding failures silently drop voters from maps). With 1M+ voters, a 1% error rate means 10,000 bad records.

**Why it happens:** Every voter data source is unique. Maine's CVR provides: name, year of birth, residence address, mailing address, electoral districts, voter status, registration date, and record number. L2 adds phone numbers, modeled data, and demographics. Merging these requires fuzzy matching on names and addresses since there is no universal voter ID across sources.

**Consequences:** Duplicate voters mean volunteers contact the same person twice (annoying and unprofessional). Missing voters mean gaps in outreach. Bad geocoding means voters appear in the wrong turf or don't appear on maps at all.

**Warning signs:**
- Import process has no validation step or error report
- No deduplication strategy defined
- Assuming address formats are consistent and clean
- No plan for incremental updates (re-importing full file each time)
- Geocoding costs/rate limits not budgeted

**Prevention:**
- Build a staging table approach: import raw data into staging, validate, deduplicate, then promote to production tables
- Define a canonical voter record schema early and map each source to it
- Implement fuzzy matching for dedup: normalized name + address + year of birth is a reasonable composite key for Maine (smaller state, less ambiguity)
- Handle geocoding as a background batch job with rate limiting, caching, and fallback (address-level -> ZIP+4 -> ZIP centroid)
- Budget for geocoding costs: at 1M voters, even free tiers may not suffice. Census geocoder is free but slow and limited; Google/Mapbox charge per request
- Generate an import report: X records imported, Y duplicates merged, Z geocoding failures, W validation errors
- Design for incremental updates: track source record IDs and only process changes

**Objective mapping:** Voter import should be an early objective. It gates turf management, mapping, and all outreach features. Geocoding can be deferred to the mapping objective but the data model must support it from the start.

---

### Pitfall 5: Offline Map Tile Storage Explodes Device Storage

**What goes wrong:** Maine is 35,385 square miles. Downloading raster map tiles for the entire state at zoom levels useful for door-knocking (zoom 14-17) requires tens of gigabytes. Volunteers' phones run out of storage. If tiles are downloaded on-demand and cached, first-time-in-area usage has no map. If tiles are pre-bundled, the app install size is enormous.

**Why it happens:** Teams underestimate tile storage requirements. At zoom level 16, a single tile covers roughly 600m x 600m. Covering all of Maine at zoom 16 requires approximately 2.3 million tiles. At ~20KB per tile, that is ~46GB of raster tiles.

**Consequences:** App is unusable offline in areas without pre-cached tiles. Volunteers in rural Maine (the primary use case) have poor connectivity AND no cached tiles. Storage warnings cause volunteers to uninstall the app.

**Warning signs:**
- No calculation of tile storage requirements for target coverage area
- Plan to "download all of Maine" without understanding the size implications
- No tile format decision made (raster vs vector)
- No per-turf tile scoping strategy

**Prevention:**
- Use vector tiles (MBTiles/PMTiles format), which are 5-10x smaller than raster tiles. A vector tile set for Maine at all zoom levels is likely 1-3GB, manageable on modern phones
- Scope tile downloads to assigned turfs plus a buffer, not the entire state. A typical canvassing turf might be 2-5 square miles, requiring only 50-200MB of tiles at high zoom
- Use flutter_map with flutter_map_tile_caching (FMTC) or MapLibre GL with offline style packs
- Implement progressive download: low zoom (state overview) tiles bundled with app (~50MB), high zoom tiles downloaded per-turf assignment
- Show storage usage in the app and let volunteers manage their cached areas
- Set maximum cache size and implement LRU eviction for old turfs

**Objective mapping:** Mapping/turf objective must include storage budgeting as a design constraint. Tile format decision (vector vs raster) is an architectural choice that must be made before implementation begins.

---

### Pitfall 6: Map Rendering Chokes on 100K+ Voter Pins

**What goes wrong:** Rendering 100,000+ map markers causes the UI to freeze, scroll/zoom to stutter, and memory to spike. On older phones (common among volunteers), the app crashes. Even on good hardware, rendering all pins at state-level zoom is both slow and visually useless (pins overlap into a solid mass).

**Why it happens:** Naive implementations create a widget/marker object for every voter. Flutter's rendering pipeline cannot handle 100K+ overlay objects simultaneously.

**Consequences:** Map feature is unusable at scale. Volunteers see a frozen screen when loading their turf. App gets poor reviews and low adoption.

**Warning signs:**
- No clustering strategy in the map implementation
- Testing only with small datasets (< 1,000 voters)
- All voters loaded into memory regardless of viewport
- No zoom-level-dependent rendering logic

**Prevention:**
- Implement marker clustering (show aggregated counts at low zoom, individual pins at high zoom). Libraries like flutter_map_supercluster or Mapbox's built-in clustering handle this
- Use viewport-based loading: only query and render voters within the current map bounds
- Implement spatial indexing in SQLite (R-tree or geohash-based) for fast spatial queries
- Use canvas-based rendering for markers instead of widget-based (significantly faster for large counts)
- Set a maximum visible marker count (~500-1000) and cluster beyond that regardless of zoom
- Test with production-scale data (1M voters) on low-end devices throughout development

**Objective mapping:** Performance testing with realistic data volumes must be a requirement in the mapping objective, not a "nice to have" at the end.

---

## Serious Pitfalls

Mistakes that cause significant rework, user frustration, or operational problems.

---

### Pitfall 7: Sync Storms When Volunteers Return to Connectivity

**What goes wrong:** 50+ volunteers finish canvassing in areas with no cell service (rural Maine). They all drive back to town and regain connectivity simultaneously. Every device tries to sync at once, overwhelming the backend. The server either crashes, times out, or processes syncs out of order, creating data inconsistencies.

**Why it happens:** The thundering herd problem. Mobile apps typically detect connectivity changes and immediately attempt to sync all queued operations. With no backoff strategy, the server receives a burst of requests equal to (number of volunteers) x (queued operations per volunteer).

**Consequences:** Backend overload causes sync failures, which trigger retries, which compound the overload. Volunteers see "sync failed" errors and lose confidence. Data may be partially synced, creating inconsistent state.

**Warning signs:**
- No rate limiting or backoff on the sync client
- Sync triggers immediately on connectivity change
- Backend has no request queuing or rate limiting
- No load testing with concurrent sync scenarios

**Prevention:**
- Add jitter to sync initiation: when connectivity resumes, wait a random 0-60 seconds before starting sync
- Implement exponential backoff with jitter on sync retries
- Use a sync queue on the backend that processes operations sequentially per-user
- Implement server-side rate limiting per device/user
- Design sync to be idempotent: the same operation applied twice produces the same result
- Batch sync operations: send all changes in a single request rather than one-per-record
- Load test with 200 simultaneous sync sessions, each with 50-100 queued operations

**Objective mapping:** Sync architecture objective must include thundering herd mitigation as a design requirement. Load testing should be part of acceptance criteria.

---

### Pitfall 8: Opt-Out Mishandling Creates Legal Exposure

**What goes wrong:** A voter texts "STOP" but continues receiving messages because: (a) the opt-out processor has a delay, (b) the suppression list isn't shared across P2P and A2P channels, (c) a re-import of the voter file re-enables the voter, or (d) a different volunteer sends via P2P not knowing about the opt-out. Each additional message after STOP is a separate TCPA violation ($500-$1,500).

**Why it happens:** Opt-out is treated as a messaging feature rather than a system-wide data constraint. The suppression list must be the single source of truth that overrides all other data.

**Consequences:** A single voter who texts STOP and receives 10 more messages can file a claim for $5,000-$15,000. At scale, a class action could involve thousands of voters.

**Warning signs:**
- Opt-out processing takes more than a few seconds
- Suppression list is per-campaign rather than global
- Voter file re-import process does not check against suppression list
- P2P and A2P systems have separate contact lists
- No automated testing of opt-out flow end-to-end

**Prevention:**
- Implement a global suppression table that is checked before ANY message send (P2P or A2P)
- Process STOP keywords in real-time via webhook from the SMS provider (Twilio, Bandwidth, etc.)
- Voter file imports must LEFT JOIN against the suppression list and never re-enable opted-out voters
- The suppression list is append-only (a voter can opt back in, but that requires a separate explicit opt-in record, not deletion from the suppression list)
- Include common STOP variants: STOP, UNSUBSCRIBE, CANCEL, END, QUIT
- Automated test: send STOP, verify within 5 seconds that subsequent sends are blocked
- Audit log every suppression event with timestamp and source

**Objective mapping:** Suppression list must be part of the core data model, not the SMS feature. It must exist before any messaging feature is built.

---

### Pitfall 9: Volunteer Onboarding Friction Kills Adoption

**What goes wrong:** Volunteers download the app, face a complex setup process (account creation, permissions, training), and abandon before their first canvassing shift. Political volunteers are time-limited, often non-technical, and have zero tolerance for friction. A 10-minute onboarding process can lose 40%+ of volunteers.

**Why it happens:** Engineers build for power users and add features before simplifying the entry path. Campaign staff don't have time to train every volunteer individually.

**Consequences:** Low volunteer adoption means the campaign falls back to paper walk lists, defeating the purpose of the platform. Volunteer coordinators spend more time on tech support than organizing.

**Warning signs:**
- Onboarding requires more than 3 steps
- Volunteer must configure settings before first use
- No way to start canvassing within 5 minutes of download
- Training materials are text-heavy documentation rather than in-app guidance
- No "demo mode" or practice area

**Prevention:**
- Design for the "parking lot test": a volunteer sitting in their car before a canvass shift should go from download to ready-to-knock in under 5 minutes
- Use invite links/codes from organizers that pre-configure turf assignments and permissions
- Progressive disclosure: show only what's needed for the current task. Hide admin features, analytics, and advanced options
- Build contextual, inline guidance (tooltips, example data) rather than separate training docs
- Support the "clipboard fallback": if tech fails, volunteers should be able to print their walk list and enter data later
- Design for the lowest-common-denominator device and technical skill level

**Objective mapping:** UX/onboarding should be a dedicated objective or a hard requirement within the first user-facing objective. Do not defer it to "polish" at the end.

---

### Pitfall 10: Battery Drain Makes the App Unusable in the Field

**What goes wrong:** Continuous GPS tracking for location on the map, frequent map tile rendering, SQLite queries, and background sync attempts drain the volunteer's phone battery in 2-3 hours. A typical canvassing shift is 3-4 hours. Volunteers' phones die before they finish, losing unsynced data.

**Why it happens:** Each feature independently uses battery-intensive resources (GPS, network, screen, CPU). Combined, they drain faster than any individual feature would suggest. GPS alone consumes 13-38% of battery depending on signal strength. Weak GPS signal (common in rural Maine) increases drain because the phone searches longer for satellites (12-30 seconds in good signal, up to 12 minutes in poor signal).

**Consequences:** Volunteers stop using the app or carry external batteries. Unsynced data is lost when phones die. The app gets a reputation as a "battery killer."

**Warning signs:**
- GPS updates are continuous/high-frequency
- Map re-renders on every location update
- No battery-conscious mode
- Background sync attempts occur on a fixed schedule regardless of battery level
- No battery usage testing during realistic field scenarios

**Prevention:**
- Use distance-based GPS updates, not time-based: only update location when the volunteer has moved 50+ meters
- Reduce GPS accuracy when battery is below 30% (switch from high-accuracy GPS to network-based location)
- Cache the current turf's map tiles so rendering doesn't require network
- Pause background sync when battery is below 20%
- Use geofencing instead of continuous tracking where possible
- Dark mode support (OLED screens save significant battery)
- Test with a real 4-hour canvassing simulation and measure battery consumption

**Objective mapping:** Battery optimization must be a non-functional requirement for the mapping/canvassing objective, not a separate optimization pass.

---

### Pitfall 11: Data Staleness Makes Canvassing Inefficient

**What goes wrong:** Voter files are imported once and never updated. Over months, voters move, change phone numbers, register/unregister, or die. Volunteers knock on doors of people who moved away, call disconnected numbers, or skip new registrants. Maine voter data decay rate is roughly 1-2% per month due to population mobility.

**Why it happens:** Initial import is hard enough that teams avoid re-importing. There is no automated update pipeline. The CVR data costs $2,200 per statewide pull, creating a financial disincentive to update frequently.

**Consequences:** After 6 months without updates, 5-10% of voter records may be stale. Volunteers waste time on bad data. Campaign strategy based on outdated voter counts is unreliable.

**Warning signs:**
- No "last updated" timestamp visible in the UI
- No scheduled re-import process
- Voter records have no "confidence" or "freshness" indicator
- No way to mark a voter as "moved" or "bad address" during canvassing
- Field feedback (bad addresses, moved voters) doesn't flow back to improve data quality

**Prevention:**
- Design the import pipeline for incremental updates from the start, not just initial bulk load
- Track source data timestamps and display freshness indicators in the UI
- Allow field volunteers to flag stale data (moved, deceased, wrong address) and incorporate this feedback
- Budget for periodic CVR re-pulls (quarterly at minimum during election year)
- Implement NCOA (National Change of Address) checking if budget allows
- Show "last verified" dates on voter records so volunteers know what to expect

**Objective mapping:** The voter import objective must design for incremental updates, not just initial load. Field data feedback should be part of the canvassing objective.

---

### Pitfall 12: Carrier Filtering Silently Drops Messages

**What goes wrong:** Even with proper 10DLC registration, carriers use AI to match live messages against registered samples in real-time. Messages that look "too political," contain certain keywords, or are sent in patterns that resemble spam get silently filtered. The sender sees "delivered" but the recipient never receives the message. Apple's iOS 26 (September 2025) routes unknown senders to a hidden folder with no notification.

**Why it happens:** Carrier filtering is opaque. There are no public rules, no notification when messages are filtered, and no appeal process. Political content is especially scrutinized. iOS device-level filtering compounds the problem.

**Consequences:** Campaign believes messages were delivered when they weren't. Response rates drop mysteriously. Resources are wasted on an ineffective channel.

**Warning signs:**
- Delivery rates above 95% but response rates below 1%
- No delivery receipt/status tracking beyond "sent"
- Message templates contain flagged keywords (FREE, VOTE, URGENT, etc.)
- High message volume sent in short bursts
- No A/B testing of message content

**Prevention:**
- Monitor delivery AND response rates, not just send counts. A sudden drop in response rate may indicate filtering
- Implement delivery status webhooks from the SMS provider and track actual delivery confirmation
- Avoid spam-trigger words and URL shorteners in message content
- Spread message sends over time (don't blast 10,000 messages in 5 minutes)
- Use message templates approved during 10DLC campaign registration
- Test messages to phones on each major carrier (AT&T, T-Mobile, Verizon) before large sends
- Build in fallback channels (phone calls, door knocks) for voters who don't respond to SMS
- Educate campaign staff about iOS unknown sender filtering and encourage volunteers to save the sending number

**Objective mapping:** SMS objective must include delivery monitoring and analytics, not just send capability.

---

## Moderate Pitfalls

Mistakes that cause delays, technical debt, or moderate user impact.

---

### Pitfall 13: Turf Polygon Complexity Causes Performance Issues

**What goes wrong:** Turfs created from census block groups, voting precincts, or hand-drawn boundaries have complex polygons with hundreds or thousands of vertices. Point-in-polygon queries against these complex shapes are slow, especially when checking which turf each of 1M voters belongs to. Complex polygons also render slowly on maps.

**Prevention:**
- Simplify polygons on import (Douglas-Peucker algorithm) to reduce vertex count while preserving shape
- Pre-compute voter-to-turf assignments as a batch job, don't calculate in real-time
- Store turf assignments in the voter record as a foreign key, not computed on each query
- Use spatial indexes (PostGIS on server, R-tree in SQLite on device)
- Limit turf polygon complexity in the turf creation UI (warn when complexity exceeds thresholds)

**Objective mapping:** Turf management objective must include polygon simplification and pre-computed assignments.

---

### Pitfall 14: Election Cycle Timing Pressure Creates Technical Debt

**What goes wrong:** Political campaigns operate on immovable deadlines (election day). Features get rushed, testing is skipped, and "temporary" solutions become permanent. The platform launches with known bugs because "we'll fix it after the election" -- but after the election, funding disappears and the team disbands.

**Prevention:**
- Prioritize ruthlessly: a working MVP with 5 solid features beats a buggy app with 15 features
- Build for the NEXT election, not just the current one. Design for reuse across cycles
- Implement feature flags so incomplete features can be hidden without blocking deployment
- Accept that some features won't make the current cycle and plan accordingly
- Automated testing is not optional -- it's the only way to maintain quality under time pressure

**Objective mapping:** Every objective should have a "minimum viable" definition that can ship under time pressure, plus "full" scope for when time allows.

---

### Pitfall 15: RBAC Complexity Grows Beyond the Initial 3-Role Model

**What goes wrong:** The platform starts with 3 clean roles (Admin, Organizer, Navigator/Volunteer). Then reality intrudes: regional coordinators need to see multiple turfs but not all turfs. Volunteer team leads need to manage their team but not others. Data entry volunteers need different permissions than field volunteers. The 3-role model becomes 7+ roles with ad-hoc permission checks scattered throughout the codebase.

**Prevention:**
- Design permission system as role + scope (e.g., "Organizer of Region X") not just role
- Use a permission-based system underneath roles: roles are just bundles of permissions
- Centralize all permission checks in middleware/interceptors, not in individual handlers
- Plan for at least 5-6 roles even if launching with 3
- Document the permission matrix early and review it with campaign staff

**Objective mapping:** RBAC belongs in the foundational objective. Getting it wrong early means refactoring every endpoint later.

---

### Pitfall 16: Geocoding Rate Limits and Costs at Scale

**What goes wrong:** Geocoding 1M+ voter addresses hits rate limits (Census geocoder: 10,000/batch with slow processing; Google: $5/1,000 requests = $5,000 for 1M voters; Mapbox: similar pricing). The team either blows through the budget, gets rate-limited and the import takes days, or uses a free geocoder with poor accuracy for rural Maine addresses.

**Prevention:**
- Use the US Census Bureau geocoder for initial bulk geocoding (free, but slow -- plan for multi-day processing)
- Cache all geocoding results aggressively -- addresses rarely change
- Only re-geocode records where the address has changed on re-import
- Consider Nominatim (OpenStreetMap) self-hosted for free unlimited geocoding, but quality varies in rural areas
- For failed geocodes, fall back to ZIP centroid rather than dropping the voter from the map
- Budget geocoding costs explicitly and track spend

**Objective mapping:** Geocoding belongs in the voter import objective with explicit cost/time budgets.

---

### Pitfall 17: State-Specific Voter Data Restrictions in Maine

**What goes wrong:** Maine law (Title 21-A, Section 196-A) restricts who can access CVR data and what it can be used for. The data is available to political parties, candidates, and government entities -- but misuse can result in loss of access. Sharing raw voter data with unauthorized parties, using it for commercial purposes, or failing to protect it adequately can violate state law.

**Prevention:**
- Legal review of Maine's Title 21-A Section 196-A before designing data access patterns
- Implement audit logging for all voter data access (who viewed/exported what, when)
- RBAC must prevent volunteers from bulk-exporting voter data
- Data should be scoped: volunteers see only their assigned turf's voters
- No voter PII in client-side logs, crash reports, or analytics
- Terms of use for the platform must include data use restrictions
- Maine is advancing new data privacy legislation (LD 1822, as of March 2026) -- monitor for changes

**Objective mapping:** Legal/compliance review should gate the voter import objective. Audit logging should be part of the foundational data model.

---

### Pitfall 18: Volunteer Turnover Erases Institutional Knowledge

**What goes wrong:** Volunteers join, canvass for a few weeks, then stop showing up. Their turf knowledge, contact notes, and relationship context leave with them. New volunteers start cold in the same turf, re-contacting voters who were already engaged, ignorant of local context.

**Prevention:**
- All volunteer activity must be captured in the system, not in volunteer's personal notes
- Structured data entry (dropdowns for disposition, required fields) rather than free-text
- Turf handoff process: when a volunteer is reassigned, their history stays with the turf
- Design reports showing turf coverage and contact history so new volunteers can see what's been done
- Don't assign critical turfs to a single volunteer -- pair them or rotate

**Objective mapping:** Canvassing data model must capture structured per-interaction data. Turf management must support reassignment with history preservation.

---

## Objective-Specific Warnings

| Objective Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Data model / foundation** | RBAC too simple, suppression list missing | Design permission+scope system; global suppression table from day one |
| **Voter import** | Dedup failures, geocoding costs, Maine legal restrictions | Staging table approach, fuzzy matching, Census geocoder first, legal review |
| **Turf management** | Polygon complexity, storage planning | Douglas-Peucker simplification, pre-compute voter assignments |
| **Offline maps** | Tile storage explosion, marker rendering performance | Vector tiles, per-turf scoping, marker clustering, spatial indexing |
| **Offline sync** | Conflict corruption, sync storms | Field-level merge, turf-scoped assignment prevents conflicts, jitter on reconnect |
| **SMS (P2P)** | TCPA liability, P2P/A2P confusion | Legal review of UX, per-message human action, audit logging |
| **SMS (A2P)** | 10DLC delays, carrier filtering, opt-out failures | Register immediately, delivery monitoring, global suppression list |
| **Canvassing / door knocking** | Battery drain, onboarding friction, data staleness | Distance-based GPS, 5-min onboarding, freshness indicators |
| **Analytics** | Misleading metrics from undelivered SMS, stale data | Track delivery confirmation, show data freshness |
| **Scale / hardening** | Concurrent sync overload, large dataset performance | Load testing with 200 users, spatial indexing, batch sync |

---

## Sources

### SMS and Compliance
- [CallHub: 10DLC 2025 Registration](https://callhub.io/blog/compliance/10dlc-2025-registration-callhub/)
- [Telnyx: Political Campaign Text Messaging Guide](https://telnyx.com/resources/guide-to-political-campaign-text-messaging)
- [Political Comms: 2025 Political Texting Compliance](https://politicalcomms.com/blog/2025-political-texting-compliance-fcc-tcpa/)
- [Wiley: TCPA Suits Against Political Campaigns](https://www.wiley.law/newsletter-TCPA-Suit-Against-Political-Campaigns-Rise-Trump-Campaign-Facing-Separate-Class-Action-Suits)
- [Wiley: FCC P2P Texting Ruling](https://www.wiley.law/newsletter-Major-TCPA-Updates-with-Implications-for-Political-Callers-FCC-Weighs-In-on-P2P-Texting-Platforms-Supreme-Court-Invalidates-Narrow-TCPA-Exception-and-Agrees-to-Consider-Autodialer-Definition)
- [RumbleUp: P2P Industry Insights](https://rumbleup.com/blog/industry-insights-for-p2p-texting-2025)
- [Infillion: Political Text Message Apocalypse](https://infillion.com/blog/the-political-text-message-apocalypse-is-here/)
- [ActiveProspect: TCPA Text Message Rules 2026](https://activeprospect.com/blog/tcpa-text-messages/)
- [SubscriberVerify: 2025 SMS Carrier Restrictions](https://subscriberverify.com/blog/sms-carrier-restrictions-2025)

### Offline Sync
- [DEV Community: Offline-First Mobile App Architecture](https://dev.to/odunayo_dada/offline-first-mobile-app-architecture-syncing-caching-and-conflict-resolution-518n)
- [Medium: Conflict Resolution in Offline-First Apps](https://shakilbd.medium.com/conflict-resolution-in-offline-first-apps-when-local-and-remote-diverge-12334baa01a7)
- [DEV Community: Offline-First Architecture in Flutter](https://dev.to/anurag_dev/implementing-offline-first-architecture-in-flutter-part-1-local-storage-with-conflict-resolution-4mdl)

### Voter Data
- [DNC Tech Team: What is the Voter File](https://medium.com/democratictech/what-is-the-voter-file-a8f99dd07895)
- [Maine Legislature: Title 21-A Section 196-A](https://www.mainelegislature.org/legis/statutes/21-a/title21-Asec196-A.html)
- [Maine Secretary of State: Voter Registration Information Protections](https://www.maine.gov/sos/news/2017/voterreginfo.html)

### Mapping and Performance
- [Flutter Map: Offline Mapping Docs](https://docs.fleaflet.dev/tile-servers/offline-mapping)
- [PowerSync: SQLite Optimizations](https://www.powersync.com/blog/sqlite-optimizations-for-ultra-high-performance)
- [Stadia Maps: Offline Maps with Flutter MapLibre GL](https://docs.stadiamaps.com/tutorials/offline-maps-with-flutter-maplibre-gl/)

### Battery and GPS
- [Timeero: GPS Tracking Battery Drain](https://timeero.com/post/do-gps-tracking-apps-drain-mobile-battery-heres-what-you-need-to-know)
- [Android Developers: Background Location and Battery](https://developer.android.com/develop/sensors-and-location/location/battery)
- [HubStaff: GPS Tracking and Battery Life](https://hubstaff.com/workforce-management/employee-gps-tracking-battery-life)

### Thundering Herd
- [Encore Blog: Thundering Herd Problem](https://encore.dev/blog/thundering-herd-problem)
- [Arpit Bhayani: Thundering Herd and Randomness](https://arpit.substack.com/p/thundering-herd-problem-and-addressing)
