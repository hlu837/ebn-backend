const express = require('express');
const { requireAuth } = require('./auth');
const model = require('../models/serviceProviders');

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

const router = express.Router();

/**
 * GET /api/service-providers/categories
 * The fixed category list, for the browse screen's filter chips.
 * Registered before /:id so it isn't swallowed by that param route.
 */
router.get(
  '/categories',
  requireAuth,
  asyncHandler(async (req, res) => {
    res.json({ categories: model.CATEGORIES });
  })
);

/**
 * GET /api/service-providers
 * Tenant-facing browse of the active directory. Any authenticated user
 * can browse — not gated to tenants specifically, same as most
 * read-only catalog data (categories, cities).
 * Query: category, city (both optional filters).
 */
router.get(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await model.list({
      activeOnly: true,
      category: req.query.category,
      city: req.query.city,
    });
    res.json(rows.map(model.toPublic));
  })
);

/** GET /api/service-providers/:id */
router.get(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const row = await model.findById(req.params.id);
    if (!row || !row.is_active) return res.status(404).json({ error: 'Not found.' });
    res.json(model.toPublic(row));
  })
);

module.exports = { router };
