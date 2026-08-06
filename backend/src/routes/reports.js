const express = require('express');
const { requireAuth } = require('./auth');

const model = require('../models/reports');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

function requireAdmin(req, res, next) {
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
  next();
}

// GET /api/reports/overview
// Admin-only. Everything the Reports screen shows in one call: sell/order
// request funnels (with a conversion rate each), the live catalog's
// category breakdown, and the last 7 days of submission volume. See
// models/reports.js for what "converted" means for each request type —
// there's no single shared definition across the two.
router.get(
  '/overview',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    res.json(await model.overview());
  })
);

module.exports = { router };
