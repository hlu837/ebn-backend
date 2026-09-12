-- Property Owner Inbox: one row per incoming request against a Property
-- Owner's listing — "I want more info", "I want a tour", or "I want to
-- rent this now" (the advance-payment / documents / agreement / payment
-- lifecycle described for the Review tab is intentionally NOT modeled
-- here yet — that's a separate follow-up; this only needs to carry
-- enough to list, filter, and open a conversation).
--
-- Messaging itself is NOT duplicated here — each request is linked to a
-- row in the existing `chat_threads`/`chat_messages` tables (see
-- 0xx_chat.sql / backend/src/models/chat.js), keyed the same way an
-- Agent's listing chat already is: customer_id = requester, agent_id =
-- the owner (assets.broker_id already holds the owner's user id for a
-- Property Owner self-listing — see 064_property_owner_role.sql).
--
-- `status` only tracks pending vs closed here; "has the owner replied
-- yet" is derived at query time from the linked thread's
-- last_message_sender_id rather than stored, so there's no separate
-- transition to keep in sync.

DO $$ BEGIN
  CREATE TYPE property_request_type AS ENUM ('info', 'tour', 'rent_now');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE property_request_status AS ENUM ('pending', 'closed');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS property_requests (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  asset_id       UUID NOT NULL REFERENCES assets(id),
  owner_id       UUID NOT NULL REFERENCES users(id),
  requester_id   UUID NOT NULL REFERENCES users(id),

  request_type   property_request_type NOT NULL,
  status         property_request_status NOT NULL DEFAULT 'pending',

  -- The chat_threads row this request's conversation lives in. Nullable
  -- only so a request row can never fail to insert because of a chat
  -- hiccup; in practice `propertyRequests.create` always sets it in the
  -- same call.
  thread_id      UUID REFERENCES chat_threads(id),

  -- The requester's opening message (also posted as the first chat
  -- message) — kept here too so the Inbox list can show/search it
  -- without a join for the common case.
  message        TEXT,

  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_property_requests_owner_id ON property_requests (owner_id);
CREATE INDEX IF NOT EXISTS idx_property_requests_asset_id ON property_requests (asset_id);
CREATE INDEX IF NOT EXISTS idx_property_requests_requester_id ON property_requests (requester_id);
CREATE INDEX IF NOT EXISTS idx_property_requests_thread_id ON property_requests (thread_id);
