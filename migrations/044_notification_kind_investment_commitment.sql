-- Extend the generic notification_kind enum (023_notifications.sql) with
-- the kind investment commitments need. Kept as its own migration,
-- separate from 043_investment_commitments.sql and from any route code
-- that uses the new value, per the note in
-- 024_notification_kind_affiliate.sql (can't ALTER TYPE ... ADD VALUE and
-- use the new value in the same transaction).
ALTER TYPE notification_kind ADD VALUE IF NOT EXISTS 'investment_commitment';
