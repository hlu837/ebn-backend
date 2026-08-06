const crypto = require('crypto');
const { query } = require('../db');
const notificationsModel = require('./notifications');
const { broadcastNotification } = require('../socket');

// ── Shape converters ────────────────────────────────────────────────────

function toPublicReferral(row) {
  if (!row) return null;
  return {
    id: row.id,
    affiliateId: row.affiliate_id,
    customerName: row.customer_name,
    customerUserId: row.customer_user_id,
    assetId: row.asset_id,
    assetTitle: row.asset_title,
    commissionAmount: Number(row.commission_amount),
    commissionCurrency: row.commission_currency,
    status: row.status,
    isPending: row.status === 'pending',
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function toPublicPayout(row) {
  if (!row) return null;
  return {
    id: row.id,
    affiliateId: row.affiliate_id,
    amount: Number(row.amount),
    currency: row.currency,
    status: row.status,
    source: row.source,
    requestedAt: row.requested_at,
    paidAt: row.paid_at,
  };
}

function toPublicTokenEntry(row) {
  if (!row) return null;
  return {
    id: row.id,
    affiliateId: row.affiliate_id,
    type: row.type,
    amount: Number(row.amount),
    reason: row.reason,
    referredUserId: row.referred_user_id,
    referredUserName: row.referred_user_name,
    payoutId: row.payout_id,
    createdAt: row.created_at,
  };
}

function toPublicTokenSettings(row) {
  if (!row) return null;
  return {
    signupBonusTokens: row.signup_bonus_tokens,
    clickBonusTokens: row.click_bonus_tokens,
    etbPerToken: Number(row.etb_per_token),
    minRedeemableTokens: row.min_redeemable_tokens,
    updatedAt: row.updated_at,
  };
}

function toPublicCampaign(row) {
  if (!row) return null;
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    badge: row.badge,
    icon: row.icon,
    status: row.status,
    startsAt: row.starts_at,
    endsAt: row.ends_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/**
 * Affiliate notifications used to live in their own `affiliate_notifications`
 * table (011_affiliates.sql), predating the generic notifications feed
 * (023_notifications.sql). They're now the 'affiliater' slice of that
 * shared table (see 024/025_*.sql for the migration) — this reads a raw
 * `notifications` row (recipient_id, not affiliate_id) but keeps the same
 * public shape so nothing calling toPublicNotification needs to change.
 */
function toPublicNotification(row) {
  if (!row) return null;
  return {
    id: row.id,
    affiliateId: row.recipient_id,
    kind: row.kind,
    title: row.title,
    body: row.body,
    isRead: row.is_read,
    createdAt: row.created_at,
  };
}

// ── Affiliate code ──────────────────────────────────────────────────────

function generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I — easier to read aloud
  let suffix = '';
  for (let i = 0; i < 6; i += 1) {
    suffix += chars[crypto.randomInt(chars.length)];
  }
  return `EBN-${suffix}`;
}

/**
 * Returns the caller's existing affiliate code, minting one on first call.
 * Retries on the rare unique-constraint collision.
 */
async function getOrCreateCode(userId) {
  const { rows } = await query('SELECT affiliate_code FROM users WHERE id = $1', [userId]);
  if (rows[0]?.affiliate_code) return rows[0].affiliate_code;

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const code = generateCode();
    try {
      const { rows: updated } = await query(
        `UPDATE users SET affiliate_code = $2 WHERE id = $1 AND affiliate_code IS NULL RETURNING affiliate_code`,
        [userId, code]
      );
      if (updated[0]) return updated[0].affiliate_code;
      // Someone else set it concurrently — re-read and return that.
      const { rows: reread } = await query('SELECT affiliate_code FROM users WHERE id = $1', [userId]);
      if (reread[0]?.affiliate_code) return reread[0].affiliate_code;
    } catch (err) {
      if (err.code !== '23505') throw err; // unique_violation -> retry with a new code
    }
  }
  throw new Error('Could not generate a unique affiliate code — try again.');
}

async function findUserIdByCode(code) {
  const { rows } = await query('SELECT id FROM users WHERE affiliate_code = $1', [code]);
  return rows[0]?.id || null;
}

// ── Referrals ────────────────────────────────────────────────────────────

async function listReferrals(affiliateId, { status } = {}) {
  const params = [affiliateId];
  let sql = 'SELECT * FROM affiliate_referrals WHERE affiliate_id = $1';
  if (status) {
    params.push(status);
    sql += ` AND status = $${params.length}`;
  }
  sql += ' ORDER BY created_at DESC';
  const { rows } = await query(sql, params);
  return rows;
}

/**
 * Records a new referral/commission row. There's no automated
 * sale-attribution pipeline yet (no checkout flow tags a sale with the
 * affiliate code that referred it), so this is called by an admin for now
 * — see POST /api/affiliates/:affiliateId/referrals.
 */
async function createReferral({ affiliateId, customerName, customerUserId, assetId, assetTitle, commissionAmount, commissionCurrency }) {
  const { rows } = await query(
    `INSERT INTO affiliate_referrals
       (affiliate_id, customer_name, customer_user_id, asset_id, asset_title, commission_amount, commission_currency)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [affiliateId, customerName, customerUserId || null, assetId || null, assetTitle, commissionAmount, commissionCurrency || 'ETB']
  );
  const row = rows[0];
  await createNotification({
    affiliateId,
    kind: 'referral',
    title: 'New referral',
    body: `${customerName} was referred for "${assetTitle}" — commission pending.`,
  });
  return row;
}

async function markReferralCompleted(id) {
  const { rows } = await query(
    `UPDATE affiliate_referrals SET status = 'completed' WHERE id = $1 AND status = 'pending' RETURNING *`,
    [id]
  );
  const row = rows[0] || null;
  if (row) {
    await createNotification({
      affiliateId: row.affiliate_id,
      kind: 'commission',
      title: 'Commission cleared',
      body: `Your ${Number(row.commission_amount).toFixed(0)} ${row.commission_currency} commission for "${row.asset_title}" has cleared and is available for payout.`,
    });
  }
  return row;
}

// ── Earnings & payouts ──────────────────────────────────────────────────

async function earningsSummary(affiliateId) {
  const { rows } = await query(
    `SELECT
       COALESCE(SUM(commission_amount), 0) AS total_earned,
       COALESCE(SUM(commission_amount) FILTER (WHERE status = 'pending'), 0) AS pending
     FROM affiliate_referrals
     WHERE affiliate_id = $1`,
    [affiliateId]
  );
  const { rows: payoutRows } = await query(
    `SELECT
       COALESCE(SUM(amount) FILTER (WHERE status = 'paid'), 0) AS paid_out,
       COALESCE(SUM(amount) FILTER (WHERE status = 'processing'), 0) AS processing
     FROM affiliate_payouts
     WHERE affiliate_id = $1`,
    [affiliateId]
  );

  const totalEarned = Number(rows[0].total_earned);
  const pending = Number(rows[0].pending);
  const paidOut = Number(payoutRows[0].paid_out);
  const processing = Number(payoutRows[0].processing);
  // Funds already tied up in a paid or in-flight payout request can't be
  // requested again — otherwise the same commission could be claimed twice
  // before an admin gets to review the first request.
  const availableForPayout = Math.max(0, totalEarned - pending - paidOut - processing);

  return { totalEarned, pending, paidOut, processing, availableForPayout };
}

async function requestPayout(affiliateId, amount) {
  const requested = amount != null ? Number(amount) : null;
  if (requested != null && (!Number.isFinite(requested) || requested <= 0)) {
    return { error: 'amount must be a positive number.' };
  }

  // Single atomic statement: recomputes what's available from committed
  // data and only inserts if the requested amount (or, if omitted, the
  // full available balance) fits — avoids the read-then-write race where
  // two requests could both see the same "available" balance and both
  // succeed before either is marked paid.
  const { rows } = await query(
    `WITH earned AS (
       SELECT
         COALESCE(SUM(commission_amount), 0) AS total_earned,
         COALESCE(SUM(commission_amount) FILTER (WHERE status = 'pending'), 0) AS pending
       FROM affiliate_referrals WHERE affiliate_id = $1
     ),
     paid AS (
       SELECT
         COALESCE(SUM(amount) FILTER (WHERE status = 'paid'), 0) AS paid_out,
         COALESCE(SUM(amount) FILTER (WHERE status = 'processing'), 0) AS processing
       FROM affiliate_payouts WHERE affiliate_id = $1
     ),
     calc AS (
       SELECT GREATEST(0, earned.total_earned - earned.pending - paid.paid_out - paid.processing) AS available
       FROM earned, paid
     )
     INSERT INTO affiliate_payouts (affiliate_id, amount)
     SELECT $1, COALESCE($2, calc.available)
     FROM calc
     WHERE COALESCE($2, calc.available) > 0 AND COALESCE($2, calc.available) <= calc.available
     RETURNING *`,
    [affiliateId, requested]
  );

  if (!rows[0]) {
    const summary = await earningsSummary(affiliateId);
    if (summary.availableForPayout <= 0) {
      return { error: 'Nothing is currently available for payout.' };
    }
    return { error: `Only ${summary.availableForPayout.toFixed(2)} ETB is available for payout.` };
  }
  return { row: rows[0] };
}

async function listPayouts(affiliateId) {
  const { rows } = await query(
    'SELECT * FROM affiliate_payouts WHERE affiliate_id = $1 ORDER BY requested_at DESC',
    [affiliateId]
  );
  return rows;
}

async function markPayoutPaid(id) {
  const { rows } = await query(
    `UPDATE affiliate_payouts SET status = 'paid', paid_at = now() WHERE id = $1 AND status = 'processing' RETURNING *`,
    [id]
  );
  const row = rows[0] || null;
  if (row) {
    await createNotification({
      affiliateId: row.affiliate_id,
      kind: 'payout',
      title: 'Payout sent',
      body: `Your payout of ${Number(row.amount).toFixed(0)} ${row.currency} was sent.`,
    });
  }
  return row;
}

// ── Tokens ────────────────────────────────────────────────────────────────
// A reward layer separate from affiliate_referrals/commissions: tokens are
// credited automatically when someone signs up using the affiliate's
// referral code (see routes/auth.js signup + creditSignupTokens below), and
// can be redeemed for cash, which files a normal affiliate_payouts row so it
// goes through the same admin payout pipeline commissions already use.

async function getTokenSettings() {
  const { rows } = await query('SELECT * FROM affiliate_token_settings WHERE id = true');
  return rows[0];
}

async function updateTokenSettings({ signupBonusTokens, clickBonusTokens, etbPerToken, minRedeemableTokens }) {
  const { rows } = await query(
    `UPDATE affiliate_token_settings
     SET signup_bonus_tokens = COALESCE($1, signup_bonus_tokens),
         click_bonus_tokens = COALESCE($2, click_bonus_tokens),
         etb_per_token = COALESCE($3, etb_per_token),
         min_redeemable_tokens = COALESCE($4, min_redeemable_tokens)
     WHERE id = true
     RETURNING *`,
    [signupBonusTokens ?? null, clickBonusTokens ?? null, etbPerToken ?? null, minRedeemableTokens ?? null]
  );
  return rows[0];
}

/**
 * Credits an affiliate with their signup bonus for a new referred user.
 * Called from POST /api/auth/signup when the new account's referralCode
 * matches an existing affiliate_code — see findUserIdByCode.
 */
async function creditSignupTokens({ affiliateId, referredUserId, referredUserName }) {
  const settings = await getTokenSettings();
  const bonus = settings.signup_bonus_tokens;

  const { rows } = await query(
    `INSERT INTO affiliate_token_ledger
       (affiliate_id, type, amount, reason, referred_user_id, referred_user_name)
     VALUES ($1, 'earned', $2, $3, $4, $5)
     RETURNING *`,
    [affiliateId, bonus, `Referral signup: ${referredUserName}`, referredUserId || null, referredUserName]
  );
  const ledgerRow = rows[0];

  const notificationRow = await createNotification({
    affiliateId,
    kind: 'token',
    title: 'New referral signup',
    body: `${referredUserName} registered using your referral link — you earned ${bonus} tokens.`,
  });
  broadcastNotification('affiliater', affiliateId, notificationsModel.toPublic(notificationRow));

  return { ledgerRow, notificationRow };
}

/**
 * Credits an affiliate's smaller "someone clicked my shared link" bonus —
 * a much weaker signal than a signup, so it's worth less and capped at one
 * reward per affiliate per asset per day (see the unique index on
 * affiliate_click_rewards) so the affiliate can't farm tokens by repeatedly
 * opening their own link. Called from the public GET /api/affiliates/r/:code
 * redirect a shared link now points at — never from an authenticated
 * request, since the clicker is usually just a visitor, not signed in.
 *
 * Best-effort and silent either way: if the cap has already been hit today
 * this simply does not credit anything, and the caller still redirects the
 * visitor on to the real destination regardless of the outcome here.
 */
async function creditReferralClick({ affiliateId, assetId }) {
  const { rows: inserted } = await query(
    `INSERT INTO affiliate_click_rewards (affiliate_id, asset_id)
     VALUES ($1, $2)
     ON CONFLICT (affiliate_id, COALESCE(asset_id, ''), click_day) DO NOTHING
     RETURNING *`,
    [affiliateId, assetId || null]
  );
  if (!inserted[0]) {
    return { rewarded: false };
  }

  const settings = await getTokenSettings();
  const bonus = settings.click_bonus_tokens;

  const { rows } = await query(
    `INSERT INTO affiliate_token_ledger (affiliate_id, type, amount, reason)
     VALUES ($1, 'earned', $2, $3)
     RETURNING *`,
    [affiliateId, bonus, assetId ? `Shared link clicked (asset ${assetId})` : 'Shared link clicked']
  );
  const ledgerRow = rows[0];

  const notificationRow = await createNotification({
    affiliateId,
    kind: 'token',
    title: 'Your link was clicked',
    body: `Someone opened your shared link — you earned ${bonus} tokens.`,
  });
  broadcastNotification('affiliater', affiliateId, notificationsModel.toPublic(notificationRow));

  return { rewarded: true, ledgerRow, notificationRow };
}

async function tokenBalance(affiliateId) {
  const { rows } = await query(
    `SELECT COALESCE(SUM(amount), 0) AS balance FROM affiliate_token_ledger WHERE affiliate_id = $1`,
    [affiliateId]
  );
  return Number(rows[0].balance);
}

async function tokenSummary(affiliateId) {
  const { rows } = await query(
    `SELECT
       COALESCE(SUM(amount) FILTER (WHERE type = 'earned'), 0) AS total_earned,
       COALESCE(SUM(-amount) FILTER (WHERE type = 'redeemed'), 0) AS total_redeemed,
       COALESCE(SUM(amount), 0) AS balance
     FROM affiliate_token_ledger WHERE affiliate_id = $1`,
    [affiliateId]
  );
  const settings = await getTokenSettings();
  const balance = Number(rows[0].balance);
  const etbPerToken = Number(settings.etb_per_token);

  return {
    balance,
    totalEarned: Number(rows[0].total_earned),
    totalRedeemed: Number(rows[0].total_redeemed),
    cashValue: balance * etbPerToken,
    etbPerToken,
    minRedeemableTokens: settings.min_redeemable_tokens,
  };
}

async function listTokenLedger(affiliateId) {
  const { rows } = await query(
    'SELECT * FROM affiliate_token_ledger WHERE affiliate_id = $1 ORDER BY created_at DESC',
    [affiliateId]
  );
  return rows;
}

/**
 * Converts `tokens` (or, if omitted, the caller's full balance) into a cash
 * payout at the current etb_per_token rate. One atomic statement so a
 * double-tap can't redeem the same tokens twice: it recomputes the balance
 * and rate from committed data and only inserts if the requested amount
 * clears both the current balance and the minimum-redemption floor.
 */
async function redeemTokens(affiliateId, tokens) {
  const requested = tokens != null ? Number(tokens) : null;
  if (requested != null && (!Number.isInteger(requested) || requested <= 0)) {
    return { error: 'tokens must be a positive whole number.' };
  }

  const { rows } = await query(
    `WITH balance AS (
       SELECT COALESCE(SUM(amount), 0) AS balance FROM affiliate_token_ledger WHERE affiliate_id = $1
     ),
     settings AS (
       SELECT etb_per_token, min_redeemable_tokens FROM affiliate_token_settings WHERE id = true
     ),
     requested AS (
       SELECT COALESCE($2, balance.balance) AS tokens FROM balance
     ),
     new_payout AS (
       INSERT INTO affiliate_payouts (affiliate_id, amount, currency, status, source)
       SELECT $1, requested.tokens * settings.etb_per_token, 'ETB', 'processing', 'token_redemption'
       FROM requested, settings, balance
       WHERE requested.tokens > 0
         AND requested.tokens <= balance.balance
         AND requested.tokens >= settings.min_redeemable_tokens
       RETURNING *
     ),
     ledger_entry AS (
       INSERT INTO affiliate_token_ledger (affiliate_id, type, amount, reason, payout_id)
       SELECT $1, 'redeemed', -requested.tokens,
              'Redeemed ' || requested.tokens || ' tokens for cash', new_payout.id
       FROM requested, new_payout
       RETURNING amount
     )
     SELECT new_payout.*, -ledger_entry.amount AS tokens_redeemed
     FROM new_payout, ledger_entry`,
    [affiliateId, requested]
  );

  if (!rows[0]) {
    const [summary, settings] = await Promise.all([tokenSummary(affiliateId), getTokenSettings()]);
    if (summary.balance <= 0) {
      return { error: 'You have no tokens available to redeem.' };
    }
    if ((requested ?? summary.balance) < settings.min_redeemable_tokens) {
      return { error: `You must redeem at least ${settings.min_redeemable_tokens} tokens at a time.` };
    }
    return { error: `Only ${summary.balance} tokens are available to redeem.` };
  }

  const row = rows[0];
  const notificationRow = await createNotification({
    affiliateId,
    kind: 'token',
    title: 'Tokens redeemed',
    body: `You redeemed ${row.tokens_redeemed} tokens for ${Number(row.amount).toFixed(0)} ${row.currency} — your payout is processing.`,
  });
  broadcastNotification('affiliater', affiliateId, notificationsModel.toPublic(notificationRow));

  return { row };
}

// ── Campaigns ────────────────────────────────────────────────────────────

async function listCampaigns() {
  const { rows } = await query(
    `SELECT * FROM affiliate_campaigns
     ORDER BY (status = 'active') DESC, (status = 'upcoming') DESC, created_at DESC`
  );
  return rows;
}

async function createCampaign({ title, description, badge, icon, status, startsAt, endsAt }) {
  const { rows } = await query(
    `INSERT INTO affiliate_campaigns (title, description, badge, icon, status, starts_at, ends_at)
     VALUES ($1, $2, $3, $4, COALESCE($5, 'upcoming'), $6, $7)
     RETURNING *`,
    [title, description, badge, icon || 'campaign', status || null, startsAt || null, endsAt || null]
  );
  return rows[0];
}

async function updateCampaign(id, fields) {
  const allowed = ['title', 'description', 'badge', 'icon', 'status', 'starts_at', 'ends_at'];
  const keys = Object.keys(fields).filter((k) => allowed.includes(k));
  if (!keys.length) return findCampaignById(id);

  const setClauses = keys.map((k, i) => `${k} = $${i + 2}`);
  const values = keys.map((k) => fields[k]);
  const { rows } = await query(
    `UPDATE affiliate_campaigns SET ${setClauses.join(', ')} WHERE id = $1 RETURNING *`,
    [id, ...values]
  );
  return rows[0] || null;
}

async function findCampaignById(id) {
  const { rows } = await query('SELECT * FROM affiliate_campaigns WHERE id = $1', [id]);
  return rows[0] || null;
}

// ── Clicks & reports ─────────────────────────────────────────────────────

async function recordClick(affiliateId, assetId) {
  const { rows } = await query(
    `INSERT INTO affiliate_clicks (affiliate_id, asset_id) VALUES ($1, $2) RETURNING *`,
    [affiliateId, assetId || null]
  );
  return rows[0];
}

/**
 * Totals + a month-by-month breakdown of clicks, referrals, and cleared
 * commission for the Reports screen.
 */
async function reportsSummary(affiliateId) {
  const { rows: clickRows } = await query(
    `SELECT to_char(created_at, 'YYYY-MM') AS month, COUNT(*)::int AS clicks
     FROM affiliate_clicks WHERE affiliate_id = $1 GROUP BY 1`,
    [affiliateId]
  );
  const { rows: referralRows } = await query(
    `SELECT
       to_char(created_at, 'YYYY-MM') AS month,
       COUNT(*)::int AS referrals,
       COALESCE(SUM(commission_amount), 0) AS commission
     FROM affiliate_referrals WHERE affiliate_id = $1 GROUP BY 1`,
    [affiliateId]
  );

  const byMonth = new Map();
  for (const r of clickRows) {
    byMonth.set(r.month, { month: r.month, clicks: r.clicks, referrals: 0, commission: 0 });
  }
  for (const r of referralRows) {
    const existing = byMonth.get(r.month) || { month: r.month, clicks: 0, referrals: 0, commission: 0 };
    existing.referrals = r.referrals;
    existing.commission = Number(r.commission);
    byMonth.set(r.month, existing);
  }

  const monthly = Array.from(byMonth.values()).sort((a, b) => (a.month < b.month ? 1 : -1));

  const totalClicks = monthly.reduce((sum, m) => sum + m.clicks, 0);
  const totalReferrals = monthly.reduce((sum, m) => sum + m.referrals, 0);
  const totalCommission = monthly.reduce((sum, m) => sum + m.commission, 0);
  const conversionRate = totalClicks === 0 ? 0 : (totalReferrals / totalClicks) * 100;

  return { totalClicks, totalReferrals, totalCommission, conversionRate, monthly };
}

// ── Notifications ────────────────────────────────────────────────────────
// Thin wrappers over the generic notifications model (see the comment on
// toPublicNotification above) — same function names/signatures/return
// shapes as before, so routes/affiliates.js and the Flutter side don't
// need to change.

function createNotification({ affiliateId, kind, title, body }) {
  return notificationsModel.create({ recipientType: 'affiliater', recipientId: affiliateId, kind, title, body });
}

function listNotifications(affiliateId) {
  return notificationsModel.listForRecipient('affiliater', affiliateId);
}

function markNotificationRead(id, affiliateId) {
  return notificationsModel.markRead(id, 'affiliater', affiliateId);
}

function markAllNotificationsRead(affiliateId) {
  return notificationsModel.markAllRead('affiliater', affiliateId);
}

module.exports = {
  toPublicReferral,
  toPublicPayout,
  toPublicTokenEntry,
  toPublicTokenSettings,
  toPublicCampaign,
  toPublicNotification,
  getOrCreateCode,
  findUserIdByCode,
  listReferrals,
  createReferral,
  markReferralCompleted,
  earningsSummary,
  requestPayout,
  listPayouts,
  markPayoutPaid,
  getTokenSettings,
  updateTokenSettings,
  creditSignupTokens,
  creditReferralClick,
  tokenBalance,
  tokenSummary,
  listTokenLedger,
  redeemTokens,
  listCampaigns,
  createCampaign,
  updateCampaign,
  findCampaignById,
  recordClick,
  reportsSummary,
  createNotification,
  listNotifications,
  markNotificationRead,
  markAllNotificationsRead,
};
