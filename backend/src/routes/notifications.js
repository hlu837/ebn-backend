const express = require('express');
const { requireAuth } = require('./auth');
const model = require('../models/notifications');

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

const router = express.Router();

// GET /api/notifications — the caller's own feed, scoped by their role.
router.get(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await model.listForRecipient(req.user.role, req.user.id);
    res.json(rows.map(model.toPublic));
  })
);

// POST /api/notifications/:id/read
router.post(
  '/:id/read',
  requireAuth,
  asyncHandler(async (req, res) => {
    const row = await model.markRead(req.params.id, req.user.role, req.user.id);
    if (!row) return res.status(404).json({ error: 'Notification not found.' });
    res.json(model.toPublic(row));
  })
);

// POST /api/notifications/read-all
router.post(
  '/read-all',
  requireAuth,
  asyncHandler(async (req, res) => {
    const count = await model.markAllRead(req.user.role, req.user.id);
    res.json({ markedRead: count });
  })
);

module.exports = { router };
