const express = require('express');
const { requireAuth } = require('./auth');

const model = require('../models/activityLog');

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

// GET /api/activity-log?limit=&offset=
// Admin-only, paginated. Scope is deliberately narrow — see
// migrations/048_activity_log.sql — this is approve/reject decisions
// only, not a full audit trail of every mutation in the app.
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

    const [rows, total] = await Promise.all([model.list({ limit, offset }), model.count()]);
    res.json({ entries: rows.map(model.toPublic), total, limit, offset });
  })
);

module.exports = { router };
