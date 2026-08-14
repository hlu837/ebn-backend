-- Payments: tracks every Chapa checkout this backend initializes, regardless
-- of what it's paying for. Right now that's only the 100 ETB "sell my
-- property" listing fee, but `purpose` is kept as free text so any future
-- paid flow can reuse this same table instead of growing a new one.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()

DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM (
    'pending',  -- initialized with Chapa, checkout not confirmed yet
    'success',  -- verified paid via GET /transaction/verify
    'failed'    -- verified as failed/cancelled
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS payments (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  tx_ref                 TEXT NOT NULL UNIQUE, -- our reference; sent to Chapa and echoed back
  purpose                TEXT NOT NULL,        -- e.g. 'sell_request_fee'
  owner_user_id          TEXT,                 -- whichever app-side user this payment is for

  amount                 NUMERIC(12, 2) NOT NULL,
  currency               TEXT NOT NULL DEFAULT 'ETB',
  email                  TEXT NOT NULL,
  first_name             TEXT,
  last_name              TEXT,

  status                 payment_status NOT NULL DEFAULT 'pending',
  chapa_checkout_url     TEXT,
  chapa_verify_response  JSONB, -- raw response from the last /transaction/verify call

  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_tx_ref ON payments (tx_ref);
CREATE INDEX IF NOT EXISTS idx_payments_owner ON payments (owner_user_id);
