const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    userId: row.user_id,
    avatarUrl: row.avatar_url,
    bio: row.bio,
    city: row.city,
    specialties: row.specialties || [],
    boosted: row.boosted,
    boostedUntil: row.boosted_until,
    updatedAt: row.updated_at,
  };
}

function reviewToPublic(row) {
  return {
    id: row.id,
    reviewerName: row.reviewer_name,
    stars: row.stars,
    quote: row.quote,
    createdAt: row.created_at,
  };
}

async function getOrCreate(userId) {
  const existing = await query(`SELECT * FROM agent_profiles WHERE user_id = $1`, [userId]);
  if (existing.rows[0]) return existing.rows[0];
  const created = await query(
    `INSERT INTO agent_profiles (user_id) VALUES ($1)
     ON CONFLICT (user_id) DO UPDATE SET user_id = EXCLUDED.user_id
     RETURNING *`,
    [userId]
  );
  return created.rows[0];
}

function update(userId, { avatarUrl, bio, city, specialties }) {
  return query(
    `INSERT INTO agent_profiles (user_id, avatar_url, bio, city, specialties)
    VALUES ($1, $2, COALESCE($3, ''), COALESCE($4, ''), COALESCE($5::text[], '{}'::text[]))
     ON CONFLICT (user_id) DO UPDATE
       SET avatar_url = COALESCE($2, agent_profiles.avatar_url),
           bio = COALESCE($3, agent_profiles.bio),
           city = COALESCE($4, agent_profiles.city),
           specialties = COALESCE($5::text[], agent_profiles.specialties)
     RETURNING *`,
    [userId, avatarUrl ?? null, bio ?? null, city ?? null, specialties ?? null]
  ).then((r) => r.rows[0]);
}

function boost(userId, days = 7) {
  return query(
    `INSERT INTO agent_profiles (user_id, boosted, boosted_until)
     VALUES ($1, true, now() + ($2 || ' days')::interval)
     ON CONFLICT (user_id) DO UPDATE
       SET boosted = true, boosted_until = now() + ($2 || ' days')::interval
     RETURNING *`,
    [userId, String(days)]
  ).then((r) => r.rows[0]);
}

async function reviewSummary(agentId) {
  const { rows } = await query(
    `SELECT COUNT(*)::int AS review_count, COALESCE(AVG(stars), 0) AS avg_rating
     FROM agent_reviews WHERE agent_id = $1`,
    [agentId]
  );
  return { reviewCount: rows[0].review_count, avgRating: Number(rows[0].avg_rating) };
}

function listReviews(agentId) {
  return query(`SELECT * FROM agent_reviews WHERE agent_id = $1 ORDER BY created_at DESC`, [agentId]).then(
    (r) => r.rows.map(reviewToPublic)
  );
}

function addReview(agentId, { reviewerName, stars, quote }) {
  return query(
    `INSERT INTO agent_reviews (agent_id, reviewer_name, stars, quote) VALUES ($1, $2, $3, $4) RETURNING *`,
    [agentId, reviewerName, stars, quote]
  ).then((r) => reviewToPublic(r.rows[0]));
}

/**
 * The Broker Network directory: every agent, joined with their profile and
 * rating, optionally filtered by specialty/city/search text and excluding
 * one user (the caller, so agents don't see themselves in their own list).
 */
async function listDirectory({ specialty, city, search, excludeUserId, userId } = {}) {
  const conds = [`u.role = 'agent'`];
  const vals = [];
  let i = 1;

  if (userId) {
    conds.push(`u.id::text = $${i++}`);
    vals.push(userId);
  }
  if (excludeUserId) {
    conds.push(`u.id != $${i++}`);
    vals.push(excludeUserId);
  }
  if (specialty) {
    conds.push(`$${i++} = ANY(COALESCE(p.specialties, '{}'))`);
    vals.push(specialty);
  }
  if (city) {
    conds.push(`p.city ILIKE $${i++}`);
    vals.push(city);
  }
  if (search) {
    conds.push(`(u.full_name ILIKE $${i} OR u.agency_or_license ILIKE $${i} OR p.city ILIKE $${i})`);
    vals.push(`%${search}%`);
    i++;
  }

  const { rows } = await query(
    `SELECT
       u.id, u.full_name, u.agency_or_license, u.phone,
       u.agent_latitude, u.agent_longitude,
      p.avatar_url, p.bio, p.city, p.specialties, p.boosted,
       COALESCE(r.review_count, 0) AS review_count,
       COALESCE(r.avg_rating, 0) AS avg_rating,
       COALESCE(m.tier, 'bronze') AS tier
     FROM users u
     LEFT JOIN agent_profiles p ON p.user_id = u.id
     LEFT JOIN agent_memberships m ON m.user_id = u.id
     LEFT JOIN (
       SELECT agent_id, COUNT(*)::int AS review_count, AVG(stars) AS avg_rating
       FROM agent_reviews GROUP BY agent_id
     ) r ON r.agent_id = u.id
     WHERE ${conds.join(' AND ')}
     ORDER BY p.boosted DESC NULLS LAST, avg_rating DESC NULLS LAST, u.full_name ASC`,
    vals
  );

  return rows.map((row) => ({
    userId: row.id,
    name: row.full_name,
    company: row.agency_or_license,
    avatarUrl: row.avatar_url,
    phone: row.phone,
    bio: row.bio || '',
    city: row.city || '',
    specialties: row.specialties || [],
    boosted: row.boosted || false,
    reviewCount: row.review_count,
    rating: Number(row.avg_rating),
    tier: row.tier,
    // null when the agent hasn't set a location yet — callers that plot
    // pins (the map) should skip anyone without one.
    latitude: row.agent_latitude !== null ? Number(row.agent_latitude) : null,
    longitude: row.agent_longitude !== null ? Number(row.agent_longitude) : null,
  }));
}

module.exports = {
  toPublic,
  getOrCreate,
  update,
  boost,
  reviewSummary,
  listReviews,
  addReview,
  listDirectory,
};
