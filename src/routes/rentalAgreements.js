const express = require('express');
const { requireAuth } = require('./auth');
const model = require('../models/rentalAgreements');
const scheduler = require('../scheduler');
const { broadcastNotification } = require('../socket');

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function sendModelError(res, err) {
  if (err && err.status) return res.status(err.status).json({ error: err.message });
  throw err;
}

const router = express.Router();

/** Arms (or re-arms) the payment-window expiry timer for a sent agreement. */
function armExpiry(agreement) {
  if (!agreement.expires_at) return;
  scheduler.schedule(agreement.id, agreement.expires_at, async (id) => {
    const expired = await model.expire(id);
    if (!expired) return; // already paid/rejected just before the timer fired
    broadcastNotification('property_owner', expired.owner_id, { kind: 'rental_agreement_expired', id: expired.id });
  });
}

/**
 * POST /api/rental-agreements
 * body: { propertyRequestId, idDocumentUrl, documentUrls?, note? }
 * Requester-side: submits their digital ID + supporting documents against
 * a rent_now request they already sent. Reserves the listing for review.
 */
router.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { propertyRequestId, idDocumentUrl, documentUrls, note } = req.body || {};
    if (!propertyRequestId) return res.status(400).json({ error: 'propertyRequestId is required' });
    try {
      const row = await model.submitDocuments({
        propertyRequestId,
        requesterId: req.user.id,
        idDocumentUrl,
        documentUrls,
        note,
      });
      res.status(201).json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/** GET /api/rental-agreements/queue — the caller's Review tab, as an owner.
 *  Query: status ('active' | 'documents_submitted' | 'agreement_sent' |
 *  'paid' | 'rejected' | 'expired'), defaults to 'active'. */
router.get(
  '/queue',
  requireAuth,
  asyncHandler(async (req, res) => {
    const status = req.query.status || 'active';
    const rows = await model.listForOwner(req.user.id, { status });
    res.json(rows.map(model.toPublic));
  })
);

/** GET /api/rental-agreements/mine — the caller's own pipeline rows, as a requester. */
router.get(
  '/mine',
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await model.listForRequester(req.user.id);
    res.json(rows.map(model.toPublic));
  })
);

/** GET /api/rental-agreements/:id — either party may view their own row. */
router.get(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const row = await model.findById(req.params.id);
    if (!row || (row.owner_id !== req.user.id && row.requester_id !== req.user.id)) {
      return res.status(404).json({ error: 'Not found.' });
    }
    res.json(model.toPublic(row));
  })
);

/**
 * POST /api/rental-agreements/:id/send
 * body: { terms, rentAmount, depositAmount?, currency?, hours? }
 * Owner approves the documents and sends the rental agreement, starting
 * the payment countdown (default 24h).
 */
router.post(
  '/:id/send',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { terms, rentAmount, depositAmount, currency, hours } = req.body || {};
    try {
      const row = await model.sendAgreement({
        id: req.params.id,
        ownerId: req.user.id,
        terms,
        rentAmount,
        depositAmount,
        currency,
        hours,
      });
      armExpiry(row);
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/** POST /api/rental-agreements/:id/reject — body: { reason? } */
router.post(
  '/:id/reject',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const row = await model.reject({ id: req.params.id, ownerId: req.user.id, reason: req.body?.reason });
      scheduler.cancel(row.id);
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

module.exports = { router, armExpiry };
