-- Affiliate program: backs the Affiliater role's dashboard, referrals,
-- earnings/payouts, reports, campaigns, and notifications screens.
-- Mirrors the mock data the Flutter app currently ships with
-- (affiliater_home_screen.dart, affiliate_referrals_screen.dart,
-- affiliate_earnings_screen.dart, affiliate_reports_screen.dart,
-- affiliate_campaigns_screen.dart, affiliate_notifications_screen.dart) so
-- the client-side shapes carry over with minimal changes once wired up.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()

-- Every affiliater gets one shareable code (e.g. "EBN-1A2B3C"), minted on
-- first request rather than at signup so existing affiliater accounts pick
-- one up automatically the first time they open the dashboard.
ALTER TABLE users ADD COLUMN IF NOT EXISTS affiliate_code CITEXT UNIQUE;

DO $$ BEGIN
  CREATE TYPE affiliate_referral_status AS ENUM (
    'pending',   -- referred customer's deal hasn't fully settled yet
    'completed'  -- commission has cleared
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE affiliate_payout_status AS ENUM (
    'processing', -- requested, awaiting admin review
    'paid'        -- funds sent
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE affiliate_campaign_status AS ENUM (
    'upcoming',
    'active',
    'ended'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE affiliate_notification_kind AS ENUM (
    'commission',
    'referral',
    'campaign',
    'payout',
    'system'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- One row per click/sign-up/sale an affiliate's link generated, and the
-- commission it earned. TEXT (not a FK) for affiliate_id/asset_id, matching
-- how order_requests/sell_requests reference users/assets elsewhere.
CREATE TABLE IF NOT EXISTS affiliate_referrals (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  affiliate_id          TEXT NOT NULL,

  customer_name         TEXT NOT NULL,
  customer_user_id      TEXT, -- set if the referred customer has an account

  asset_id              TEXT,
  asset_title           TEXT NOT NULL,

  commission_amount     NUMERIC(12, 2) NOT NULL,
  commission_currency   TEXT NOT NULL DEFAULT 'ETB',

  status                affiliate_referral_status NOT NULL DEFAULT 'pending',

  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_affiliate_id ON affiliate_referrals (affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_referrals_status ON affiliate_referrals (status);

DROP TRIGGER IF EXISTS trg_affiliate_referrals_updated_at ON affiliate_referrals;
CREATE TRIGGER trg_affiliate_referrals_updated_at
  BEFORE UPDATE ON affiliate_referrals
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- One row per payout request/disbursement.
CREATE TABLE IF NOT EXISTS affiliate_payouts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  affiliate_id   TEXT NOT NULL,

  amount         NUMERIC(12, 2) NOT NULL,
  currency       TEXT NOT NULL DEFAULT 'ETB',
  status         affiliate_payout_status NOT NULL DEFAULT 'processing',

  requested_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_at        TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_affiliate_payouts_affiliate_id ON affiliate_payouts (affiliate_id);

-- Platform-wide promotional campaigns affiliates can see and share —
-- admin-managed, not per-affiliate.
CREATE TABLE IF NOT EXISTS affiliate_campaigns (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  title               TEXT NOT NULL,
  description         TEXT NOT NULL,
  badge               TEXT NOT NULL,      -- short label, e.g. "4% Commission" or "5,000 ETB bonus"
  icon                TEXT NOT NULL DEFAULT 'campaign', -- key the client maps to a Flutter IconData
  status              affiliate_campaign_status NOT NULL DEFAULT 'upcoming',

  starts_at           TIMESTAMPTZ,
  ends_at             TIMESTAMPTZ,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_campaigns_status ON affiliate_campaigns (status);

DROP TRIGGER IF EXISTS trg_affiliate_campaigns_updated_at ON affiliate_campaigns;
CREATE TRIGGER trg_affiliate_campaigns_updated_at
  BEFORE UPDATE ON affiliate_campaigns
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Per-affiliate notification feed (commission cleared, new referral, a
-- campaign going live, a payout being sent, etc).
CREATE TABLE IF NOT EXISTS affiliate_notifications (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  affiliate_id   TEXT NOT NULL,

  kind           affiliate_notification_kind NOT NULL,
  title          TEXT NOT NULL,
  body           TEXT NOT NULL,
  is_read        BOOLEAN NOT NULL DEFAULT false,

  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_notifications_affiliate_id ON affiliate_notifications (affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_notifications_is_read ON affiliate_notifications (is_read);

-- One row per "Generate Link" tap / referral-link visit — backs the
-- Reports screen's click counts and conversion rate. There's no public
-- redirect endpoint serving these links yet, so today every row comes
-- from POST /api/affiliates/me/links (the dashboard's "Generate Link"
-- button); a future public GET /api/affiliates/r/:code/:assetId redirect
-- can log real visits into this same table without any schema change.
CREATE TABLE IF NOT EXISTS affiliate_clicks (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  affiliate_id   TEXT NOT NULL,
  asset_id       TEXT,

  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_affiliate_id ON affiliate_clicks (affiliate_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_created_at ON affiliate_clicks (created_at);
