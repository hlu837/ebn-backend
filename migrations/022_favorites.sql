-- Favorites: one row per (user, asset) a visitor has hearted. Replaces
-- the client's in-memory `FavoritesController._favoriteAssetIds` mock —
-- saved listings now persist across sessions/devices instead of
-- evaporating on app restart.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gives us gen_random_uuid()

CREATE TABLE IF NOT EXISTS favorites (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  asset_id    UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- A visitor can only favorite a given asset once — toggling is
  -- add-if-missing / remove-if-present, never a duplicate row.
  UNIQUE (user_id, asset_id)
);

-- Powers "my saved listings" (WHERE user_id = ...).
CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON favorites (user_id);
-- Powers "how many people saved this asset" style lookups, and keeps the
-- ON DELETE CASCADE from assets fast.
CREATE INDEX IF NOT EXISTS idx_favorites_asset_id ON favorites (asset_id);
