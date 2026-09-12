const { query } = require('../db');
const { toPublic: assetToPublic } = require('./assets');

/**
 * Every asset a user has favorited, newest-saved first — the exact wire
 * shape `Asset.fromJson` on the client already expects (same as
 * `GET /api/assets`), so the Favorites screen can render these directly
 * without a second lookup against the full asset feed.
 *
 * @param {string} userId
 * @returns {Promise<Array<Object>>}
 */
function listAssetsForUser(userId) {
  return query(
    `SELECT a.*
     FROM favorites f
     JOIN assets a ON a.id = f.asset_id
     WHERE f.user_id = $1
     ORDER BY f.created_at DESC`,
    [userId]
  ).then((r) => r.rows.map(assetToPublic));
}

/**
 * Just the favorited asset ids for a user — lightweight, used to hydrate
 * `FavoritesController`'s local saved-state cache on the client (so every
 * heart icon across the app, not just the Favorites screen, knows what's
 * already saved) without pulling full asset payloads.
 *
 * @param {string} userId
 * @returns {Promise<string[]>}
 */
function listAssetIdsForUser(userId) {
  return query(`SELECT asset_id FROM favorites WHERE user_id = $1`, [userId]).then((r) =>
    r.rows.map((row) => row.asset_id)
  );
}

/**
 * Saves an asset for a user. Idempotent — favoriting something already
 * saved just returns the existing row instead of erroring.
 *
 * @returns {Promise<Object>} the favorite row
 */
function add(userId, assetId) {
  return query(
    `INSERT INTO favorites (user_id, asset_id)
     VALUES ($1, $2)
     ON CONFLICT (user_id, asset_id) DO UPDATE SET user_id = EXCLUDED.user_id
     RETURNING *`,
    [userId, assetId]
  ).then((r) => r.rows[0]);
}

/**
 * Un-saves an asset for a user. A no-op (not an error) if it wasn't
 * saved in the first place.
 *
 * @returns {Promise<boolean>} whether a row was actually removed
 */
function remove(userId, assetId) {
  return query(`DELETE FROM favorites WHERE user_id = $1 AND asset_id = $2 RETURNING id`, [
    userId,
    assetId,
  ]).then((r) => r.rowCount > 0);
}

module.exports = {
  listAssetsForUser,
  listAssetIdsForUser,
  add,
  remove,
};
