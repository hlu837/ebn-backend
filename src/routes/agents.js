const express = require('express');
const { requireAuth } = require('./auth');

const walletModel = require('../models/agentWallet');
const scheduleModel = require('../models/agentSchedule');
const settingsModel = require('../models/agentSettings');
const membershipModel = require('../models/agentMembership');
const profileModel = require('../models/agentProfile');
const notificationsModel = require('../models/notifications');
const customerNotesModel = require('../models/agentCustomerNotes');
const networkModel = require('../models/agentNetwork');
const usersModel = require('../models/users');
const { broadcastNotification } = require('../socket');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

/**
 * Every route below is scoped to /agents/:agentId. This restricts write
 * access (and the more private reads, like wallet/settings) to either the
 * agent themself or an admin — the same pattern requireRole uses in
 * affiliates.js, just checked against the :agentId param instead of a
 * fixed role list.
 */
function requireSelfOrAdmin(req, res, next) {
  if (req.user.role !== 'admin' && req.user.id !== req.params.agentId) {
    return res.status(403).json({ error: "You can only access your own agent resources." });
  }
  next();
}

const requireOwner = [requireAuth, requireSelfOrAdmin];

// ── Wallet ───────────────────────────────────────────────────────────────

// GET /api/agents/:agentId/wallet
router.get(
  '/:agentId/wallet',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const [summary, transactions] = await Promise.all([
      walletModel.getSummary(req.params.agentId),
      walletModel.listByAgent(req.params.agentId),
    ]);
    res.json({ ...summary, transactions: transactions.map(walletModel.toPublic) });
  })
);

// POST /api/agents/:agentId/wallet/withdraw
// Body: { amount }
router.post(
  '/:agentId/wallet/withdraw',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const { amount } = req.body || {};
    if (typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({ error: 'amount must be a positive number.' });
    }
    const { balance } = await walletModel.getSummary(req.params.agentId);
    if (amount > balance) {
      return res.status(409).json({ error: 'Withdrawal amount exceeds available balance.' });
    }
    // Destination is always read from the agent's saved payout settings —
    // never trust a client-supplied bankAccountLast4, since nothing would
    // stop a caller from passing an arbitrary (or full, unmasked) value
    // straight into the transaction label/column.
    const settings = await settingsModel.getOrCreate(req.params.agentId);
    const bankAccountLast4 = settings.bank_account_last4 || null;
    const label = bankAccountLast4 ? `Withdrawal to ····${bankAccountLast4}` : 'Withdrawal requested';
    const row = await walletModel.requestWithdrawal(req.params.agentId, { amount, bankAccountLast4, label });
    res.status(201).json(walletModel.toPublic(row));
  })
);

// POST /api/agents/:agentId/wallet/transactions/:txId/clear — admin marks a
// pending transaction (commission or withdrawal) as cleared.
router.post(
  '/:agentId/wallet/transactions/:txId/clear',
  requireAuth,
  asyncHandler(async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
    const row = await walletModel.clearTransaction(req.params.agentId, req.params.txId);
    if (!row) return res.status(409).json({ error: 'Transaction not found or already cleared.' });
    const transaction = walletModel.toPublic(row);

    // Only withdrawals clearing count as a "payout" from the agent's
    // perspective — a cleared commission is just money becoming
    // spendable, not a payout landing. Best-effort, same as the
    // new_dispatch/chat_message notifications: a failure here shouldn't
    // fail the clear that triggered it.
    if (transaction.type === 'withdrawal') {
      try {
        const settings = settingsModel.toPublic(await settingsModel.getOrCreate(req.params.agentId));
        const shouldNotify = !settings || settings.notifyPayouts !== false;
        if (shouldNotify) {
          const notifRow = await notificationsModel.create({
            recipientType: 'agent',
            recipientId: req.params.agentId,
            kind: 'payout',
            title: 'Payout sent',
            body: `${transaction.label || 'Your withdrawal'} — ETB ${Math.abs(transaction.amount).toLocaleString('en-US')} has been sent.`,
            relatedId: transaction.id,
          });
          broadcastNotification('agent', req.params.agentId, notificationsModel.toPublic(notifRow));
        }
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error(`[agents] failed to notify agent ${req.params.agentId} of payout`, err);
      }
    }

    res.json(transaction);
  })
);

