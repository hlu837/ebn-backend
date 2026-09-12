-- Support tickets: lands submissions from the agent (and eventually any
-- role's) Support screen somewhere real, so admin_support_inbox_screen on
-- the Admin side has actual data to read instead of its current
-- hardcoded `_sampleMessages` list.

DO $$ BEGIN
  CREATE TYPE support_ticket_category AS ENUM ('account', 'payments', 'listings', 'bug', 'other');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE support_ticket_status AS ENUM ('open', 'resolved');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS support_tickets (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  user_id         UUID REFERENCES users (id) ON DELETE SET NULL,
  sender_name     TEXT NOT NULL,
  sender_contact  TEXT NOT NULL,

  category        support_ticket_category NOT NULL DEFAULT 'other',
  subject         TEXT NOT NULL,
  body            TEXT NOT NULL,

  status          support_ticket_status NOT NULL DEFAULT 'open',

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_tickets_user_id ON support_tickets (user_id);

DROP TRIGGER IF EXISTS trg_support_tickets_updated_at ON support_tickets;
CREATE TRIGGER trg_support_tickets_updated_at
  BEFORE UPDATE ON support_tickets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
