const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    tierKey: row.tier_key,
    title: row.title,
    description: row.description,
    priceEtb: Number(row.price_etb),
    benefits: Array.isArray(row.benefits) ? row.benefits : [],
    footerNote: row.footer_note,
    updatedAt: row.updated_at,
  };
}

function get() {
  return query(`SELECT * FROM investor_membership_plan WHERE id = 1`).then((r) => r.rows[0] || null);
}

function update(fields) {
  const map = {
    tierKey: 'tier_key',
    title: 'title',
    description: 'description',
    priceEtb: 'price_etb',
    benefits: 'benefits',
    footerNote: 'footer_note',
  };
  const sets = [];
  const vals = [];
  let i = 1;
  for (const [key, col] of Object.entries(map)) {
    if (fields[key] !== undefined) {
      sets.push(`${col} = $${i++}`);
      vals.push(key === 'benefits' ? JSON.stringify(fields[key]) : fields[key]);
    }
  }
  if (!sets.length) return get();
  return query(`UPDATE investor_membership_plan SET ${sets.join(', ')} WHERE id = 1 RETURNING *`, vals).then(
    (r) => r.rows[0] || null
  );
}

module.exports = { toPublic, get, update };
