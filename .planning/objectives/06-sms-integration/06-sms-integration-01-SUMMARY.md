---
objective: 06-sms-integration
trd: "01"
subsystem: sms
tags: [sms, twilio, nats, webhooks, compliance, p2p-texting]
dependency_graph:
  requires: [suppression_service, permissions, contact_logs, nats]
  provides: [sms_tables, sms_service, twilio_integration, webhook_handlers, nats_workers, sms_handler]
  affects: [main.go, permissions.go, go.mod]
tech_stack:
  added: [twilio-go v1.30.4, nats.go/jetstream (direct)]
  patterns: [async webhook processing via NATS JetStream, fail-closed compliance, Twilio signature validation]
key_files:
  created:
    - navigators-go/migrations/navigators/013_sms.up.sql
    - navigators-go/migrations/navigators/013_sms.down.sql
    - navigators-go/queries/navigators/sms.sql
    - navigators-go/proto/navigators/v1/sms.proto
    - navigators-go/internal/navigators/sms_service.go
    - navigators-go/internal/navigators/sms_compliance.go
    - navigators-go/internal/navigators/sms_webhook_handler.go
    - navigators-go/internal/navigators/sms_worker.go
    - navigators-go/internal/navigators/sms_handler.go
  modified:
    - navigators-go/internal/navigators/permissions.go
    - navigators-go/cmd/server/main.go
    - navigators-go/go.mod
    - navigators-go/go.sum
decisions:
  - "NATS connection failure is non-fatal: SMS features degrade but server starts"
  - "Single-company (MaineGOP) assumption for inbound webhook voter lookup in v1"
  - "Company admin user used for added_by FK when processing webhook-driven opt-outs"
  - "Twilio signature validation skipped in dev mode when auth token not set"
  - "Phone normalization strips +1 prefix and non-digit chars for voter lookup"
metrics:
  duration: 12min
  completed: 2026-04-11
---

# Objective 06 TRD 01: SMS Infrastructure Summary

SMS data model, Twilio provider integration, P2P texting, webhook handling, and NATS async processing with quiet hours enforcement and opt-out pipeline.

## One-liner

P2P SMS via Twilio with NATS JetStream async webhook processing, fail-closed suppression checks, Eastern timezone quiet hours, and STOP/START opt-out to suppression_list.

## What Was Built

### Migration 013: SMS Tables
- `sms_config`: Per-company Twilio credentials, messaging service SIDs, quiet hours (default 9PM-8AM), 10DLC tracking
- `sms_templates`: Message templates with merge field support, soft delete
- `sms_campaigns`: Bulk campaign tracking with recipient/sent/delivered/failed counters
- `sms_messages`: Individual messages (inbound + outbound), Twilio SID dedup via UNIQUE constraint, conversation threading indexes

### SMSComplianceService
- `CheckSendAllowed`: Suppression check (fail-closed) + quiet hours gate
- `isQuietHours`: Wrapping midnight logic (hour >= start OR hour < end for 21:00-08:00)
- `ProcessOptOut`: STOP inserts to suppression_list (via company admin user for FK), START removes

### SMSService
- `SendP2P`: Claims extraction, config load, compliance check, voter phone lookup, Twilio CreateMessage, DB insert, contact_log entry, audit log
- `GetConversation`: Paginated chronological message thread per voter
- `ListConversations`: Voter summaries with last message for conversation list
- `GetConfig` / `UpdateConfig`: Admin SMS configuration CRUD

### SMSWebhookHandler (Plain HTTP)
- `HandleInbound`: Twilio signature validation, form parsing, NATS publish to navigators.sms.inbound, TwiML response
- `HandleStatus`: Twilio signature validation, form parsing, NATS publish to navigators.sms.status
- URL reconstruction for signature validation with X-Forwarded-Proto/Host support

### SMSWorker (NATS JetStream)
- Creates NAVIGATORS_SMS stream with navigators.sms.> subjects (FileStorage)
- Durable consumers: sms-inbound-worker, sms-status-worker
- `processInbound`: Voter lookup by phone, idempotent message insert, opt-out processing
- `processStatus`: Message status update, campaign counter increment (delivered/failed)

### SMSHandler (ConnectRPC)
- Implements SMSServiceHandler interface: SendP2PMessage, GetConversation, ListConversations, GetSMSConfig, UpdateSMSConfig
- Offset-based pagination with page tokens

### Permission Matrix
- FeatureSMS: send (Navigator), view (Navigator), config (Admin), admin (Admin)
- 5 procedure permissions mapped

### main.go Wiring
- NATS connection (non-fatal on failure)
- Twilio config from env vars
- SMS compliance, service, handler, webhook handler, NATS worker all wired

## Commits

| Task | Commit | Description |
|---|---|---|
| 1 | db01962 | Migration 013, sqlc queries, proto definitions, Twilio SDK |
| 2 | 8ea66c4 | SMS service, compliance, webhooks, NATS worker, handler, main.go wiring |

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: SMS migration, sqlc queries, proto, Twilio SDK | `cd navigators-go && go build ./...` | 0 | PASS |
| 2: SMS service, compliance, webhooks, NATS worker, handler, main.go wiring | `cd navigators-go && go build ./...` | 0 | PASS |

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| build | `cd navigators-go && go build ./...` | 0 | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added GetCompanyAdminUserID query for opt-out processing**
- **Found during:** Task 2
- **Issue:** suppression_list.added_by has NOT NULL FK to users(id); webhook-driven opt-outs have no authenticated user context
- **Fix:** Added sqlc query GetCompanyAdminUserID that finds a company admin user via company_memberships JOIN roles
- **Files modified:** queries/navigators/sms.sql, internal/db/sms.sql.go
- **Commit:** 8ea66c4

**2. [Rule 3 - Blocking] Added GetVoterPhone and GetVoterByPhone queries**
- **Found during:** Task 1
- **Issue:** No existing query to look up voter phone number by ID, or find voter by phone number for inbound SMS
- **Fix:** Added GetVoterPhone (for outbound send) and GetVoterByPhone (for inbound webhook) queries
- **Files modified:** queries/navigators/sms.sql
- **Commit:** db01962

**3. [Rule 2 - Missing functionality] Added InsertContactLog query**
- **Found during:** Task 1
- **Issue:** No direct insert query for contact_logs (only UpsertContactLogFromSync existed, which requires all fields including id and door_status)
- **Fix:** Added simplified InsertContactLog query for SMS contact log entries
- **Files modified:** queries/navigators/sms.sql
- **Commit:** db01962

## Post-TRD Verification

- Auto-fix cycles used: 1 (sqlc query for eden user_roles -> company_memberships table name)
- Must-haves verified: 6/6
- Gate failures: None

## Decisions Made

1. **NATS connection failure is non-fatal**: Server starts with degraded SMS features if NATS unavailable
2. **Single-company assumption for v1**: Inbound webhook uses MaineGOPCompanyID for voter lookup
3. **Company admin user for opt-out FK**: GetCompanyAdminUserID query finds an admin user for the suppression_list.added_by foreign key when processing webhook-driven STOP keywords
4. **Dev mode signature skip**: Twilio webhook signature validation skipped when auth token is empty (dev environments)
5. **Phone normalization**: Strips +1 prefix and non-digits for consistent voter phone lookup
