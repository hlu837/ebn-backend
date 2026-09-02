-- Extends the generic `notification_kind` enum (see 023_notifications.sql)
-- with 'token', used by the affiliate token program (030_affiliate_tokens.sql)
-- for "you earned N tokens" / "tokens redeemed" notifications.
--
-- Has to be its own migration file, separate from the one that uses this
-- value: migrate.js re-runs every file on every deploy in one implicit
-- transaction each, and Postgres won't let a newly-added enum value be
-- used in the same transaction that added it.

ALTER TYPE notification_kind ADD VALUE IF NOT EXISTS 'token';
