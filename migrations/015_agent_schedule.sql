-- Agent schedule: the calendar of property tours / client bookings shown
-- on the Schedule screen. `source` distinguishes bookings the agent added
-- manually from ones that will eventually be auto-created when a dispatch
-- is accepted off the ringing overlay (see tour_requests) — that link is
-- not wired yet, so `dispatch_tour_request_id` just sits ready for it.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$ BEGIN
  CREATE TYPE agent_booking_status AS ENUM ('pending', 'confirmed', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE agent_booking_source AS ENUM ('manual', 'dispatch');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS agent_bookings (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  agent_id                  UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  client_name               TEXT NOT NULL,
  property_title            TEXT NOT NULL,
  address                   TEXT,

  start_at                  TIMESTAMPTZ NOT NULL,
  duration_minutes          INT NOT NULL DEFAULT 60,

  status                    agent_booking_status NOT NULL DEFAULT 'pending',
  source                    agent_booking_source NOT NULL DEFAULT 'manual',
  dispatch_tour_request_id  UUID REFERENCES tour_requests (id) ON DELETE SET NULL,

  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_bookings_agent_id ON agent_bookings (agent_id, start_at);

DROP TRIGGER IF EXISTS trg_agent_bookings_updated_at ON agent_bookings;
CREATE TRIGGER trg_agent_bookings_updated_at
  BEFORE UPDATE ON agent_bookings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
