---
objective: 06-sms-integration
trd: "02"
subsystem: sms
tags: [templates, campaigns, 10dlc, nats, a2p, rate-limiting]
dependency_graph:
  requires: ["06-01"]
  provides: ["template-crud", "campaign-lifecycle", "campaign-worker", "10dlc-gating"]
  affects: ["sms_handler", "sms_worker", "permissions", "main.go"]
tech_stack:
  added: ["golang.org/x/time/rate"]
  patterns: ["text/template merge fields", "NATS batch publish", "rate-limited consumer", "10DLC A2P gating"]
key_files:
  created:
    - navigators-go/internal/navigators/sms_template_service.go
    - navigators-go/internal/navigators/sms_campaign_service.go
  modified:
    - navigators-go/internal/navigators/sms_worker.go
    - navigators-go/internal/navigators/sms_handler.go
    - navigators-go/internal/navigators/sms_service.go
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/proto/navigators/v1/sms.proto
    - navigators-go/cmd/server/main.go
    - navigators-go/queries/navigators/sms.sql
decisions:
  - "VoterContext struct with 5 merge fields (FirstName, LastName, City, District, Party) for template rendering"
  - "Campaign segment filtering simplified to company-wide voters with phone for v1; full segment_filters JSONB parsing deferred"
  - "Rate limiter at 1 msg/sec conservative default using golang.org/x/time/rate"
  - "SMSService.TwilioClient() accessor added for shared client between P2P service and campaign worker"
metrics:
  duration: "8min"
  completed: "2026-04-11"
---

# Objective 06 TRD 02: Message Templates and Broadcast Campaigns Summary

Template CRUD with text/template merge fields, A2P broadcast campaigns with NATS batch worker, 10DLC registration gating, and campaign progress tracking.

## What Was Built

### Task 1: Template Service and Campaign Service with 10DLC Gating

**SMSTemplateService** (`sms_template_service.go`):
- Full CRUD: CreateTemplate, ListTemplates, GetTemplate, UpdateTemplate, DeleteTemplate
- Template body validation via `text/template` parse on create/update (catches syntax errors early)
- RenderTemplate: parses body with restricted FuncMap, executes with VoterContext
- PreviewTemplate: renders with sample data (Jane Doe, Portland, HD-1, Republican)
- VoterContext struct: FirstName, LastName, City, District, Party
- VoterContextFromRow helper for building context from sqlc query rows

**SMSCampaignService** (`sms_campaign_service.go`):
- CreateCampaign: validates template exists and is active, inserts with status='draft'
- LaunchCampaign: 10DLC gate (ten_dlc_status must be 'approved'), counts targets, sets status='sending', publishes CampaignSendJob to NATS in batches of 100
- PauseCampaign/CancelCampaign: status transitions with validation
- GetCampaign/ListCampaigns: standard CRUD with company scoping
- Get10DLCStatus/Update10DLCStatus: admin tracks registration status from Twilio dashboard
- CampaignSendJob struct: CampaignID, VoterID, CompanyID, TemplateID (JSON over NATS)

**sqlc queries added:**
- UpdateCampaignTotalRecipients: sets total after voter count
- GetCampaignVoterTargets: voter ID, phone, name, city, district, party for rendering
- CountCampaignVoterTargets: count voters with phone numbers

### Task 2: Campaign NATS Worker, Proto Updates, Handler, Permissions, Wiring

**Campaign NATS Worker** (updated `sms_worker.go`):
- Third durable consumer "sms-campaign-worker" on navigators.sms.campaign.send
- Rate limiter: `rate.NewLimiter(1, 1)` -- 1 msg/sec conservative A2P default
- processCampaignSend flow:
  1. Rate limit wait
  2. Check campaign status still 'sending' (supports pause/cancel mid-batch)
  3. Compliance check at SEND TIME: suppression + quiet hours
  4. Load template, load voter data, render with VoterContext
  5. Send via Twilio A2P Messaging Service SID
  6. Insert sms_messages row (direction=outbound, message_type=a2p, campaign_id set)
  7. Insert contact_log (contact_type='text')
  8. Increment sent_count; check completion (sent+failed >= total -> status='completed')
- Error handling: individual send failures increment failed_count, campaign continues

**Proto** (updated `sms.proto`):
- 14 new RPCs: CreateTemplate, ListTemplates, GetTemplate, UpdateTemplate, DeleteTemplate, PreviewTemplate, CreateCampaign, LaunchCampaign, PauseCampaign, CancelCampaign, GetCampaign, ListCampaigns, Get10DLCStatus, Update10DLCStatus
- SMSTemplate message type: id, name, body, merge_fields, is_active, timestamps
- SMSCampaign message type: id, name, template_id, segment_filters, status, counts, timestamps

**Handler** (updated `sms_handler.go`):
- All 14 new RPCs implemented with input validation and service delegation
- Proto conversion helpers: smsTemplateToProto, smsCampaignToProto
- NewSMSHandler now accepts smsService, templateService, campaignService

**Permissions** (updated `permissions.go`):
- sms:template (Admin) and sms:campaign (Admin) in permission matrix
- 16 new procedure permission mappings for template, campaign, and 10DLC RPCs

**main.go wiring:**
- templateService and campaignService created and passed to handler and worker
- Worker receives templateService + TwilioClient for A2P sending

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] SMSService.TwilioClient() accessor**
- **Found during:** Task 2 (wiring)
- **Issue:** Worker needed Twilio client for A2P sends but SMSService held it privately
- **Fix:** Added TwilioClient() getter method on SMSService
- **Files modified:** sms_service.go
- **Commit:** c12fd3c

**2. [Rule 3 - Blocking] golang.org/x/time upgrade**
- **Found during:** Task 2 (build)
- **Issue:** x/time was indirect dep at v0.12.0; rate package import needed direct dep
- **Fix:** `go get golang.org/x/time` upgraded to v0.15.0 as direct dependency
- **Files modified:** go.mod, go.sum
- **Commit:** c12fd3c

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Template + Campaign service | `cd navigators-go && go build ./...` | 0 | PASS |
| 2: Worker, proto, handler, wiring | `cd navigators-go && go build ./...` | 0 | PASS |

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| build | `cd navigators-go && go build ./...` | 0 | PASS |

## Post-TRD Verification

- Auto-fix cycles used: 2 (TwilioClient accessor, unused import removal)
- Must-haves verified: 7/7
- Gate failures: None

## Commits

| Task | Commit | Message |
|---|---|---|
| 1 | 75f4fde | feat(06-02): template service and campaign service with 10DLC gating |
| 2 | c12fd3c | feat(06-02): campaign NATS worker, proto updates, handler, permissions, main.go wiring |
