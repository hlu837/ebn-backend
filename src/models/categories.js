const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    slug: row.slug,
    label: row.label,
    listingFeeCents: row.listing_fee_cents,
    sortOrder: row.sort_order,
    isActive: row.is_active,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** Active-first isn't required — admin sees everything, ordered for display. */
function list() {
  return query(`SELECT * FROM categories ORDER BY sort_order ASC, label ASC`).then((r) => r.rows);
}

function findById(id) {
  return query(`SELECT * FROM categories WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

function findBySlug(slug) {
  return query(`SELECT * FROM categories WHERE slug = $1`, [slug]).then((r) => r.rows[0] || null);
}

async function create({ slug, label, listingFeeCents, sortOrder }) {
  const maxOrder = await query(`SELECT COALESCE(MAX(sort_order), -1) AS max FROM categories`);
  const nextOrder = sortOrder ?? maxOrder.rows[0].max + 1;
  return query(
    `INSERT INTO categories (slug, label, listing_fee_cents, sort_order)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [slug, label, listingFeeCents || 0, nextOrder]
  ).then((r) => r.rows[0]);
}

function update(id, fields) {
  const map = {
    label: 'label',
    listingFeeCents: 'listing_fee_cents',
    sortOrder: 'sort_order',
    isActive: 'is_active',
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
  if (!sets.length) return findById(id);
  vals.push(id);
  return query(`UPDATE categories SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`, vals).then(
    (r) => r.rows[0] || null
  );
}

/** Reorders every category in one shot — [orderedIds] is the full new sequence. */
async function reorder(orderedIds) {
  await Promise.all(
    orderedIds.map((id, index) => query(`UPDATE categories SET sort_order = $2 WHERE id = $1`, [id, index]))
  );
  return list();
}

function remove(id) {
  // Soft-delete via is_active — listings may already reference the slug.
  return update(id, { isActive: false });
}

module.exports = { toPublic, list, findById, findBySlug, create, update, reorder, remove };
