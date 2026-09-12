-- Company ads shown as a horizontally-scrollable carousel on the guest
-- landing page (replaces the old static "Order Verified Inspection" promo
-- card). Admin authors each ad with a title, description, image, and an
-- optional link: if link_url is set, tapping the card should navigate
-- there; if it's null, the client should just zoom the image instead.

CREATE TABLE IF NOT EXISTS company_ads (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  title        TEXT NOT NULL,
  description  TEXT NOT NULL DEFAULT '',
  image_url    TEXT NOT NULL,
  link_url     TEXT,

  sort_order   INTEGER NOT NULL DEFAULT 0,
  is_active    BOOLEAN NOT NULL DEFAULT true,

  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_company_ads_active_sort
  ON company_ads (is_active, sort_order ASC, created_at DESC);
