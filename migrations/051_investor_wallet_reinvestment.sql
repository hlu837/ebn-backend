-- Adds 'reinvestment' as a third investor_wallet_transactions type,
-- alongside 'payout' and 'withdrawal' (045_investor_wallet.sql). A
-- reinvestment rolls an investor's existing wallet balance (payouts
-- already received) straight into a new investment commitment instead of
-- withdrawing it to a bank account. It's recorded as a negative amount
-- just like a withdrawal, but tagged distinctly so the transaction
-- history and admin views can tell the two apart, and — unlike a
-- withdrawal — clears immediately rather than sitting 'pending': the
-- money never leaves the platform, it just moves from spendable balance
-- into a Pending investment_commitments row (see investorWallet.js's
-- reinvest() and the /api/investors/:id/wallet/reinvest route).

DO $$ BEGIN
  ALTER TYPE investor_wallet_tx_type ADD VALUE 'reinvestment';
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
