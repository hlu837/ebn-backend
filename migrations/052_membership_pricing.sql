-- Admin-configurable membership pricing for agents and affiliates.
-- This replaces the hardcoded fee tables in agentMembership.js and
-- affiliateMembership.js, allowing admins to adjust pricing per tier
-- via Admin > Settings > Membership Pricing.

CREATE TABLE IF NOT EXISTS membership_pricing (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role          TEXT NOT NULL, -- 'agent' or 'affiliate'
  tier          TEXT NOT NULL, -- 'bronze', 'silver', 'gold', 'diamond'
  monthly_fee_etb NUMERIC(14, 2) NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(role, tier)
);

DROP TRIGGER IF EXISTS trg_membership_pricing_updated_at ON membership_pricing;
CREATE TRIGGER trg_membership_pricing_updated_at
  BEFORE UPDATE ON membership_pricing
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Seed with current hardcoded values so existing behavior doesn't change
-- until admin explicitly updates the pricing.
INSERT INTO membership_pricing (role, tier, monthly_fee_etb) VALUES
  ('agent', 'bronze', 0),
  ('agent', 'silver', 800),
  ('agent', 'gold', 2200),
  ('agent', 'diamond', 5000),
  ('affiliate', 'bronze', 0),
  ('affiliate', 'silver', 500),
  ('affiliate', 'gold', 1500),
  ('affiliate', 'diamond', 3500)
ON CONFLICT (role, tier) DO NOTHING;
