-- name: UpsertSMSConfig :exec
INSERT INTO sms_config (company_id, twilio_account_sid, twilio_auth_token_encrypted, p2p_messaging_service_sid, a2p_messaging_service_sid, inbound_webhook_url, status_webhook_url, quiet_hours_start, quiet_hours_end, ten_dlc_brand_sid, ten_dlc_campaign_sid, ten_dlc_status)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
ON CONFLICT (company_id) DO UPDATE SET
    twilio_account_sid = EXCLUDED.twilio_account_sid,
    twilio_auth_token_encrypted = EXCLUDED.twilio_auth_token_encrypted,
    p2p_messaging_service_sid = EXCLUDED.p2p_messaging_service_sid,
    a2p_messaging_service_sid = EXCLUDED.a2p_messaging_service_sid,
    inbound_webhook_url = EXCLUDED.inbound_webhook_url,
    status_webhook_url = EXCLUDED.status_webhook_url,
    quiet_hours_start = EXCLUDED.quiet_hours_start,
    quiet_hours_end = EXCLUDED.quiet_hours_end,
    ten_dlc_brand_sid = EXCLUDED.ten_dlc_brand_sid,
    ten_dlc_campaign_sid = EXCLUDED.ten_dlc_campaign_sid,
    ten_dlc_status = EXCLUDED.ten_dlc_status,
    updated_at = now();

-- name: GetSMSConfig :one
SELECT * FROM sms_config WHERE company_id = $1;

-- name: InsertSMSMessage :one
INSERT INTO sms_messages (company_id, voter_id, user_id, campaign_id, direction, message_type, from_number, to_number, body, twilio_message_sid, status, segments)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
RETURNING id, created_at;

-- name: GetSMSMessageByTwilioSid :one
SELECT * FROM sms_messages WHERE twilio_message_sid = $1;

-- name: UpdateSMSMessageStatus :exec
UPDATE sms_messages
SET status = $2, error_code = $3, updated_at = now()
WHERE twilio_message_sid = $1;

-- name: ListConversation :many
SELECT * FROM sms_messages
WHERE company_id = $1 AND voter_id = $2
ORDER BY created_at ASC
LIMIT $3 OFFSET $4;

-- name: CountConversationMessages :one
SELECT COUNT(*) FROM sms_messages
WHERE company_id = $1 AND voter_id = $2;

-- name: InsertSMSMessageIdempotent :exec
INSERT INTO sms_messages (company_id, voter_id, user_id, campaign_id, direction, message_type, from_number, to_number, body, twilio_message_sid, status, segments)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
ON CONFLICT (twilio_message_sid) DO NOTHING;

-- name: CreateSMSTemplate :one
INSERT INTO sms_templates (company_id, name, body, merge_fields, created_by)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, created_at;

-- name: ListSMSTemplates :many
SELECT * FROM sms_templates
WHERE company_id = $1 AND is_active = true
ORDER BY name
LIMIT $2 OFFSET $3;

-- name: GetSMSTemplate :one
SELECT * FROM sms_templates
WHERE id = $1 AND company_id = $2;

-- name: UpdateSMSTemplate :exec
UPDATE sms_templates
SET name = $3, body = $4, merge_fields = $5, updated_at = now()
WHERE id = $1 AND company_id = $2;

-- name: DeleteSMSTemplate :exec
UPDATE sms_templates SET is_active = false, updated_at = now()
WHERE id = $1 AND company_id = $2;

-- name: CreateSMSCampaign :one
INSERT INTO sms_campaigns (company_id, name, template_id, segment_filters, created_by)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, created_at;

-- name: GetSMSCampaign :one
SELECT * FROM sms_campaigns
WHERE id = $1 AND company_id = $2;

-- name: UpdateCampaignStatus :exec
UPDATE sms_campaigns
SET status = $3,
    launched_at = CASE WHEN $3 = 'sending' AND launched_at IS NULL THEN now() ELSE launched_at END,
    completed_at = CASE WHEN $3 IN ('completed', 'cancelled') THEN now() ELSE completed_at END,
    updated_at = now()
WHERE id = $1 AND company_id = $2;

-- name: IncrementCampaignSentCount :exec
UPDATE sms_campaigns SET sent_count = sent_count + 1, updated_at = now()
WHERE id = $1;

-- name: IncrementCampaignDeliveredCount :exec
UPDATE sms_campaigns SET delivered_count = delivered_count + 1, updated_at = now()
WHERE id = $1;

-- name: IncrementCampaignFailedCount :exec
UPDATE sms_campaigns SET failed_count = failed_count + 1, updated_at = now()
WHERE id = $1;

-- name: UpdateCampaignTotalRecipients :exec
UPDATE sms_campaigns SET total_recipients = $2, updated_at = now()
WHERE id = $1;

-- name: GetCampaignVoterTargets :many
-- Returns voter IDs and phone numbers matching segment filters for campaign sends.
-- Uses simple company-wide query; segment filtering done in Go for flexibility.
SELECT id, phone, first_name, last_name, res_city, state_house_district, party
FROM voters
WHERE company_id = $1 AND phone != ''
ORDER BY last_name, first_name
LIMIT $2 OFFSET $3;

-- name: CountCampaignVoterTargets :one
SELECT COUNT(*) FROM voters
WHERE company_id = $1 AND phone != '';

-- name: ListSMSCampaigns :many
SELECT * FROM sms_campaigns
WHERE company_id = $1
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListConversationVoters :many
SELECT DISTINCT ON (m.voter_id)
    m.voter_id,
    v.first_name,
    v.last_name,
    m.body AS last_message_body,
    m.created_at AS last_message_at
FROM sms_messages m
JOIN voters v ON v.id = m.voter_id
WHERE m.company_id = $1
ORDER BY m.voter_id, m.created_at DESC
LIMIT $2 OFFSET $3;

-- name: GetVoterPhone :one
SELECT phone FROM voters WHERE id = $1 AND company_id = $2;

-- name: GetVoterByPhone :one
SELECT id, company_id FROM voters WHERE phone = $1 AND company_id = $2;

-- name: InsertContactLog :exec
INSERT INTO contact_logs (company_id, voter_id, user_id, contact_type, notes)
VALUES ($1, $2, $3, $4, $5);

-- name: GetSMSMessageCampaignID :one
SELECT campaign_id FROM sms_messages WHERE twilio_message_sid = $1;

-- name: GetCompanyAdminUserID :one
-- Returns any admin user for the company (for system-initiated operations like opt-out processing).
SELECT cm.user_id FROM company_memberships cm
JOIN roles r ON r.id = cm.role_id
WHERE cm.company_id = $1 AND r.level >= 80
LIMIT 1;
