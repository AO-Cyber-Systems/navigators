# Objective 6: SMS Integration - Research

**Researched:** 2026-04-10
**Domain:** SMS messaging (Twilio), TCPA compliance, async webhook processing
**Confidence:** HIGH

## Summary

SMS integration for Navigators involves two distinct messaging paths: P2P (person-to-person) texting where a Navigator manually sends individual texts to voters, and A2P (application-to-person) broadcast campaigns where an Admin sends templated messages to voter segments. These paths have different compliance requirements, different Twilio configurations, and different code paths, but share infrastructure (conversation threading, delivery status tracking, opt-out handling).

The Twilio Go SDK (`github.com/twilio/twilio-go` v1.30.4) is the official, actively maintained library for all Twilio API interactions. It provides typed clients for sending messages, managing Messaging Services, handling 10DLC registration, and validating webhook signatures. The existing eden platform already has NATS JetStream infrastructure (`platform/bridge`) which provides the async processing pattern needed for webhook ingestion and campaign batch sending.

**Primary recommendation:** Use Twilio Messaging Services as the send abstraction (not raw phone numbers), with separate Messaging Service SIDs for P2P and A2P traffic. Process all Twilio webhooks through NATS JetStream consumers for reliability. Implement quiet hours enforcement server-side as a pre-send gate rather than relying solely on Twilio's Compliance Toolkit.

<phase_requirements>
## Objective Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SMS-01 | Navigator sends P2P text (human-initiated, TCPA compliant) | Twilio `CreateMessage` API with `MessagingServiceSid`; P2P path requires human-in-the-loop send; suppression check pre-send |
| SMS-02 | Full conversation threading per voter | `sms_messages` table keyed on `(company_id, voter_id)` with direction/timestamps; inbound webhook delivers replies |
| SMS-03 | Admin creates message templates with merge fields | `sms_templates` table with Go `text/template` or simple `{{.FirstName}}` replacement; template preview endpoint |
| SMS-04 | Admin creates A2P broadcast campaigns targeting voter segments | `sms_campaigns` + `sms_campaign_messages` tables; batch sending via NATS JetStream worker; rate limiting per Twilio throughput |
| SMS-05 | System processes STOP/opt-out keywords and updates suppression list | Twilio Advanced Opt-Out handles carrier-level STOP; inbound webhook with `OptOutType` param triggers suppression_list insert |
| SMS-06 | System enforces quiet hours (no texts 8am-9pm) | Server-side pre-send gate checking recipient timezone via area code; Twilio Compliance Toolkit as secondary layer |
| SMS-07 | System supports 10DLC registration flow | Twilio BrandRegistration + UsAppToPerson APIs; admin UI to track registration status; gate A2P sends on approved status |
| SMS-08 | System tracks delivery status via provider webhooks | Twilio StatusCallback URL on each sent message; webhook handler updates `sms_messages.status`; NATS consumer for async processing |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `github.com/twilio/twilio-go` | v1.30.4 | Twilio REST API client | Official SDK; typed clients for Messages, Messaging Services, 10DLC, webhook validation |
| `github.com/nats-io/nats.go` | v1.49.0 (already in go.mod) | Async message processing | Already a dependency; eden bridge pattern provides JetStream consumer model |
| `connectrpc.com/connect` | v1.19.1 (already in go.mod) | RPC handlers for SMS service | Existing project pattern for all service handlers |
| `github.com/jackc/pgx/v5` | (already in go.mod) | Database for message storage | Existing project pattern; sqlc generates typed queries |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `text/template` (stdlib) | - | Template merge field rendering | Rendering `{{.FirstName}}` etc. in message templates |
| `golang.org/x/time/rate` | (already indirect) | Rate limiting campaign sends | Throttle A2P batch sends to Twilio throughput limits |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Twilio | Vonage/Bandwidth | Twilio has best 10DLC support, Go SDK, political messaging docs |
| NATS JetStream | Database polling | JetStream already in eden; provides at-least-once delivery, backpressure |
| Server-side quiet hours | Twilio Compliance Toolkit only | Compliance Toolkit is a paid add-on; server-side gate is free and gives full control |

