-- Investment Commitments: an investor's request to put capital into a
-- specific opportunity. Mirrors the role_upgrade_requests pattern —
-- investor submits, admin approves/rejects — rather than moving real
-- money automatically, since there's no payment rail wired to this yet
-- (see Chapa integration on the sell/tour side for that when it lands).
--
-- This is the record wallet balances and payouts will eventually key off
-- of: a Confirmed commitment is what a future "My Investments" screen
-- and payout/ROI job will read.

DO $$ BEGIN
  CREATE TYPE investment_commitment_status AS ENUM ('Pending', 'Confirmed', 'Rejected');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS investment_commitments (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  user_id           UUID NOT NULL REFERENCES users (id),
  opportunity_id    UUID NOT NULL REFERENCES investment_opportunities (id),

  amount            NUMERIC(14, 2) NOT NULL,
  status            investment_commitment_status NOT NULL DEFAULT 'Pending',
  admin_note        TEXT,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  decided_at        TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_investment_commitments_user ON investment_commitments (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_investment_commitments_opportunity ON investment_commitments (opportunity_id);
CREATE INDEX IF NOT EXISTS idx_investment_commitments_status ON investment_commitments (status, created_at DESC);
