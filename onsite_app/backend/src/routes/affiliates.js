const express = require('express');
const model = require('../models/affiliates');
const settingsModel = require('../models/affiliateSettings');
const membershipModel = require('../models/affiliateMembership');
const { requireAuth } = require('./auth');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

/** Restricts a route to one or more roles (checked after requireAuth). */
function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: `This endpoint requires one of these roles: ${roles.join(', ')}.` });
    }
    next();
  };
}

const requireAffiliater = [requireAuth, requireRole('affiliater', 'admin')];
const requireAdmin = [requireAuth, requireRole('admin')];

// ── Affiliate code ───────────────────────────────────────────────────────

// GET /api/affiliates/me/code
// Returns the caller's shareable affiliate code, minting one on first call.
router.get(
  '/me/code',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const code = await model.getOrCreateCode(req.user.id);
    res.json({ code });
  })
);

// ── Links / clicks ───────────────────────────────────────────────────────

// POST /api/affiliates/me/links
// Body: { assetId }. "Generate Link" — mints (or reuses) the caller's code,
// logs a click for reporting, and returns a shareable URL. The URL points
// at GET /api/affiliates/r/:code below rather than straight at the app, so
// that an actual open of the link (not just generating it) is what earns
// the affiliate's "other share" click bonus — see that route.
router.post(
  '/me/links',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const { assetId } = req.body || {};
    const code = await model.getOrCreateCode(req.user.id);
    await model.recordClick(req.user.id, assetId || null);
    const apiBase = process.env.PUBLIC_API_URL || `${req.protocol}://${req.get('host')}`;
    const url = assetId
      ? `${apiBase}/api/affiliates/r/${code}?assetId=${assetId}`
      : `${apiBase}/api/affiliates/r/${code}`;
    res.status(201).json({ code, url });
  })
);

// GET /api/affiliates/r/:code — public, no auth (the visitor opening a
// shared link is usually not signed in). This is what a shared link's URL
// actually points at now: it credits the affiliate's 10-token "other
// share" click bonus (capped at once per affiliate per asset per day —
// see creditReferralClick), then forwards the visitor on to the real
// destination in the app with the same ?ref= code, so the existing
// referral-signup auto-fill on the sign-up screen keeps working unchanged.
// Crediting is best-effort: an unknown code, or an already-hit daily cap,
// still redirects — it just doesn't award anything.
router.get(
  '/r/:code',
  asyncHandler(async (req, res) => {
    const { code } = req.params;
    const assetId = req.query.assetId ? String(req.query.assetId) : null;

    try {
      const affiliateId = await model.findUserIdByCode(code);
      if (affiliateId) {
        await model.creditReferralClick({ affiliateId, assetId });
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[affiliates] failed to credit referral click', err);
    }

    const appBase = process.env.PUBLIC_APP_URL || 'https://ebn.et';
    const path = assetId ? `/assets/${assetId}` : '/';
    res.redirect(302, `${appBase}${path}?ref=${encodeURIComponent(code)}`);
  })
);

// ── Referrals ────────────────────────────────────────────────────────────

// GET /api/affiliates/me/referrals?status=pending|completed
router.get(
  '/me/referrals',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const { status } = req.query;
    if (status && !['pending', 'completed'].includes(status)) {
      return res.status(400).json({ error: 'status must be "pending" or "completed".' });
    }
    const rows = await model.listReferrals(req.user.id, { status });
    res.json(rows.map(model.toPublicReferral));
  })
);

// POST /api/affiliates/:affiliateId/referrals — admin only.
// Records a new referral/commission. Manual for now — there's no checkout
// flow yet that tags a sale with the affiliate code that referred it.
// Body: { customerName, customerUserId?, assetId?, assetTitle, commissionAmount, commissionCurrency? }
router.post(
  '/:affiliateId/referrals',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const { customerName, customerUserId, assetId, assetTitle, commissionAmount, commissionCurrency } = req.body || {};
    if (!customerName || !assetTitle || commissionAmount === undefined) {
      return res.status(400).json({ error: 'customerName, assetTitle, and commissionAmount are required.' });
    }
    const amount = Number(commissionAmount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'commissionAmount must be a positive number.' });
    }
    const row = await model.createReferral({
      affiliateId: req.params.affiliateId,
      customerName: String(customerName).trim(),
      customerUserId: customerUserId || null,
      assetId: assetId || null,
      assetTitle: String(assetTitle).trim(),
      commissionAmount: amount,
      commissionCurrency,
    });
    res.status(201).json(model.toPublicReferral(row));
  })
);

