-- One free-text note per (agent, customer), so an Agent/Broker can jot
-- down context about a person they're working with — preferences, deal
-- terms discussed, follow-up reminders — and have it persist across every
-- interaction with that same customer, whether they show up again as an
-- "Order Us" buyer or a "Sell/Rent" owner.
--
-- `customer_user_id` matches `order_requests.requester_user_id` /
-- `sell_requests.owner_user_id` — the visitor's own account id, which is
-- the one identifier both request tables share.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()

CREATE TABLE IF NOT EXISTS agent_customer_notes (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id          TEXT NOT NULL,
  customer_user_id  TEXT NOT NULL,
  note              TEXT NOT NULL DEFAULT '',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (agent_id, customer_user_id)
);

CREATE INDEX IF NOT EXISTS idx_agent_customer_notes_agent_id ON agent_customer_notes (agent_id);

-- Reuses the set_updated_at() trigger function defined in
-- 003_sell_requests.sql to keep updated_at current on every UPDATE.
DROP TRIGGER IF EXISTS trg_agent_customer_notes_updated_at ON agent_customer_notes;
CREATE TRIGGER trg_agent_customer_notes_updated_at
  BEFORE UPDATE ON agent_customer_notes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
