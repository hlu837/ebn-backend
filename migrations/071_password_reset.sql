-- Supports the "Forgot password" flow: a short-lived, single-use reset
-- code is emailed to the user, and we only ever store its SHA-256 hash
-- (never the raw code) so a leaked DB backup can't be used to reset
-- accounts directly.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS reset_password_token_hash TEXT,
  ADD COLUMN IF NOT EXISTS reset_password_expires_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_users_reset_password_token_hash
  ON users (reset_password_token_hash)
  WHERE reset_password_token_hash IS NOT NULL;