// POST /api/agents/:agentId/wallet/commission — admin/system credits a
// commission (e.g. once a sale is confirmed). Body: { amount, label, status? }
//
// Routed through networkModel.creditCommission rather than
// walletModel.addCommission directly: if this agent has a sponsor (see
// the Network program below), the sponsor automatically earns their
// override commission in the same call.
router.post(
  '/:agentId/wallet/commission',
  requireAuth,
  asyncHandler(async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
    const { amount, label, status } = req.body || {};
    if (typeof amount !== 'number' || amount <= 0 || !label) {
      return res.status(400).json({ error: 'amount (positive number) and label are required.' });
    }
    const agent = await usersModel.findById(req.params.agentId);
    const { commission, override } = await networkModel.creditCommission(req.params.agentId, {
      amount,
      label,
      status,
      agentName: agent?.full_name,
    });

    if (override) {
      try {
        const notifRow = await notificationsModel.create({
          recipientType: 'agent',
          recipientId: override.sponsorId,
          kind: 'commission',
          title: 'Network commission earned',
          body: `You earned ${networkModel.AGENT_NETWORK_OVERRIDE_PERCENT}% (ETB ${Math.abs(override.transaction.amount).toLocaleString('en-US')}) from ${agent?.full_name || 'an agent in your network'}'s commission.`,
          relatedId: override.transaction.id,
        });
        broadcastNotification('agent', override.sponsorId, notificationsModel.toPublic(notifRow));
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error(`[agents] failed to notify sponsor ${override.sponsorId} of override commission`, err);
      }
    }

    res.status(201).json(walletModel.toPublic(commission));
  })
);

// ── Network (agent-to-agent referral program) ───────────────────────────
// Separate from the Affiliater program: an agent gets their own "AGT-"
// code/link, other agents sign up under it, and every time a downline
// agent earns a commission their sponsor automatically earns
// AGENT_NETWORK_OVERRIDE_PERCENT% on top (see agentNetwork.creditCommission).

// GET /api/agents/:agentId/network — referral code/link, downline list,
// and override earnings summary.
router.get(
  '/:agentId/network',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const membership = await membershipModel.getOrCreate(req.params.agentId);
    if (membership.tier !== 'gold') {
      return res.status(403).json({
        error: 'The agent network is available to Gold members and above.',
      });
    }
    const [code, downline, overrides] = await Promise.all([
      networkModel.getOrCreateCode(req.params.agentId),
      networkModel.listDownline(req.params.agentId),
      networkModel.getOverrideSummary(req.params.agentId),
    ]);
    res.json({
      referralCode: code,
      overridePercent: networkModel.AGENT_NETWORK_OVERRIDE_PERCENT,
      downline,
      overrideEarnings: overrides,
    });
  })
);

// ── Schedule ─────────────────────────────────────────────────────────────

// GET /api/agents/:agentId/schedule
router.get(
  '/:agentId/schedule',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const rows = await scheduleModel.listByAgent(req.params.agentId);
    res.json(rows.map(scheduleModel.toPublic));
  })
);

// POST /api/agents/:agentId/schedule
// Body: { clientName, propertyTitle, address?, startAt, durationMinutes?, status? }
router.post(
  '/:agentId/schedule',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const { clientName, propertyTitle, address, startAt, durationMinutes, status } = req.body || {};
    if (!clientName || !propertyTitle || !startAt) {
      return res.status(400).json({ error: 'clientName, propertyTitle, and startAt are required.' });
    }
    const row = await scheduleModel.create(req.params.agentId, {
      clientName,
      propertyTitle,
      address,
      startAt,
      durationMinutes,
      status,
    });
    res.status(201).json(scheduleModel.toPublic(row));
  })
);

// PATCH /api/agents/:agentId/schedule/:id — reschedule / change status
router.patch(
  '/:agentId/schedule/:id',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const row = await scheduleModel.update(req.params.agentId, req.params.id, req.body || {});
    if (!row) return res.status(404).json({ error: 'Booking not found.' });
    res.json(scheduleModel.toPublic(row));
  })
);

