-- Automated payout schedule for confirmed investment commitments.
-- Previously an admin had to manually type in a payout amount against a
-- confirmed commitment (see AdminConfirmedInvestmentsScreen / POST
-- /api/investors/:investorId/wallet/payout) — there was no link back to
-- the opportunity's own expected_return_pct / term_months, so "paid based
-- on the investment agreement" wasn't actually automatic.
--
-- These two columns are the only state the scheduler needs: how many
-- monthly payout periods have already been credited, and (once the term
-- is complete and principal has been returned) when the commitment
-- matured. Everything else — amounts, due dates — is derived at run time
-- from decided_at + the opportunity's expected_return_pct/term_months.
-- See investmentPayoutScheduler.js.

ALTER TABLE investment_commitments ADD COLUMN IF NOT EXISTS payouts_made INTEGER NOT NULL DEFAULT 0;
ALTER TABLE investment_commitments ADD COLUMN IF NOT EXISTS matured_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_investment_commitments_scheduling
  ON investment_commitments (status, matured_at)
  WHERE status = 'Confirmed';
