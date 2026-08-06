const { query } = require('../db');

// Mirrors the Flutter `_kTierPerks` / `_kTierMonthlyFeeEtb` const maps in
// affiliate_membership_screen.dart — kept here as the source of truth for
// fee amounts so upgrades can't be spoofed with a client-supplied price.
const TIERS = ['bronze', 'silver', 'gold', 'diamond'];
const TIER_MONTHLY_FEE_ETB = { bronze: 0, silver: 500, gold: 1500, diamond: 3500 };
const TIER_PERKS = {
  bronze: ['10 tokens per referral signup', 'Standard payout processing', 'Email support'],
  silver: [
    '10 tokens per referral signup + 15% bigger commission rate',
    'Faster payout processing',
    'Access to seasonal campaigns',
    'Chat + email support',
  ],
  gold: [
    'Everything in Silver',
    '30% bigger commission rate',
    '"Verified Affiliate" badge on shared links',
    'Priority payout processing',
    'Chat + phone support',
  ],
  diamond: [
    'Everything in Gold',
    '50% bigger commission rate',
    'Dedicated account manager',
    'Early access to new campaigns',
    '24/7 priority support line',
  ],
};

async function getOrCreate(userId) {
  const existing = await query(`SELECT * FROM affiliate_memberships WHERE user_id = $1`, [userId]);
  if (existing.rows[0]) return existing.rows[0];
  const created = await query(
    `INSERT INTO affiliate_memberships (user_id) VALUES ($1)
     ON CONFLICT (user_id) DO UPDATE SET user_id = EXCLUDED.user_id
     RETURNING *`,
    [userId]
  );
  return created.rows[0];
}

function toPublic(row) {
  if (!row) return null;
  return {
    tier: row.tier,
    renewalDate: row.renewal_date,
    monthlyFeeEtb: TIER_MONTHLY_FEE_ETB[row.tier],
    perks: TIER_PERKS[row.tier],
  };
}

function billingToPublic(row) {
  return {
    id: row.id,
    label: row.label,
    amount: Number(row.amount),
    status: row.status,
    billedOn: row.billed_on,
  };
}

function listBilling(userId) {
  return query(
    `SELECT * FROM affiliate_membership_billing WHERE user_id = $1 ORDER BY billed_on DESC, created_at DESC`,
    [userId]
  ).then((r) => r.rows.map(billingToPublic));
}

/**
 * Upgrades/downgrades the affiliate's tier, resets the 30-day renewal
 * window, and records a billing entry. Payment is treated as immediately
 * paid — same "no real gateway wired in yet" state as agentMembership.js.
 */
async function setTier(userId, tier) {
  if (!TIERS.includes(tier)) throw Object.assign(new Error('Invalid tier.'), { status: 400 });
  const row = await query(
    `INSERT INTO affiliate_memberships (user_id, tier, renewal_date)
     VALUES ($1, $2, CURRENT_DATE + INTERVAL '30 days')
     ON CONFLICT (user_id) DO UPDATE
       SET tier = EXCLUDED.tier, renewal_date = EXCLUDED.renewal_date
     RETURNING *`,
    [userId, tier]
  ).then((r) => r.rows[0]);

  const fee = TIER_MONTHLY_FEE_ETB[tier];
  if (fee > 0) {
    await query(
      `INSERT INTO affiliate_membership_billing (user_id, label, amount, status)
       VALUES ($1, $2, $3, 'paid')`,
      [userId, `${tier[0].toUpperCase()}${tier.slice(1)} plan — monthly`, fee]
    );
  }
  return row;
}

module.exports = { TIERS, TIER_MONTHLY_FEE_ETB, TIER_PERKS, toPublic, getOrCreate, listBilling, setTier };
