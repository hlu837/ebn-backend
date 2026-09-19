-- Once Admin approves a sell-request submission, try broadcasting it to
-- nearby agents first (same nearest-agent pattern as tour_requests /
-- order_requests) instead of opening it to the entire agent pool right
-- away. Falls back to the old global `open_to_brokers` behavior when the
-- submission has no usable location (address didn't geocode, or no agent
-- is within radius) so nothing regresses for existing data.

-- ── New status enum (same rename-swap pattern as 010/013) ───────────────
DO $$ BEGIN
  CREATE TYPE sell_request_status_v2 AS ENUM (
    'pending_admin_approval',
    'submission_rejected',
    'broadcasting',      -- new: sent to nearby agents first, first to claim wins
    'open_to_brokers',   -- fallback: no location on file / no nearby agent -> visible to everyone
    'claimed',
    'report_pending_approval',
    'report_rejected',
    'listed'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE sell_requests ALTER COLUMN status DROP DEFAULT;

ALTER TABLE sell_requests
  ALTER COLUMN status TYPE sell_request_status_v2
  USING (status::text::sell_request_status_v2);

ALTER TABLE sell_requests ALTER COLUMN status SET DEFAULT 'pending_admin_approval';

DROP TYPE sell_request_status;
ALTER TYPE sell_request_status_v2 RENAME TO sell_request_status;

-- ── Location, geocoded server-side from city/address_line at submission ──
ALTER TABLE sell_requests
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- ── Broadcast pool used while status = 'broadcasting' ────────────────────
ALTER TABLE sell_requests
  ADD COLUMN IF NOT EXISTS broadcast_agent_ids TEXT[] NOT NULL DEFAULT '{}';
