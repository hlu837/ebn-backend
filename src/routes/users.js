const express = require('express');
const { requireAuth } = require('./auth');

const model = require('../models/users');
const activityLogModel = require('../models/activityLog');

const router = express.Router();

const MAX_LIMIT = 100;
const DEFAULT_LIMIT = 20;

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

function requireAdmin(req, res, next) {
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
  next();
}

// GET /api/users?role=&search=&limit=&offset= — Admin > Users list.
router.get(
  '/',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    let limit = req.query.limit !== undefined ? Number(req.query.limit) : DEFAULT_LIMIT;
    if (!Number.isFinite(limit) || limit <= 0) limit = DEFAULT_LIMIT;
    limit = Math.min(limit, MAX_LIMIT);

    let offset = req.query.offset !== undefined ? Number(req.query.offset) : 0;
    if (!Number.isFinite(offset) || offset < 0) offset = 0;

    const role = req.query.role || undefined;
    const accountStatus = req.query.accountStatus || undefined;
    const search = req.query.search || undefined;

    const [rows, total] = await Promise.all([
      model.listAll({ role, accountStatus, search, limit, offset }),
      model.count({ role, accountStatus, search }),
    ]);
    res.json({ users: rows.map(model.toPublic), total, limit, offset });
  })
);

// GET /api/users/:id — Admin > User detail.
router.get(
  '/:id',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const user = await model.findById(req.params.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });
    res.json(model.toPublic(user));
  })
);

// PATCH /api/users/:id/suspend — Body: { suspended: boolean }.
// Admin only, and can't be used on another admin account (or on the
// caller's own account) to avoid an admin locking themselves or a peer out.
router.patch(
  '/:id/suspend',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const { suspended } = req.body || {};
    if (typeof suspended !== 'boolean') {
      return res.status(400).json({ error: 'suspended (boolean) is required.' });
    }

    const target = await model.findById(req.params.id);
    if (!target) return res.status(404).json({ error: 'User not found.' });
    if (target.role === 'admin') {
      return res.status(403).json({ error: "Admin accounts can't be suspended from here." });
    }

    const updated = await model.setSuspended(req.params.id, suspended);

    try {
      await activityLogModel.create({
        actorId: req.user.id,
        actorName: req.user.fullName || req.user.email,
        action: suspended ? 'user_suspended' : 'user_reactivated',
        targetType: 'user',
        targetId: req.params.id,
        detail: target.full_name,
      });
    } catch (err) {
      // Best-effort, same convention as elsewhere — a logging failure
      // shouldn't fail the suspend action that triggered it.
      // eslint-disable-next-line no-console
      console.error(`[users] failed to log suspend action for ${req.params.id}`, err);
    }

    res.json(model.toPublic(updated));
  })
);

// PATCH /api/users/:id/approve-pending-role — Admin only.
// Activates an account that signed up as e.g. Property Owner and is
// sitting in account_status = 'pending_approval'. Sets role = its
// pending_role and account_status = 'active'.
router.patch(
  '/:id/approve-pending-role',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const target = await model.findById(req.params.id);
    if (!target) return res.status(404).json({ error: 'User not found.' });
    if (target.account_status !== 'pending_approval' || !target.pending_role) {
      return res.status(409).json({ error: 'This account has no pending approval to act on.' });
    }

    const updated = await model.activatePendingRole(req.params.id, target.pending_role);
    if (!updated) return res.status(409).json({ error: 'Failed to approve — account state may have changed.' });

    try {
      await activityLogModel.create({
        actorId: req.user.id,
        actorName: req.user.fullName || req.user.email,
        action: 'user_role_approved',
        targetType: 'user',
        targetId: req.params.id,
        detail: `${target.full_name} approved as ${target.pending_role}`,
      });
    } catch (err) {
      console.error(`[users] failed to log role approval for ${req.params.id}`, err);
    }

    res.json(model.toPublic(updated));
  })
);

// PATCH /api/users/:id/reject-pending-role — Admin only.
// Declines a pending signup (e.g. Property Owner) and demotes the
// account back to a plain active Visitor rather than deleting it.
router.patch(
  '/:id/reject-pending-role',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const target = await model.findById(req.params.id);
    if (!target) return res.status(404).json({ error: 'User not found.' });
    if (target.account_status !== 'pending_approval' || !target.pending_role) {
      return res.status(409).json({ error: 'This account has no pending approval to act on.' });
    }

    const updated = await model.rejectPendingRole(req.params.id, target.pending_role);
    if (!updated) return res.status(409).json({ error: 'Failed to reject — account state may have changed.' });

    try {
      await activityLogModel.create({
        actorId: req.user.id,
        actorName: req.user.fullName || req.user.email,
        action: 'user_role_rejected',
        targetType: 'user',
        targetId: req.params.id,
        detail: `${target.full_name}'s ${target.pending_role} request rejected`,
      });
    } catch (err) {
      console.error(`[users] failed to log role rejection for ${req.params.id}`, err);
    }

    res.json(model.toPublic(updated));
  })
);

module.exports = { router };
