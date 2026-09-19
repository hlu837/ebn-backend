-- Supports "verify your email" on signup: a short-lived, single-use code
-- is emailed to the user, and we only ever store its SHA-256 hash (same
-- pattern as migrations/071_password_reset.sql). email_verified starts
-- false for every new account and flips to true once the code is
-- confirmed via POST /api/auth/verify-email.
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS email_verify_token_hash TEXT,
  ADD COLUMN IF NOT EXISTS email_verify_expires_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_users_email_verify_token_hash
  ON users (email_verify_token_hash)
  WHERE email_verify_token_hash IS NOT NULL;
