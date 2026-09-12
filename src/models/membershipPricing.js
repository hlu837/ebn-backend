const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    role: row.role,
    tier: row.tier,
    monthlyFeeEtb: Number(row.monthly_fee_etb),
  };
}

/**
 * Get all membership pricing tiers for both roles (agent, affiliate).
 * Returns a nested object: { agent: {...}, affiliate: {...} }
 */
async function getAll() {
  const result = await query(
    `SELECT role, tier, monthly_fee_etb FROM membership_pricing
     ORDER BY role, CASE tier WHEN 'bronze' THEN 0 WHEN 'silver' THEN 1 WHEN 'gold' THEN 2 ELSE 3 END`
  );
  
  const pricing = { agent: {}, affiliate: {} };
  for (const row of result.rows) {
    pricing[row.role][row.tier] = Number(row.monthly_fee_etb);
  }
  return pricing;
}

/**
 * Get pricing for a specific role (agent or affiliate).
 * Returns an object: { bronze: 0, silver: 800, gold: 2200, diamond: 5000 }
 */
async function getByRole(role) {
  const result = await query(
    `SELECT tier, monthly_fee_etb FROM membership_pricing
     WHERE role = $1
     ORDER BY CASE tier WHEN 'bronze' THEN 0 WHEN 'silver' THEN 1 WHEN 'gold' THEN 2 ELSE 3 END`,
    [role]
  );
  
  const pricing = {};
  for (const row of result.rows) {
    pricing[row.tier] = Number(row.monthly_fee_etb);
  }
  return pricing;
}

/**
 * Update pricing for a specific tier and role.
 */
async function updateTierPrice(role, tier, monthlyFeeEtb) {
  const result = await query(
    `INSERT INTO membership_pricing (role, tier, monthly_fee_etb)
     VALUES ($1, $2, $3)
     ON CONFLICT (role, tier) DO UPDATE
       SET monthly_fee_etb = EXCLUDED.monthly_fee_etb
     RETURNING *`,
    [role, tier, monthlyFeeEtb]
  );
  return toPublic(result.rows[0]);
}

module.exports = { toPublic, getAll, getByRole, updateTierPrice };
