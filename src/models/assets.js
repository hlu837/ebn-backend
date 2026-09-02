const { query } = require('../db');

/** Converts a DB row (snake_case) to the exact shape `Asset.fromJson` on
 *  the client already expects (see frontend/lib/models/asset.dart) — keys
 *  stay snake_case on the wire, the client maps them to camelCase itself. */
function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    price_amount: Number(row.price_amount),
    price_currency: row.price_currency,
    category_slug: row.category_slug,
    status: row.status,
    address_line: row.address_line,
    city: row.city,
    latitude: row.latitude !== null ? Number(row.latitude) : 0,
    longitude: row.longitude !== null ? Number(row.longitude) : 0,
    attributes: row.attributes,
    image_url: row.image_url,
    // Full ordered gallery for the detail screen's carousel. Falls back to
    // a one-item array built from image_url for any row that somehow has
    // no image_urls yet (belt-and-suspenders alongside the migration
    // backfill — e.g. a row inserted directly against an older schema).
    image_urls:
      Array.isArray(row.image_urls) && row.image_urls.length
        ? row.image_urls
        : row.image_url
        ? [row.image_url]
        : [],
    posted_label: row.posted_label,
    broker_id: row.broker_id,
    rating: row.rating !== null ? Number(row.rating) : null,
    review_count: row.review_count,
    roi_percent: row.roi_percent !== null ? Number(row.roi_percent) : null,
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}

/**
 * Listing feed with optional filters — powers the visitor's Top Picks
 * grid, category tabs, and search bar.
 *
 * @param {Object} opts
 * @param {string} [opts.category] - category_slug, exact match
 * @param {string} [opts.city] - city, exact match
 * @param {string} [opts.status] - defaults to only 'active' listings;
 *   pass explicitly to include drafts/sold/etc (e.g. for an Admin view),
 *   or pass 'all' to skip the status filter entirely (every status).
 * @param {string} [opts.q] - free-text search against title (ILIKE)
 * @param {string} [opts.brokerId] - only this broker's listings
 * @param {number} [opts.limit] - defaults to 60
 */
function list({ category, city, status, q, brokerId, limit } = {}) {
  const conditions = [];
  const params = [];

  if (status !== 'all') {
    conditions.push(`status = $${params.push(status || 'active')}::asset_status`);
  }
  if (category) conditions.push(`category_slug = $${params.push(category)}`);
  if (city) conditions.push(`city = $${params.push(city)}`);
  if (brokerId) conditions.push(`broker_id = $${params.push(brokerId)}`);
  if (q) conditions.push(`title ILIKE $${params.push(`%${q}%`)}`);

  const cappedLimit = Math.min(Number(limit) || 60, 200);
  params.push(cappedLimit);
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

  return query(
    `SELECT * FROM assets
     ${where}
     ORDER BY created_at DESC
     LIMIT $${params.length}`,
    params
  ).then((r) => r.rows);
}

