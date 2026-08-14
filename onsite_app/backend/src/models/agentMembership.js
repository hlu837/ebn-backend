const { query } = require('../db');

// Mirrors the Flutter `_kTierPerks` / `_kTierMonthlyFeeEtb` const maps in
// agent_membership_screen.dart — kept here as the source of truth for fee
// amounts so upgrades can't be spoofed with a client-supplied price.
// These are fallback values; actual pricing is fetched from membership_pricing table.
const TIERS = ['bronze', 'silver', 'gold', 'diamond'];
const TIER_MONTHLY_FEE_ETB = { bronze: 0, silver: 800, gold: 2200, diamond: 5000 };
const TIER_PERKS = {
  bronze: ['List up to 5 active properties', 'Standard search placement', 'Email support'],
  silver: [
    'List up to 20 active properties',
    'Priority search placement',
    'Access to the Broker Network',
    'Chat + email support',
  ],
  gold: [
    'Unlimited active listings',
    'Top search placement + "Verified" badge',
    'Featured on the Property Report leaderboard',
    'Priority dispatch on nearby order requests',
    'Chat + phone support',
  ],
  diamond: [
    'Everything in Gold',
    'Dedicated account manager',
    'Boosted listings included free (up to 3/mo)',
    'Early access to new markets',
    '24/7 priority support line',
  ],
};

/** Fetch tier pricing from database, falling back to hardcoded if unavailable. */
async function getTierPricing() {
  try {
    const result = await query(
      `SELECT tier, monthly_fee_etb FROM membership_pricing WHERE role = 'agent'
       ORDER BY CASE tier WHEN 'bronze' THEN 0 WHEN 'silver' THEN 1 WHEN 'gold' THEN 2 ELSE 3 END`
    );
    const pricing = {};
    for (const row of result.rows) {
      pricing[row.tier] = Number(row.monthly_fee_etb);
    }
    return Object.keys(pricing).length > 0 ? pricing : TIER_MONTHLY_FEE_ETB;
  } catch {
    return TIER_MONTHLY_FEE_ETB;
  }
}

// Cache for tier pricing to avoid repeated DB queries
let cachedPricing = TIER_MONTHLY_FEE_ETB;
let lastPricingFetch = 0;
const PRICING_CACHE_TTL = 60000; // 60 seconds

async function getCachedTierPricing() {
  const now = Date.now();
  if (now - lastPricingFetch > PRICING_CACHE_TTL) {
    cachedPricing = await getTierPricing();
    lastPricingFetch = now;
  }
  return cachedPricing;
}

async function getOrCreate(userId) {
  const existing = await query(`SELECT * FROM agent_memberships WHERE user_id = $1`, [userId]);
  if (existing.rows[0]) return existing.rows[0];
  const created = await query(
    `INSERT INTO agent_memberships (user_id) VALUES ($1)
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

/** Async version that uses cached database pricing */
async function toPublicAsync(row) {
  if (!row) return null;
  const pricing = await getCachedTierPricing();
  return {
    tier: row.tier,
    renewalDate: row.renewal_date,
    monthlyFeeEtb: pricing[row.tier] ?? TIER_MONTHLY_FEE_ETB[row.tier],
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
    `SELECT * FROM agent_membership_billing WHERE user_id = $1 ORDER BY billed_on DESC, created_at DESC`,
    [userId]
  ).then((r) => r.rows.map(billingToPublic));
}

/**
 * Upgrades/downgrades the agent's tier, resets the 30-day renewal window,
 * and records a billing entry. Payment is treated as immediately paid —
 * there's no real payment gateway wired in yet (the codebase's existing
 * Chapa integration in payments.js is the natural place to hook this up
 * to next, same as property-listing fees).
 */
async function setTier(userId, tier) {
  if (!TIERS.includes(tier)) throw Object.assign(new Error('Invalid tier.'), { status: 400 });
  const row = await query(
    `INSERT INTO agent_memberships (user_id, tier, renewal_date)
     VALUES ($1, $2, CURRENT_DATE + INTERVAL '30 days')
     ON CONFLICT (user_id) DO UPDATE
       SET tier = EXCLUDED.tier, renewal_date = EXCLUDED.renewal_date
     RETURNING *`,
    [userId, tier]
  ).then((r) => r.rows[0]);

  const pricing = await getCachedTierPricing();
  const fee = pricing[tier] ?? TIER_MONTHLY_FEE_ETB[tier];
  if (fee > 0) {
    await query(
      `INSERT INTO agent_membership_billing (user_id, label, amount, status)
       VALUES ($1, $2, $3, 'paid')`,
      [userId, `${tier[0].toUpperCase()}${tier.slice(1)} plan — monthly`, fee]
    );
  }
  return row;
}

module.exports = { TIERS, TIER_MONTHLY_FEE_ETB, TIER_PERKS, toPublic, toPublicAsync, getOrCreate, listBilling, setTier, getTierPricing, getCachedTierPricing };
