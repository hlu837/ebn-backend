const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    shortCode: row.short_code,
    isActive: row.is_active,
    sortOrder: row.sort_order,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** Every bank, active or not — the Admin > Settings screen needs to see
 *  and toggle deactivated ones too. Owners picking a bank to register an
 *  account against should filter to isActive themselves (or call
 *  [listActive]). */
function list() {
  return query(`SELECT * FROM platform_banks ORDER BY sort_order ASC, name ASC`).then((r) => r.rows);
}

/** Only the banks currently accepted — what an owner's "add account"
 *  dropdown, and the tenant-facing payment screen, should actually use. */
function listActive() {
  return query(`SELECT * FROM platform_banks WHERE is_active = true ORDER BY sort_order ASC, name ASC`).then(
    (r) => r.rows
  );
}

function findById(id) {
  return query(`SELECT * FROM platform_banks WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

function findByName(name) {
  return query(`SELECT * FROM platform_banks WHERE name = $1`, [name]).then((r) => r.rows[0] || null);
}

async function create({ name, shortCode, isActive, sortOrder }) {
  const maxOrder = await query(`SELECT COALESCE(MAX(sort_order), -1) AS max FROM platform_banks`);
  const nextOrder = sortOrder ?? maxOrder.rows[0].max + 1;
  return query(
    `INSERT INTO platform_banks (name, short_code, is_active, sort_order) VALUES ($1, $2, $3, $4) RETURNING *`,
    [name, shortCode || null, isActive ?? true, nextOrder]
  ).then((r) => r.rows[0]);
}

function update(id, fields) {
  const map = { name: 'name', shortCode: 'short_code', isActive: 'is_active', sortOrder: 'sort_order' };
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
  return query(`UPDATE platform_banks SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`, vals).then(
    (r) => r.rows[0] || null
  );
}

/** Hard delete is intentionally not exposed here — deactivating (isActive:
 *  false) is the supported way to retire a bank without breaking the FK
 *  from any owner_bank_accounts row already pointing at it. See
 *  ownerBankAccounts.js for how deactivated banks get filtered out of the
 *  tenant-facing list without deleting anyone's saved account. */
module.exports = { toPublic, list, listActive, findById, findByName, create, update };
