const { query } = require('../db');

/** Converts a DB row (snake_case) to the camelCase shape the client expects. */
function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    txRef: row.tx_ref,
    purpose: row.purpose,
    ownerUserId: row.owner_user_id,
    // Present only on rows returned by listAll(), which joins users —
    // falls back to the checkout's own first/last name for a payer who
    // isn't a registered account (or whose id didn't match).
    ownerName: row.owner_full_name || [row.first_name, row.last_name].filter(Boolean).join(' ') || null,
    amount: Number(row.amount),
    currency: row.currency,
    email: row.email,
    firstName: row.first_name,
    lastName: row.last_name,
    status: row.status,
    checkoutUrl: row.chapa_checkout_url,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function create({
  txRef,
  purpose,
  ownerUserId,
  amount,
  currency = 'ETB',
  email,
  firstName,
  lastName,
  checkoutUrl,
  pendingUserPayload,
}) {
  const { rows } = await query(
    `INSERT INTO payments
       (tx_ref, purpose, owner_user_id, amount, currency, email, first_name, last_name, chapa_checkout_url, pending_user_payload)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [
      txRef,
      purpose,
      ownerUserId || null,
      amount,
      currency,
      email,
      firstName || null,
      lastName || null,
      checkoutUrl || null,
      pendingUserPayload ? JSON.stringify(pendingUserPayload) : null,
    ]
  );
  return rows[0];
}

async function findByTxRef(txRef) {
  const { rows } = await query('SELECT * FROM payments WHERE tx_ref = $1', [txRef]);
  return rows[0] || null;
}

/**
 * Returns the most-recent *pending* agent or investor payment for the given
 * email, or null if none exists. Used by the signup endpoint to block
 * plain-user creation when the person already started a paid-role checkout.
 */
async function findPendingByEmail(email) {
  const { rows } = await query(
    `SELECT * FROM payments
     WHERE email ILIKE $1
       AND status = 'pending'
       AND (purpose LIKE 'agent\_%' OR purpose LIKE 'investor\_%')
     ORDER BY created_at DESC
     LIMIT 1`,
    [email]
  );
  return rows[0] || null;
}

async function markStatus(txRef, status, verifyResponse) {
  const { rows } = await query(
    `UPDATE payments
     SET status = $2, chapa_verify_response = $3, updated_at = now()
     WHERE tx_ref = $1
     RETURNING *`,
    [txRef, status, verifyResponse ? JSON.stringify(verifyResponse) : null]
  );
  return rows[0] || null;
}

/**
 * Admin > Transactions list. [status] filters to an exact payment_status;
 * [search] matches the payer's name/email or the payment's purpose
 * (case-insensitive, partial). `owner_user_id` is free-text (not a real
 * FK — see migrations/004_payments.sql), so the join to users is a
 * best-effort match on id, not a guaranteed one.
 */
async function listAll({ status, search, limit = 20, offset = 0 } = {}) {
  const conditions = [];
  const params = [];

  if (status) {
    params.push(status);
    conditions.push(`p.status = $${params.length}`);
  }
  if (search) {
    params.push(`%${search}%`);
    const s = params.length;
    conditions.push(`(u.full_name ILIKE $${s} OR p.email ILIKE $${s} OR p.purpose ILIKE $${s})`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  params.push(limit);
  params.push(offset);

  const { rows } = await query(
    `SELECT p.*, u.full_name AS owner_full_name
     FROM payments p
     LEFT JOIN users u ON u.id::text = p.owner_user_id
     ${where}
     ORDER BY p.created_at DESC
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );
  return rows;
}

/** Matches the same filters as [listAll], for pagination totals. */
async function countAll({ status, search } = {}) {
  const conditions = [];
  const params = [];

  if (status) {
    params.push(status);
    conditions.push(`p.status = $${params.length}`);
  }
  if (search) {
    params.push(`%${search}%`);
    const s = params.length;
    conditions.push(`(u.full_name ILIKE $${s} OR p.email ILIKE $${s} OR p.purpose ILIKE $${s})`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const { rows } = await query(
    `SELECT COUNT(*)::int AS count
     FROM payments p
     LEFT JOIN users u ON u.id::text = p.owner_user_id
     ${where}`,
    params
  );
  return rows[0].count;
}

module.exports = { toPublic, create, findByTxRef, findPendingByEmail, markStatus, listAll, countAll };
