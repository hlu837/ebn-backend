-- Paid agent/investor signups remain unusable until payment or approval.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS account_status TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS pending_role user_role;

ALTER TABLE users
  DROP CONSTRAINT IF EXISTS users_account_status_check;

ALTER TABLE users
  ADD CONSTRAINT users_account_status_check
  CHECK (account_status IN ('active', 'pending_payment', 'pending_approval'));

CREATE INDEX IF NOT EXISTS idx_users_account_status ON users (account_status);