**Installation:**
```bash
cd navigators-go && go get github.com/twilio/twilio-go@latest
```

## Architecture Patterns

### Recommended Project Structure
```
internal/navigators/
    sms_service.go           # Core SMS operations (send, receive, thread lookup)
    sms_campaign_service.go  # Campaign CRUD, batch send orchestration
    sms_template_service.go  # Template CRUD, merge field rendering
    sms_webhook_handler.go   # HTTP handlers for Twilio webhooks (NOT ConnectRPC)
    sms_handler.go           # ConnectRPC handler for SMS RPC endpoints
    sms_worker.go            # NATS JetStream consumer for async send/status processing
    sms_compliance.go        # Quiet hours, suppression check, opt-out processing

proto/navigators/v1/
    sms.proto                # SMS service protobuf definitions

queries/navigators/
    sms.sql                  # sqlc queries for SMS tables

migrations/navigators/
    013_sms.up.sql           # SMS tables (messages, templates, campaigns, config)
    013_sms.down.sql
```

### Pattern 1: Two-Path Send Architecture
**What:** P2P and A2P sends use different code paths with shared infrastructure.
**When to use:** Always -- these have different compliance requirements.

P2P path (Navigator sends single text):
1. Navigator calls `SendP2PMessage` RPC
2. Server checks: voter not suppressed, quiet hours OK, company has P2P messaging service configured
3. Server calls Twilio `CreateMessage` with `MessagingServiceSid` (P2P service)
4. Server inserts row into `sms_messages` with `status=queued`, `direction=outbound`, `message_type=p2p`
5. Twilio webhook updates delivery status asynchronously

A2P path (Admin creates campaign):
1. Admin calls `CreateCampaign` RPC with template ID + voter segment filters
2. Server creates `sms_campaigns` row with `status=draft`
3. Admin calls `LaunchCampaign` RPC
4. Server publishes batch of send jobs to NATS JetStream subject `navigators.sms.campaign.send`
5. Worker consumer picks up jobs, applies quiet hours + suppression checks, sends via Twilio with A2P Messaging Service SID
6. Worker inserts `sms_messages` rows and `sms_campaign_messages` join rows

### Pattern 2: Webhook Ingestion via NATS
**What:** Twilio webhooks hit a thin HTTP handler that publishes to NATS; a JetStream consumer does the real work.
**When to use:** All webhook processing (inbound messages, delivery status updates).

```
Twilio --> POST /webhooks/twilio/inbound  --> validate signature --> publish to NATS "navigators.sms.inbound"
Twilio --> POST /webhooks/twilio/status   --> validate signature --> publish to NATS "navigators.sms.status"

NATS Consumer "sms-inbound-worker":
  - Parse inbound message
  - Check OptOutType param --> if STOP, add to suppression_list
  - Insert sms_messages row with direction=inbound
  - (Future: notify Navigator of reply)

NATS Consumer "sms-status-worker":
  - Parse status update
  - UPDATE sms_messages SET status=$1 WHERE twilio_message_sid=$2
```

### Pattern 3: Messaging Service Abstraction
**What:** Never send from raw phone numbers. Always use Twilio Messaging Service SIDs.
**When to use:** All sends.

Messaging Services provide:
- Number pool management (Twilio picks the best number)
- Sticky sender (same number used for conversation continuity)
- Built-in opt-out handling at carrier level
- 10DLC campaign association (numbers in the pool are automatically associated)

