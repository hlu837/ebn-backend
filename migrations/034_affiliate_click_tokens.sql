-- Second reward in the affiliate token program (see 030_affiliate_tokens.sql):
-- signup tokens are for someone actually registering via the affiliate's
-- referral link (unchanged mechanism, just a bigger reward now). This
-- migration adds the "any other share" reward — tokens for someone merely
-- *clicking* a shared link (asset link or plain referral link), whether or
-- not they ever sign up. That's a materially weaker signal than a signup,
-- so it's worth much less (10 vs 100) and is capped so it can't be farmed by
-- repeatedly clicking your own link: at most one reward per affiliate per
-- asset per day (or one per affiliate per day for links with no asset).

-- 100 tokens per referred signup (was 10).
UPDATE affiliate_token_settings SET signup_bonus_tokens = 100 WHERE id = true;
ALTER TABLE affiliate_token_settings ALTER COLUMN signup_bonus_tokens SET DEFAULT 100;

-- 10 tokens per rewarded click, admin-editable alongside the other token
-- settings (GET/PATCH /api/affiliates/token-settings).
ALTER TABLE affiliate_token_settings
  ADD COLUMN IF NOT EXISTS click_bonus_tokens INTEGER NOT NULL DEFAULT 10;

-- One row per *rewarded* click (not every click — just the ones that pass
-- the daily cap below). Written from GET /api/affiliates/r/:code, the
-- public redirect a shared link now points at: it credits tokens, then
-- forwards the visitor on to the real destination in the app.
CREATE TABLE IF NOT EXISTS affiliate_click_rewards (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  affiliate_id  TEXT NOT NULL,
  asset_id      TEXT,
  click_day     DATE NOT NULL DEFAULT CURRENT_DATE,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enforces the daily cap: inserting a second reward for the same
-- affiliate + asset (or affiliate + no-asset link) on the same day
-- violates this and is treated as "already rewarded today" rather than
-- credited again. COALESCE collapses NULL asset_id to a single bucket per
-- affiliate per day, since NULL <> NULL in a plain unique constraint.
CREATE UNIQUE INDEX IF NOT EXISTS idx_affiliate_click_rewards_daily_cap
  ON affiliate_click_rewards (affiliate_id, COALESCE(asset_id, ''), click_day);

CREATE INDEX IF NOT EXISTS idx_affiliate_click_rewards_affiliate_id ON affiliate_click_rewards (affiliate_id);
