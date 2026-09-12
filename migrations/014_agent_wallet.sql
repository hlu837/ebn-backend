-- Agent wallet: itemized commission/withdrawal ledger backing the Wallet
-- screen. Available balance is derived (not stored) from this ledger —
-- see agentWallet.js model for the exact formula — so it can never drift
-- out of sync with the transaction history shown to the agent.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()

DO $$ BEGIN
  CREATE TYPE wallet_tx_type AS ENUM ('commission', 'withdrawal');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE wallet_tx_status AS ENUM ('pending', 'cleared');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS agent_wallet_transactions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  agent_id      UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,

  type          wallet_tx_type NOT NULL,
  -- Commissions are stored positive, withdrawals negative — the ledger
  -- balance is just SUM(amount) over the rows that count (see model).
  amount        NUMERIC(14, 2) NOT NULL,
  label         TEXT NOT NULL,
  status        wallet_tx_status NOT NULL DEFAULT 'pending',

  -- Only set for withdrawals — which bank account the payout is headed to.
  bank_account_last4 TEXT,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_agent_wallet_tx_agent_id ON agent_wallet_transactions (agent_id);
CREATE INDEX IF NOT EXISTS idx_agent_wallet_tx_status ON agent_wallet_transactions (agent_id, status);

DROP TRIGGER IF EXISTS trg_agent_wallet_tx_updated_at ON agent_wallet_transactions;
CREATE TRIGGER trg_agent_wallet_tx_updated_at
  BEFORE UPDATE ON agent_wallet_transactions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
