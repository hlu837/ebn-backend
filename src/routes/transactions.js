const express = require('express');
const { requireAuth } = require('./auth');

const model = require('../models/payments');

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

// GET /api/transactions?status=&search=&limit=&offset= — Admin > Transactions.
// Reads the same `payments` table every Chapa checkout already writes to
// (see routes/payments.js) — this just exposes it to the admin dashboard.
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

    const status = req.query.status || undefined;
    const search = req.query.search || undefined;

    const [rows, total] = await Promise.all([
      model.listAll({ status, search, limit, offset }),
      model.countAll({ status, search }),
    ]);
    res.json({ transactions: rows.map(model.toPublic), total, limit, offset });
  })
);

module.exports = { router };
