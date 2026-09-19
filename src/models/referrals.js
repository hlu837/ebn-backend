const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    senderId: row.sender_id,
    receiverId: row.receiver_id,
    senderName: row.sender_name || null,
    receiverName: row.receiver_name || null,
    clientName: row.client_name,
    clientPhone: row.client_phone,
    categorySlug: row.category_slug,
    feePercent: Number(row.fee_percent),
    status: row.status,
    notes: row.notes,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function create({ senderId, receiverId, clientName, clientPhone, categorySlug, feePercent, notes }) {
  const result = await query(
    `INSERT INTO referrals (
       sender_id, receiver_id, client_name, client_phone, category_slug, fee_percent, notes
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [senderId, receiverId, clientName, clientPhone, categorySlug, feePercent || 10, notes || null]
  );
  return getById(result.rows[0].id);
}

async function getById(id) {
  const result = await query(
    `SELECT r.*,
            s.full_name AS sender_name,
            rec.full_name AS receiver_name
     FROM referrals r
     LEFT JOIN users s ON s.id = r.sender_id
     LEFT JOIN users rec ON rec.id = r.receiver_id
     WHERE r.id = $1`,
    [id]
  );
  return toPublic(result.rows[0]);
}

async function listForUser(userId) {
  const result = await query(
    `SELECT r.*,
            s.full_name AS sender_name,
            rec.full_name AS receiver_name
     FROM referrals r
     LEFT JOIN users s ON s.id = r.sender_id
     LEFT JOIN users rec ON rec.id = r.receiver_id
     WHERE r.sender_id = $1 OR r.receiver_id = $1
     ORDER BY r.created_at DESC`,
    [userId]
  );
  return result.rows.map(toPublic);
}

async function updateStatus(id, userId, status) {
  const result = await query(
    `UPDATE referrals
     SET status = $2, updated_at = now()
     WHERE id = $1 AND (sender_id = $3 OR receiver_id = $3)
     RETURNING *`,
    [id, status, userId]
  );
  if (!result.rows[0]) return null;
  return getById(id);
}

module.exports = {
  toPublic,
  create,
  getById,
  listForUser,
  updateStatus,
};
