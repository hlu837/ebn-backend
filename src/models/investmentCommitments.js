const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    userId: row.user_id,
    opportunityId: row.opportunity_id,
    amount: Number(row.amount),
    status: row.status,
    adminNote: row.admin_note,
    decidedAt: row.decided_at,
    createdAt: row.created_at,
    // Present only on rows joined with opportunity/user details.
    opportunityTitle: row.opportunity_title,
    opportunityStatus: row.opportunity_status,
    userFullName: row.user_full_name,
    userEmail: row.user_email,
    // Payout schedule — see investmentPayoutScheduler.js. termMonths is
    // only present when joined with the opportunity (listByUser/listPending/
    // listConfirmed/findById all do this); payoutsMade/maturedAt are
    // always present now that the column exists.
    termMonths: row.term_months != null ? Number(row.term_months) : null,
    payoutsMade: row.payouts_made != null ? Number(row.payouts_made) : 0,
    maturedAt: row.matured_at || null,
  };
}

/** Creates a new pending commitment. */
function create({ userId, opportunityId, amount }) {
  return query(
    `INSERT INTO investment_commitments (user_id, opportunity_id, amount)
     VALUES ($1, $2, $3)
     RETURNING *`,
    [userId, opportunityId, amount]
  ).then((r) => r.rows[0]);
}

/** Every commitment this investor has made, newest first, with opportunity titles. */
function listByUser(userId) {
  return query(
    `SELECT ic.*, io.title AS opportunity_title, io.status AS opportunity_status,
            io.term_months, io.expected_return_pct
     FROM investment_commitments ic
     JOIN investment_opportunities io ON io.id = ic.opportunity_id
     WHERE ic.user_id = $1
     ORDER BY ic.created_at DESC`,
    [userId]
  ).then((r) => r.rows);
}

/** Admin queue — every pending commitment, joined with investor + opportunity info. */
function listPending() {
  return query(
    `SELECT ic.*, io.title AS opportunity_title, io.status AS opportunity_status,
            io.term_months, io.expected_return_pct,
            u.full_name AS user_full_name, u.email AS user_email
     FROM investment_commitments ic
     JOIN investment_opportunities io ON io.id = ic.opportunity_id
     JOIN users u ON u.id = ic.user_id
     WHERE ic.status = 'Pending'
     ORDER BY ic.created_at ASC`
  ).then((r) => r.rows);
}

/** Admin: every confirmed commitment (an investor's active holding), newest first. */
function listConfirmed() {
  return query(
    `SELECT ic.*, io.title AS opportunity_title, io.status AS opportunity_status,
            io.term_months, io.expected_return_pct,
            u.full_name AS user_full_name, u.email AS user_email
     FROM investment_commitments ic
     JOIN investment_opportunities io ON io.id = ic.opportunity_id
     JOIN users u ON u.id = ic.user_id
     WHERE ic.status = 'Confirmed'
     ORDER BY ic.created_at DESC`
  ).then((r) => r.rows);
}

/**
 * Every Confirmed, not-yet-matured commitment, joined with everything the
 * payout scheduler needs to compute its schedule and credit payouts — see
 * investmentPayoutScheduler.js's runDuePayouts.
 */
function listConfirmedForScheduling() {
  return query(
    `SELECT ic.*, io.title AS opportunity_title, io.term_months, io.expected_return_pct,
            u.full_name AS user_full_name
     FROM investment_commitments ic
     JOIN investment_opportunities io ON io.id = ic.opportunity_id
     JOIN users u ON u.id = ic.user_id
     WHERE ic.status = 'Confirmed' AND ic.matured_at IS NULL`
  ).then((r) => r.rows);
}

/** How many of this investor's commitments are currently Confirmed — used to detect a "first confirmed commitment" for the referral-reward trigger. */
function countConfirmedByUser(userId) {
  return query(
    `SELECT COUNT(*)::int AS count FROM investment_commitments WHERE user_id = $1 AND status = 'Confirmed'`,
    [userId]
  ).then((r) => r.rows[0]?.count || 0);
}

function findById(id) {
  return query(
    `SELECT ic.*, io.title AS opportunity_title, io.status AS opportunity_status,
            io.term_months, io.expected_return_pct,
            u.full_name AS user_full_name, u.email AS user_email
     FROM investment_commitments ic
     JOIN investment_opportunities io ON io.id = ic.opportunity_id
     JOIN users u ON u.id = ic.user_id
     WHERE ic.id = $1`,
    [id]
  ).then((r) => r.rows[0] || null);
}

function approve(id, { adminNote } = {}) {
  return query(
    `UPDATE investment_commitments
     SET status = 'Confirmed', admin_note = $2, decided_at = now()
     WHERE id = $1 AND status = 'Pending'
     RETURNING *`,
    [id, adminNote ? String(adminNote).trim() : null]
  ).then((r) => r.rows[0] || null);
}

function reject(id, { adminNote } = {}) {
  return query(
    `UPDATE investment_commitments
     SET status = 'Rejected', admin_note = $2, decided_at = now()
     WHERE id = $1 AND status = 'Pending'
     RETURNING *`,
    [id, adminNote ? String(adminNote).trim() : null]
  ).then((r) => r.rows[0] || null);
}

/**
 * Advances a commitment's payout progress by exactly one period — called
 * once per period credited, so a crash mid-sweep can only ever under-count
 * (safe to re-run) rather than double-credit. Pass matured: true on the
 * final period to stamp matured_at and stop the scheduler from
 * considering this commitment again.
 */
function recordScheduledPayout(id, { matured = false } = {}) {
  return query(
    `UPDATE investment_commitments
     SET payouts_made = payouts_made + 1,
         matured_at = CASE WHEN $2 THEN now() ELSE matured_at END
     WHERE id = $1
     RETURNING *`,
    [id, matured]
  ).then((r) => r.rows[0] || null);
}

module.exports = {
  toPublic,
  create,
  listByUser,
  listPending,
  listConfirmed,
  listConfirmedForScheduling,
  countConfirmedByUser,
  findById,
  approve,
  reject,
  recordScheduledPayout,
};
