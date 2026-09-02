const { query } = require('../db');

/** Public shape returned to clients — never leaks password_hash. */
function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    role: row.role,
    phone: row.phone,
    agencyOrLicense: row.agency_or_license,
    interestedInFractionalInvesting: row.interested_in_fractional_investing,
    referralCode: row.referral_code,
    createdAt: row.created_at,
    isSuspended: row.is_suspended,
    suspendedAt: row.suspended_at,
    agentLatitude: row.agent_latitude,
    agentLongitude: row.agent_longitude,
    agentLocationUpdatedAt: row.agent_location_updated_at,
    accountStatus: row.account_status,
    pendingRole: row.pending_role,
  };
}

function create({
  fullName,
  email,
  passwordHash,
  role,
  phone,
  agencyOrLicense,
  interestedInFractionalInvesting,
  referralCode,
}) {
  return query(
    `INSERT INTO users (
       full_name, email, password_hash, role,
       phone, agency_or_license, interested_in_fractional_investing, referral_code,
       account_status
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'active')
     RETURNING *`,
    [
      fullName,
      email,
      passwordHash,
      role,
      phone || null,
      agencyOrLicense || null,
      Boolean(interestedInFractionalInvesting),
      referralCode || null,
    ]
  ).then((r) => r.rows[0]);
}

/**
 * Creates a user whose account is awaiting payment before activation.
 * The row is inserted immediately so the email is reserved in the DB and
 * cannot be re-used for a plain visitor signup. Payment completion calls
 * activatePendingRole() to set role = pendingRole and account_status = 'active'.
 */
function createPending({
  fullName,
  email,
  passwordHash,
  pendingRole,
  phone,
  agencyOrLicense,
  interestedInFractionalInvesting,
  referralCode,
}) {
  return query(
    `INSERT INTO users (
       full_name, email, password_hash, role,
       phone, agency_or_license, interested_in_fractional_investing, referral_code,
       account_status, pending_role
     )
     VALUES ($1, $2, $3, 'user', $4, $5, $6, $7, 'pending_payment', $8)
     RETURNING *`,
    [
      fullName,
      email,
      passwordHash,
      phone || null,
      agencyOrLicense || null,
      Boolean(interestedInFractionalInvesting),
      referralCode || null,
      pendingRole,
    ]
  ).then((r) => r.rows[0]);
}


/** Looks up by email — CITEXT column, so this is already case-insensitive. */
function findByEmail(email) {
  return query(`SELECT * FROM users WHERE email = $1`, [email]).then((r) => r.rows[0] || null);
}

function findById(id) {
  return query(`SELECT * FROM users WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

/**
 * Admin > Users list. [role] filters to an exact `user_role`; [search]
 * matches full_name/email/phone (case-insensitive, partial). Newest
 * accounts first, paginated with [limit]/[offset].
 */
function listAll({ role, search, limit = 20, offset = 0 } = {}) {
  const conditions = [];
  const params = [];

  if (role) {
    params.push(role);
    conditions.push(`role = $${params.length}`);
  }
  if (search) {
    params.push(`%${search}%`);
    const p = params.length;
    conditions.push(`(full_name ILIKE $${p} OR email ILIKE $${p} OR phone ILIKE $${p})`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  params.push(limit);
  params.push(offset);

  return query(
    `SELECT * FROM users ${where} ORDER BY created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  ).then((r) => r.rows);
}

/** Matches the same filters as [listAll], for pagination totals. */
function count({ role, search } = {}) {
  const conditions = [];
  const params = [];

  if (role) {
    params.push(role);
    conditions.push(`role = $${params.length}`);
  }
  if (search) {
    params.push(`%${search}%`);
    const p = params.length;
    conditions.push(`(full_name ILIKE $${p} OR email ILIKE $${p} OR phone ILIKE $${p})`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  return query(`SELECT COUNT(*)::int AS count FROM users ${where}`, params).then((r) => r.rows[0].count);
}

/** Admin suspend/reactivate toggle — see migrations/049_users_admin_management.sql. */
function setSuspended(id, suspended) {
  return query(
    `UPDATE users
     SET is_suspended = $2, suspended_at = CASE WHEN $2 THEN now() ELSE NULL END
     WHERE id = $1
     RETURNING *`,
    [id, Boolean(suspended)]
  ).then((r) => r.rows[0] || null);
}

/** Agent-only — records where they currently are, for nearby-request matching. */
function setAgentLocation(id, { latitude, longitude }) {
  return query(
    `UPDATE users
     SET agent_latitude = $2, agent_longitude = $3, agent_location_updated_at = now()
     WHERE id = $1 AND role = 'agent'
     RETURNING *`,
    [id, latitude, longitude]
  ).then((r) => r.rows[0] || null);
}

/**
 * Agents with a location on file, within [radiusKm] of ([latitude],
 * [longitude]), excluding [excludeAgentIds]. Nearest first. Distance via
 * the haversine formula — no PostGIS/earthdistance extension required.
 */
function findNearbyAgents({ latitude, longitude, radiusKm, excludeAgentIds = [] }) {
  return query(
    `SELECT * FROM (
       SELECT
         id, full_name, phone,
         (6371 * acos(
           LEAST(1, GREATEST(-1,
             cos(radians($1)) * cos(radians(agent_latitude)) * cos(radians(agent_longitude) - radians($2))
             + sin(radians($1)) * sin(radians(agent_latitude))
           ))
         )) AS distance_km
       FROM users
       WHERE role = 'agent' AND agent_latitude IS NOT NULL AND agent_longitude IS NOT NULL
     ) nearby
     WHERE distance_km <= $3 AND NOT (id::text = ANY($4::text[]))
     ORDER BY distance_km ASC`,
    [latitude, longitude, radiusKm, excludeAgentIds]
  ).then((r) => r.rows);
}

/**
 * Updates the caller's own editable account details (Settings screen's
 * "Account details" section). Email is intentionally not editable here —
 * it's the sign-in identity and changing it needs its own verification
 * flow, which doesn't exist yet.
 */
function updateProfile(id, { fullName, phone }) {
  return query(
    `UPDATE users
     SET full_name = COALESCE($2, full_name),
         phone = COALESCE($3, phone)
     WHERE id = $1
     RETURNING *`,
    [id, fullName ?? null, phone ?? null]
  ).then((r) => r.rows[0] || null);
}

function updatePasswordHash(id, passwordHash) {
  return query(`UPDATE users SET password_hash = $2 WHERE id = $1 RETURNING *`, [id, passwordHash]).then(
    (r) => r.rows[0] || null
  );
}

function activatePendingRole(id, role) {
  return query(
    `UPDATE users
     SET role = $2, account_status = 'active', pending_role = NULL
     WHERE id = $1 AND account_status <> 'active' AND pending_role = $2
     RETURNING *`,
    [id, role]
  ).then((r) => r.rows[0] || null);
}

function markPendingApproval(id, role) {
  return query(
    `UPDATE users
     SET account_status = 'pending_approval'
     WHERE id = $1 AND account_status = 'pending_payment' AND pending_role = $2
     RETURNING *`,
    [id, role]
  ).then((r) => r.rows[0] || null);
}

module.exports = {
  toPublic,
  create,
  createPending,
  findByEmail,
  findById,
  listAll,
  count,
  setSuspended,
  setAgentLocation,
  findNearbyAgents,
  updateProfile,
  updatePasswordHash,
  activatePendingRole,
  markPendingApproval,
};
