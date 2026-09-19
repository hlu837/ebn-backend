-- Affiliate token program: a reward layer that sits alongside (and is
-- separate from) the deal-based commission system in affiliate_referrals.
--
-- Tokens are credited automatically when someone signs up using an
-- affiliate's referral code (see users.referral_code, POST /api/auth/signup,
-- and affiliatesModel.creditSignupTokens) — this is the "get notification
-- ... when someone registers using his or her referral link, and earn
-- token" flow. Tokens can then be redeemed for cash at a fixed conversion
-- rate, which creates a normal affiliate_payouts row so it goes through the
-- exact same admin payout pipeline commissions already use.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$ BEGIN
  CREATE TYPE affiliate_token_entry_type AS ENUM (
    'earned',    -- credited to the affiliate (e.g. a referral signup)
    'redeemed'   -- converted to cash via a payout
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Distinguishes a token-redemption payout from a regular commission payout
-- on the existing affiliate_payouts table, so admins (and the affiliate's
-- own history) can tell the two apart without joining the ledger.
DO $$ BEGIN
  CREATE TYPE affiliate_payout_source AS ENUM (
    'commission',
    'token_redemption'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE affiliate_payouts
  ADD COLUMN IF NOT EXISTS source affiliate_payout_source NOT NULL DEFAULT 'commission';

-- One row per token event. `amount` is signed (+N for 'earned', -N for
-- 'redeemed') so the running balance is just SUM(amount).
CREATE TABLE IF NOT EXISTS affiliate_token_ledger (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  affiliate_id       TEXT NOT NULL,

  type               affiliate_token_entry_type NOT NULL,
  amount             INTEGER NOT NULL,
  reason             TEXT NOT NULL,

  -- Set when type = 'earned' via a referral signup.
  referred_user_id   TEXT,
  referred_user_name TEXT,

  -- Set when type = 'redeemed' — points at the payout it created.
  payout_id          UUID REFERENCES affiliate_payouts (id),

  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT affiliate_token_ledger_amount_sign CHECK (
    (type = 'earned' AND amount > 0) OR (type = 'redeemed' AND amount < 0)
  )
);

CREATE INDEX IF NOT EXISTS idx_affiliate_token_ledger_affiliate_id ON affiliate_token_ledger (affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_token_ledger_created_at ON affiliate_token_ledger (created_at);

-- Singleton config row: how many tokens a signup is worth, and the cash
-- conversion rate — admin-editable (GET/PATCH /api/affiliates/token-settings)
-- so changing the reward doesn't need a deploy.
CREATE TABLE IF NOT EXISTS affiliate_token_settings (
  id                   BOOLEAN PRIMARY KEY DEFAULT true CHECK (id),

  signup_bonus_tokens  INTEGER NOT NULL DEFAULT 10,
  etb_per_token        NUMERIC(10, 2) NOT NULL DEFAULT 1.00,
  min_redeemable_tokens INTEGER NOT NULL DEFAULT 100,

  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_affiliate_token_settings_updated_at ON affiliate_token_settings;
CREATE TRIGGER trg_affiliate_token_settings_updated_at
  BEFORE UPDATE ON affiliate_token_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO affiliate_token_settings (id) VALUES (true) ON CONFLICT DO NOTHING;
