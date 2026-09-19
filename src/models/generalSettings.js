const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    appName: row.app_name,
    logoUrl: row.logo_url,
    supportEmail: row.support_email,
    supportPhone: row.support_phone,
    updatedAt: row.updated_at,
  };
}

function get() {
  return query(`SELECT * FROM general_settings WHERE id = 1`).then((r) => r.rows[0] || null);
}

function update(fields) {
  const map = {
    appName: 'app_name',
    logoUrl: 'logo_url',
    supportEmail: 'support_email',
    supportPhone: 'support_phone',
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
  if (!sets.length) return get();
  return query(`UPDATE general_settings SET ${sets.join(', ')} WHERE id = 1 RETURNING *`, vals).then(
    (r) => r.rows[0] || null
  );
}

module.exports = { toPublic, get, update };
