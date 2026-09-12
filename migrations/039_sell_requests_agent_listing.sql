-- Lets an Agent submit a "sell my property" request for a property they
-- own themselves, instead of a Visitor's. Same 100 ETB fee and the same
-- Admin submission-screening queue, but the Agent supplies everything a
-- Visitor would (title/description/pricing/etc) *plus* the photos/video
-- and written notes a claiming Agent would normally only add later via
-- the inspection-report step (015/019) — because there's no point
-- assigning an inspection to a different agent when the submitting agent
-- already is the on-the-ground source.
--
-- On approval this skips straight from `pending_admin_approval` to
-- `listed` (see models/sellRequests.js#approveSubmission), never touching
-- `broadcasting` / `open_to_brokers` / `claimed` / `report_pending_approval`
-- — the property is posted under the submitting agent's own name, not
-- handed off to whichever agent claims it first.

ALTER TABLE sell_requests
  ADD COLUMN IF NOT EXISTS is_agent_listing BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_sell_requests_is_agent_listing
  ON sell_requests (is_agent_listing)
  WHERE is_agent_listing;
