-- Replaces the single overwritable `agent_customer_notes` row per
-- (agent, customer) with a running log of timestamped entries, so an
-- agent can see how their read on a customer changed over time —
-- "called 8/1 — wants to see it Saturday", "called 8/3 — pushed to
-- next week" — instead of losing prior context every time the note
-- gets edited.
--
-- `customer_user_id` keeps the same meaning as before: it matches
-- `order_requests.requester_user_id` / `sell_requests.owner_user_id`.

CREATE TABLE IF NOT EXISTS agent_customer_note_entries (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id          TEXT NOT NULL,
  customer_user_id  TEXT NOT NULL,
  body              TEXT NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Entries are always fetched per (agent, customer) ordered newest-first,
-- and the agent-wide list screen fetches per agent ordered the same way.
CREATE INDEX IF NOT EXISTS idx_agent_customer_note_entries_agent_customer
  ON agent_customer_note_entries (agent_id, customer_user_id, created_at DESC);

-- Carry forward any note an agent already wrote as the first entry in
-- that customer's new log, so nothing gets lost in the switch.
INSERT INTO agent_customer_note_entries (agent_id, customer_user_id, body, created_at)
SELECT agent_id, customer_user_id, note, updated_at
FROM agent_customer_notes
WHERE note IS NOT NULL AND btrim(note) <> '';

DROP TABLE IF EXISTS agent_customer_notes;
