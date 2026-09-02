-- Investment Opportunities: admin-curated deals investors can browse.
-- Read is public/investor-facing (same shape as announcements); writes
-- are admin-only. This is the foundation the wallet/payout/history
-- features will eventually reference (an investor "holding" will point
-- at an opportunity row here), but for now it's just the browsable list.

DO $$ BEGIN
  CREATE TYPE investment_opportunity_category AS ENUM ('Real Estate', 'Vehicle', 'Machinery', 'Other');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE investment_opportunity_status AS ENUM ('Open', 'Funded', 'Closed');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS investment_opportunities (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  title               TEXT NOT NULL,
  description         TEXT NOT NULL,
  category            investment_opportunity_category NOT NULL DEFAULT 'Other',
  status              investment_opportunity_status NOT NULL DEFAULT 'Open',

  target_amount       NUMERIC(14, 2) NOT NULL,
  min_investment       NUMERIC(14, 2) NOT NULL,
  expected_return_pct  NUMERIC(6, 2) NOT NULL,
  term_months          INTEGER NOT NULL,
  image_url            TEXT,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_investment_opportunities_status_created
  ON investment_opportunities (status, created_at DESC);
