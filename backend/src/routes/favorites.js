const express = require('express');
const model = require('../models/favorites');
const { requireAuth } = require('./auth');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

// Every route here is the signed-in visitor's own favorites — there's no
// "view someone else's saved listings" concept, so all of them run behind
// requireAuth and always scope to req.user.id (never a body/param userId).
router.use(requireAuth);

// GET /api/favorites — full asset objects for everything the caller has
// saved, newest-saved first. Powers the Favorites / Saved Listings screen.
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const rows = await model.listAssetsForUser(req.user.id);
    res.json(rows);
  })
);

// GET /api/favorites/ids — just the saved asset ids. Lightweight; used to
// hydrate the heart-icon state everywhere else in the app (Top Picks
// grid, asset detail, broker profile) without pulling full listings.
router.get(
  '/ids',
  asyncHandler(async (req, res) => {
    const ids = await model.listAssetIdsForUser(req.user.id);
    res.json(ids);
  })
);

// POST /api/favorites/:assetId — save a listing. Idempotent.
router.post(
  '/:assetId',
  asyncHandler(async (req, res) => {
    try {
      await model.add(req.user.id, req.params.assetId);
      res.status(201).json({ ok: true });
    } catch (err) {
      if (err.code === '23503') return res.status(404).json({ error: 'Asset not found.' });
      if (err.code === '22P02') return res.status(400).json({ error: 'Invalid asset id.' });
      throw err;
    }
  })
);

// DELETE /api/favorites/:assetId — un-save a listing. Not an error if it
// wasn't saved to begin with.
router.delete(
  '/:assetId',
  asyncHandler(async (req, res) => {
    try {
      await model.remove(req.user.id, req.params.assetId);
      res.json({ ok: true });
    } catch (err) {
      if (err.code === '22P02') return res.status(400).json({ error: 'Invalid asset id.' });
      throw err;
    }
  })
);

module.exports = { router };