// DELETE /api/agents/:agentId/schedule/:id — cancel
router.delete(
  '/:agentId/schedule/:id',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const row = await scheduleModel.cancel(req.params.agentId, req.params.id);
    if (!row) return res.status(404).json({ error: 'Booking not found.' });
    res.json(scheduleModel.toPublic(row));
  })
);

// ── Settings ─────────────────────────────────────────────────────────────

// GET /api/agents/:agentId/settings
router.get(
  '/:agentId/settings',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const row = await settingsModel.getOrCreate(req.params.agentId);
    res.json(settingsModel.toPublic(row));
  })
);

// PATCH /api/agents/:agentId/settings
// Body: any subset of { notifyNewDispatches, notifyChatMessages, notifyPromotions,
// notifyPayouts, language, bankName, bankAccountHolder, bankAccountNumber }
//
// bankAccountNumber is the FULL account number, but it's only ever used
// transiently here to derive the last 4 digits — never persisted, logged,
// or echoed back. A raw `bankAccountLast4` in the request body is ignored
// on purpose: accepting it directly would let a caller store an arbitrary
// (or full, unmasked) string in a column named "last4".
router.patch(
  '/:agentId/settings',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const { bankAccountNumber, bankAccountLast4: _ignoredRawLast4, ...fields } = req.body || {};
    if (bankAccountNumber !== undefined) {
      // Strip spaces/dashes so numbers copied from a bank app/statement
      // (e.g. "1000 2345 6789" or "1000-2345-6789") still validate.
      const full = String(bankAccountNumber).replace(/[\s-]/g, '').trim();
      if (!/^\d{4,34}$/.test(full)) {
        return res.status(400).json({ error: 'bankAccountNumber must be 4-34 digits.' });
      }
      fields.bankAccountLast4 = full.slice(-4);
      // `full` is intentionally not referenced again — do not add logging
      // of req.body or of this variable anywhere in this handler.
    }
    const row = await settingsModel.update(req.params.agentId, fields);
    res.json(settingsModel.toPublic(row));
  })
);

// ── Membership ───────────────────────────────────────────────────────────

// GET /api/agents/:agentId/membership
router.get(
  '/:agentId/membership',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const [membershipRow, billing] = await Promise.all([
      membershipModel.getOrCreate(req.params.agentId),
      membershipModel.listBilling(req.params.agentId),
    ]);
    res.json({ ...membershipModel.toPublic(membershipRow), billingHistory: billing });
  })
);

// POST /api/agents/:agentId/membership/upgrade — Body: { tier }
router.post(
  '/:agentId/membership/upgrade',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const { tier } = req.body || {};
    if (!tier || !membershipModel.TIERS.includes(tier)) {
      return res.status(400).json({ error: `tier must be one of: ${membershipModel.TIERS.join(', ')}.` });
    }
    const current = await membershipModel.getOrCreate(req.params.agentId);
    if (membershipModel.TIERS.indexOf(tier) < membershipModel.TIERS.indexOf(current.tier)) {
      return res.status(400).json({ error: 'Downgrading isn\'t available — you can only move to a higher tier.' });
    }
    const row = await membershipModel.setTier(req.params.agentId, tier);
    res.json(membershipModel.toPublic(row));
  })
);

// ── Profile (Visibility/Profile screen) ─────────────────────────────────

// GET /api/agents/:agentId/profile — public: anyone can view an agent's profile
router.get(
  '/:agentId/profile',
  asyncHandler(async (req, res) => {
    const [row, summary, reviews] = await Promise.all([
      profileModel.getOrCreate(req.params.agentId),
      profileModel.reviewSummary(req.params.agentId),
      profileModel.listReviews(req.params.agentId),
    ]);
    res.json({ ...profileModel.toPublic(row), ...summary, reviews });
  })
);

