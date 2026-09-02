-- Investor membership plan: single row (id = 1), admin-editable, powers
-- the Investor "Shareholder & Investor Membership" screen the Flutter app
-- shows during signup/upgrade. Previously this content (price, benefits,
-- copy) was hardcoded in the app itself — moving it here lets an admin
-- change the price or benefits without a redeploy. Mirrors the shape of
-- general_settings (050_admin_settings.sql): fixed single row, no history.

CREATE TABLE IF NOT EXISTS investor_membership_plan (
  id            SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  tier_key      TEXT NOT NULL DEFAULT 'investor_shareholder',
  title         TEXT NOT NULL DEFAULT E'SHAREHOLDER & INVESTOR\nMEMBERSHIP',
  description   TEXT NOT NULL DEFAULT 'Become part of the future vision of AEBNG.',
  price_etb     NUMERIC(14, 2) NOT NULL DEFAULT 1500000,
  benefits      JSONB NOT NULL DEFAULT '[]'::jsonb,
  footer_note   TEXT NOT NULL DEFAULT 'Join the exclusive investor circle.',
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_investor_membership_plan_updated_at ON investor_membership_plan;
CREATE TRIGGER trg_investor_membership_plan_updated_at
  BEFORE UPDATE ON investor_membership_plan
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO investor_membership_plan (id, tier_key, title, description, price_etb, benefits, footer_note)
VALUES (
  1,
  'investor_shareholder',
  E'SHAREHOLDER & INVESTOR\nMEMBERSHIP',
  'Become part of the future vision of AEBNG.',
  1500000,
  '[
    "Shareholder Opportunity",
    "Executive-Level Access",
    "Partnership Opportunities",
    "Major Investment Projects",
    "Priority Business Deals",
    "Long-Term Growth Benefits",
    "Leadership Participation",
    "National & International Expansion Opportunities"
  ]'::jsonb,
  'Join the exclusive investor circle.'
)
ON CONFLICT (id) DO NOTHING;