// POST /api/affiliates/referrals/:id/complete — admin only.
// Marks a referral's commission as cleared (moves it out of "pending" and
// into what's available for payout).
router.post(
  '/referrals/:id/complete',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const row = await model.markReferralCompleted(req.params.id);
    if (!row) return res.status(409).json({ error: 'Referral is not pending (already completed, or does not exist).' });
    res.json(model.toPublicReferral(row));
  })
);

// ── Earnings & payouts ──────────────────────────────────────────────────

// GET /api/affiliates/me/earnings
router.get(
  '/me/earnings',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const summary = await model.earningsSummary(req.user.id);
    res.json(summary);
  })
);

// POST /api/affiliates/me/payouts
// Body: { amount? } — omit to request everything currently available.
router.post(
  '/me/payouts',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const { amount } = req.body || {};
    const { row, error } = await model.requestPayout(req.user.id, amount);
    if (error) return res.status(400).json({ error });
    res.status(201).json(model.toPublicPayout(row));
  })
);

// GET /api/affiliates/me/payouts
router.get(
  '/me/payouts',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const rows = await model.listPayouts(req.user.id);
    res.json(rows.map(model.toPublicPayout));
  })
);

// POST /api/affiliates/payouts/:id/mark-paid — admin only.
router.post(
  '/payouts/:id/mark-paid',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const row = await model.markPayoutPaid(req.params.id);
    if (!row) return res.status(409).json({ error: 'Payout is not awaiting payment (already paid, or does not exist).' });
    res.json(model.toPublicPayout(row));
  })
);

// ── Tokens ────────────────────────────────────────────────────────────────

// GET /api/affiliates/me/tokens
// Balance, lifetime earned/redeemed, cash value, and the current
// conversion rate / minimum redemption.
router.get(
  '/me/tokens',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const summary = await model.tokenSummary(req.user.id);
    res.json(summary);
  })
);

// GET /api/affiliates/me/tokens/ledger
// Full history of token events (earned from signups, redeemed for cash).
router.get(
  '/me/tokens/ledger',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const rows = await model.listTokenLedger(req.user.id);
    res.json(rows.map(model.toPublicTokenEntry));
  })
);

// POST /api/affiliates/me/tokens/redeem
// Body: { tokens? } — omit to redeem the full balance. Converts tokens to
// cash at the current rate and files a normal payout (source:
// 'token_redemption') that goes through the same admin review as
// commission payouts.
router.post(
  '/me/tokens/redeem',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const { tokens } = req.body || {};
    const { row, error } = await model.redeemTokens(req.user.id, tokens);
    if (error) return res.status(400).json({ error });
    res.status(201).json(model.toPublicPayout(row));
  })
);

// GET /api/affiliates/token-settings — admin only.
// Current signup bonus, ETB-per-token rate, and minimum redeemable amount.
router.get(
  '/token-settings',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const settings = await model.getTokenSettings();
    res.json(model.toPublicTokenSettings(settings));
  })
);

// PATCH /api/affiliates/token-settings — admin only.
// Body: any subset of { signupBonusTokens, clickBonusTokens, etbPerToken, minRedeemableTokens }
router.patch(
  '/token-settings',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const { signupBonusTokens, clickBonusTokens, etbPerToken, minRedeemableTokens } = req.body || {};
    const settings = await model.updateTokenSettings({
      signupBonusTokens,
      clickBonusTokens,
      etbPerToken,
      minRedeemableTokens,
    });
    res.json(model.toPublicTokenSettings(settings));
  })
);

// ── Membership ───────────────────────────────────────────────────────────
// Mirrors GET/POST /api/agents/:agentId/membership* — the same tier +
// billing-history shape, just scoped to the caller's own affiliate account
// rather than an :agentId param, since there's no separate "view another
// affiliate's membership" admin use case yet.

// GET /api/affiliates/me/membership
router.get(
  '/me/membership',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const [membershipRow, billing] = await Promise.all([
      membershipModel.getOrCreate(req.user.id),
      membershipModel.listBilling(req.user.id),
    ]);
    res.json({ ...membershipModel.toPublic(membershipRow), billingHistory: billing });
  })
);

// POST /api/affiliates/me/membership/upgrade — Body: { tier }
router.post(
  '/me/membership/upgrade',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const { tier } = req.body || {};
    if (!tier || !membershipModel.TIERS.includes(tier)) {
      return res.status(400).json({ error: `tier must be one of: ${membershipModel.TIERS.join(', ')}.` });
    }
    const row = await membershipModel.setTier(req.user.id, tier);
    res.json(membershipModel.toPublic(row));
  })
);

// ── Reports ──────────────────────────────────────────────────────────────

