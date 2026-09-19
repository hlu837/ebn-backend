const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    serviceProviderId: row.service_provider_id,
    type: row.type,
    amountCents: row.amount_cents,
    label: row.label,
    status: row.status,
    maintenanceAssignmentId: row.maintenance_assignment_id || null,
    recordedByAdminId: row.recorded_by_admin_id || null,
    createdAt: row.created_at,
  };
}

function listByProvider(serviceProviderId) {
  return query(
    `SELECT * FROM specialist_wallet_transactions WHERE service_provider_id = $1 ORDER BY created_at DESC`,
    [serviceProviderId]
  ).then((r) => r.rows);
}

/**
 * Available balance = SUM(amount_cents) over the ledger -- credits
 * positive, payouts negative, same formula as agentWallet/investorWallet.
 * There's no "pending clearance" bucket here (unlike those two) since
 * every row is entered already-cleared -- see 085's migration note.
 */
async function getSummary(serviceProviderId) {
  const { rows } = await query(
    `SELECT COALESCE(SUM(amount_cents), 0) AS balance_cents
     FROM specialist_wallet_transactions
     WHERE service_provider_id = $1`,
    [serviceProviderId]
  );
  return { balanceCents: Number(rows[0]?.balance_cents || 0) };
}

/** Summary balances for every provider at once, for the admin wallet list. */
async function getSummaries() {
  const { rows } = await query(
    `SELECT service_provider_id, COALESCE(SUM(amount_cents), 0) AS balance_cents
     FROM specialist_wallet_transactions
     GROUP BY service_provider_id`
  );
  const byProvider = {};
  for (const r of rows) byProvider[r.service_provider_id] = Number(r.balance_cents);
  return byProvider;
}

/** Called from maintenanceAssignments.confirmComplete once escrow releases. */
function creditFromEscrow(serviceProviderId, { amountCents, label, maintenanceAssignmentId }) {
  return query(
    `INSERT INTO specialist_wallet_transactions
       (service_provider_id, type, amount_cents, label, status, maintenance_assignment_id)
     VALUES ($1, 'credit', $2, $3, 'cleared', $4)
     RETURNING *`,
    [serviceProviderId, amountCents, label, maintenanceAssignmentId || null]
  ).then((r) => r.rows[0]);
}

/**
 * Admin records a payout they've already made offline (bank transfer,
 * cash, mobile money) -- see 085's migration note on why this isn't a
 * pending-request flow like agent/investor withdrawals. Recorded as a
 * negative amount, same convention as those wallets' withdrawals.
 */
async function recordManualPayout(serviceProviderId, { amountCents, label, adminId }) {
  const amount = Number(amountCents);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw Object.assign(new Error('Enter a valid payout amount.'), { status: 400 });
  }
  const { balanceCents } = await getSummary(serviceProviderId);
  if (amount > balanceCents) {
    throw Object.assign(new Error('Payout exceeds the specialist’s current balance.'), { status: 409 });
  }
  return query(
    `INSERT INTO specialist_wallet_transactions
       (service_provider_id, type, amount_cents, label, status, recorded_by_admin_id)
     VALUES ($1, 'payout', $2, $3, 'cleared', $4)
     RETURNING *`,
    [serviceProviderId, -Math.abs(Math.round(amount)), label || 'Manual payout', adminId || null]
  ).then((r) => r.rows[0]);
}

module.exports = { toPublic, listByProvider, getSummary, getSummaries, creditFromEscrow, recordManualPayout };
