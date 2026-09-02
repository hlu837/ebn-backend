const { query } = require('../db');

/**
 * Admin is a shared queue, not a per-user inbox — matching the socket
 * layer (all admin sockets join one shared `admin` room, see socket.js)
 * and the existing admin approval-queue endpoints (every admin sees the
 * same queue, there's no per-admin read state). Notifications created
 * for admin use this constant as recipient_id since the column is
 * NOT NULL, but every admin's `GET /api/notifications` should see them
 * regardless of which admin id (if any) they were filed against.
 */
const ADMIN_SHARED_RECIPIENT_ID = 'all';

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    recipientType: row.recipient_type,
    recipientId: row.recipient_id,
    kind: row.kind,
    title: row.title,
    body: row.body,
    isRead: row.is_read,
    relatedId: row.related_id,
    createdAt: row.created_at,
  };
}

/**
 * Creates one notification row for a single recipient. Delivery over
 * socket (if the recipient is currently connected) is a separate step —
 * see `broadcastNotification` in ../socket — callers typically do both
 * together so the row exists for anyone polling as well as anyone
 * connected live.
 *
 * For recipientType 'admin', pass any admin id or omit it — it's
 * normalized to the shared queue below, since admin notifications go to
 * every admin, not one.
 */
async function create({ recipientType, recipientId, kind, title, body, relatedId }) {
  const resolvedRecipientId = recipientType === 'admin' ? ADMIN_SHARED_RECIPIENT_ID : recipientId;
  const row = await query(
    `INSERT INTO notifications (recipient_type, recipient_id, kind, title, body, related_id)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [recipientType, resolvedRecipientId, kind, title, body, relatedId || null]
  ).then((r) => r.rows[0]);
  return row;
}

function listForRecipient(recipientType, recipientId) {
  if (recipientType === 'admin') {
    return query(
      `SELECT * FROM notifications WHERE recipient_type = 'admin' ORDER BY created_at DESC`
    ).then((r) => r.rows);
  }
  return query(
    `SELECT * FROM notifications WHERE recipient_type = $1 AND recipient_id = $2 ORDER BY created_at DESC`,
    [recipientType, recipientId]
  ).then((r) => r.rows);
}

function markRead(id, recipientType, recipientId) {
  if (recipientType === 'admin') {
    return query(
      `UPDATE notifications SET is_read = true
       WHERE id = $1 AND recipient_type = 'admin'
       RETURNING *`,
      [id]
    ).then((r) => r.rows[0] || null);
  }
  return query(
    `UPDATE notifications SET is_read = true
     WHERE id = $1 AND recipient_type = $2 AND recipient_id = $3
     RETURNING *`,
    [id, recipientType, recipientId]
  ).then((r) => r.rows[0] || null);
}

function markAllRead(recipientType, recipientId) {
  if (recipientType === 'admin') {
    return query(
      `UPDATE notifications SET is_read = true
       WHERE recipient_type = 'admin' AND is_read = false
       RETURNING id`
    ).then((r) => r.rows.length);
  }
  return query(
    `UPDATE notifications SET is_read = true
     WHERE recipient_type = $1 AND recipient_id = $2 AND is_read = false
     RETURNING id`,
    [recipientType, recipientId]
  ).then((r) => r.rows.length);
}

module.exports = { toPublic, create, listForRecipient, markRead, markAllRead, ADMIN_SHARED_RECIPIENT_ID };