Store per-company config:
```sql
CREATE TABLE sms_config (
    company_id UUID PRIMARY KEY REFERENCES companies(id),
    twilio_account_sid TEXT NOT NULL,
    twilio_auth_token_encrypted TEXT NOT NULL,
    p2p_messaging_service_sid TEXT NOT NULL DEFAULT '',
    a2p_messaging_service_sid TEXT NOT NULL DEFAULT '',
    webhook_url TEXT NOT NULL DEFAULT '',
    quiet_hours_start INT NOT NULL DEFAULT 21,  -- 9 PM
    quiet_hours_end INT NOT NULL DEFAULT 8,     -- 8 AM
    ten_dlc_brand_sid TEXT NOT NULL DEFAULT '',
    ten_dlc_campaign_sid TEXT NOT NULL DEFAULT '',
    ten_dlc_status TEXT NOT NULL DEFAULT 'not_started',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### Pattern 4: Conversation Threading
**What:** Group all messages for a voter into a conversation thread.
**When to use:** SMS-02 conversation view.

The `sms_messages` table uses `(company_id, voter_id)` as the logical thread key. Query conversation by:
```sql
SELECT * FROM sms_messages
WHERE company_id = $1 AND voter_id = $2
ORDER BY created_at ASC;
```

No separate "conversation" table needed -- the voter IS the conversation anchor. This aligns with how political texting works: each voter has one ongoing thread.

### Anti-Patterns to Avoid
- **Sending from raw phone numbers:** Always use Messaging Service SIDs for number pool management and sticky sender
- **Synchronous webhook processing:** Twilio expects fast responses (< 15s); do heavy work in NATS consumer
- **Client-side quiet hours check only:** Must enforce server-side; client clocks are unreliable
- **Storing Twilio credentials in plaintext:** Use eden platform's encryption or environment variables
- **Polling for delivery status:** Use StatusCallback webhooks; polling wastes API calls and is delayed

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Opt-out keyword detection | Custom STOP/UNSUBSCRIBE parser | Twilio Advanced Opt-Out + OptOutType webhook param | Carriers handle this at network level; Twilio passes `OptOutType` in webhook |
| Phone number management | Number assignment logic | Twilio Messaging Service number pool | Handles sticky sender, load balancing, failover automatically |
| Webhook signature validation | Custom HMAC implementation | `twilio-go/client.RequestValidator` | SDK handles timestamp validation, encoding edge cases |
| SMS segment counting | Character counting logic | Twilio handles segmentation | GSM-7 vs UCS-2 encoding rules are complex; Twilio returns `NumSegments` |
| Timezone lookup from phone | Area code to timezone mapping | Twilio Compliance Toolkit + server-side area code lookup | Area codes are imperfect but standard approach; Twilio Contact API accepts ZIP for better accuracy |
| 10DLC registration flow | Custom TCR integration | Twilio BrandRegistration + UsAppToPerson APIs | Twilio abstracts TCR complexity; status webhooks notify on approval |

**Key insight:** Twilio's Messaging Service layer handles most of the hard infrastructure problems (number selection, opt-out at carrier level, segment encoding). Your job is to build the application layer: conversation UI, templates, campaigns, compliance gates, and status tracking.

## Common Pitfalls

### Pitfall 1: Mixing P2P and A2P Traffic on Same Messaging Service
**What goes wrong:** Carriers flag high-volume traffic from a P2P-registered number pool, leading to filtering and message blocking.
**Why it happens:** P2P and A2P have different throughput expectations and compliance registrations.
**How to avoid:** Use separate Twilio Messaging Service SIDs for P2P and A2P. Store both in `sms_config`.
**Warning signs:** Delivery rates dropping, 30007 errors from Twilio.

### Pitfall 2: Not Gating on 10DLC Registration Status
**What goes wrong:** A2P messages sent before 10DLC approval are filtered by carriers with error 30034.
**Why it happens:** 10DLC registration takes days/weeks; developers test with trial accounts and forget the gate.
**How to avoid:** Store `ten_dlc_status` in config; check `status == 'approved'` before any A2P send. P2P sends also benefit from 10DLC but have higher tolerance.
**Warning signs:** High undelivered rates on A2P campaigns.

### Pitfall 3: Webhook URL Not Publicly Accessible
**What goes wrong:** Twilio cannot deliver status callbacks or inbound messages in development.
**Why it happens:** Local development environments are behind NAT.
**How to avoid:** Use ngrok or Twilio CLI for local development; document webhook URL configuration.
**Warning signs:** No delivery status updates appearing; inbound messages not received.

### Pitfall 4: Quiet Hours Timezone Miscalculation
**What goes wrong:** Messages sent at 8:50 PM sender time arrive at 11:50 PM recipient time (different timezone).
**Why it happens:** Using server timezone instead of recipient timezone.
**How to avoid:** Infer recipient timezone from phone number area code. Maine is Eastern Time, which simplifies this for the initial use case (all recipients in Maine). Store timezone offset and check against it.
**Warning signs:** Opt-out complaints citing late-night messages.

### Pitfall 5: Suppression Check Race Condition
**What goes wrong:** A STOP message arrives milliseconds after a campaign send is queued, and the voter receives one more message after opting out.
**Why it happens:** Campaign batch sends are queued ahead of time; suppression check happens at queue time, not send time.
**How to avoid:** Check suppression at the moment of actual Twilio API call (in the NATS worker), not at campaign queue time. The existing suppression service is FAIL-CLOSED which is correct.
**Warning signs:** Complaints from voters who said STOP but got one more message.

### Pitfall 6: Not Handling Twilio Webhook Retries
**What goes wrong:** Duplicate message processing; double-insertion of inbound messages.
**Why it happens:** Twilio retries webhooks if your server returns non-2xx or times out.
**How to avoid:** Use `MessageSid` as idempotency key. `INSERT ... ON CONFLICT (twilio_message_sid) DO NOTHING` for inbound messages; `UPDATE ... WHERE twilio_message_sid = $1` for status updates (naturally idempotent).
**Warning signs:** Duplicate messages in conversation threads.

## Code Examples

### Sending a P2P Message via Twilio
```go
// Source: https://pkg.go.dev/github.com/twilio/twilio-go + official docs
import (
    "github.com/twilio/twilio-go"
    twilioApi "github.com/twilio/twilio-go/rest/api/v2010"
)

