const crypto = require('crypto');
const { query } = require('../db');
const walletModel = require('./agentWallet');

/**
 * Percent of a downline agent's commission their sponsor automatically
 * earns as an override, the moment the downline's commission is credited.
 * Single source of truth — everything below reads from here.
 */
const AGENT_NETWORK_OVERRIDE_PERCENT = 6;

// ── Referral code ────────────────────────────────────────────────────────
// Same shape/collision-retry pattern as affiliates.generateCode /
// getOrCreateCode, just a distinct "AGT-" prefix and column so the two
// referral programs never share codes.

function generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I — easier to read aloud
  let suffix = '';
  for (let i = 0; i < 6; i += 1) {
    suffix += chars[crypto.randomInt(chars.length)];
  }
  return `AGT-${suffix}`;
}

async function getOrCreateCode(agentId) {
  const { rows } = await query('SELECT agent_referral_code FROM users WHERE id = $1', [agentId]);
  if (rows[0]?.agent_referral_code) return rows[0].agent_referral_code;

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const code = generateCode();
    try {
      const { rows: updated } = await query(
        `UPDATE users SET agent_referral_code = $2 WHERE id = $1 AND agent_referral_code IS NULL RETURNING agent_referral_code`,
        [agentId, code]
      );
      if (updated[0]) return updated[0].agent_referral_code;
      const { rows: reread } = await query('SELECT agent_referral_code FROM users WHERE id = $1', [agentId]);
      if (reread[0]?.agent_referral_code) return reread[0].agent_referral_code;
    } catch (err) {
      if (err.code !== '23505') throw err; // unique_violation -> retry with a new code
    }
  }
  throw new Error('Could not generate a unique agent referral code — try again.');
}

async function findAgentIdByCode(code) {
  const { rows } = await query(
    `SELECT id FROM users WHERE agent_referral_code = $1 AND role = 'agent'`,
    [code]
  );
  return rows[0]?.id || null;
}

// ── Sponsorship ──────────────────────────────────────────────────────────

/**
 * Links a newly-created agent to the sponsor whose referral code they
 * signed up with. Only ever set once — a no-op if this agent already has
 * a sponsor, and refuses to let an agent sponsor themself.
 */
async function setSponsor(agentId, sponsorAgentId) {
  if (!sponsorAgentId || sponsorAgentId === agentId) return null;
  const { rows } = await query(
    `UPDATE users SET sponsor_agent_id = $2
     WHERE id = $1 AND role = 'agent' AND sponsor_agent_id IS NULL
     RETURNING sponsor_agent_id`,
    [agentId, sponsorAgentId]
  );
  return rows[0]?.sponsor_agent_id || null;
}

async function getSponsorId(agentId) {
  const { rows } = await query('SELECT sponsor_agent_id FROM users WHERE id = $1', [agentId]);
  return rows[0]?.sponsor_agent_id || null;
}

// ── Downline & earnings ─────────────────────────────────────────────────

/** Every agent directly recruited by this agent, with their own commission totals. */
async function listDownline(agentId) {
  const { rows } = await query(
    `SELECT
       u.id, u.full_name, u.email, u.created_at AS joined_at,
       COALESCE(SUM(t.amount) FILTER (WHERE t.type = 'commission' AND t.source_agent_id IS NULL), 0) AS total_earned
     FROM users u
     LEFT JOIN agent_wallet_transactions t ON t.agent_id = u.id
     WHERE u.sponsor_agent_id = $1 AND u.role = 'agent'
     GROUP BY u.id
     ORDER BY u.created_at DESC`,
    [agentId]
  );
  return rows.map((row) => ({
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    joinedAt: row.joined_at,
    totalEarned: Number(row.total_earned),
  }));
}

/** Total override commissions this agent has earned from their downline, cleared + pending. */
async function getOverrideSummary(agentId) {
  const { rows } = await query(
    `SELECT
       COALESCE(SUM(amount) FILTER (WHERE status = 'cleared'), 0) AS cleared,
       COALESCE(SUM(amount) FILTER (WHERE status = 'pending'), 0) AS pending
     FROM agent_wallet_transactions
     WHERE agent_id = $1 AND type = 'commission' AND source_agent_id IS NOT NULL`,
    [agentId]
  );
  const row = rows[0] || { cleared: 0, pending: 0 };
  return { cleared: Number(row.cleared), pending: Number(row.pending) };
}

/**
 * Credits a direct commission to `agentId` and, if they have a sponsor,
 * automatically credits that sponsor an override of
 * AGENT_NETWORK_OVERRIDE_PERCENT % of the same amount — this is the one
 * place a commission should ever be added so the override always fires.
 * Returns { commission, override } — override is null if there's no sponsor.
 */
async function creditCommission(agentId, { amount, label, status = 'pending', agentName }) {
  const commission = await walletModel.addCommission(agentId, { amount, label, status });

  const sponsorId = await getSponsorId(agentId);
  let override = null;
  if (sponsorId) {
    const overrideAmount = Math.round(amount * (AGENT_NETWORK_OVERRIDE_PERCENT / 100) * 100) / 100;
    if (overrideAmount > 0) {
      const overrideLabel = `${AGENT_NETWORK_OVERRIDE_PERCENT}% override — ${agentName || 'agent in your network'}`;
      const { rows } = await query(
        `INSERT INTO agent_wallet_transactions (agent_id, type, amount, label, status, source_agent_id)
         VALUES ($1, 'commission', $2, $3, $4, $5)
         RETURNING *`,
        [sponsorId, overrideAmount, overrideLabel, status, agentId]
      );
      override = { sponsorId, transaction: walletModel.toPublic(rows[0]) };
    }
  }

  return { commission, override };
}

module.exports = {
  AGENT_NETWORK_OVERRIDE_PERCENT,
  getOrCreateCode,
  findAgentIdByCode,
  setSponsor,
  getSponsorId,
  listDownline,
  getOverrideSummary,
  creditCommission,
};
