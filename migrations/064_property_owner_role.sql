-- New role: Property Owner. Signs up like Investor — no payment, but the
-- account sits in 'pending_approval' until an admin approves it (see
-- auth.js /signup and users.js /:id/approve-pending-role).
--
-- Kept as its own migration, separate from any route code that uses the
-- new values — can't ALTER TYPE ... ADD VALUE and use the new value in
-- the same transaction (same note as 024_notification_kind_affiliate.sql).

ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'property_owner';

ALTER TYPE notification_kind ADD VALUE IF NOT EXISTS 'property_owner_signup';
