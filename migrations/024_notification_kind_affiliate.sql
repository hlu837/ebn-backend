-- Extends the generic `notification_kind` enum (see 023_notifications.sql)
-- with the kinds the affiliate program's own `affiliate_notifications`
-- table used (see 011_affiliates.sql) — a prerequisite for folding that
-- table into the generic one (see 025_migrate_affiliate_notifications.sql).
--
-- This has to be its own migration file, separate from the one that
-- copies data using these new values: migrate.js re-runs every file on
-- every deploy in one implicit transaction each (there's no migration-
-- tracking table), and Postgres won't let a newly-added enum value be
-- used in the same transaction that added it.

ALTER TYPE notification_kind ADD VALUE IF NOT EXISTS 'referral';
ALTER TYPE notification_kind ADD VALUE IF NOT EXISTS 'campaign';
ALTER TYPE notification_kind ADD VALUE IF NOT EXISTS 'commission';
