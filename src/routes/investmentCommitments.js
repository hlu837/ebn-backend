const express = require('express');
const model = require('../models/investmentCommitments');
const opportunitiesModel = require('../models/investmentOpportunities');
const notificationsModel = require('../models/notifications');
const networkModel = require('../models/investorNetwork');
const { broadcastNotification } = require('../socket');
const { requireAuth } = require('./auth');

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
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

const requireInvestor = [requireAuth, requireRole('investor')];
const requireAdmin = [requireAuth, requireRole('admin')];

const router = express.Router();

// ── Investor: commit capital + track your own commitments ────────────────

// POST /api/investment-commitments
// Body: { opportunityId, amount }
router.post(
  '/',
  ...requireInvestor,
  asyncHandler(async (req, res) => {
    const { opportunityId, amount } = req.body || {};

    if (!opportunityId) return res.status(400).json({ error: 'opportunityId is required.' });
    if (amount === undefined || Number.isNaN(Number(amount)) || Number(amount) <= 0) {
      return res.status(400).json({ error: 'amount must be a positive number.' });
    }

    const opportunity = await opportunitiesModel.getById(opportunityId);
    if (!opportunity) return res.status(404).json({ error: 'Investment opportunity not found.' });
    if (opportunity.status !== 'Open') {
      return res.status(409).json({ error: `This opportunity is ${opportunity.status.toLowerCase()} and no longer accepting commitments.` });
    }
    if (Number(amount) < opportunity.minInvestment) {
      return res.status(400).json({
        error: `Minimum investment for this opportunity is ${opportunity.minInvestment}.`,
      });
    }

    const row = await model.create({ userId: req.user.id, opportunityId, amount: Number(amount) });
    const created = model.toPublic(row);

    try {
      const notifRow = await notificationsModel.create({
        recipientType: 'admin',
        kind: 'investment_commitment',
        title: 'New investment commitment',
        body: `${req.user.fullName} committed ${amount} to "${opportunity.title}".`,
        relatedId: created.id,
      });
      broadcastNotification('admin', null, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[investmentCommitments] failed to notify admins of new commitment', err);
    }

    res.status(201).json(created);
  })
);

// GET /api/investment-commitments/me — this investor's full history, newest first.
router.get(
  '/me',
  ...requireInvestor,
  asyncHandler(async (req, res) => {
    const rows = await model.listByUser(req.user.id);
    res.json(rows.map(model.toPublic));
  })
);

// ── Admin: review queue ───────────────────────────────────────────────────

// GET /api/investment-commitments/pending
router.get(
  '/pending',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const rows = await model.listPending();
    res.json(rows.map(model.toPublic));
  })
);

// GET /api/investment-commitments/confirmed
// Admin: every confirmed commitment (active investor holding) — used to
// pick which one a payout should be credited against.
router.get(
  '/confirmed',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const rows = await model.listConfirmed();
    res.json(rows.map(model.toPublic));
  })
);

// POST /api/investment-commitments/:id/approve
// Body: { adminNote? }
router.post(
  '/:id/approve',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const before = await model.findById(req.params.id);
    if (!before) return res.status(404).json({ error: 'Commitment not found.' });

    const row = await model.approve(req.params.id, { adminNote: req.body?.adminNote });
    if (!row) return res.status(409).json({ error: 'Commitment is not awaiting a decision.' });
    const updated = model.toPublic(row);

    try {
      const notifRow = await notificationsModel.create({
        recipientType: 'investor',
        recipientId: before.user_id,
        kind: 'investment_commitment',
        title: 'Your investment was confirmed',
        body: `Your commitment of ${before.amount} to "${before.opportunity_title}" was confirmed.`,
        relatedId: before.id,
      });
      broadcastNotification('investor', before.user_id, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[investmentCommitments] failed to notify investor of approval', err);
    }

    // Investor network: if this is the investor's *first* confirmed
    // commitment and they have a sponsor, credit that sponsor a one-time
    // referral reward — see investorNetwork.creditReferralReward.
    // Best-effort, same as the notification above: never let this block
    // or fail the approval response itself.
    try {
      const confirmedCount = await model.countConfirmedByUser(before.user_id);
      if (confirmedCount === 1) {
        const reward = await networkModel.creditReferralReward(before.user_id, {
          commitmentId: updated.id,
          commitmentAmount: updated.amount,
          investorName: before.user_full_name,
        });
        if (reward) {
          const notifRow = await notificationsModel.create({
            recipientType: 'investor',
            recipientId: reward.sponsorId,
            kind: 'investment_commitment',
            title: 'Referral reward credited',
            body: `You earned ETB ${Math.abs(reward.transaction.amount).toLocaleString('en-US')} (${networkModel.INVESTOR_REFERRAL_REWARD_PERCENT}%) for referring ${before.user_full_name}.`,
            relatedId: reward.transaction.id,
          });
          broadcastNotification('investor', reward.sponsorId, notificationsModel.toPublic(notifRow));
        }
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[investmentCommitments] failed to credit referral reward', err);
    }

    res.json(updated);
  })
);

// POST /api/investment-commitments/:id/reject
// Body: { adminNote? }
router.post(
  '/:id/reject',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const before = await model.findById(req.params.id);
    if (!before) return res.status(404).json({ error: 'Commitment not found.' });

    const row = await model.reject(req.params.id, { adminNote: req.body?.adminNote });
    if (!row) return res.status(409).json({ error: 'Commitment is not awaiting a decision.' });
    const updated = model.toPublic(row);

    try {
      const notifRow = await notificationsModel.create({
        recipientType: 'investor',
        recipientId: before.user_id,
        kind: 'investment_commitment',
        title: 'Your investment was not confirmed',
        body: req.body?.adminNote
          ? `Your commitment to "${before.opportunity_title}" was declined: ${req.body.adminNote}`
          : `Your commitment to "${before.opportunity_title}" was declined. Contact support for details.`,
        relatedId: before.id,
      });
      broadcastNotification('investor', before.user_id, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[investmentCommitments] failed to notify investor of rejection', err);
    }

    res.json(updated);
  })
);

module.exports = { router };
