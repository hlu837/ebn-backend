const express = require('express');
const { requireAuth } = require('./auth');

const walletModel = require('../models/investorWallet');
const commitmentsModel = require('../models/investmentCommitments');
const opportunitiesModel = require('../models/investmentOpportunities');
const notificationsModel = require('../models/notifications');
const networkModel = require('../models/investorNetwork');
const { broadcastNotification } = require('../socket');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

/**
 * Every route below is scoped to /investors/:investorId. Restricts write
 * access (and the more private reads, like wallet) to either the investor
 * themself or an admin — same pattern as agents.js's requireSelfOrAdmin.
 */
function requireSelfOrAdmin(req, res, next) {
  if (req.user.role !== 'admin' && req.user.id !== req.params.investorId) {
    return res.status(403).json({ error: 'You can only access your own investor resources.' });
  }
  next();
}

const requireOwner = [requireAuth, requireSelfOrAdmin];

// GET /api/investors/:investorId/wallet
router.get(
  '/:investorId/wallet',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const [summary, transactions] = await Promise.all([
      walletModel.getSummary(req.params.investorId),
      walletModel.listByInvestor(req.params.investorId),
    ]);
    res.json({ ...summary, transactions: transactions.map(walletModel.toPublic) });
  })
);

// POST /api/investors/:investorId/wallet/withdraw
// Body: { amount, bankAccountLast4? }
router.post(
  '/:investorId/wallet/withdraw',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const { amount, bankAccountLast4 } = req.body || {};
    if (typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({ error: 'amount must be a positive number.' });
    }
    const { balance } = await walletModel.getSummary(req.params.investorId);
    if (amount > balance) {
      return res.status(409).json({ error: 'Withdrawal amount exceeds available balance.' });
    }
    // There's no dedicated investor payout-settings screen yet (see
    // agentSettings for that pattern on the agent side) — for now the
    // destination is whatever the investor supplies on the request itself.
    const last4 = bankAccountLast4 ? String(bankAccountLast4).slice(-4) : null;
    const label = last4 ? `Withdrawal to ····${last4}` : 'Withdrawal requested';
    const row = await walletModel.requestWithdrawal(req.params.investorId, {
      amount,
      bankAccountLast4: last4,
      label,
    });
    res.status(201).json(walletModel.toPublic(row));
  })
);

// POST /api/investors/:investorId/wallet/reinvest
// Investor-only: rolls part of their existing wallet balance into a new
// investment opportunity instead of withdrawing it to a bank account.
// Creates a normal Pending investment commitment (same admin
// approve/reject queue as any other commitment) and debits the wallet
// immediately, since the funds are already the investor's own money
// sitting on the platform — no bank clearance step needed.
// Body: { opportunityId, amount }
router.post(
  '/:investorId/wallet/reinvest',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const { opportunityId, amount } = req.body || {};

    if (!opportunityId) return res.status(400).json({ error: 'opportunityId is required.' });
    if (typeof amount !== 'number' || amount <= 0) {
      return res.status(400).json({ error: 'amount must be a positive number.' });
    }

    const opportunity = await opportunitiesModel.getById(opportunityId);
    if (!opportunity) return res.status(404).json({ error: 'Investment opportunity not found.' });
    if (opportunity.status !== 'Open') {
      return res
        .status(409)
        .json({ error: `This opportunity is ${opportunity.status.toLowerCase()} and no longer accepting commitments.` });
    }
    if (amount < opportunity.minInvestment) {
      return res.status(400).json({
        error: `Minimum investment for this opportunity is ${opportunity.minInvestment}.`,
      });
    }

    const { balance } = await walletModel.getSummary(req.params.investorId);
    if (amount > balance) {
      return res.status(409).json({ error: 'Reinvestment amount exceeds your available wallet balance.' });
    }

    const commitmentRow = await commitmentsModel.create({
      userId: req.params.investorId,
      opportunityId,
      amount,
    });
    const commitment = commitmentsModel.toPublic(commitmentRow);

    const txRow = await walletModel.reinvest(req.params.investorId, {
      amount,
      label: `Reinvested into "${opportunity.title}"`,
      commitmentId: commitment.id,
    });
    const transaction = walletModel.toPublic(txRow);

    try {
      const notifRow = await notificationsModel.create({
        recipientType: 'admin',
        kind: 'investment_commitment',
        title: 'New investment commitment (reinvestment)',
        body: `${req.user.fullName} reinvested ${amount} from their wallet into "${opportunity.title}".`,
        relatedId: commitment.id,
      });
      broadcastNotification('admin', null, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[investorWallet] failed to notify admins of reinvestment', err);
    }

    res.status(201).json({ commitment, transaction });
  })
);

