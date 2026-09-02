const { query } = require('../db');

// Mirrors the Flutter `_kTierPerks` / `_kTierMonthlyFeeEtb` const maps in
// affiliate_membership_screen.dart — kept here as the source of truth for
// fee amounts so upgrades can't be spoofed with a client-supplied price.
// These are fallback values; actual pricing is fetched from membership_pricing table.
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

/** Fetch tier pricing from database, falling back to hardcoded if unavailable. */
async function getTierPricing() {
  try {
    const result = await query(
      `SELECT tier, monthly_fee_etb FROM membership_pricing WHERE role = 'affiliate'
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
    `SELECT * FROM affiliate_membership_billing WHERE user_id = $1 ORDER BY billed_on DESC, created_at DESC`,
    [userId]
  ).then((r) => r.rows.map(billingToPublic));
}

async function ensureBillingEntry(userId, label, fee) {
  const existing = await query(
    `SELECT 1 FROM affiliate_membership_billing
     WHERE user_id = $1 AND label = $2 AND amount = $3 AND status = 'paid'
       AND billed_on = CURRENT_DATE
     LIMIT 1`,
    [userId, label, fee]
  );

  if (existing.rows[0]) return null;

  return query(
    `INSERT INTO affiliate_membership_billing (user_id, label, amount, status)
     VALUES ($1, $2, $3, 'paid')
     RETURNING *`,
    [userId, label, fee]
  ).then((r) => r.rows[0]);
}

/**
 * Upgrades/downgrades the affiliate's tier, resets the 30-day renewal
 * window, and records a billing entry. Payment is treated as immediately
 * paid — same "no real gateway wired in yet" state as agentMembership.js.
 */
/**
 * Upgrades/downgrades the affiliate's tier, resets the 30-day renewal
 * window, and records a billing entry — but only when this is an actual
 * upgrade (moving to a higher-priced tier). Downgrades just switch the
 * tier for the next renewal cycle; they're never billed immediately,
 * even if the destination tier still costs something (e.g. Gold ->
 * Silver shouldn't charge the Silver fee on the spot).
 */
async function setTier(userId, tier) {
  if (!TIERS.includes(tier)) throw Object.assign(new Error('Invalid tier.'), { status: 400 });

  const existing = await query(`SELECT tier FROM affiliate_memberships WHERE user_id = $1`, [userId]);
  const previousTier = existing.rows[0]?.tier ?? 'bronze';
  const isUpgrade = TIERS.indexOf(tier) > TIERS.indexOf(previousTier);

  const row = await query(
    `INSERT INTO affiliate_memberships (user_id, tier, renewal_date)
     VALUES ($1, $2, CURRENT_DATE + INTERVAL '30 days')
     ON CONFLICT (user_id) DO UPDATE
       SET tier = EXCLUDED.tier, renewal_date = EXCLUDED.renewal_date
     RETURNING *`,
    [userId, tier]
  ).then((r) => r.rows[0]);

  if (isUpgrade) {
    const pricing = await getCachedTierPricing();
    const fee = pricing[tier] ?? TIER_MONTHLY_FEE_ETB[tier];
    if (fee > 0) {
      const label = `${tier[0].toUpperCase()}${tier.slice(1)} plan — monthly`;
      await ensureBillingEntry(userId, label, fee);
    }
  }
  return row;
}

module.exports = { TIERS, TIER_MONTHLY_FEE_ETB, TIER_PERKS, toPublic, toPublicAsync, getOrCreate, listBilling, setTier, getTierPricing, getCachedTierPricing };
