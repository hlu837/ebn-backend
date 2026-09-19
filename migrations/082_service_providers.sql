-- Phase 3 of the maintenance-request workflow (see 080_maintenance_requests.sql
-- for Phase 1/2). Admin-managed directory of local service professionals —
-- same "admin CRUD, tenant-facing browse" split as cities/categories
-- (050_admin_settings.sql): admin routes live in adminSettings.js, the
-- tenant-facing browse/search lives in its own serviceProviders.js router.
--
-- Providers are standalone rows, not `users` — most specialists in this
-- market won't have (or need) a platform login for Phase 3, which is
-- browse-only. If a provider ever needs their own login (e.g. to manage
-- their own profile or, later, to receive payouts in Phase 5/6), add a
-- nullable `user_id UUID REFERENCES users(id)` column then rather than
-- forcing every provider through signup now.

DO $$ BEGIN
  CREATE TYPE service_provider_category AS ENUM (
    'electrician',
    'plumber',
    'carpenter',
    'mechanic',
    'appliance_technician',
    'other'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS service_providers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  name          TEXT NOT NULL,
  category      service_provider_category NOT NULL,
  phone         TEXT NOT NULL,
  city          TEXT NOT NULL,
  latitude      DOUBLE PRECISION,
  longitude     DOUBLE PRECISION,

  rate_cents    INTEGER NOT NULL DEFAULT 0,
  rating        NUMERIC(2,1),
  photo_url     TEXT,

  is_active     BOOLEAN NOT NULL DEFAULT true,

  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_service_providers_category ON service_providers (category);
CREATE INDEX IF NOT EXISTS idx_service_providers_city ON service_providers (city);
CREATE INDEX IF NOT EXISTS idx_service_providers_is_active ON service_providers (is_active);

DROP TRIGGER IF EXISTS trg_service_providers_updated_at ON service_providers;
CREATE TRIGGER trg_service_providers_updated_at
  BEFORE UPDATE ON service_providers
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
