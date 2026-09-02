const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    category: row.category,
    status: row.status,
    targetAmount: Number(row.target_amount),
    minInvestment: Number(row.min_investment),
    expectedReturnPct: Number(row.expected_return_pct),
    termMonths: row.term_months,
    imageUrl: row.image_url,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** Investor-facing list: open deals first, then newest first. */
async function listPublic() {
  const { rows } = await query(
    `SELECT * FROM investment_opportunities
     ORDER BY (status = 'Open') DESC, created_at DESC`
  );
  return rows.map(toPublic);
}

/** Admin management list: everything, newest first. */
async function listAll() {
  const { rows } = await query(
    'SELECT * FROM investment_opportunities ORDER BY created_at DESC'
  );
  return rows.map(toPublic);
}

async function getById(id) {
  const { rows } = await query('SELECT * FROM investment_opportunities WHERE id = $1', [id]);
  return toPublic(rows[0]);
}

async function create({
  title,
  description,
  category,
  targetAmount,
  minInvestment,
  expectedReturnPct,
  termMonths,
  imageUrl,
}) {
  const { rows } = await query(
    `INSERT INTO investment_opportunities
       (title, description, category, target_amount, min_investment, expected_return_pct, term_months, image_url)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [title, description, category, targetAmount, minInvestment, expectedReturnPct, termMonths, imageUrl || null]
  );
  return toPublic(rows[0]);
}

async function update(id, fields) {
  const columns = {
    title: 'title',
    description: 'description',
    category: 'category',
    status: 'status',
    targetAmount: 'target_amount',
    minInvestment: 'min_investment',
    expectedReturnPct: 'expected_return_pct',
    termMonths: 'term_months',
    imageUrl: 'image_url',
  };

  const sets = [];
  const values = [];
  let i = 1;
  for (const [key, column] of Object.entries(columns)) {
    if (fields[key] !== undefined) {
      sets.push(`${column} = $${i}`);
      values.push(fields[key]);
      i += 1;
    }
  }
  if (!sets.length) return getById(id);

  sets.push(`updated_at = now()`);
  values.push(id);

  const { rows } = await query(
    `UPDATE investment_opportunities SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`,
    values
  );
  return toPublic(rows[0]);
}

async function remove(id) {
  const { rows } = await query(
    'DELETE FROM investment_opportunities WHERE id = $1 RETURNING id',
    [id]
  );
  return rows[0] ? rows[0].id : null;
}

module.exports = { listPublic, listAll, getById, create, update, remove };
