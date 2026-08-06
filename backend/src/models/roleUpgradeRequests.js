const { query } = require('../db');

const REQUESTABLE_ROLES = ['affiliater', 'agent', 'investor'];

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id,
    requestedRole: row.requested_role,
    status: row.status,
    message: row.message,
    agencyOrLicense: row.agency_or_license,
    interestedInFractionalInvesting: row.interested_in_fractional_investing,
    adminNote: row.admin_note,
    decidedAt: row.decided_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    // Present only on admin-facing rows (see listPending's join).
    userFullName: row.user_full_name,
    userEmail: row.user_email,
    currentRole: row.current_role,
  };
}

/**
 * Creates a new pending request. Throws a Postgres unique-violation
 * (code 23505) if this user already has one pending — callers should
 * catch that and surface "you already have a request in review".
 */
function create({ userId, requestedRole, message, agencyOrLicense, interestedInFractionalInvesting }) {
  return query(
    `INSERT INTO role_upgrade_requests (
       user_id, requested_role, message, agency_or_license, interested_in_fractional_investing
     )
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [
      userId,
      requestedRole,
      message ? String(message).trim() : null,
      agencyOrLicense ? String(agencyOrLicense).trim() : null,
      Boolean(interestedInFractionalInvesting),
    ]
  ).then((r) => r.rows[0]);
}

/** Every request this visitor has ever submitted, newest first. */
function listByUser(userId) {
  return query(`SELECT * FROM role_upgrade_requests WHERE user_id = $1 ORDER BY created_at DESC`, [userId]).then(
    (r) => r.rows
  );
}

/** This visitor's current pending request, if any. */
function findPendingForUser(userId) {
  return query(
    `SELECT * FROM role_upgrade_requests WHERE user_id = $1 AND status = 'pending' LIMIT 1`,
    [userId]
  ).then((r) => r.rows[0] || null);
}

/** Admin queue — every pending request, joined with the requester's identity. */
function listPending() {
  return query(
    `SELECT rur.*, u.full_name AS user_full_name, u.email AS user_email, u.role AS current_role
     FROM role_upgrade_requests rur
     JOIN users u ON u.id = rur.user_id
     WHERE rur.status = 'pending'
     ORDER BY rur.created_at ASC`
  ).then((r) => r.rows);
}

function findById(id) {
  return query(
    `SELECT rur.*, u.full_name AS user_full_name, u.email AS user_email, u.role AS current_role
     FROM role_upgrade_requests rur
     JOIN users u ON u.id = rur.user_id
     WHERE rur.id = $1`,
    [id]
  ).then((r) => r.rows[0] || null);
}

/**
 * Approves a still-pending request and returns { request, user } — the
 * caller (route) is responsible for issuing a fresh token if the caller
 * happens to be the affected user's own active session, since the role
 * embedded in an existing JWT won't update until they sign in again.
 */
async function approve(id, { adminNote } = {}) {
  const row = await query(
    `UPDATE role_upgrade_requests
     SET status = 'approved', admin_note = $2, decided_at = now()
     WHERE id = $1 AND status = 'pending'
     RETURNING *`,
    [id, adminNote ? String(adminNote).trim() : null]
  ).then((r) => r.rows[0] || null);
  if (!row) return null;

  const userRow = await query(`UPDATE users SET role = $2 WHERE id = $1 RETURNING *`, [
    row.user_id,
    row.requested_role,
  ]).then((r) => r.rows[0] || null);

  return { request: row, user: userRow };
}

function reject(id, { adminNote } = {}) {
  return query(
    `UPDATE role_upgrade_requests
     SET status = 'rejected', admin_note = $2, decided_at = now()
     WHERE id = $1 AND status = 'pending'
     RETURNING *`,
    [id, adminNote ? String(adminNote).trim() : null]
  ).then((r) => r.rows[0] || null);
}

module.exports = {
  REQUESTABLE_ROLES,
  toPublic,
  create,
  listByUser,
  findPendingForUser,
  listPending,
  findById,
  approve,
  reject,
};
