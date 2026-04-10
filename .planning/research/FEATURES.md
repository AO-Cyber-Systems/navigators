# Feature Landscape

**Domain:** Political voter outreach / field organizing platform
**Researched:** 2026-04-10
**Platforms analyzed:** MiniVAN (NGP VAN), Hustle/ThruText, GetThru/ThruTalk, Reach, Campaign Knock, Qomon, PDI, Ecanvasser, Vottiv, CallHub

## Table Stakes

Features users expect. Missing = organizers and volunteers will not adopt the platform.

### Canvassing / Door-Knocking

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Walk list generation from voter data | Every platform does this; canvassers need a list of who to visit | Medium | Must support filtering by party, district, voting history, geography |
| Map view of assigned turf with voter pins | MiniVAN, Ecanvasser, Qomon, Vottiv all provide this; volunteers expect visual navigation | High | Mapbox GL with offline tiles. Pin density optimization needed at scale |
| Offline mode for canvassing | Qomon, Reach, Ecanvasser, Vottiv all support offline. Critical for rural Maine | High | Download map tiles + voter data before going out. Sync on reconnect. This is THE differentiator for Maine |
| Configurable survey questions | Every platform supports custom surveys per campaign. MiniVAN uses Survey Questions + Activist Codes | Medium | Must support multiple question types: single-select, multi-select, text, rating |
| Branching/conditional scripts | MiniVAN and VAN pioneered this; Qomon and others followed. Volunteers expect guided conversations | Medium | Branch based on voter response to show different follow-up questions or talking points |
| Door disposition tracking | Universal across all platforms. "Not home", "Refused", "Moved", "Deceased", etc. | Low | Standard disposition codes plus custom ones. Critical for attempt tracking |
| Per-voter notes | MiniVAN added floating "Add Note" button; all platforms support notes | Low | Voice-to-text dictation is a nice touch (MiniVAN has this) |
| GPS location of canvasser | MiniVAN Manager, Vottiv, Ecanvasser all track canvasser location | Low | Uses device GPS. Privacy considerations: only share with team leads/admins |
| Auto-sync on reconnect | Every offline-capable app does this. Qomon: "sync everything in one click" | High | Conflict resolution is the hard part. Last-write-wins with audit trail |

### Texting (SMS)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| P2P texting (human-initiated) | Hustle, GetThru ThruText are the market leaders. Human-initiated = stronger TCPA protection | High | Volunteer sees contact, personalizes message, hits send. NOT automated |
| Message templates with merge fields | Every texting platform supports `{first_name}`, `{precinct}`, etc. | Low | Admin creates templates, volunteers can personalize before sending |
| Opt-out handling (STOP keyword) | TCPA mandatory. Must honor within 10 business days (FCC April 2025 rule). All platforms do this | Medium | Auto-detect STOP/QUIT/CANCEL/UNSUBSCRIBE. Confirmation within 5 minutes. No marketing in confirmation |
| Conversation view (threaded) | Hustle, GetThru all show conversation history per contact | Low | Volunteers need context on prior messages before replying |
| Quiet hours enforcement | TCPA compliance. Most platforms restrict to 8am-9pm local time | Low | Config-driven. Maine is single timezone (Eastern) which simplifies |

### Phone Banking

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Click-to-call with native dialer | Vottiv, NGP VAN (VPB Connect), CallHub all offer this | Low | Launch native phone app with pre-filled number. No VoIP complexity in v1 |
| Call scripts displayed during call | Every phone banking tool shows scripts. MiniVAN, CallHub, GetThru all do this | Low | Overlay or split-screen showing script + survey while on call |
| Post-call disposition logging | Universal. "Answered", "Voicemail", "Wrong number", "Do not call" | Low | Must capture immediately after call ends. Include survey responses |
| Call list management | Standard in all phone banking tools. Filter/prioritize who to call | Medium | Integrate with same voter list/turf system used for canvassing |

### Turf Management

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Draw turf polygon boundaries on map | Ecanvasser "turf cutting", MiniVAN via VAN, Qomon turf assignment | High | Admin draws polygons; system auto-populates voter list within boundary |
| Assign turfs to volunteers | Every platform does this. Qomon: "pre-assign areas so every canvasser knows where they're going" | Medium | One turf to one or more Navigators. Navigators see only their turf |
| Turf progress visualization | Ecanvasser, MiniVAN Manager track completion. "X% of doors knocked" | Medium | Color-coded: not visited, attempted, contacted, completed |
| Pre-generated walk routes | Vottiv generates optimized walking routes. Qomon suggests paths clustering nearby contacts | High | Route optimization within turf polygon. Huge UX improvement for volunteers |

