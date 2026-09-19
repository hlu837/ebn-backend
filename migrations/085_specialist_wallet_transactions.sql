-- Phase 6 payout ledger for service specialists, mirroring
-- agent_wallet_transactions (014_agent_wallet.sql) exactly but scoped to
-- service_providers instead of users -- providers don't have a login yet
-- (082_service_providers.sql), so there's no self-service withdrawal
-- request like agents/investors have. Every 'payout' row here is entered
-- by an admin *after* they've already paid the specialist offline (bank
-- transfer, cash, mobile money) -- it's a record of a completed payout,
-- not a pending request, so status is always 'cleared'. The status
-- column is kept (rather than omitted) so self-service payouts can slot
-- in later, once specialists have their own login, without a reshape.

DO $$ BEGIN
  CREATE TYPE specialist_wallet_tx_type AS ENUM ('credit', 'payout');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE specialist_wallet_tx_status AS ENUM ('cleared');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS specialist_wallet_transactions (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  service_provider_id     UUID NOT NULL REFERENCES service_providers(id) ON DELETE CASCADE,

  type                    specialist_wallet_tx_type NOT NULL,
  -- Credits are stored positive, payouts negative -- the ledger balance
  -- is just SUM(amount) over this table (see specialistWallet.js).
  amount_cents            INTEGER NOT NULL,
  label                   TEXT NOT NULL,
  status                  specialist_wallet_tx_status NOT NULL DEFAULT 'cleared',

  -- Only set on credits -- which job this payout is for.
  maintenance_assignment_id UUID REFERENCES maintenance_assignments(id),

  -- Only set on payouts -- which admin recorded the offline payment.
  recorded_by_admin_id    UUID REFERENCES users(id),

  created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_specialist_wallet_tx_provider_id ON specialist_wallet_transactions (service_provider_id);
