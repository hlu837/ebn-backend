const express = require('express');
const { requireAuth } = require('./auth');
const model = require('../models/maintenanceAssignments');

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function sendModelError(res, err) {
  if (err && err.status) return res.status(err.status).json({ error: err.message });
  throw err;
}

const router = express.Router();

/**
 * POST /api/maintenance-assignments
 * body: { maintenanceRequestId, serviceProviderId, quotedCostCents }
 * Tenant picks a specialist for a request the owner rejected. Doesn't
 * take payment itself -- the client follows up with the generic
 * POST /api/payments/chapa/initialize using purpose
 * `maintenance_escrow_<assignment id>` and amount = quotedCostCents / 100,
 * same two-step pattern rental_agreements uses for its own payment.
 */
router.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const { maintenanceRequestId, serviceProviderId, quotedCostCents } = req.body || {};
      const row = await model.assign({
        tenantId: req.user.id,
        maintenanceRequestId,
        serviceProviderId,
        quotedCostCents,
      });
      res.status(201).json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/** GET /api/maintenance-assignments/mine — the caller's own assignments, as a tenant. */
router.get(
  '/mine',
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await model.listForTenant(req.user.id);
    res.json(rows.map(model.toPublic));
  })
);

/** GET /api/maintenance-assignments/:id — tenant may view their own row. */
router.get(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const row = await model.findById(req.params.id);
    if (!row || row.tenant_id !== req.user.id) {
      return res.status(404).json({ error: 'Not found.' });
    }
    res.json(model.toPublic(row));
  })
);

/**
 * PATCH /api/maintenance-assignments/:id/confirm-complete
 * Tenant-only. Single-tap "job's done, release the payment" — see
 * maintenanceAssignments.js's confirmComplete for why there's no
 * separate provider-side step.
 */
router.patch(
  '/:id/confirm-complete',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const row = await model.confirmComplete({ id: req.params.id, tenantId: req.user.id });
      if (!row) return res.status(404).json({ error: 'Not found.' });
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

module.exports = { router };
