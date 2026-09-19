-- Tour requests: one row per "request a tour" submission from a customer.
-- Replaces the old single-shared-slot LoopController with a real,
-- multi-request, per-customer history backed by Postgres.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()

DO $$ BEGIN
  CREATE TYPE tour_request_status AS ENUM (
    'pending_approval', -- just submitted, waiting on Admin
    'dispatched',        -- Admin approved, ringing an Agent, countdown running
    'accepted',          -- Agent accepted
    'declined',          -- Agent declined -> back to Admin's queue
    'expired'            -- countdown hit 0 with no response -> back to Admin's queue
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS tour_requests (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  customer_id              TEXT NOT NULL,
  customer_name            TEXT NOT NULL,

  asset_id                 TEXT NOT NULL,
  asset_title              TEXT NOT NULL,

  status                   tour_request_status NOT NULL DEFAULT 'pending_approval',

  agent_id                 TEXT,
  agent_name               TEXT,

  dispatch_window_seconds  INT NOT NULL DEFAULT 30,
  dispatched_at            TIMESTAMPTZ,
  expires_at               TIMESTAMPTZ,
  responded_at             TIMESTAMPTZ,

  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tour_requests_customer_id ON tour_requests (customer_id);
CREATE INDEX IF NOT EXISTS idx_tour_requests_agent_id ON tour_requests (agent_id);
CREATE INDEX IF NOT EXISTS idx_tour_requests_status ON tour_requests (status);

-- Keep updated_at current on every UPDATE.
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tour_requests_updated_at ON tour_requests;
CREATE TRIGGER trg_tour_requests_updated_at
  BEFORE UPDATE ON tour_requests
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
