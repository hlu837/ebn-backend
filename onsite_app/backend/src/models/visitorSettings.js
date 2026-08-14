const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    notifyRequestUpdates: row.notify_request_updates,
    notifyChatMessages: row.notify_chat_messages,
    notifyPriceDrops: row.notify_price_drops,
    notifyPromotions: row.notify_promotions,
    language: row.language,
    updatedAt: row.updated_at,
  };
}

/** Lazily creates a default row on first access — no signup-time hook needed. */
async function getOrCreate(userId) {
  const existing = await query(`SELECT * FROM visitor_settings WHERE user_id = $1`, [userId]);
  if (existing.rows[0]) return existing.rows[0];
  const created = await query(
    `INSERT INTO visitor_settings (user_id) VALUES ($1)
     ON CONFLICT (user_id) DO UPDATE SET user_id = EXCLUDED.user_id
     RETURNING *`,
    [userId]
  );
  return created.rows[0];
}

function update(userId, fields) {
  const map = {
    notifyRequestUpdates: 'notify_request_updates',
    notifyChatMessages: 'notify_chat_messages',
    notifyPriceDrops: 'notify_price_drops',
    notifyPromotions: 'notify_promotions',
    language: 'language',
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
  if (!sets.length) return getOrCreate(userId).then(toPublic);
  vals.push(userId);
  return query(
    `INSERT INTO visitor_settings (user_id) VALUES ($${vals.length})
     ON CONFLICT (user_id) DO NOTHING`,
    [userId]
  ).then(() =>
    query(`UPDATE visitor_settings SET ${sets.join(', ')} WHERE user_id = $${i} RETURNING *`, vals).then(
      (r) => r.rows[0]
    )
  );
}

module.exports = { toPublic, getOrCreate, update };
