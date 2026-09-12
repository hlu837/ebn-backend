-- Consolidates affiliate_notifications (011_affiliates.sql) into the
-- generic notifications table (023_notifications.sql). The affiliate
-- program predates the generic feed and got its own parallel table;
-- this backfills its history into the shared one so
-- models/affiliates.js's notification functions can become thin
-- wrappers around models/notifications.js instead of maintaining a
-- second table going forward (see that file for the code side).
--
-- Reuses each row's original id so this is safe to run on every deploy
-- (ON CONFLICT on the shared primary key skips rows already copied) —
-- required since migrate.js has no migration-tracking table and re-runs
-- every file every time.
--
-- affiliate_notifications itself is left in place, untouched, as a
-- historical/rollback safety net. It's no longer written to after this
-- change ships and can be dropped in a later cleanup once that's been
-- confirmed in your own environment.
INSERT INTO notifications (id, recipient_type, recipient_id, kind, title, body, is_read, created_at)
SELECT
  id,
  'affiliater',
  affiliate_id,
  kind::text::notification_kind,
  title,
  body,
  is_read,
  created_at
FROM affiliate_notifications
ON CONFLICT (id) DO NOTHING;
