const express = require('express');
const { requireAuth } = require('./auth');
const { query } = require('../db');
const model = require('../models/maintenanceRequests');

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function sendModelError(res, err) {
  if (err && err.status) return res.status(err.status).json({ error: err.message });
  throw err;
}

const router = express.Router();

/**
 * GET /api/maintenance-requests/eligible-assets
 * Which of the caller's leases are currently active — i.e. which assets
 * they're allowed to file a maintenance request against. Drives whether
 * the "My Rental Agreements" screen shows the "Report a maintenance
 * issue" button and, if there's more than one active lease, which asset
 * to file against. Same active-lease definition model.create re-checks
 * server-side on submit — this is only what decides whether to show the
 * button, not a substitute for that check.
 */
router.get(
  '/eligible-assets',
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await query(
      `SELECT ra.id AS rental_agreement_id, ra.asset_id, a.title AS asset_title, a.image_url AS asset_image_url
       FROM rental_agreements ra
       JOIN assets a ON a.id = ra.asset_id
       WHERE ra.requester_id = $1 AND ra.status = 'paid' AND ra.vacated_at IS NULL
       ORDER BY ra.paid_at DESC`,
      [req.user.id]
    );
    res.json(
      rows.rows.map((r) => ({
        rentalAgreementId: r.rental_agreement_id,
        assetId: r.asset_id,
        assetTitle: r.asset_title,
        assetImageUrl: r.asset_image_url,
      }))
    );
  })
);

/**
 * POST /api/maintenance-requests
 * body: { assetId, category, description, photoUrls? }
 * Tenant files a new request. model.create re-verifies the active lease
 * server-side — see its doc comment.
 */
router.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const { assetId, category, description, photoUrls } = req.body;
      const row = await model.create({
        tenantId: req.user.id,
        assetId,
        category,
        description,
        photoUrls,
      });
      res.status(201).json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/** GET /api/maintenance-requests/mine — the caller's own filed requests, as a tenant. */
router.get(
  '/mine',
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await model.listForTenant(req.user.id);
    res.json(rows.map(model.toPublic));
  })
);

/** GET /api/maintenance-requests/queue — the caller's incoming requests, as an owner.
 *  Query: status ('submitted' | 'accepted' | 'rejected'), omit for all. */
router.get(
  '/queue',
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await model.listForOwner(req.user.id, { status: req.query.status });
    res.json(rows.map(model.toPublic));
  })
);

/** GET /api/maintenance-requests/:id — either party may view their own row. */
router.get(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const row = await model.findById(req.params.id);
    if (!row || (row.owner_id !== req.user.id && row.tenant_id !== req.user.id)) {
      return res.status(404).json({ error: 'Not found.' });
    }
    res.json(model.toPublic(row));
  })
);

/**
 * PATCH /api/maintenance-requests/:id/decide
 * body: { accept: boolean, note? }
 * Owner-only. Accept or reject an open request.
 */
router.patch(
  '/:id/decide',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const row = await model.decide({
        id: req.params.id,
        ownerId: req.user.id,
        accept: !!req.body.accept,
        note: req.body.note,
      });
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

module.exports = { router };
