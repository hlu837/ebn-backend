-- Phase 2 of the rental-payment flow: banks the platform has an
-- agreement with (admin-managed whitelist), and the actual receiving
-- bank accounts property owners register against those banks. Together
-- these back the tenant-facing "pick a bank account to transfer into"
-- payment screen (see routes/ownerBankAccounts.js and
-- routes/rentalAgreements.js GET /:id/bank-accounts).
--
-- Deliberately NOT modeled like agent_settings/affiliate_settings' bank
-- fields, which store only bank_account_last4 -- those are payout
-- accounts the platform pays money INTO and never need to be shown to
-- anyone else. This is the opposite: a receiving account a *tenant* is
-- meant to read the full number from and transfer into, so the full
-- account number is stored and returned on purpose, only to the narrow
-- audience allowed to see it (enforced at the route level, not here).

CREATE TABLE IF NOT EXISTS platform_banks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE, -- e.g. "Commercial Bank of Ethiopia"
  short_code  TEXT,                 -- e.g. "CBE" -- display only
  is_active   BOOLEAN NOT NULL DEFAULT true, -- false = no longer accepted; existing owner accounts on it are hidden from tenants, not deleted
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_platform_banks_updated_at ON platform_banks;
CREATE TRIGGER trg_platform_banks_updated_at
  BEFORE UPDATE ON platform_banks
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- A handful of real Ethiopian banks to seed the whitelist with so the
-- admin screen and owner "add account" dropdown aren't empty on a fresh
-- DB. Admin can deactivate/add more from Admin > Settings.
INSERT INTO platform_banks (name, short_code, sort_order) VALUES
  ('Commercial Bank of Ethiopia', 'CBE', 0),
  ('Bank of Abyssinia', 'BOA', 1),
  ('Dashen Bank', 'Dashen', 2),
  ('Awash Bank', 'Awash', 3),
  ('Telebirr', 'Telebirr', 4)
ON CONFLICT (name) DO NOTHING;

CREATE TABLE IF NOT EXISTS owner_bank_accounts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  bank_id         UUID NOT NULL REFERENCES platform_banks(id),

  -- The name that should show up on the payment screen next to the
  -- number -- typically the owner's company name (e.g. "Noh Real
  -- Estate"), not necessarily the individual's own name.
  account_name    TEXT NOT NULL,
  account_number  TEXT NOT NULL,

  -- Which account gets pre-selected when an owner has more than one.
  -- Enforced as "only one true per owner" in application code
  -- (ownerBankAccounts.js), not a DB constraint.
  is_default      BOOLEAN NOT NULL DEFAULT false,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_owner_bank_accounts_owner_id ON owner_bank_accounts (owner_id);

DROP TRIGGER IF EXISTS trg_owner_bank_accounts_updated_at ON owner_bank_accounts;
CREATE TRIGGER trg_owner_bank_accounts_updated_at
  BEFORE UPDATE ON owner_bank_accounts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
