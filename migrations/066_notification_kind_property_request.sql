-- Extend the generic notification_kind enum (023_notifications.sql) with
-- the kind Property Owner Inbox requests need. Kept as its own migration,
-- separate from 065_property_requests.sql and from any route code that
-- uses the new value, per the note in 024_notification_kind_affiliate.sql
-- (can't ALTER TYPE ... ADD VALUE and use the new value in the same
-- transaction).
ALTER TYPE notification_kind ADD VALUE IF NOT EXISTS 'property_request';
