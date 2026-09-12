const express = require('express');
const referralsModel = require('../models/referrals');
const { requireAuth } = require('./auth');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

// GET /api/referrals — list all referrals sent or received by the current user
router.get(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const items = await referralsModel.listForUser(req.user.id);
    res.json(items);
  })
);

// POST /api/referrals — send a new referral to another agent/broker
router.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { receiverId, clientName, clientPhone, categorySlug, feePercent, notes } = req.body || {};

    if (!receiverId || !String(receiverId).trim()) {
      return res.status(400).json({ error: 'receiverId is required.' });
    }
    if (!clientName || !String(clientName).trim()) {
      return res.status(400).json({ error: 'clientName is required.' });
    }
    if (!clientPhone || !String(clientPhone).trim()) {
      return res.status(400).json({ error: 'clientPhone is required.' });
    }

    const created = await referralsModel.create({
      senderId: req.user.id,
      receiverId: String(receiverId).trim(),
      clientName: String(clientName).trim(),
      clientPhone: String(clientPhone).trim(),
      categorySlug: categorySlug ? String(categorySlug).trim() : 'apartments',
      feePercent: Number(feePercent) || 10,
      notes: notes ? String(notes).trim() : null,
    });

    res.status(201).json(created);
  })
);

// PATCH /api/referrals/:id/status — update referral status (accepted, closed, declined)
router.patch(
  '/:id/status',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { status } = req.body || {};
    const validStatuses = ['pending', 'accepted', 'closed', 'declined'];
    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({ error: `status must be one of: ${validStatuses.join(', ')}.` });
    }

    const updated = await referralsModel.updateStatus(req.params.id, req.user.id, status);
    if (!updated) {
      return res.status(404).json({ error: 'Referral not found or access denied.' });
    }
    res.json(updated);
  })
);

module.exports = { router };
