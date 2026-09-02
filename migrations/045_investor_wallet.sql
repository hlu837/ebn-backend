-- Investor wallet: itemized payout/withdrawal ledger, mirroring
-- agent_wallet_transactions (014_agent_wallet.sql) exactly but scoped to
-- investors. Available balance is derived (not stored) from this ledger —
-- see investorWallet.js model for the exact formula.
--
-- Payouts are credited by an admin against a Confirmed
-- investment_commitments row (see 043_investment_commitments.sql) — see
-- investorWallet.js's addPayout and the /api/investors/:id/wallet/payout
-- route.

DO $$ BEGIN
  CREATE TYPE investor_wallet_tx_type AS ENUM ('payout', 'withdrawal');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE investor_wallet_tx_status AS ENUM ('pending', 'cleared');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS investor_wallet_transactions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  investor_id   UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  type          investor_wallet_tx_type NOT NULL,
  -- Payouts are stored positive, withdrawals negative — the ledger
  -- balance is just SUM(amount) over the rows that count (see model).
  amount        NUMERIC(14, 2) NOT NULL,
  label         TEXT NOT NULL,
  status        investor_wallet_tx_status NOT NULL DEFAULT 'pending',

  -- Only set on payouts — which investment commitment this payout is for.
  commitment_id UUID REFERENCES investment_commitments (id),

  -- Only set for withdrawals — which bank account the payout is headed to.
  bank_account_last4 TEXT,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_investor_wallet_tx_investor_id ON investor_wallet_transactions (investor_id);
CREATE INDEX IF NOT EXISTS idx_investor_wallet_tx_status ON investor_wallet_transactions (investor_id, status);

DROP TRIGGER IF EXISTS trg_investor_wallet_tx_updated_at ON investor_wallet_transactions;
CREATE TRIGGER trg_investor_wallet_tx_updated_at
  BEFORE UPDATE ON investor_wallet_transactions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
