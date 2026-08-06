const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    actorId: row.actor_id,
    actorName: row.actor_name,
    action: row.action,
    targetType: row.target_type,
    targetId: row.target_id,
    detail: row.detail,
    createdAt: row.created_at,
  };
}

/**
 * Writes one audit entry. Best-effort by convention at the call site (see
 * routes/sellRequests.js etc.) — a logging failure shouldn't fail the
 * approve/reject action that triggered it, so callers wrap this in a
 * try/catch and swallow errors, same pattern as the notification writes
 * elsewhere in this codebase.
 */
function create({ actorId, actorName, action, targetType, targetId, detail }) {
  return query(
    `INSERT INTO activity_log (actor_id, actor_name, action, target_type, target_id, detail)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [actorId, actorName, action, targetType, targetId, detail || null]
  ).then((r) => r.rows[0]);
}

function list({ limit = 20, offset = 0 } = {}) {
  return query(
    `SELECT * FROM activity_log ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
    [limit, offset]
  ).then((r) => r.rows);
}

function count() {
  return query(`SELECT COUNT(*)::int AS count FROM activity_log`).then((r) => r.rows[0].count);
}

module.exports = { toPublic, create, list, count };