// PATCH /api/agents/:agentId/profile — Body: { avatarUrl?, bio?, city?, specialties? }
router.patch(
  '/:agentId/profile',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const { avatarUrl, bio, city, specialties } = req.body || {};
    if (avatarUrl !== undefined && avatarUrl !== null &&
        (typeof avatarUrl !== 'string' || avatarUrl.length > 5 * 1024 * 1024)) {
      return res.status(400).json({ error: 'avatarUrl must be a string no larger than 5 MB.' });
    }
    if (specialties !== undefined && !Array.isArray(specialties)) {
      return res.status(400).json({ error: 'specialties must be an array of strings.' });
    }
    const row = await profileModel.update(req.params.agentId, { avatarUrl, bio, city, specialties });
    res.json(profileModel.toPublic(row));
  })
);

// POST /api/agents/:agentId/profile/boost — Body: { days? } (default 7)
router.post(
  '/:agentId/profile/boost',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const days = Number(req.body?.days) > 0 ? Number(req.body.days) : 7;
    const row = await profileModel.boost(req.params.agentId, days);
    res.json(profileModel.toPublic(row));
  })
);

// POST /api/agents/:agentId/reviews — leave a review (e.g. from a customer
// after a completed sale/tour). Open to any signed-in user, not just the
// agent themself — no requireOwner here.
router.post(
  '/:agentId/reviews',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { reviewerName, stars, quote } = req.body || {};
    const starsNum = Number(stars);
    if (!reviewerName || !quote || !Number.isInteger(starsNum) || starsNum < 1 || starsNum > 5) {
      return res.status(400).json({ error: 'reviewerName, quote, and stars (integer 1-5) are required.' });
    }
    const review = await profileModel.addReview(req.params.agentId, { reviewerName, stars: starsNum, quote });
    res.status(201).json(review);
  })
);

// ── Customer notes ───────────────────────────────────────────────────────
// A running, timestamped log per (agent, customer) — not a single
// overwritable note — so an agent can see how their read on a customer
// changed over time ("called 8/1 — wants Saturday", "called 8/3 —
// pushed to next week") instead of losing prior context on every edit.
// Entries are append-only: there's no update/delete route for one.

// GET /api/agents/:agentId/customer-notes — every entry this agent has
// ever written, across every customer, newest first. Fetched once for
// the whole Customers screen instead of one call per row.
router.get(
  '/:agentId/customer-notes',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const rows = await customerNotesModel.listForAgent(req.params.agentId);
    res.json(rows.map(customerNotesModel.toPublic));
  })
);

// GET /api/agents/:agentId/customer-notes/:customerUserId/entries — the
// full log for one customer, newest first (used when opening that
// customer's note history directly rather than off the cached list above).
router.get(
  '/:agentId/customer-notes/:customerUserId/entries',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const rows = await customerNotesModel.listForCustomer(req.params.agentId, req.params.customerUserId);
    res.json(rows.map(customerNotesModel.toPublic));
  })
);

// POST /api/agents/:agentId/customer-notes/:customerUserId/entries
// Body: { body }. Appends a new timestamped entry to this customer's
// log — it never edits or replaces an existing one.
router.post(
  '/:agentId/customer-notes/:customerUserId/entries',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const { body } = req.body || {};
    if (typeof body !== 'string' || !body.trim()) {
      return res.status(400).json({ error: 'body (non-empty string) is required.' });
    }
    const row = await customerNotesModel.addEntry(req.params.agentId, req.params.customerUserId, body.trim());
    res.status(201).json(customerNotesModel.toPublic(row));
  })
);

// ── Broker Network directory ────────────────────────────────────────────

// GET /api/agents?specialty=&city=&search=&excludeUserId=&userId= — public: the
// Broker Network / map is browsed by visitors before they ever sign up,
// same as the single-agent profile route below. `userId` does an exact
// lookup (used by the listing detail page to resolve one asset's
// assigned broker) — returns a single-item array, or an empty one if
// `userId` doesn't resolve to a real agent (e.g. a listing still holding
// a legacy mock broker id).
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { specialty, city, search, excludeUserId, userId } = req.query;
    const rows = await profileModel.listDirectory({
      specialty: specialty ? String(specialty) : undefined,
      city: city ? String(city) : undefined,
      search: search ? String(search) : undefined,
      excludeUserId: excludeUserId ? String(excludeUserId) : undefined,
      userId: userId ? String(userId) : undefined,
    });
    res.json(rows);
  })
);

module.exports = { router };
