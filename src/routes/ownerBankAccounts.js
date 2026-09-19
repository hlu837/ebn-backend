const express = require('express');
const model = require('../models/ownerBankAccounts');
const platformBanksModel = require('../models/platformBanks');
const { requireAuth } = require('./auth');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ error: `This endpoint requires one of these roles: ${roles.join(', ')}.` });
    }
    next();
  };
}

const requirePropertyOwner = [requireAuth, requireRole('property_owner', 'admin')];

/** GET /api/owner-bank-accounts/banks — the banks a property owner may
 *  register an account against right now. Same source list the tenant-
 *  facing payment screen ultimately draws from (rentalAgreements.js
 *  GET /:id/bank-accounts), so an owner never picks a bank that then
 *  fails to show up for their tenant. */
router.get(
  '/banks',
  ...requirePropertyOwner,
  asyncHandler(async (req, res) => {
    const rows = await platformBanksModel.listActive();
    res.json({ banks: rows.map(platformBanksModel.toPublic) });
  })
);

/** GET /api/owner-bank-accounts/me — the caller's own accounts, numbers
 *  masked (see models/ownerBankAccounts.js maskAccountNumber) — this is
 *  the owner managing their own list, not a tenant reading a number to
 *  transfer into, so there's no reason to show the full digits back. */
router.get(
  '/me',
  ...requirePropertyOwner,
  asyncHandler(async (req, res) => {
    const rows = await model.listForOwner(req.user.id);
    res.json(rows.map(model.toPublicMasked));
  })
);

/** POST /api/owner-bank-accounts — body: { bankId, accountName, accountNumber, isDefault? } */
router.post(
  '/',
  ...requirePropertyOwner,
  asyncHandler(async (req, res) => {
    const { bankId, accountName, accountNumber, isDefault } = req.body || {};
    if (!bankId) return res.status(400).json({ error: 'bankId is required.' });
    try {
      const row = await model.create({ ownerId: req.user.id, bankId, accountName, accountNumber, isDefault });
      res.status(201).json(model.toPublicMasked(row));
    } catch (err) {
      if (err && err.status) return res.status(err.status).json({ error: err.message });
      throw err;
    }
  })
);

/** PATCH /api/owner-bank-accounts/:id — body: any of { bankId, accountName, accountNumber, isDefault } */
router.patch(
  '/:id',
  ...requirePropertyOwner,
  asyncHandler(async (req, res) => {
    const { bankId, accountName, accountNumber, isDefault } = req.body || {};
    try {
      const row = await model.update(req.params.id, req.user.id, { bankId, accountName, accountNumber, isDefault });
      res.json(model.toPublicMasked(row));
    } catch (err) {
      if (err && err.status) return res.status(err.status).json({ error: err.message });
      throw err;
    }
  })
);

/** DELETE /api/owner-bank-accounts/:id */
router.delete(
  '/:id',
  ...requirePropertyOwner,
  asyncHandler(async (req, res) => {
    const row = await model.remove(req.params.id, req.user.id);
    if (!row) return res.status(404).json({ error: 'Not found.' });
    res.json({ ok: true });
  })
);

module.exports = { router };
