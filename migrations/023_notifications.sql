-- Generic, cross-role notification feed. The affiliate program already has
-- its own `affiliate_notifications` table/routes; this is the same idea
-- generalized so agents and customers can get notified too (new order
-- dispatches, chat messages, payouts) without a separate table per role.

DO $$ BEGIN
  CREATE TYPE notification_recipient_type AS ENUM ('user', 'agent', 'affiliater', 'investor', 'admin');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE notification_kind AS ENUM (
    'new_dispatch',
    'chat_message',
    'payout',
    'system'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS notifications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  recipient_type  notification_recipient_type NOT NULL,
  recipient_id    TEXT NOT NULL,

  kind            notification_kind NOT NULL,
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  is_read         BOOLEAN NOT NULL DEFAULT false,

  -- Optional pointer back to whatever this notification is about (an
  -- order request id, a chat thread id, etc) so a tap can deep-link.
  related_id      TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications (recipient_type, recipient_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications (is_read);
