const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    isLive: row.is_live,
    sortOrder: row.sort_order,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function list() {
  return query(`SELECT * FROM cities ORDER BY sort_order ASC, name ASC`).then((r) => r.rows);
}

function findById(id) {
  return query(`SELECT * FROM cities WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

function findByName(name) {
  return query(`SELECT * FROM cities WHERE name = $1`, [name]).then((r) => r.rows[0] || null);
}

async function create({ name, isLive, sortOrder }) {
  const maxOrder = await query(`SELECT COALESCE(MAX(sort_order), -1) AS max FROM cities`);
  const nextOrder = sortOrder ?? maxOrder.rows[0].max + 1;
  return query(
    `INSERT INTO cities (name, is_live, sort_order) VALUES ($1, $2, $3) RETURNING *`,
    [name, isLive ?? true, nextOrder]
  ).then((r) => r.rows[0]);
}

function update(id, fields) {
  const map = { name: 'name', isLive: 'is_live', sortOrder: 'sort_order' };
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
  return query(`UPDATE cities SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`, vals).then(
    (r) => r.rows[0] || null
  );
}

function remove(id) {
  return query(`DELETE FROM cities WHERE id = $1 RETURNING *`, [id]).then((r) => r.rows[0] || null);
}

module.exports = { toPublic, list, findById, findByName, create, update, remove };