### Volunteer Management

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Role-based access control | All enterprise platforms have roles. PDI: "assign roles and manage access" | Medium | Already planned: Admin, Super Navigator, Navigator. Eden-libs provides RBAC |
| Volunteer onboarding flow | Standard practice. Must acknowledge data usage terms | Low | Maine Title 21-A acknowledgment + basic training/orientation |
| Volunteer activity tracking | MiniVAN Manager, Ecanvasser scoreboards. Who knocked how many doors | Medium | Personal stats: doors knocked, calls made, texts sent, hours active |

### Reporting / Analytics

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Real-time canvassing dashboard | MiniVAN Manager, Ecanvasser, Vottiv all provide live dashboards | Medium | Doors knocked, contact rate, survey results, canvasser locations |
| Team performance metrics | Ecanvasser scoreboards, MiniVAN Manager per-canvasser stats | Medium | Leaderboards, completion rates, contact rates by Navigator/team |
| Survey response aggregation | All platforms roll up survey results. "67% support candidate X in Turf 12" | Medium | Filterable by turf, time period, question, demographic |
| Data export (CSV/Excel) | Admin-only feature in most platforms. PDI, Ecanvasser support this | Low | Admin-restricted. Compliance audit trail on exports |

### Compliance

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| 10DLC registration flow (for A2P) | Mandatory since Feb 2025. Carriers block unregistered traffic | High | Register brand + campaign with TCR. Need EIN, privacy policy, sample messages. Consider handling this as admin setup, not in-app |
| Audit trail for voter data access | PDI reviews canvasser routes to confirm they walked assigned area. Maine Title 21-A requires accountability | Medium | Log every view, edit, export of voter data. Eden-libs provides audit logging |
| Opt-out/DNC list management | TCPA requirement. All platforms maintain do-not-contact lists | Medium | Unified across channels: if opted out of SMS, flag shows on all views |
| Data encryption at rest | Standard security practice for PII/voter data | Low | Eden-platform-go should handle this at the database level |

## Differentiators

Features that set Navigators apart. Not expected, but create competitive advantage.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Truly offline maps with vector tiles | Most apps claim "offline" but degrade without signal. Vottiv and Reach do this well; most others are spotty. Full offline vector maps for rural Maine is a genuine differentiator | High | Pre-download Mapbox vector tiles for assigned turf. Most competitors use raster or require some connectivity |
| Unified contact timeline | Show ALL interactions (door knock, text, call, notes) on one voter profile. Few platforms do this well -- most silo channels | Medium | Single view: "Knocked 4/2, not home. Texted 4/5, replied supportive. Called 4/8, confirmed yard sign" |
| Voice-to-text notes at the door | MiniVAN just added dictation (2025). Most competitors lack this | Low | Use device speech-to-text API. Huge time saver at the door |
| Geographic heat maps | Admin sees which areas are hot/cold for support. Qomon has "AI-powered lookalike zones" but most platforms lack proper geographic visualization | High | Overlay survey results on map. Red/blue/purple by precinct or turf |
| Voter sentiment tracking over time | Track how a voter's support level changes across multiple contacts. Rare feature | Medium | Chart showing sentiment trend: "Leaning against -> Undecided -> Leaning support" |
| A2P broadcast SMS campaigns | Having BOTH P2P (volunteer conversations) and A2P (admin broadcasts) in one platform. Most tools are one or the other (Hustle = P2P, but no A2P campaign blasts) | High | Requires separate 10DLC registration. Different UX for broadcast vs conversation |
| Smart task assignment | Auto-assign follow-up tasks based on canvassing results. "If voter said undecided, create follow-up task for 2 weeks" | Medium | Rule-based automation. Reduces admin overhead significantly |
| Anti-cheating / canvass verification | Vottiv has "anti-cheating mechanisms." PDI lets campaigns review canvasser routes to confirm they walked their area | Medium | GPS breadcrumb trail verification. Flag canvassers who logged responses without being near the address |
| Event management with check-in | Qomon "Public Events" with sign-up pages. Mobilize specializes in this | Medium | Create canvass events, phone bank sessions. RSVP, check-in, auto-assign turfs at event |
| Downloadable offline data bundles | Reach offers pre-packaged offline data sets admins can prepare. Better than "download everything" | Medium | Admin prepares curated data bundles per event/turf. Reduces download time and storage |

