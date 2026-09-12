const express = require('express');
const { requireAuth } = require('./auth');
const model = require('../models/investmentOpportunities');

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function requireAdmin(req, res, next) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required.' });
  }
  next();
}

const VALID_CATEGORIES = ['Real Estate', 'Vehicle', 'Machinery', 'Other'];
const VALID_STATUSES = ['Open', 'Funded', 'Closed'];

function validateCreateBody(body) {
  const { title, description, category, targetAmount, minInvestment, expectedReturnPct, termMonths } = body;

  if (!title || !title.trim()) return 'title is required.';
  if (!description || !description.trim()) return 'description is required.';
  if (category && !VALID_CATEGORIES.includes(category)) {
    return `category must be one of: ${VALID_CATEGORIES.join(', ')}`;
  }
  if (targetAmount === undefined || Number.isNaN(Number(targetAmount)) || Number(targetAmount) <= 0) {
    return 'targetAmount must be a positive number.';
  }
  if (minInvestment === undefined || Number.isNaN(Number(minInvestment)) || Number(minInvestment) <= 0) {
    return 'minInvestment must be a positive number.';
  }
  if (Number(minInvestment) > Number(targetAmount)) {
    return 'minInvestment cannot exceed targetAmount.';
  }
  if (expectedReturnPct === undefined || Number.isNaN(Number(expectedReturnPct)) || Number(expectedReturnPct) < 0) {
    return 'expectedReturnPct must be a non-negative number.';
  }
  if (termMonths === undefined || !Number.isInteger(Number(termMonths)) || Number(termMonths) <= 0) {
    return 'termMonths must be a positive whole number.';
  }
  return null;
}

const router = express.Router();

// GET /api/investment-opportunities
// Public/investor feed — open deals first, then newest first.
router.get(
  '/',
  asyncHandler(async (req, res) => {
    res.json(await model.listPublic());
  })
);

// GET /api/investment-opportunities/all
// Admin-only: every opportunity regardless of status, for the management screen.
router.get(
  '/all',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    res.json(await model.listAll());
  })
);

// POST /api/investment-opportunities
// Admin-only: create a new opportunity.
router.post(
  '/',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const error = validateCreateBody(req.body);
    if (error) return res.status(400).json({ error });

    const { title, description, category, targetAmount, minInvestment, expectedReturnPct, termMonths, imageUrl } =
      req.body;

    const created = await model.create({
      title: title.trim(),
      description: description.trim(),
      category: category || 'Other',
      targetAmount: Number(targetAmount),
      minInvestment: Number(minInvestment),
      expectedReturnPct: Number(expectedReturnPct),
      termMonths: Number(termMonths),
      imageUrl: imageUrl || null,
    });
    res.status(201).json(created);
  })
);

// PATCH /api/investment-opportunities/:id
// Admin-only: update fields (including status, e.g. marking Funded/Closed).
router.patch(
  '/:id',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const existing = await model.getById(req.params.id);
    if (!existing) return res.status(404).json({ error: 'Investment opportunity not found.' });

    const { category, status, targetAmount, minInvestment, expectedReturnPct, termMonths } = req.body;
    if (category !== undefined && !VALID_CATEGORIES.includes(category)) {
      return res.status(400).json({ error: `category must be one of: ${VALID_CATEGORIES.join(', ')}` });
    }
    if (status !== undefined && !VALID_STATUSES.includes(status)) {
      return res.status(400).json({ error: `status must be one of: ${VALID_STATUSES.join(', ')}` });
    }
    if (targetAmount !== undefined && (Number.isNaN(Number(targetAmount)) || Number(targetAmount) <= 0)) {
      return res.status(400).json({ error: 'targetAmount must be a positive number.' });
    }
    if (minInvestment !== undefined && (Number.isNaN(Number(minInvestment)) || Number(minInvestment) <= 0)) {
      return res.status(400).json({ error: 'minInvestment must be a positive number.' });
    }
    if (
      expectedReturnPct !== undefined &&
      (Number.isNaN(Number(expectedReturnPct)) || Number(expectedReturnPct) < 0)
    ) {
      return res.status(400).json({ error: 'expectedReturnPct must be a non-negative number.' });
    }
    if (termMonths !== undefined && (!Number.isInteger(Number(termMonths)) || Number(termMonths) <= 0)) {
      return res.status(400).json({ error: 'termMonths must be a positive whole number.' });
    }

    const updated = await model.update(req.params.id, {
      ...req.body,
      ...(targetAmount !== undefined ? { targetAmount: Number(targetAmount) } : {}),
      ...(minInvestment !== undefined ? { minInvestment: Number(minInvestment) } : {}),
      ...(expectedReturnPct !== undefined ? { expectedReturnPct: Number(expectedReturnPct) } : {}),
      ...(termMonths !== undefined ? { termMonths: Number(termMonths) } : {}),
    });
    res.json(updated);
  })
);

// DELETE /api/investment-opportunities/:id
// Admin-only: remove an opportunity.
router.delete(
  '/:id',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const deletedId = await model.remove(req.params.id);
    if (!deletedId) return res.status(404).json({ error: 'Investment opportunity not found.' });
    res.json({ deleted: deletedId });
  })
);

module.exports = { router };