func (s *SMSService) SendP2P(ctx context.Context, to, body, messagingServiceSid, statusCallbackURL string) (string, error) {
    params := &twilioApi.CreateMessageParams{}
    params.SetTo(to)
    params.SetBody(body)
    params.SetMessagingServiceSid(messagingServiceSid)
    params.SetStatusCallback(statusCallbackURL)

    resp, err := s.twilioClient.Api.CreateMessage(params)
    if err != nil {
        return "", fmt.Errorf("twilio create message: %w", err)
    }
    return *resp.Sid, nil
}
```

### Validating Twilio Webhook Signature
```go
// Source: https://pkg.go.dev/github.com/twilio/twilio-go/client
import "github.com/twilio/twilio-go/client"

func (h *WebhookHandler) validateRequest(r *http.Request, authToken string) bool {
    validator := client.NewRequestValidator(authToken)
    url := "https://yourdomain.com" + r.URL.Path
    body, _ := io.ReadAll(r.Body)
    r.Body = io.NopCloser(bytes.NewReader(body)) // reset body for later parsing
    signature := r.Header.Get("X-Twilio-Signature")
    return validator.ValidateBody(url, body, signature)
}
```

### Inbound Webhook Handler (Thin + NATS Publish)
```go
// Twilio sends application/x-www-form-urlencoded POST
func (h *WebhookHandler) HandleInbound(w http.ResponseWriter, r *http.Request) {
    if !h.validateRequest(r, h.authToken) {
        http.Error(w, "invalid signature", http.StatusForbidden)
        return
    }
    r.ParseForm()
    
    envelope := InboundSMSEvent{
        MessageSid:          r.FormValue("MessageSid"),
        From:                r.FormValue("From"),
        To:                  r.FormValue("To"),
        Body:                r.FormValue("Body"),
        OptOutType:          r.FormValue("OptOutType"), // "STOP", "HELP", "START", or ""
        MessagingServiceSid: r.FormValue("MessagingServiceSid"),
    }
    
    data, _ := json.Marshal(envelope)
    _, err := h.js.Publish(ctx, "navigators.sms.inbound", data)
    if err != nil {
        slog.Error("failed to publish inbound SMS to NATS", "error", err)
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }
    
    // Return empty TwiML (no auto-reply)
    w.Header().Set("Content-Type", "application/xml")
    w.Write([]byte("<Response></Response>"))
}
```

### NATS JetStream Consumer Setup (Following Eden Bridge Pattern)
```go
// Source: eden-platform-go/platform/bridge/bridge.go pattern
func (w *SMSWorker) Start(ctx context.Context) error {
    stream, err := w.js.CreateOrUpdateStream(ctx, jetstream.StreamConfig{
        Name:     "NAVIGATORS_SMS",
        Subjects: []string{"navigators.sms.>"},
        Storage:  jetstream.FileStorage,
    })
    
    cons, err := w.js.CreateOrUpdateConsumer(ctx, "NAVIGATORS_SMS", jetstream.ConsumerConfig{
        Durable:       "sms-worker",
        FilterSubject: "navigators.sms.>",
        AckPolicy:     jetstream.AckExplicitPolicy,
    })
    
    // Process messages in loop (same pattern as BridgeService.Start)
    go func() {
        for {
            select {
            case <-ctx.Done():
                return
            default:
            }
            msg, err := cons.Next(jetstream.FetchMaxWait(5 * time.Second))
            if err != nil {
                continue
            }
            w.processMessage(ctx, msg)
        }
    }()
    return nil
}
```

### Template Merge Field Rendering
```go
import "text/template"

