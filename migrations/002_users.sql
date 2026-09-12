-- Users: one row per registered account (sign up / sign in).
-- Backs the app's role-based smart router — the same email/password form
-- is used by every role, and the saved `role` decides where login lands.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS citext;   -- case-insensitive email column

DO $$ BEGIN
  CREATE TYPE user_role AS ENUM (
    'user',        -- "Visitor" in the UI
    'affiliater',
    'agent',        -- Agent / Broker
    'investor',
    'admin'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS users (
  id                                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  full_name                              TEXT NOT NULL,
  email                                  CITEXT NOT NULL UNIQUE,
  password_hash                          TEXT NOT NULL,

  role                                   user_role NOT NULL DEFAULT 'user',

  phone                                  TEXT,
  agency_or_license                      TEXT,      -- Agent / Broker only
  interested_in_fractional_investing     BOOLEAN NOT NULL DEFAULT false, -- Investor only
  referral_code                          TEXT,      -- who gets affiliate credit for this signup

  created_at                             TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);

-- Keep updated_at current on every UPDATE.
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