## Anti-Features

Features to explicitly NOT build in v1. These add complexity without proportional value for a grassroots Maine GOP pilot.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| VoIP / predictive dialer | ThruTalk, CallHub offer predictive dialing but it requires SIP infrastructure, AMD (answering machine detection), call quality management, and significant per-minute costs. Massive complexity for marginal v1 benefit | Click-to-call via native dialer. Volunteers use their own phone. Log disposition after call. Power dialer is v2+ |
| Fundraising / donation processing | NationBuilder, NGP VAN bundle this. Payment processing adds PCI compliance burden, Stripe integration, FEC reporting requirements | Out of scope. Navigators is voter outreach, not fundraising. Use ActBlue/WinRed separately |
| Social media integration | Some platforms post canvassing results to social. Adds API complexity, moderation concerns, and distraction from core mission | Not a voter contact channel. Focus on door, text, phone |
| Email campaigns | Hustle and others offer email. But grassroots volunteers are knocking doors and texting, not running email drip campaigns | Not the primary channel for field organizing. Use Mailchimp/Constant Contact separately if needed |
| AI-powered voter scoring / prediction | Qomon has "AI Profiles" for lookalike modeling. Premature for v1 -- need baseline data first before ML adds value | Start with manual tagging and simple filters. AI scoring is a v2+ feature after you have real contact data |
| Voter registration tools | Reach has voter registration features. Maine CVR integration for registration is a separate regulatory burden | Focus on outreach to already-registered voters. Registration is a different workflow |
| Custom CRM / relationship management | Ecanvasser positions as "field CRM." Full CRM features (deals, pipelines, follow-up sequences) bloat the core product | Keep voter profiles simple: contact info, survey responses, notes, contact history. Not a CRM |
| Multi-organization / multi-tenant SaaS | Qomon and Ecanvasser serve many organizations. Building multi-tenant adds auth complexity, data isolation concerns | Single-org deployment for MaineGOP. Multi-tenant is a future concern if the platform is adopted elsewhere |
| Direct mail / postcard integration | Vottiv offers direct-mail postcards. Print/mail fulfillment integration is operationally complex | Out of scope. If needed, export addresses and use a mail house |
| Gamification / leaderboards with rewards | Some platforms gamify canvassing with points, badges, rewards. Can feel patronizing to serious volunteers | Show basic stats (doors knocked, contacts made) without gamification. Let team leads recognize performance directly |
| Complex workflow automation | Multi-step automated workflows (if X then Y then Z) add significant UI/UX complexity | Simple rule-based follow-ups at most. Manual task assignment is fine for <200 Navigators |
| Integration with NGP VAN / VoteBuilder | Greenfield system. VAN integration requires partnership agreements and API access that may not be available to state GOP orgs | Standalone system with CSV import/export. Data flows through Maine CVR and L2 vendor files |

## Feature Dependencies

```
Voter Data Import
  |
  +---> Voter Search/Filter ---> Walk List Generation
  |                                    |
  +---> Geocoding ------+              |
  |                     |              |
  +---> Map Display <---+              |
         |                             |
         +---> Turf Drawing            |
                |                      |
                +---> Turf Assignment -+---> Canvassing (offline surveys)
                |                      |
                +---> Offline Map Tiles |
                                       |
                         Walk Routes <--+
                                       |
Survey Builder -----> Door-Knock Data Capture
                                       |
Script Builder -----> Call Scripts      |
                      |                |
Click-to-Call --------+                |
                                       |
Message Templates --> P2P Texting       |
                      |                |
10DLC Registration -> A2P SMS          |
                                       |
Opt-out Handling ---> All SMS/Call -----+
                                       |
Contact Timeline <--- All Interactions |
                                       |
RBAC (eden-libs) ---> Data Scoping     |
                      |                |
Audit Logging --------+               |
                                       |
All Data -----------> Analytics Dashboard
                      |
                      +---> Data Export
```

