-- Extend notification_kind for the Review tab's events (documents
-- submitted, agreement sent, rejected, paid, expired). Kept as its own
-- migration, separate from 068_rental_agreements.sql and from any route
-- code that uses the new value, per the note in
-- 024_notification_kind_affiliate.sql (can't ALTER TYPE ... ADD VALUE
-- and use the new value in the same transaction).
ALTER TYPE notification_kind ADD VALUE IF NOT EXISTS 'rental_agreement';
