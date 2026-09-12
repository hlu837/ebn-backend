-- Tour requests now go straight to the listing's credited agent
-- (assets.broker_id) instead of always waiting on Admin. If that agent
-- doesn't answer in time (expires) or declines, the request is
-- auto-broadcast to nearby agents (same "first to claim wins" pattern as
-- order_requests) instead of just parking in Admin's queue. Admin can
-- still manually dispatch at any point as an override.

-- ── New status enum (same rename-swap pattern as 010_order_requests_broadcast) ──
DO $$ BEGIN
  CREATE TYPE tour_request_status_v2 AS ENUM (
    'pending_approval', -- no credited agent found for the listing -> Admin picks manually
    'dispatched',        -- ringing one specific agent (the credited agent, or Admin's manual pick), countdown running
    'broadcasting',      -- credited agent didn't answer/declined -> sent to nearby agents, first to claim wins
    'accepted',          -- an agent accepted
    'declined',          -- Agent declined -> Admin's queue (auto-broadcasts if a location is on file)
    'expired'            -- countdown hit 0 with no response -> Admin's queue (auto-broadcasts if a location is on file)
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE tour_requests ALTER COLUMN status DROP DEFAULT;

ALTER TABLE tour_requests
  ALTER COLUMN status TYPE tour_request_status_v2
  USING (status::text::tour_request_status_v2);

ALTER TABLE tour_requests ALTER COLUMN status SET DEFAULT 'pending_approval';

DROP TYPE tour_request_status;
ALTER TYPE tour_request_status_v2 RENAME TO tour_request_status;

-- ── Listing location, snapshotted at creation so nearby-matching doesn't ──
-- ── need to re-join `assets` every time.                                 ──
ALTER TABLE tour_requests
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- ── Credited agent (assets.broker_id, if it resolves to a real agent    ──
-- ── account) + the broadcast pool used once that agent falls through.   ──
ALTER TABLE tour_requests
  ADD COLUMN IF NOT EXISTS credited_agent_id  UUID REFERENCES users(id),
  ADD COLUMN IF NOT EXISTS broadcast_agent_ids TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS excluded_agent_ids  TEXT[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_tour_requests_credited_agent_id ON tour_requests (credited_agent_id);