function findById(id) {
  return query(`SELECT * FROM assets WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

/** Every listing by a given broker, any status — used on the broker's
 *  own profile page (visitor-facing "their listings" list). */
function listByBroker(brokerId) {
  return query(
    `SELECT * FROM assets WHERE broker_id = $1 ORDER BY created_at DESC`,
    [brokerId]
  ).then((r) => r.rows);
}

function create({
  title,
  description,
  priceAmount,
  priceCurrency,
  categorySlug,
  status,
  addressLine,
  city,
  latitude,
  longitude,
  attributes,
  imageUrl,
  imageUrls,
  postedLabel,
  brokerId,
  rating,
  reviewCount,
  roiPercent,
}) {
  // `imageUrls` is the full gallery; `imageUrl` is the cover photo shown on
  // listing cards. If only one of the two was supplied, derive the other
  // so they never disagree (card always shows imageUrls[0]).
  const gallery = Array.isArray(imageUrls) ? imageUrls.filter(Boolean) : [];
  const cover = imageUrl || gallery[0] || null;
  const resolvedGallery = gallery.length ? gallery : cover ? [cover] : [];

  return query(
    `INSERT INTO assets (
       title, description, price_amount, price_currency, category_slug, status,
       address_line, city, latitude, longitude, attributes, image_url,
       image_urls, posted_label, broker_id, rating, review_count, roi_percent
     )
     VALUES ($1, $2, $3, $4, $5, $6::asset_status, $7, $8, $9, $10, $11::jsonb, $12, $13::jsonb, $14, $15, $16, $17, $18)
     RETURNING *`,
    [
      title,
      description || null,
      priceAmount,
      priceCurrency || 'ETB',
      categorySlug,
      status || 'active',
      addressLine || null,
      city || null,
      latitude || 0,
      longitude || 0,
      JSON.stringify(attributes || {}),
      cover,
      JSON.stringify(resolvedGallery),
      postedLabel || null,
      brokerId || null,
      rating ?? null,
      reviewCount ?? null,
      roiPercent ?? null,
    ]
  ).then((r) => r.rows[0]);
}

/** Whitelisted patchable columns and how each incoming (camelCase) body
 *  key maps to a column + SQL cast. Only keys actually present in the
 *  patch are touched — this is a partial update, not a full replace. */
const PATCHABLE_FIELDS = {
  title: { column: 'title', cast: '' },
  description: { column: 'description', cast: '' },
  priceAmount: { column: 'price_amount', cast: '' },
  priceCurrency: { column: 'price_currency', cast: '' },
  categorySlug: { column: 'category_slug', cast: '' },
  status: { column: 'status', cast: '::asset_status' },
  addressLine: { column: 'address_line', cast: '' },
  city: { column: 'city', cast: '' },
  latitude: { column: 'latitude', cast: '' },
  longitude: { column: 'longitude', cast: '' },
  attributes: { column: 'attributes', cast: '::jsonb', serialize: (v) => JSON.stringify(v ?? {}) },
  imageUrl: { column: 'image_url', cast: '' },
  imageUrls: {
    column: 'image_urls',
    cast: '::jsonb',
    serialize: (v) => JSON.stringify(Array.isArray(v) ? v.filter(Boolean) : []),
  },
  postedLabel: { column: 'posted_label', cast: '' },
  brokerId: { column: 'broker_id', cast: '' },
  rating: { column: 'rating', cast: '' },
  reviewCount: { column: 'review_count', cast: '' },
  roiPercent: { column: 'roi_percent', cast: '' },
};

/**
 * Partial update — e.g. Admin editing a listing's title/price/address, or
 * changing its status (active -> sold/archived/etc). Only columns present
 * as keys on `patch` are touched; anything else on the row is left alone.
 *
 * @param {string} id
 * @param {Object} patch - camelCase keys, same shape as `create`'s input
 * @returns {Promise<Object|null>} the updated row, or null if `id` doesn't exist
 */
function update(id, patch = {}) {
  const sets = [];
  const params = [];

  for (const [key, value] of Object.entries(patch)) {
    const field = PATCHABLE_FIELDS[key];
    if (!field || value === undefined) continue;
    const serialized = field.serialize ? field.serialize(value) : value;
    sets.push(`${field.column} = $${params.push(serialized)}${field.cast}`);
  }

  if (!sets.length) return findById(id);

  params.push(id);
  return query(
    `UPDATE assets SET ${sets.join(', ')} WHERE id = $${params.length} RETURNING *`,
    params
  ).then((r) => r.rows[0] || null);
}

/**
 * Hard-deletes a listing (e.g. Admin removing a bad/duplicate entry).
 * There's no FK from sell_requests.listed_asset_id -> assets.id, so this
 * is safe to do without touching anything else.
 *
 * @returns {Promise<Object|null>} the deleted row, or null if it didn't exist
 */
function remove(id) {
  return query(`DELETE FROM assets WHERE id = $1 RETURNING *`, [id]).then((r) => r.rows[0] || null);
}

module.exports = {
  toPublic,
  list,
  findById,
  listByBroker,
  create,
  update,
  remove,
};
