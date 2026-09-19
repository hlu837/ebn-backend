-- Agent membership: current tier + renewal date, and the billing history
-- shown on the Membership screen. Tier perks/fees are small fixed lookup
-- tables kept in code (agentMembership.js) rather than here, matching how
-- the Flutter side already defines them as const maps.

DO $$ BEGIN
  CREATE TYPE agent_tier AS ENUM ('bronze', 'silver', 'gold', 'diamond');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE agent_billing_status AS ENUM ('paid', 'upcoming');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS agent_memberships (
  user_id       UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  tier          agent_tier NOT NULL DEFAULT 'bronze',
  renewal_date  DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '30 days'),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_agent_memberships_updated_at ON agent_memberships;
CREATE TRIGGER trg_agent_memberships_updated_at
  BEFORE UPDATE ON agent_memberships
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS agent_membership_billing (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  label       TEXT NOT NULL,
  amount      NUMERIC(14, 2) NOT NULL,
  status      agent_billing_status NOT NULL DEFAULT 'paid',
  billed_on   DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_membership_billing_user_id ON agent_membership_billing (user_id, billed_on DESC);
