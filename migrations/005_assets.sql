-- Assets: one row per live/draft listing across every category (house,
-- apartments, vehicles, machinery, land, etc). Replaces the client's
-- hard-coded `mock_asset_data.dart` — the Flutter `Asset.fromJson` factory
-- was already written against exactly this wire shape, so no client-side
-- parsing changes are needed once this is live.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()

DO $$ BEGIN
  CREATE TYPE asset_status AS ENUM (
    'draft',
    'active',
    'under_inspection',
    'sold',
    'archived'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS assets (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  title             TEXT NOT NULL,
  price_amount      NUMERIC(14, 2) NOT NULL,
  price_currency    TEXT NOT NULL DEFAULT 'ETB',

  -- Free text (not an enum) so new categories never need a migration —
  -- same rationale as `sell_requests.category`. The client's
  -- AssetCategorySlugX.fromSlug() falls back to 'apartments' on anything
  -- it doesn't recognize.
  category_slug     TEXT NOT NULL,
  status            asset_status NOT NULL DEFAULT 'active',

  address_line      TEXT,
  city              TEXT,
  latitude          DOUBLE PRECISION NOT NULL DEFAULT 0,
  longitude         DOUBLE PRECISION NOT NULL DEFAULT 0,

  -- Category-specific spec fields (bedrooms/bathrooms/sqft, year/make/model,
  -- etc) — shape depends on category_slug, same JSONB-per-category pattern
  -- as sell_requests' house_details/vehicle_details/machinery_details.
  attributes        JSONB NOT NULL DEFAULT '{}'::jsonb,

  image_url         TEXT,
  posted_label      TEXT, -- e.g. "New · 1 hour ago" — cosmetic, set at insert time

  broker_id         TEXT, -- matches Broker.id in mock_brokers.dart for now

  rating            NUMERIC(2, 1),
  review_count      INT,
  roi_percent       NUMERIC(5, 2),

  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_assets_category_slug ON assets (category_slug);
CREATE INDEX IF NOT EXISTS idx_assets_status ON assets (status);
CREATE INDEX IF NOT EXISTS idx_assets_city ON assets (city);
CREATE INDEX IF NOT EXISTS idx_assets_broker_id ON assets (broker_id);

-- Keep updated_at current on every UPDATE (function already defined by
-- 001_init.sql, but CREATE OR REPLACE here too in case migrations ever
-- run against a fresh DB in a different order).
CREATE OR REPLACE FUNCTION set_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_assets_updated_at ON assets;
CREATE TRIGGER trg_assets_updated_at
  BEFORE UPDATE ON assets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
