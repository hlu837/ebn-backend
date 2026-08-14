const crypto = require('crypto');
const { query } = require('../db');
const walletModel = require('./investorWallet');

/**
 * Percent of a referred investor's *first confirmed* commitment amount
 * their sponsor is credited as a one-time referral reward. Unlike the
 * agent network (which overrides an ongoing commission), investors don't
 * earn commissions — the reward is a single credit that fires once, the
 * moment an admin confirms the referred investor's first commitment.
 * Single source of truth — everything below reads from here.
 */
const INVESTOR_REFERRAL_REWARD_PERCENT = 2;

// ── Referral code ────────────────────────────────────────────────────────
// Same shape/collision-retry pattern as affiliates.generateCode /
// agentNetwork.generateCode, just a distinct "INV-" prefix and column so
// the referral programs never share codes.

function generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I — easier to read aloud
  let suffix = '';
  for (let i = 0; i < 6; i += 1) {
    suffix += chars[crypto.randomInt(chars.length)];
  }
  return `INV-${suffix}`;
}

async function getOrCreateCode(investorId) {
  const { rows } = await query('SELECT investor_referral_code FROM users WHERE id = $1', [investorId]);
  if (rows[0]?.investor_referral_code) return rows[0].investor_referral_code;

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const code = generateCode();
    try {
      const { rows: updated } = await query(
        `UPDATE users SET investor_referral_code = $2 WHERE id = $1 AND investor_referral_code IS NULL RETURNING investor_referral_code`,
        [investorId, code]
      );
      if (updated[0]) return updated[0].investor_referral_code;
      const { rows: reread } = await query('SELECT investor_referral_code FROM users WHERE id = $1', [investorId]);
      if (reread[0]?.investor_referral_code) return reread[0].investor_referral_code;
    } catch (err) {
      if (err.code !== '23505') throw err; // unique_violation -> retry with a new code
    }
  }
  throw new Error('Could not generate a unique investor referral code — try again.');
}

async function findInvestorIdByCode(code) {
  const { rows } = await query(
    `SELECT id FROM users WHERE investor_referral_code = $1 AND role = 'investor'`,
    [code]
  );
  return rows[0]?.id || null;
}

// ── Sponsorship ──────────────────────────────────────────────────────────

/**
 * Links a newly-created investor to the sponsor whose referral code they
 * signed up with. Only ever set once — a no-op if this investor already
 * has a sponsor, and refuses to let an investor sponsor themself.
 */
async function setSponsor(investorId, sponsorInvestorId) {
  if (!sponsorInvestorId || sponsorInvestorId === investorId) return null;
  const { rows } = await query(
    `UPDATE users SET sponsor_investor_id = $2
     WHERE id = $1 AND role = 'investor' AND sponsor_investor_id IS NULL
     RETURNING sponsor_investor_id`,
    [investorId, sponsorInvestorId]
  );
  return rows[0]?.sponsor_investor_id || null;
}

async function getSponsorId(investorId) {
  const { rows } = await query('SELECT sponsor_investor_id FROM users WHERE id = $1', [investorId]);
  return rows[0]?.sponsor_investor_id || null;
}

// ── Downline & earnings ─────────────────────────────────────────────────

/**
 * Every investor directly recruited by this investor, plus whether their
 * first commitment has been confirmed yet (i.e. whether they've already
 * generated a reward for this sponsor).
 */
async function listDownline(investorId) {
  const { rows } = await query(
    `SELECT
       u.id, u.full_name, u.email, u.created_at AS joined_at,
       EXISTS (
         SELECT 1 FROM investor_wallet_transactions t
         WHERE t.investor_id = $1 AND t.source_investor_id = u.id
       ) AS reward_credited
     FROM users u
     WHERE u.sponsor_investor_id = $1 AND u.role = 'investor'
     ORDER BY u.created_at DESC`,
    [investorId]
  );
  return rows.map((row) => ({
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    joinedAt: row.joined_at,
    rewardCredited: row.reward_credited,
  }));
}

/** Total referral rewards this investor has earned from their downline, cleared + pending. */
async function getRewardSummary(investorId) {
  const { rows } = await query(
    `SELECT
       COALESCE(SUM(amount) FILTER (WHERE status = 'cleared'), 0) AS cleared,
       COALESCE(SUM(amount) FILTER (WHERE status = 'pending'), 0) AS pending
     FROM investor_wallet_transactions
     WHERE investor_id = $1 AND type = 'payout' AND source_investor_id IS NOT NULL`,
    [investorId]
  );
  const row = rows[0] || { cleared: 0, pending: 0 };
  return { cleared: Number(row.cleared), pending: Number(row.pending) };
}

/**
 * Fires once, the moment an admin confirms a referred investor's *first*
 * commitment — credits that investor's sponsor (if any) a one-time reward
 * of INVESTOR_REFERRAL_REWARD_PERCENT% of the commitment amount. Callers
 * (investmentCommitments.js's approve route) are responsible for checking
 * this really is the referred investor's first confirmed commitment
 * before calling this — see countConfirmedByUser.
 * Returns the credited transaction, or null if the investor has no sponsor.
 */
async function creditReferralReward(investorId, { commitmentId, commitmentAmount, investorName }) {
  const sponsorId = await getSponsorId(investorId);
  if (!sponsorId) return null;

  const rewardAmount = Math.round(commitmentAmount * (INVESTOR_REFERRAL_REWARD_PERCENT / 100) * 100) / 100;
  if (rewardAmount <= 0) return null;

  const label = `${INVESTOR_REFERRAL_REWARD_PERCENT}% referral reward — ${investorName || 'investor you referred'}'s first investment`;
  const row = await walletModel.addPayout(sponsorId, {
    amount: rewardAmount,
    label,
    status: 'cleared',
    commitmentId,
  });

  // Stamp source_investor_id separately — addPayout's column set doesn't
  // include it (it's specific to this reward path, not ordinary payouts).
  const { rows: stamped } = await query(
    `UPDATE investor_wallet_transactions SET source_investor_id = $2 WHERE id = $1 RETURNING *`,
    [row.id, investorId]
  );

  return { sponsorId, transaction: walletModel.toPublic(stamped[0] || row) };
}

module.exports = {
  INVESTOR_REFERRAL_REWARD_PERCENT,
  getOrCreateCode,
  findInvestorIdByCode,
  setSponsor,
  getSponsorId,
  listDownline,
  getRewardSummary,
  creditReferralReward,
};