// POST /api/investors/:investorId/wallet/transactions/:txId/clear
// Admin marks a pending transaction (withdrawal, usually) as cleared.
router.post(
  '/:investorId/wallet/transactions/:txId/clear',
  requireAuth,
  asyncHandler(async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
    const row = await walletModel.clearTransaction(req.params.investorId, req.params.txId);
    if (!row) return res.status(409).json({ error: 'Transaction not found or already cleared.' });
    const transaction = walletModel.toPublic(row);

    if (transaction.type === 'withdrawal') {
      try {
        const notifRow = await notificationsModel.create({
          recipientType: 'investor',
          recipientId: req.params.investorId,
          kind: 'payout',
          title: 'Payout sent',
          body: `${transaction.label || 'Your withdrawal'} — ETB ${Math.abs(transaction.amount).toLocaleString('en-US')} has been sent.`,
          relatedId: transaction.id,
        });
        broadcastNotification('investor', req.params.investorId, notificationsModel.toPublic(notifRow));
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error(`[investorWallet] failed to notify investor ${req.params.investorId} of payout`, err);
      }
    }

    res.json(transaction);
  })
);

// POST /api/investors/:investorId/wallet/payout
// Admin-only: credits a payout against a Confirmed investment commitment.
// Body: { amount, label, commitmentId?, status? }
router.post(
  '/:investorId/wallet/payout',
  requireAuth,
  asyncHandler(async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
    const { amount, label, commitmentId, status } = req.body || {};
    if (typeof amount !== 'number' || amount <= 0 || !label) {
      return res.status(400).json({ error: 'amount (positive number) and label are required.' });
    }

    if (commitmentId) {
      const commitment = await commitmentsModel.findById(commitmentId);
      if (!commitment) return res.status(404).json({ error: 'Investment commitment not found.' });
      if (commitment.user_id !== req.params.investorId) {
        return res.status(400).json({ error: 'commitmentId does not belong to this investor.' });
      }
      if (commitment.status !== 'Confirmed') {
        return res.status(409).json({ error: 'Payouts can only be credited against a confirmed commitment.' });
      }
    }

    const row = await walletModel.addPayout(req.params.investorId, { amount, label, status, commitmentId });
    const payout = walletModel.toPublic(row);

    try {
      const notifRow = await notificationsModel.create({
        recipientType: 'investor',
        recipientId: req.params.investorId,
        kind: 'payout',
        title: 'Payout credited',
        body: `${label} — ETB ${Number(amount).toLocaleString('en-US')} was credited to your wallet.`,
        relatedId: payout.id,
      });
      broadcastNotification('investor', req.params.investorId, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(`[investorWallet] failed to notify investor ${req.params.investorId} of payout credit`, err);
    }

    res.status(201).json(payout);
  })
);

// ── Network (investor-to-investor referral program) ──────────────────────
// Separate from the agent network and the Affiliater program: an investor
// gets their own "INV-" code/link, other investors sign up under it, and
// the sponsor earns a one-time reward when a downline investor's first
// commitment is confirmed (see investorNetwork.creditReferralReward,
// triggered from investmentCommitments.js's approve route).

// GET /api/investors/:investorId/network — referral code/link, downline
// list, and reward earnings summary.
router.get(
  '/:investorId/network',
  ...requireOwner,
  asyncHandler(async (req, res) => {
    const [code, downline, rewards] = await Promise.all([
      networkModel.getOrCreateCode(req.params.investorId),
      networkModel.listDownline(req.params.investorId),
      networkModel.getRewardSummary(req.params.investorId),
    ]);
    res.json({
      referralCode: code,
      rewardPercent: networkModel.INVESTOR_REFERRAL_REWARD_PERCENT,
      downline,
      rewardEarnings: rewards,
    });
  })
);

module.exports = { router };
