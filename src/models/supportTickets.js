const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id,
    senderName: row.sender_name,
    senderContact: row.sender_contact,
    category: row.category,
    subject: row.subject,
    body: row.body,
    status: row.status,
    adminResponse: row.admin_response,
    adminResponseAt: row.admin_response_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function create({ userId, senderName, senderContact, category, subject, body }) {
  return query(
    `INSERT INTO support_tickets (user_id, sender_name, sender_contact, category, subject, body)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [userId || null, senderName, senderContact, category || 'other', subject, body]
  ).then((r) => r.rows[0]);
}

function list({ status } = {}) {
  if (status) {
    return query(`SELECT * FROM support_tickets WHERE status = $1 ORDER BY created_at DESC`, [status]).then(
      (r) => r.rows
    );
  }
  return query(`SELECT * FROM support_tickets ORDER BY created_at DESC`).then((r) => r.rows);
}

function listByUser(userId) {
  return query(`SELECT * FROM support_tickets WHERE user_id = $1 ORDER BY created_at DESC`, [userId]).then(
    (r) => r.rows
  );
}

function findById(id) {
  return query(`SELECT * FROM support_tickets WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

function resolve(id) {
  return query(`UPDATE support_tickets SET status = 'resolved' WHERE id = $1 RETURNING *`, [id]).then(
    (r) => r.rows[0] || null
  );
}

/** Records the admin's answer. Independent of resolve() — replying doesn't
 *  force a status change, matching the two separate actions/buttons already
 *  in the admin support detail screen. */
function reply(id, adminResponse) {
  return query(
    `UPDATE support_tickets SET admin_response = $2, admin_response_at = now() WHERE id = $1 RETURNING *`,
    [id, adminResponse]
  ).then((r) => r.rows[0] || null);
}

module.exports = { toPublic, create, list, listByUser, findById, resolve, reply };
