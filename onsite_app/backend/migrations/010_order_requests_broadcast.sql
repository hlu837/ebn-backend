-- Reworks order_requests for the new flow: a Visitor's location (GPS or a
-- geocoded manual address) is used to broadcast the request to nearby
-- agents. Whichever agent confirms first is assigned. Admin can see every
-- request either way. If the Visitor and the assigned agent can't work it
-- out, the Visitor reports it and Admin re-broadcasts the same request.
--
-- This supersedes the old pending_review -> matching -> matched pipeline
-- (Admin hand-picking catalogue listings) — that mechanism is removed in
-- favor of agent assignment.

-- ── New status enum ─────────────────────────────────────────────────────
DO $$ BEGIN
  CREATE TYPE order_request_status_v2 AS ENUM (
    'broadcasting',   -- sent to nearby agents (and visible to Admin), no one has confirmed yet
    'agent_confirmed', -- an agent claimed it; Admin can also see this
    'disputed',       -- Visitor reported the assigned agent — Admin needs to re-broadcast
    'closed'          -- resolved (successfully handled, or Admin closed it out)
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE order_requests ALTER COLUMN status DROP DEFAULT;

ALTER TABLE order_requests
  ALTER COLUMN status TYPE order_request_status_v2
  USING (
    CASE status::text
      WHEN 'matched' THEN 'agent_confirmed'
      WHEN 'closed' THEN 'closed'
      ELSE 'broadcasting' -- pending_review, matching -> broadcasting
    END::order_request_status_v2
  );

ALTER TABLE order_requests ALTER COLUMN status SET DEFAULT 'broadcasting';

DROP TYPE order_request_status;
ALTER TYPE order_request_status_v2 RENAME TO order_request_status;

-- ── Location captured at submission (GPS or geocoded manual address) ────
ALTER TABLE order_requests
  ADD COLUMN IF NOT EXISTS location_source TEXT NOT NULL DEFAULT 'manual'
    CHECK (location_source IN ('gps', 'manual')),
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS address_text TEXT;

-- ── Broadcast + assignment ───────────────────────────────────────────────
ALTER TABLE order_requests
  ADD COLUMN IF NOT EXISTS broadcast_agent_ids TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS excluded_agent_ids  TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS assigned_agent_id    UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS assigned_agent_name  TEXT,
  ADD COLUMN IF NOT EXISTS assigned_agent_phone TEXT,
  ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS dispute_reason TEXT;

-- Superseded by agent assignment — Admin no longer hand-picks listings.
ALTER TABLE order_requests DROP COLUMN IF EXISTS matched_asset_ids;

CREATE INDEX IF NOT EXISTS idx_order_requests_assigned_agent_id ON order_requests (assigned_agent_id);
