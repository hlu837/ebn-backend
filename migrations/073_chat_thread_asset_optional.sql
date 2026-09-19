-- Allows a chat thread to exist without a specific listing, so a visitor
-- can message a broker directly from their profile ("Chat" button) even
-- when the broker has no active listings yet, instead of only ever being
-- able to open chat from a listing's "Chat about this listing" button.
--
-- The original UNIQUE (customer_id, agent_id, asset_id) constraint still
-- covers the per-listing case correctly once asset_id is nullable (SQL
-- treats each NULL as distinct, so it would otherwise let a customer open
-- unlimited "general" threads with the same agent) — the partial unique
-- index below closes that gap by allowing at most one asset_id IS NULL
-- thread per (customer_id, agent_id) pair.

ALTER TABLE chat_threads ALTER COLUMN asset_id DROP NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_chat_threads_customer_agent_general
  ON chat_threads (customer_id, agent_id)
  WHERE asset_id IS NULL;
