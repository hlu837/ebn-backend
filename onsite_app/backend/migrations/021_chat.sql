-- Chat: real backing for `broker_chat_screen.dart`, which today fakes a
-- two-way conversation with canned/randomized broker replies and never
-- persists anything. One thread per (customer, agent, asset) triple —
-- scoped to a listing, matching how the client always enters chat from a
-- specific asset's "Chat about this listing" button.
--
-- `agent_id` is a real `users.id` (role = 'agent'), NOT `assets.broker_id`
-- directly — `broker_id` is a loose TEXT field that may still hold a
-- legacy mock id (b1..b9) for seed listings that predate real agent
-- accounts. Threads can only be created against a broker_id that resolves
-- to an actual agent account; see routes/chat.js.

CREATE TABLE IF NOT EXISTS chat_threads (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  customer_id            UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  agent_id               UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  asset_id               UUID NOT NULL REFERENCES assets (id) ON DELETE CASCADE,

  last_message_body      TEXT,
  last_message_sender_id UUID REFERENCES users (id) ON DELETE SET NULL,
  last_message_at        TIMESTAMPTZ,

  -- Simple read-state: "I've seen everything up to this timestamp".
  -- Cheaper than a per-message read flag and enough for an unread badge.
  customer_last_read_at  TIMESTAMPTZ,
  agent_last_read_at     TIMESTAMPTZ,

  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (customer_id, agent_id, asset_id)
);

CREATE INDEX IF NOT EXISTS idx_chat_threads_customer_id ON chat_threads (customer_id, last_message_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_chat_threads_agent_id ON chat_threads (agent_id, last_message_at DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_chat_threads_asset_id ON chat_threads (asset_id);

DROP TRIGGER IF EXISTS trg_chat_threads_updated_at ON chat_threads;
CREATE TRIGGER trg_chat_threads_updated_at
  BEFORE UPDATE ON chat_threads
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS chat_messages (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id     UUID NOT NULL REFERENCES chat_threads (id) ON DELETE CASCADE,
  sender_id     UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  body          TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_thread_id ON chat_messages (thread_id, created_at ASC);