## MVP Recommendation

### Phase 1: Foundation (must ship first)
1. **Voter data import** (Maine CVR + L2) - Everything depends on this
2. **Geocoding** - Required for maps
3. **Map display with turf drawing** - Core navigation for field work
4. **RBAC and audit logging** - Compliance requirement from day one

### Phase 2: Core Field Tools
5. **Turf assignment with offline download** - The killer feature for rural Maine
6. **Walk list generation** - Feeds canvassing
7. **Survey builder + door-knock capture** - Core canvassing workflow
8. **Branching scripts** - Expected by experienced volunteers
9. **Auto-sync on reconnect** - Completes the offline loop

### Phase 3: Multi-Channel Outreach
10. **P2P texting** with templates and opt-out handling - High-impact voter contact
11. **Click-to-call** with scripts and disposition logging - Low complexity, high value
12. **Unified contact timeline** - Differentiator that prevents duplicate outreach

### Phase 4: Analytics and Operations
13. **Real-time dashboards** (Navigator, Super Nav, Admin tiers) - Leadership visibility
14. **Team performance metrics** - Accountability and optimization
15. **A2P broadcast SMS** with 10DLC registration - Admin broadcasts
16. **Event management** - Organize canvass events and phone banks

### Defer to v2+
- VoIP/power dialer
- AI-powered voter scoring
- Complex workflow automation
- Gamification
- Multi-tenant SaaS

## Competitive Positioning

| Competitor | Strengths | Navigators Advantage |
|------------|-----------|---------------------|
| MiniVAN (NGP VAN) | Market leader, huge ecosystem, branching scripts | Locked to Democrat/VAN ecosystem. Navigators is purpose-built for GOP |
| Vottiv | GOP-friendly, good offline, anti-cheating, no app install | Navigators adds texting + calling in same app, deeper Maine CVR integration |
| Campaign Knock | Free tier, simple, GPS mapping | Limited to 100 addresses free. No texting, no offline maps |
| Qomon | Modern UX, offline, AI features, multi-channel | Expensive, European origin, not tuned for US political compliance |
| Reach | Good offline, accessibility, progressive ecosystem | Progressive-only. Not available to GOP campaigns |
| PDI | Full-featured, data review, assignment management | California-focused. Heavy, enterprise-grade, expensive |
| Ecanvasser | Great analytics, turf cutting, scoreboards | Generic (not political-specific). Minimum user requirements. Pricey |

**Navigators' unique position:** Purpose-built for MaineGOP grassroots organizing with genuine offline-first architecture for rural areas, unified multi-channel outreach (door + text + call), and Maine CVR/L2 native data integration. No competitor offers all three for Republican campaigns.

## Sources

- [MiniVAN Canvassing Guide - NGP VAN](https://www.ngpvan.com/blog/canvassing-with-minivan/)
- [MiniVAN Manager - NGP VAN](https://www.ngpvan.com/minivan-manager/)
- [Hustle P2P Texting Platform](https://hustle.com/)
- [GetThru ThruTalk Dialer](https://www.getthru.io/thrutalk-dialer)
- [Qomon 2025 Release](https://qomon.com/blog/the-2025-qomon-autumn-winter-release)
- [Qomon Canvassing App Features 2026](https://qomon.com/blog/canvassing-app-best-features)
- [Reach Offline Data](https://reach.vote/knowledge-base/offline-data/)
- [Campaign Knock Features](https://campaignknock.com/features/free-political-canvassing-app)
- [PDI Platform](https://pdihelp.zendesk.com/hc/en-us/articles/28957686840212-About-the-PDI-Platform)
- [Vottiv GOP Canvassing App](https://www.vottiv.com/blog/gop-canvassing-app)
- [Vottiv Canvassing](https://www.vottiv.com/canvassing)
- [Ecanvasser Features](https://www.ecanvasser.com/features)
- [CallHub Political Campaigns](https://callhub.io/industries/political/)
- [10DLC 2025 Registration - CallHub](https://callhub.io/blog/compliance/10dlc-2025-registration-callhub/)
- [2025 Political Texting Compliance Guide](https://politicalcomms.com/blog/2025-political-texting-compliance-fcc-tcpa/)
- [Branched Scripts - VAN](https://wiki.staclabs.io/en/VAN/branched-scripts)
