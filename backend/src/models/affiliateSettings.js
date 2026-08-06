const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    notifyNewReferrals: row.notify_new_referrals,
    notifyPayouts: row.notify_payouts,
    bankName: row.bank_name,
    bankAccountLast4: row.bank_account_last4,
    updatedAt: row.updated_at,
  };
}

/** Lazily creates a default row on first access — no signup-time hook needed. */
async function getOrCreate(userId) {
  const existing = await query(`SELECT * FROM affiliate_settings WHERE user_id = $1`, [userId]);
  if (existing.rows[0]) return existing.rows[0];
  const created = await query(
    `INSERT INTO affiliate_settings (user_id) VALUES ($1)
     ON CONFLICT (user_id) DO UPDATE SET user_id = EXCLUDED.user_id
     RETURNING *`,
    [userId]
  );
  return created.rows[0];
}

function update(userId, fields) {
  const map = {
    notifyNewReferrals: 'notify_new_referrals',
    notifyPayouts: 'notify_payouts',
    bankName: 'bank_name',
    bankAccountLast4: 'bank_account_last4',
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
    `INSERT INTO affiliate_settings (user_id) VALUES ($${vals.length})
     ON CONFLICT (user_id) DO NOTHING`,
    [userId]
  ).then(() =>
    query(`UPDATE affiliate_settings SET ${sets.join(', ')} WHERE user_id = $${i} RETURNING *`, vals).then(
      (r) => r.rows[0]
    )
  );
}

module.exports = { toPublic, getOrCreate, update };
