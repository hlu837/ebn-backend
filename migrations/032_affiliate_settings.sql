-- Affiliate settings: payout/banking details and notification prefs from
-- the Affiliater "Account Settings" screen. One row per affiliate, created
-- lazily on first read/write (see affiliateSettings.js) so signup doesn't
-- need to know about this table — same pattern as 016_agent_settings.sql.
--
-- Name/phone are NOT stored here — they already live on `users` and are
-- updated via the existing PATCH /api/auth/me.

CREATE TABLE IF NOT EXISTS affiliate_settings (
  user_id                   UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,

  notify_new_referrals      BOOLEAN NOT NULL DEFAULT true,
  notify_payouts            BOOLEAN NOT NULL DEFAULT true,

  bank_name                 TEXT,
  bank_account_number       TEXT,

  created_at                TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_affiliate_settings_updated_at ON affiliate_settings;
CREATE TRIGGER trg_affiliate_settings_updated_at
  BEFORE UPDATE ON affiliate_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
