-- Affiliate membership: same shape as agent_memberships (017_agent_membership.sql)
-- — current tier + renewal date, plus billing history for the new
-- Affiliater "Upgrade Membership" screen. Tier perks/fees are kept in code
-- (affiliateMembership.js), matching how agentMembership.js does it.

DO $$ BEGIN
  CREATE TYPE affiliate_tier AS ENUM ('bronze', 'silver', 'gold', 'diamond');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE affiliate_billing_status AS ENUM ('paid', 'upcoming');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS affiliate_memberships (
  user_id       UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  tier          affiliate_tier NOT NULL DEFAULT 'bronze',
  renewal_date  DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '30 days'),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_affiliate_memberships_updated_at ON affiliate_memberships;
CREATE TRIGGER trg_affiliate_memberships_updated_at
  BEFORE UPDATE ON affiliate_memberships
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE IF NOT EXISTS affiliate_membership_billing (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  label       TEXT NOT NULL,
  amount      NUMERIC(14, 2) NOT NULL,
  status      affiliate_billing_status NOT NULL DEFAULT 'paid',
  billed_on   DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_membership_billing_user_id ON affiliate_membership_billing (user_id, billed_on DESC);