func renderTemplate(tmplBody string, voter VoterContext) (string, error) {
    t, err := template.New("sms").Parse(tmplBody)
    if err != nil {
        return "", fmt.Errorf("parse template: %w", err)
    }
    var buf bytes.Buffer
    if err := t.Execute(&buf, voter); err != nil {
        return "", fmt.Errorf("execute template: %w", err)
    }
    return buf.String(), nil
}

// VoterContext provides merge fields available in templates.
type VoterContext struct {
    FirstName   string
    LastName    string
    City        string
    District    string
    Party       string
}
```

### Quiet Hours Check
```go
func isQuietHours(now time.Time, quietStart, quietEnd int) bool {
    hour := now.Hour()
    // quietStart=21 (9PM), quietEnd=8 (8AM)
    // Quiet if hour >= 21 OR hour < 8
    if quietStart > quietEnd {
        return hour >= quietStart || hour < quietEnd
    }
    return hour >= quietStart && hour < quietEnd
}

// For Maine (all Eastern Time), convert UTC to ET before checking.
func (s *SMSService) checkQuietHours(recipientPhone string) bool {
    loc, _ := time.LoadLocation("America/New_York") // Maine = Eastern
    now := time.Now().In(loc)
    return isQuietHours(now, s.config.QuietHoursStart, s.config.QuietHoursEnd)
}
```

## Database Schema Design

### Core Tables (Migration 013)
```sql
-- Per-company Twilio configuration
CREATE TABLE sms_config (
    company_id UUID PRIMARY KEY REFERENCES companies(id),
    twilio_account_sid TEXT NOT NULL DEFAULT '',
    twilio_auth_token_encrypted TEXT NOT NULL DEFAULT '',
    p2p_messaging_service_sid TEXT NOT NULL DEFAULT '',
    a2p_messaging_service_sid TEXT NOT NULL DEFAULT '',
    inbound_webhook_url TEXT NOT NULL DEFAULT '',
    status_webhook_url TEXT NOT NULL DEFAULT '',
    quiet_hours_start INT NOT NULL DEFAULT 21,
    quiet_hours_end INT NOT NULL DEFAULT 8,
    ten_dlc_brand_sid TEXT NOT NULL DEFAULT '',
    ten_dlc_campaign_sid TEXT NOT NULL DEFAULT '',
    ten_dlc_status TEXT NOT NULL DEFAULT 'not_started'
        CHECK (ten_dlc_status IN ('not_started','pending','approved','failed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Individual SMS messages (both inbound and outbound)
CREATE TABLE sms_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    voter_id UUID NOT NULL REFERENCES voters(id),
    user_id UUID REFERENCES users(id),           -- NULL for inbound
    campaign_id UUID REFERENCES sms_campaigns(id), -- NULL for P2P
    direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
    message_type TEXT NOT NULL CHECK (message_type IN ('p2p', 'a2p')),
    from_number TEXT NOT NULL DEFAULT '',
    to_number TEXT NOT NULL DEFAULT '',
    body TEXT NOT NULL DEFAULT '',
    twilio_message_sid TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'queued'
        CHECK (status IN ('queued','sent','delivered','undelivered','failed','received')),
    error_code TEXT NOT NULL DEFAULT '',
    segments INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(twilio_message_sid)  -- idempotency key for webhooks
);
CREATE INDEX idx_sms_messages_voter ON sms_messages (company_id, voter_id, created_at);
CREATE INDEX idx_sms_messages_campaign ON sms_messages (campaign_id) WHERE campaign_id IS NOT NULL;
CREATE INDEX idx_sms_messages_twilio_sid ON sms_messages (twilio_message_sid) WHERE twilio_message_sid != '';

-- Message templates with merge fields
CREATE TABLE sms_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    name TEXT NOT NULL,
    body TEXT NOT NULL,         -- Contains {{.FirstName}} etc.
    merge_fields TEXT[] NOT NULL DEFAULT '{}',  -- List of fields used
    created_by UUID NOT NULL REFERENCES users(id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(company_id, name)
);

-- Broadcast campaigns
CREATE TABLE sms_campaigns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id),
    name TEXT NOT NULL,
    template_id UUID NOT NULL REFERENCES sms_templates(id),
    segment_filters JSONB NOT NULL DEFAULT '{}',  -- Same filter format as ListVoters
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft','sending','paused','completed','cancelled')),
    total_recipients INT NOT NULL DEFAULT 0,
    sent_count INT NOT NULL DEFAULT 0,
    delivered_count INT NOT NULL DEFAULT 0,
    failed_count INT NOT NULL DEFAULT 0,
    created_by UUID NOT NULL REFERENCES users(id),
    launched_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Send from raw phone numbers | Twilio Messaging Service (number pool) | 2022+ | Required for 10DLC; better delivery, sticky sender |
| No registration needed for A2P | 10DLC registration required for all A2P | 2023 enforcement | Unregistered A2P traffic is filtered/blocked by carriers |
| Basic STOP handling | Twilio Advanced Opt-Out + Compliance Toolkit | 2024 | Carrier-level opt-out handling; `OptOutType` webhook param |
| Twilio Compliance Toolkit optional | Increasingly standard for quiet hours | 2025 | State-specific quiet hours (10 states); AI message classification |
| `nats.go` JetStream old API | `nats.go/jetstream` new package | 2023 | Cleaner consumer API; pull-based consumers recommended |

**Deprecated/outdated:**
- `SetFrom()` for direct number sending: Still works but not recommended for political messaging; use `SetMessagingServiceSid()` instead
- Old `nats.JetStreamContext` API: Replaced by `nats.go/jetstream` package; eden bridge already uses new API

## P2P vs A2P Compliance Summary

| Aspect | P2P (Navigator sends) | A2P (Admin campaign) |
|--------|----------------------|---------------------|
| Consent required | Implied/existing relationship OK | Prior express consent required |
| 10DLC required | Recommended but not strictly required | Required; carriers filter unregistered |
| Throughput | Low (human-paced) | High (batch); rate-limited by carrier |
| Quiet hours | Enforced (good practice) | Strictly enforced (TCPA) |
| STOP handling | Twilio auto-handles | Twilio auto-handles |
| Messaging Service | Separate P2P service SID | Separate A2P service SID with 10DLC campaign |
| Content | Personalized, one-off | Templated, merge fields |
| Maine-specific | All recipients in Eastern Time | All recipients in Eastern Time |

## 10DLC Registration Flow

For a political organization like MaineGOP:
1. **Create Trust Profile** in Twilio Console (business info, EIN, address)
2. **Register Brand** via API: `POST /v1/a2p/BrandRegistrations` with customer profile bundle SID
3. **Wait for approval** (typically 1-7 days for political orgs; check status via API or webhook)
4. **Register Campaign** via API: `POST /v1/a2p/UsAppToPerson` with brand SID, messaging service SID, use case description
5. **Campaign approved** -> numbers in Messaging Service automatically associated
6. **Store status** in `sms_config.ten_dlc_status` and gate A2P sends on `approved`

Registration costs: ~$4-$44 one-time brand fee + $15 per campaign vetting + $1.50-$10/month per campaign.

## Open Questions

1. **Twilio Compliance Toolkit pricing**
   - What we know: It provides automatic quiet hours and advanced opt-out management
   - What's unclear: Whether it's included in standard pricing or is an add-on; the exact cost
   - Recommendation: Implement server-side quiet hours regardless; add Compliance Toolkit as defense-in-depth if budget allows

2. **Encrypted credential storage**
   - What we know: Twilio auth tokens must be stored securely; eden has `platform/encryption` package
   - What's unclear: Whether eden encryption package is wired up in navigators yet
   - Recommendation: Use environment variables for now (existing pattern in `config.Load()`); the `twilio_auth_token_encrypted` column can use eden encryption when available

3. **Campaign sending rate limits**
   - What we know: 10DLC campaigns have throughput limits (typically 15-75 msg/sec depending on trust score)
   - What's unclear: Exact throughput for a political org brand
   - Recommendation: Start with conservative 1 msg/sec rate limit; increase after 10DLC approval and observing actual limits

## Sources

### Primary (HIGH confidence)
- [twilio/twilio-go GitHub](https://github.com/twilio/twilio-go) - v1.30.4, Go 1.18-1.24, API surface
- [pkg.go.dev twilio-go](https://pkg.go.dev/github.com/twilio/twilio-go) - Package structure, RestClient fields
- [Twilio Messaging Webhooks](https://www.twilio.com/docs/usage/webhooks/messaging-webhooks) - Webhook request format, status callbacks
- [Twilio Inbound Webhook Request](https://www.twilio.com/docs/messaging/guides/webhook-request) - Full parameter list for inbound SMS
- [Twilio Track Outbound Status](https://www.twilio.com/docs/messaging/guides/track-outbound-message-status) - StatusCallback usage, status values
- [Twilio BrandRegistration API](https://www.twilio.com/docs/messaging/api/brand-registration-resource) - 10DLC registration endpoints
- [Twilio A2P 10DLC](https://www.twilio.com/docs/messaging/compliance/a2p-10dlc) - Registration flow, costs, requirements
- [Twilio Compliance Toolkit](https://www.twilio.com/docs/messaging/features/compliance-toolkit) - Quiet hours, opt-out enforcement
- [Twilio Advanced Opt-Out](https://support.twilio.com/hc/en-us/articles/360034798533) - OptOutType parameter, keyword handling
- [NATS JetStream docs](https://docs.nats.io/nats-concepts/jetstream) - Stream/consumer configuration
- Eden platform bridge.go (local) - JetStream consumer pattern used in project
- Existing codebase (local) - Suppression service, contact logs, permissions, proto patterns

### Secondary (MEDIUM confidence)
- [2025 Political Texting Compliance](https://politicalcomms.com/blog/2025-political-texting-compliance-fcc-tcpa/) - TCPA rules for political campaigns
- [Twilio Webhooks Security](https://www.twilio.com/docs/usage/webhooks/webhooks-security) - Signature validation approach

### Tertiary (LOW confidence)
- Twilio Compliance Toolkit pricing - not verified from official pricing page
- Exact 10DLC throughput for political orgs - varies by trust score

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official SDK verified, versions confirmed on pkg.go.dev
- Architecture: HIGH - Follows established eden/navigators patterns (bridge, handler/service, sqlc)
- Pitfalls: HIGH - Well-documented in Twilio docs and community; verified against real API behavior
- Compliance: MEDIUM - TCPA rules are well-established but enforcement nuances change; political texting has some exemptions
- 10DLC registration: MEDIUM - API documented but approval timelines and trust scores vary

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (30 days -- Twilio API is stable; compliance rules change slowly)
