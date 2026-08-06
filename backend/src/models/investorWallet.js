const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    investorId: row.investor_id,
    type: row.type,
    amount: Number(row.amount),
    label: row.label,
    status: row.status,
    commitmentId: row.commitment_id || null,
    bankAccountLast4: row.bank_account_last4,
    createdAt: row.created_at,
  };
}

function listByInvestor(investorId) {
  return query(
    `SELECT * FROM investor_wallet_transactions WHERE investor_id = $1 ORDER BY created_at DESC`,
    [investorId]
  ).then((r) => r.rows);
}

/**
 * Available balance = cleared payouts + all withdrawals (withdrawals
 * reserve funds the moment they're requested, before they clear — same
 * pattern as the agent wallet). Pending payouts are reported separately
 * and don't count toward the spendable balance yet.
 */
async function getSummary(investorId) {
  const { rows } = await query(
    `SELECT
       COALESCE(SUM(amount) FILTER (WHERE type = 'payout' AND status = 'cleared'), 0)
         + COALESCE(SUM(amount) FILTER (WHERE type = 'withdrawal'), 0) AS balance,
       COALESCE(SUM(amount) FILTER (WHERE type = 'payout' AND status = 'pending'), 0) AS pending_clearance
     FROM investor_wallet_transactions
     WHERE investor_id = $1`,
    [investorId]
  );
  const row = rows[0] || { balance: 0, pending_clearance: 0 };
  return {
    balance: Number(row.balance),
    pendingClearance: Number(row.pending_clearance),
  };
}

function addPayout(investorId, { amount, label, status = 'cleared', commitmentId }) {
  return query(
    `INSERT INTO investor_wallet_transactions (investor_id, type, amount, label, status, commitment_id)
     VALUES ($1, 'payout', $2, $3, $4, $5)
     RETURNING *`,
    [investorId, amount, label, status, commitmentId || null]
  ).then((r) => r.rows[0]);
}

/** Withdrawals are recorded as a negative amount, pending admin clearance. */
function requestWithdrawal(investorId, { amount, bankAccountLast4, label }) {
  return query(
    `INSERT INTO investor_wallet_transactions (investor_id, type, amount, label, status, bank_account_last4)
     VALUES ($1, 'withdrawal', $2, $3, 'pending', $4)
     RETURNING *`,
    [investorId, -Math.abs(amount), label, bankAccountLast4 || null]
  ).then((r) => r.rows[0]);
}

function clearTransaction(investorId, txId) {
  return query(
    `UPDATE investor_wallet_transactions
     SET status = 'cleared'
     WHERE id = $1 AND investor_id = $2 AND status = 'pending'
     RETURNING *`,
    [txId, investorId]
  ).then((r) => r.rows[0] || null);
}

module.exports = { toPublic, listByInvestor, getSummary, addPayout, requestWithdrawal, clearTransaction };
