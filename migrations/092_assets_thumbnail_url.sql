-- Cached, heavily-downscaled copy of `image_url` used ONLY by the
-- browse-feed list endpoint (GET /api/assets — Top Properties rails,
-- category grids, search, favorites, etc across every role). Those
-- responses can carry dozens/hundreds of listings at once, and
-- `image_url` is a full base64-encoded photo (see media_encoding.dart /
-- pickAndEncodeImage), so returning it per-row for every listing in a
-- list made the response many MB and slow/timed out on mobile data.
--
-- Generated server-side (see src/utils/thumbnail.js, using `sharp`)
-- whenever a row's `image_url` is created or changed — see
-- models/assets.js `create`/`update`. Existing rows are backfilled by
-- `scripts/backfillAssetThumbnails.js` (run once after this migration).
--
-- Detail views and the agent's own broker-scoped listing endpoints
-- (GET /api/assets/:id, GET /api/assets/broker/:brokerId) are NOT
-- affected — they keep returning the full-resolution `image_url` /
-- `image_urls` via the existing `toPublic`, since those feed the
-- image-gallery carousel and the "edit my listing" flow (which
-- resubmits whatever image data it was handed — shrinking it there
-- would silently degrade an agent's photos on every unrelated edit).

ALTER TABLE assets
  ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;
