const { query } = require('../db');

const CATEGORIES = ['electrician', 'plumber', 'carpenter', 'mechanic', 'appliance_technician', 'other'];

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    category: row.category,
    phone: row.phone,
    city: row.city,
    latitude: row.latitude !== null && row.latitude !== undefined ? Number(row.latitude) : null,
    longitude: row.longitude !== null && row.longitude !== undefined ? Number(row.longitude) : null,
    rateCents: row.rate_cents,
    rating: row.rating !== null && row.rating !== undefined ? Number(row.rating) : null,
    photoUrl: row.photo_url,
    isActive: row.is_active,
    userId: row.user_id || null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/**
 * Admin listing (all providers, active or not) and the tenant-facing
 * browse (activeOnly: true, optionally filtered by category/city — same
 * filter shape the "browse specialists" screen offers).
 */
function list({ activeOnly = false, category, city } = {}) {
  const params = [];
  const where = [];
  if (activeOnly) where.push('is_active = true');
  if (category) {
    params.push(category);
    where.push(`category = $${params.length}`);
  }
  if (city) {
    params.push(city);
    where.push(`city = $${params.length}`);
  }
  const sql = `SELECT * FROM service_providers
    ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
    ORDER BY rating DESC NULLS LAST, name ASC`;
  return query(sql, params).then((r) => r.rows);
}

function findById(id) {
  return query(`SELECT * FROM service_providers WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

/** The Expert profile linked to this Affiliater's account, if any (see 086's migration). */
function findByUserId(userId) {
  return query(`SELECT * FROM service_providers WHERE user_id = $1`, [userId]).then((r) => r.rows[0] || null);
}

function _validateCategory(category) {
  if (!CATEGORIES.includes(category)) {
    throw Object.assign(new Error('Not a recognized specialist category.'), { status: 400 });
  }
}

async function create({ name, category, phone, city, latitude, longitude, rateCents, rating, photoUrl, isActive, userId }) {
  _validateCategory(category);
  if (!name || !String(name).trim()) throw Object.assign(new Error('Name is required.'), { status: 400 });
  if (!phone || !String(phone).trim()) throw Object.assign(new Error('Phone is required.'), { status: 400 });
  if (!city || !String(city).trim()) throw Object.assign(new Error('City is required.'), { status: 400 });

  return query(
    `INSERT INTO service_providers
       (name, category, phone, city, latitude, longitude, rate_cents, rating, photo_url, is_active, user_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
     RETURNING *`,
    [
      String(name).trim(),
      category,
      String(phone).trim(),
      String(city).trim(),
      latitude ?? null,
      longitude ?? null,
      rateCents ?? 0,
      rating ?? null,
      photoUrl ?? null,
      isActive ?? true,
      userId ?? null,
    ]
  ).then((r) => r.rows[0]);
}

/**
 * Self-service version of [create] for the Expert-inside-Affiliate flow
 * (POST /api/affiliates/me/expert-profile). Always starts inactive --
 * same "admin flips is_active" gate the admin-entered directory already
 * uses, just repurposed here as the approval step for self-signup, so no
 * separate approval table is needed (see 028_role_upgrade_requests.sql
 * for the pattern this deliberately avoids reusing).
 */
async function createSelf(userId, { name, category, phone, city, latitude, longitude, rateCents }) {
  const existing = await findByUserId(userId);
  if (existing) {
    throw Object.assign(new Error('You already have an Expert profile.'), { status: 409 });
  }
  return create({
    name,
    category,
    phone,
    city,
    latitude,
    longitude,
    rateCents,
    isActive: false,
    userId,
  });
}

/**
 * Self-service edit of the caller's own Expert profile. Deliberately
 * excludes isActive/rating/photoUrl -- activation stays admin-only (same
 * as the admin-entered directory), rating is earned not self-reported.
 */
async function updateSelf(userId, fields) {
  const existing = await findByUserId(userId);
  if (!existing) {
    throw Object.assign(new Error('No Expert profile yet -- create one first.'), { status: 404 });
  }
  const { name, category, phone, city, latitude, longitude, rateCents } = fields;
  return update(existing.id, { name, category, phone, city, latitude, longitude, rateCents });
}

function update(id, fields) {
  if (fields.category !== undefined) _validateCategory(fields.category);

  const map = {
    name: 'name',
    category: 'category',
    phone: 'phone',
    city: 'city',
    latitude: 'latitude',
    longitude: 'longitude',
    rateCents: 'rate_cents',
    rating: 'rating',
    photoUrl: 'photo_url',
    isActive: 'is_active',
    userId: 'user_id',
  };
  const sets = [];
  const vals = [];
  let i = 1;
  for (const [key, col] of Object.entries(map)) {
    if (fields[key] !== undefined) {
      sets.push(`${col} = $${i++}`);
      vals.push(fields[key]);
    }
  }
  if (!sets.length) return findById(id);
  vals.push(id);
  return query(`UPDATE service_providers SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`, vals).then(
    (r) => r.rows[0] || null
  );
}

function remove(id) {
  return query(`DELETE FROM service_providers WHERE id = $1 RETURNING *`, [id]).then((r) => r.rows[0] || null);
}

module.exports = { toPublic, list, findById, findByUserId, create, createSelf, updateSelf, update, remove, CATEGORIES };
