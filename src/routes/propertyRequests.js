const express = require('express');
const { requireAuth } = require('./auth');
const propertyRequests = require('../models/propertyRequests');
const chat = require('../models/chat');

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function sendModelError(res, err) {
  if (err && err.status) return res.status(err.status).json({ error: err.message });
  throw err;
}

const router = express.Router();

/**
 * POST /api/property-requests
 * body: { assetId, requestType: 'info' | 'tour' | 'rent_now', message }
 * Renter-side entry point — opens (or reuses) the conversation with the
 * listing's owner and files it in their Inbox under the given type.
 */
router.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { assetId, requestType, message } = req.body || {};
    if (!assetId) return res.status(400).json({ error: 'assetId is required' });
    if (!requestType) return res.status(400).json({ error: 'requestType is required' });

    try {
      const { row, thread } = await propertyRequests.create({
        assetId,
        requesterId: req.user.id,
        requesterName: req.user.fullName,
        requestType,
        message,
      });
      res.status(201).json({
        request: propertyRequests.toPublic(row),
        thread: chat.threadToPublic(thread),
      });
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/** GET /api/property-requests — the caller's Inbox as a Property Owner.
 *  Query: status ('pending' | 'in_progress' | 'closed'), assetId, requestType. */
router.get(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { status, assetId, requestType } = req.query;
    const rows = await propertyRequests.listForOwner(req.user.id, { status, assetId, requestType });
    res.json(rows.map(propertyRequests.toPublic));
  })
);

/** GET /api/property-requests/:id */
router.get(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const row = await propertyRequests.findByIdForOwner(req.params.id, req.user.id);
    if (!row) return res.status(404).json({ error: 'Request not found' });
    res.json(propertyRequests.toPublic(row));
  })
);

/** PATCH /api/property-requests/:id/status — body: { status: 'pending' | 'closed' } */
router.patch(
  '/:id/status',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { status } = req.body || {};
    try {
      const row = await propertyRequests.setStatus(req.params.id, req.user.id, status);
      if (!row) return res.status(404).json({ error: 'Request not found' });
      res.json(propertyRequests.toPublic(row));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

module.exports = { router };
