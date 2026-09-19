const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    agentId: row.agent_id,
    type: row.type,
    amount: Number(row.amount),
    label: row.label,
    status: row.status,
    bankAccountLast4: row.bank_account_last4,
    // Set only on override commissions credited via the agent network
    // program — the downline agent whose own commission generated this
    // one. Null for every ordinary (direct) commission or withdrawal.
    sourceAgentId: row.source_agent_id || null,
    createdAt: row.created_at,
  };
}

function listByAgent(agentId) {
  return query(
    `SELECT * FROM agent_wallet_transactions WHERE agent_id = $1 ORDER BY created_at DESC`,
    [agentId]
  ).then((r) => r.rows);
}

/**
 * Available balance = cleared commissions + all withdrawals (withdrawals
 * reserve funds the moment they're requested, before they clear — matches
 * the original mock's behavior). Pending commissions are reported
 * separately and don't count toward the spendable balance yet.
 */
async function getSummary(agentId) {
  const { rows } = await query(
    `SELECT
       COALESCE(SUM(amount) FILTER (WHERE type = 'commission' AND status = 'cleared'), 0)
         + COALESCE(SUM(amount) FILTER (WHERE type = 'withdrawal'), 0) AS balance,
       COALESCE(SUM(amount) FILTER (WHERE type = 'commission' AND status = 'pending'), 0) AS pending_clearance
     FROM agent_wallet_transactions
     WHERE agent_id = $1`,
    [agentId]
  );
  const row = rows[0] || { balance: 0, pending_clearance: 0 };
  return {
    balance: Number(row.balance),
    pendingClearance: Number(row.pending_clearance),
  };
}

function addCommission(agentId, { amount, label, status = 'pending' }) {
  return query(
    `INSERT INTO agent_wallet_transactions (agent_id, type, amount, label, status)
     VALUES ($1, 'commission', $2, $3, $4)
     RETURNING *`,
    [agentId, amount, label, status]
  ).then((r) => r.rows[0]);
}

/** Withdrawals are recorded as a negative amount, pending admin clearance. */
function requestWithdrawal(agentId, { amount, bankAccountLast4, label }) {
  return query(
    `INSERT INTO agent_wallet_transactions (agent_id, type, amount, label, status, bank_account_last4)
     VALUES ($1, 'withdrawal', $2, $3, 'pending', $4)
     RETURNING *`,
    [agentId, -Math.abs(amount), label, bankAccountLast4 || null]
  ).then((r) => r.rows[0]);
}

function clearTransaction(agentId, txId) {
  return query(
    `UPDATE agent_wallet_transactions
     SET status = 'cleared'
     WHERE id = $1 AND agent_id = $2 AND status = 'pending'
     RETURNING *`,
    [txId, agentId]
  ).then((r) => r.rows[0] || null);
}

module.exports = { toPublic, listByAgent, getSummary, addCommission, requestWithdrawal, clearTransaction };
