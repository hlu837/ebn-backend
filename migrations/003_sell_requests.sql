-- Sell requests: one row per "Sell my property" submission, tracked all the
-- way from Visitor submission -> Admin screening -> Agent/Broker claim ->
-- Agent inspection report -> Admin final approval -> live listing.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()

DO $$ BEGIN
  CREATE TYPE sell_request_status AS ENUM (
    'pending_admin_approval',   -- submitted + fee paid, waiting on Admin to screen it
    'submission_rejected',      -- Admin rejected outright — never opened to brokers
    'open_to_brokers',          -- Admin approved — visible to every Agent/Broker to claim
    'claimed',                  -- an Agent claimed it, expected to inspect in person
    'report_pending_approval',  -- Agent submitted their inspection report
    'report_rejected',          -- Admin sent the report back for revision
    'listed'                    -- Admin approved the report — now a live listing
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS sell_requests (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- ── Visitor submission ────────────────────────────────────────────────
  owner_user_id               TEXT NOT NULL,
  owner_name                  TEXT NOT NULL,
  owner_phone                 TEXT NOT NULL,

  category                    TEXT NOT NULL, -- AssetCategorySlug on the client, kept as free text here
  title                       TEXT NOT NULL,
  description                 TEXT NOT NULL,
  asking_price                NUMERIC(14, 2) NOT NULL,
  city                        TEXT NOT NULL,
  address_line                TEXT NOT NULL,

  fee_amount                  NUMERIC(10, 2) NOT NULL DEFAULT 100,
  fee_paid                    BOOLEAN NOT NULL DEFAULT true,

  -- Category-specific wizard answers — only one of these is ever populated,
  -- depending on `category`. Stored as-is (client owns the shape) rather
  -- than normalized into columns, so new wizard fields never need a migration.
  house_details                JSONB,
  vehicle_details               JSONB,
  machinery_details              JSONB,

  status                      sell_request_status NOT NULL DEFAULT 'pending_admin_approval',

  -- ── Admin: submission screening ─────────────────────────────────────────
  submission_rejection_reason TEXT,

  -- ── Agent/Broker: claim ──────────────────────────────────────────────
  agent_id                    TEXT,
  agent_name                  TEXT,
  claimed_at                  TIMESTAMPTZ,

  -- ── Agent/Broker: inspection report ─────────────────────────────────────
  report_media                 JSONB NOT NULL DEFAULT '[]'::jsonb, -- [{ id, isVideo }]
  report_notes                 TEXT,
  report_submitted_at          TIMESTAMPTZ,
  report_rejection_reason      TEXT,

  -- ── Final listing ────────────────────────────────────────────────────
  listed_asset_id              TEXT,

  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sell_requests_owner_user_id ON sell_requests (owner_user_id);
CREATE INDEX IF NOT EXISTS idx_sell_requests_agent_id ON sell_requests (agent_id);
CREATE INDEX IF NOT EXISTS idx_sell_requests_status ON sell_requests (status);

-- Keep updated_at current on every UPDATE.
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sell_requests_updated_at ON sell_requests;
CREATE TRIGGER trg_sell_requests_updated_at
  BEFORE UPDATE ON sell_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
