const express = require('express');
const model = require('../models/roleUpgradeRequests');
const usersModel = require('../models/users');
const notificationsModel = require('../models/notifications');
const { broadcastNotification } = require('../socket');
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

const requireAdmin = [requireAuth, requireRole('admin')];

const ROLE_LABELS = { affiliater: 'Affiliater', agent: 'Agent / Broker', investor: 'Investor' };

// ── Visitor: submit + track your own request(s) ──────────────────────────

// POST /api/role-upgrade-requests
// Body: { requestedRole: 'affiliater' | 'agent' | 'investor', message?,
//         agencyOrLicense? (agent only), interestedInFractionalInvesting? (investor only) }
router.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { requestedRole, message, agencyOrLicense, interestedInFractionalInvesting } = req.body || {};

    if (!requestedRole || !model.REQUESTABLE_ROLES.includes(requestedRole)) {
      return res.status(400).json({
        error: `requestedRole must be one of: ${model.REQUESTABLE_ROLES.join(', ')}.`,
      });
    }
    if (req.user.role === requestedRole) {
      return res.status(409).json({ error: `You're already a${requestedRole === 'agent' ? 'n' : ''} ${ROLE_LABELS[requestedRole]}.` });
    }
    if (req.user.role === 'admin') {
      return res.status(409).json({ error: 'Admin accounts cannot request a role change here.' });
    }
    if (requestedRole === 'agent' && (!agencyOrLicense || !String(agencyOrLicense).trim())) {
      return res.status(400).json({ error: 'agencyOrLicense is required when requesting the Agent / Broker role.' });
    }

    const existingPending = await model.findPendingForUser(req.user.id);
    if (existingPending) {
      return res.status(409).json({
        error: `You already have a pending request to become ${ROLE_LABELS[existingPending.requested_role]}. Wait for a decision before submitting another.`,
      });
    }

    const row = await model.create({
      userId: req.user.id,
      requestedRole,
      message,
      agencyOrLicense,
      interestedInFractionalInvesting,
    });
    const created = model.toPublic(row);

    try {
      const notifRow = await notificationsModel.create({
        recipientType: 'admin',
        kind: 'role_upgrade',
        title: 'New role upgrade request',
        body: `${req.user.fullName} requested to become ${ROLE_LABELS[requestedRole]}.`,
        relatedId: created.id,
      });
      broadcastNotification('admin', null, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[roleUpgradeRequests] failed to notify admins of new request', err);
    }

    res.status(201).json(created);
  })
);

// GET /api/role-upgrade-requests/me — this visitor's full history, newest first.
router.get(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await model.listByUser(req.user.id);
    res.json(rows.map(model.toPublic));
  })
);

// ── Admin: review queue ───────────────────────────────────────────────────

// GET /api/role-upgrade-requests/pending
router.get(
  '/pending',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const rows = await model.listPending();
    res.json(rows.map(model.toPublic));
  })
);

// POST /api/role-upgrade-requests/:id/approve
// Body: { adminNote? } — flips the requester's `users.role` on success.
router.post(
  '/:id/approve',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const before = await model.findById(req.params.id);
    if (!before) return res.status(404).json({ error: 'Request not found.' });

    const result = await model.approve(req.params.id, { adminNote: req.body?.adminNote });
    if (!result) return res.status(409).json({ error: 'Request is not awaiting a decision.' });

    try {
      const notifRow = await notificationsModel.create({
        recipientType: before.current_role,
        recipientId: before.user_id,
        kind: 'role_upgrade',
        title: 'Your role upgrade was approved',
        body: `You're now a${before.requested_role === 'agent' ? 'n' : ''} ${ROLE_LABELS[before.requested_role]}. Sign in again to see your new workspace.`,
        relatedId: before.id,
      });
      broadcastNotification(before.current_role, before.user_id, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[roleUpgradeRequests] failed to notify user of approval', err);
    }

    res.json({ request: model.toPublic(result.request), user: usersModel.toPublic(result.user) });
  })
);

// POST /api/role-upgrade-requests/:id/reject
// Body: { adminNote? }
router.post(
  '/:id/reject',
  ...requireAdmin,
  asyncHandler(async (req, res) => {
    const before = await model.findById(req.params.id);
    if (!before) return res.status(404).json({ error: 'Request not found.' });

    const row = await model.reject(req.params.id, { adminNote: req.body?.adminNote });
    if (!row) return res.status(409).json({ error: 'Request is not awaiting a decision.' });

    try {
      const notifRow = await notificationsModel.create({
        recipientType: before.current_role,
        recipientId: before.user_id,
        kind: 'role_upgrade',
        title: 'Your role upgrade was not approved',
        body: req.body?.adminNote
          ? `Your request to become ${ROLE_LABELS[before.requested_role]} was declined: ${req.body.adminNote}`
          : `Your request to become ${ROLE_LABELS[before.requested_role]} was declined. Contact support for details.`,
        relatedId: before.id,
      });
      broadcastNotification(before.current_role, before.user_id, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[roleUpgradeRequests] failed to notify user of rejection', err);
    }

    res.json(model.toPublic(row));
  })
);

module.exports = { router };
