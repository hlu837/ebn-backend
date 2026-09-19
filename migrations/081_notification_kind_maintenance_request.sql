-- Extend the generic notification_kind enum (023_notifications.sql) with
-- the maintenance-request pipeline's events (submitted -> owner decides).
-- Kept as its own migration, separate from 080_maintenance_requests.sql
-- and from any route code that uses the new value, per the note in
-- 024_notification_kind_affiliate.sql (can't ALTER TYPE ... ADD VALUE and
-- use the new value in the same transaction).
ALTER TYPE notification_kind ADD VALUE IF NOT EXISTS 'maintenance_request';
