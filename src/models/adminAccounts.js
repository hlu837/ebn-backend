const { query } = require('../db');

/**
 * Admin > Settings > Admin Accounts. Deliberately separate from the
 * general users model's suspend flow (routes/users.js explicitly blocks
 * suspending admins there) — this is the dedicated place admin access is
 * granted/revoked.
 */

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    phone: row.phone,
    createdAt: row.created_at,
  };
}

function list() {
  return query(`SELECT * FROM users WHERE role = 'admin' ORDER BY created_at DESC`).then((r) => r.rows);
}

/** Creates a brand-new admin account (email + temp password set by the inviting admin). */
function createAdmin({ fullName, email, passwordHash, phone }) {
  return query(
    `INSERT INTO users (full_name, email, password_hash, role, phone)
     VALUES ($1, $2, $3, 'admin', $4)
     RETURNING *`,
    [fullName, email, passwordHash, phone || null]
  ).then((r) => r.rows[0]);
}

/** Demotes an admin to a regular user, revoking dashboard access. */
function revoke(id) {
  return query(`UPDATE users SET role = 'user' WHERE id = $1 AND role = 'admin' RETURNING *`, [id]).then(
    (r) => r.rows[0] || null
  );
}

module.exports = { toPublic, list, createAdmin, revoke };