// GET /api/affiliates/me/reports
router.get(
  '/me/reports',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const summary = await model.reportsSummary(req.user.id);
    res.json(summary);
  })
);

// ── Settings (payout/banking details + notification prefs) ────────────────
// Name/phone are not here — see PATCH /api/auth/me for those. Row is
// created lazily on first access (see affiliateSettings.getOrCreate).

// GET /api/affiliates/me/settings
router.get(
  '/me/settings',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const row = await settingsModel.getOrCreate(req.user.id);
    res.json(settingsModel.toPublic(row));
  })
);

// PATCH /api/affiliates/me/settings
// Body: any subset of { notifyNewReferrals, notifyPayouts, bankName, bankAccountNumber }
//
// bankAccountNumber is the FULL account number, but it is only ever used
// transiently here to derive the last 4 digits — it is never persisted,
// logged, or echoed back. Only bank_account_last4 is stored/returned, so a
// compromised DB or log stream never exposes the full number.
router.patch(
  '/me/settings',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const { notifyNewReferrals, notifyPayouts, bankName, bankAccountNumber } = req.body || {};
    for (const [key, val] of Object.entries({ notifyNewReferrals, notifyPayouts })) {
      if (val !== undefined && typeof val !== 'boolean') {
        return res.status(400).json({ error: `${key} must be a boolean.` });
      }
    }

    let bankAccountLast4;
    if (bankAccountNumber !== undefined) {
      const full = String(bankAccountNumber).trim();
      if (!/^\d{4,34}$/.test(full)) {
        return res.status(400).json({ error: 'bankAccountNumber must be 4-34 digits.' });
      }
      bankAccountLast4 = full.slice(-4);
      // `full` is intentionally not referenced again below — do not add
      // logging of req.body or of this variable anywhere in this handler.
    }

    const row = await settingsModel.update(req.user.id, {
      notifyNewReferrals,
      notifyPayouts,
      bankName: bankName !== undefined ? String(bankName).trim() : undefined,
      bankAccountLast4,
    });
    res.json(settingsModel.toPublic(row));
  })
);

// ── Campaigns ────────────────────────────────────────────────────────────

// GET /api/affiliates/campaigns
router.get(
  '/campaigns',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const rows = await model.listCampaigns();
    res.json(rows.map(model.toPublicCampaign));
  })
);

// POST /api/affiliates/campaigns — admin only.
// Body: { title, description, badge, icon?, status?, startsAt?, endsAt? }
router.post(
  '/campaigns',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const { title, description, badge, icon, status, startsAt, endsAt } = req.body || {};
    if (!title || !description || !badge) {
      return res.status(400).json({ error: 'title, description, and badge are required.' });
    }
    const row = await model.createCampaign({ title, description, badge, icon, status, startsAt, endsAt });
    res.status(201).json(model.toPublicCampaign(row));
  })
);

// PATCH /api/affiliates/campaigns/:id — admin only.
// Body: any subset of { title, description, badge, icon, status, startsAt, endsAt }
router.patch(
  '/campaigns/:id',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const body = req.body || {};
    const fields = {};
    if (body.title !== undefined) fields.title = body.title;
    if (body.description !== undefined) fields.description = body.description;
    if (body.badge !== undefined) fields.badge = body.badge;
    if (body.icon !== undefined) fields.icon = body.icon;
    if (body.status !== undefined) fields.status = body.status;
    if (body.startsAt !== undefined) fields.starts_at = body.startsAt;
    if (body.endsAt !== undefined) fields.ends_at = body.endsAt;

    const row = await model.updateCampaign(req.params.id, fields);
    if (!row) return res.status(404).json({ error: 'Campaign not found.' });
    res.json(model.toPublicCampaign(row));
  })
);

// ── Notifications ────────────────────────────────────────────────────────

// GET /api/affiliates/me/notifications
router.get(
  '/me/notifications',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const rows = await model.listNotifications(req.user.id);
    res.json(rows.map(model.toPublicNotification));
  })
);

// POST /api/affiliates/me/notifications/:id/read
router.post(
  '/me/notifications/:id/read',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const row = await model.markNotificationRead(req.params.id, req.user.id);
    if (!row) return res.status(404).json({ error: 'Notification not found.' });
    res.json(model.toPublicNotification(row));
  })
);

// POST /api/affiliates/me/notifications/read-all
router.post(
  '/me/notifications/read-all',
  ...requireAffiliater,
  asyncHandler(async (req, res) => {
    const count = await model.markAllNotificationsRead(req.user.id);
    res.json({ markedRead: count });
  })
);

module.exports = { router };
