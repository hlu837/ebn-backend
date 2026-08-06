-- Order requests: one row per "Order Us" submission — the reverse of
-- Sell/Rent. A Visitor describes what they're looking for instead of
-- listing something themselves; Admin/matching team cross-references it
-- against existing listings. Lighter pipeline than sell_requests since
-- there's no fee or on-site inspection involved:
-- pending_review -> matching -> matched -> closed.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()

DO $$ BEGIN
  CREATE TYPE order_request_status AS ENUM (
    'pending_review', -- submitted, waiting on Admin/matching team to pick it up
    'matching',        -- being cross-referenced against current listings
    'matched',         -- matching listings found — an agent will reach out
    'closed'           -- request closed (matched & handled, or no longer needed)
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS order_requests (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- ── Visitor submission ──────────────────────────────────────────────
  requester_user_id   TEXT NOT NULL,
  requester_name       TEXT NOT NULL,
  requester_phone      TEXT NOT NULL,

  category            TEXT NOT NULL, -- AssetCategorySlug on the client, kept as free text here

  -- Rendered on the client at submit time from whichever requirement
  -- wizard (property/vehicle/machinery/general) the visitor went through —
  -- stored as plain text/strings here, same approach as sell_requests'
  -- house/vehicle/machinery *_details columns not needing to be read back.
  title               TEXT NOT NULL,
  description         TEXT NOT NULL,
  budget_summary      TEXT NOT NULL,

  status              order_request_status NOT NULL DEFAULT 'pending_review',

  -- ── Admin / matching team ───────────────────────────────────────────
  admin_note          TEXT,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_requests_requester_user_id ON order_requests (requester_user_id);
CREATE INDEX IF NOT EXISTS idx_order_requests_status ON order_requests (status);

-- Reuses the set_updated_at() trigger function defined in
-- 003_sell_requests.sql to keep updated_at current on every UPDATE.
DROP TRIGGER IF EXISTS trg_order_requests_updated_at ON order_requests;
CREATE TRIGGER trg_order_requests_updated_at
  BEFORE UPDATE ON order_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
