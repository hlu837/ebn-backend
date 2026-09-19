-- Adds the ability to attach specific catalogue listings to an
-- order_request when Admin marks it "matched" — the visitor's tracker
-- reads this back to show which listings matched their requirement.

ALTER TABLE order_requests
  ADD COLUMN IF NOT EXISTS matched_asset_ids JSONB NOT NULL DEFAULT '[]'::jsonb;
