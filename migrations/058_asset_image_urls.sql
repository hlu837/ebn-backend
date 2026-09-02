-- Adds gallery support to `assets`. Previously a listing could only ever
-- carry a single `image_url`, so the detail screen and listing cards were
-- both stuck showing one photo even when a seller/agent uploaded several
-- during the sell-request flow (`_machineryMedia` etc. already collect
-- multiple photos client-side — they just had nowhere to go on approval).
--
-- `image_url` is kept as-is: it's still the "cover" photo and is exactly
-- what listing cards in feeds/grids should keep showing (first image
-- only), per product decision. `image_urls` is the full ordered gallery,
-- consumed only by the detail screen's horizontally-scrollable carousel.

ALTER TABLE assets
  ADD COLUMN IF NOT EXISTS image_urls JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Backfill: every existing listing's single photo becomes a one-item
-- gallery, so `image_urls[0] == image_url` for all pre-existing rows and
-- the detail screen has something to render immediately.
UPDATE assets
SET image_urls = jsonb_build_array(image_url)
WHERE image_url IS NOT NULL
  AND image_urls = '[]'::jsonb;
