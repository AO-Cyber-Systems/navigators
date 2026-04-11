-- 013_sms.down.sql
-- Drop SMS tables in reverse dependency order.

DROP TABLE IF EXISTS sms_messages;
DROP TABLE IF EXISTS sms_campaigns;
DROP TABLE IF EXISTS sms_templates;
DROP TABLE IF EXISTS sms_config;
