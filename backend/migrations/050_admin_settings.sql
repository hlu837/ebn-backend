-- Admin > Settings: Categories & Pricing, Cities, App Content (FAQ / About
-- Us / Features), and General app settings. Powers the previously-all-
-- placeholder Admin Settings screen.

-- ── Categories & Pricing ────────────────────────────────────────────────
-- Listing categories shown to customers, plus the fee charged per
-- submission. Seeded from the slugs already hardcoded in the Flutter
-- AssetCategorySlug enum so existing listings keep resolving.
CREATE TABLE IF NOT EXISTS categories (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              TEXT NOT NULL UNIQUE,
  label             TEXT NOT NULL,
  listing_fee_cents INTEGER NOT NULL DEFAULT 0,
  sort_order        INTEGER NOT NULL DEFAULT 0,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_categories_updated_at ON categories;
CREATE TRIGGER trg_categories_updated_at
  BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO categories (slug, label, sort_order) VALUES
  ('apartments', 'Apartments', 0),
  ('vehicles', 'Vehicles', 1),
  ('condominium', 'Condominium', 2),
  ('machinery', 'Machinery', 3),
  ('house', 'House', 4),
  ('warehouse', 'Warehouse', 5),
  ('land', 'Land', 6),
  ('building', 'Building', 7),
  ('construction-materials', 'Construction Materials', 8),
  ('others', 'Others', 9)
ON CONFLICT (slug) DO NOTHING;

-- ── Cities ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cities (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  is_live     BOOLEAN NOT NULL DEFAULT true, -- false = "coming soon"
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_cities_updated_at ON cities;
CREATE TRIGGER trg_cities_updated_at
  BEFORE UPDATE ON cities
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO cities (name, is_live, sort_order) VALUES
  ('Addis Ababa', true, 0)
ON CONFLICT (name) DO NOTHING;

-- ── App Content: FAQ ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS faq_entries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question    TEXT NOT NULL,
  answer      TEXT NOT NULL,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_faq_entries_updated_at ON faq_entries;
CREATE TRIGGER trg_faq_entries_updated_at
  BEFORE UPDATE ON faq_entries
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── App Content: static pages (About Us / Features / How It Works) ─────
-- Simple key/value store so new static pages don't need a migration.
CREATE TABLE IF NOT EXISTS app_content_pages (
  page_key    TEXT PRIMARY KEY, -- 'about_us' | 'features'
  title       TEXT NOT NULL,
  body        TEXT NOT NULL DEFAULT '',
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_app_content_pages_updated_at ON app_content_pages;
CREATE TRIGGER trg_app_content_pages_updated_at
  BEFORE UPDATE ON app_content_pages
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO app_content_pages (page_key, title, body) VALUES
  ('about_us', 'About Us', ''),
  ('features', 'Platform Features', '')
ON CONFLICT (page_key) DO NOTHING;

-- ── General settings ────────────────────────────────────────────────────
-- Single row (id fixed to 1) — app name/logo and the support contact
-- details shown to users.
CREATE TABLE IF NOT EXISTS general_settings (
  id              SMALLINT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  app_name        TEXT NOT NULL DEFAULT 'Onsite',
  logo_url        TEXT,
  support_email   TEXT,
  support_phone   TEXT,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_general_settings_updated_at ON general_settings;
CREATE TRIGGER trg_general_settings_updated_at
  BEFORE UPDATE ON general_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO general_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
