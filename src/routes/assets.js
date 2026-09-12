const express = require('express');
const model = require('../models/assets');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

// GET /api/assets?category=&city=&status=&q=&brokerId=&limit=
// Public listing feed — powers the visitor's Top Picks grid, category
// tabs, search bar, and a broker's own listings list. Defaults to only
// `active` listings unless `status` is explicitly passed.
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { category, city, status, q, brokerId, limit } = req.query;
    const rows = await model.list({
      category: category ? String(category) : undefined,
      city: city ? String(city) : undefined,
      status: status ? String(status) : undefined,
      q: q ? String(q) : undefined,
      brokerId: brokerId ? String(brokerId) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
    res.json(rows.map(model.toPublic));
  })
);

// GET /api/assets/broker/:brokerId — every listing by one broker, any
// status (kept ahead of the /:id route so "broker" never matches as an id).
router.get(
  '/broker/:brokerId',
  asyncHandler(async (req, res) => {
    const rows = await model.listByBroker(req.params.brokerId);
    res.json(rows.map(model.toPublic));
  })
);

// POST /api/assets — internal/admin use (e.g. approving a sell-request's
// inspection report into a live listing). Not called by the visitor app.
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const body = req.body || {};
    if (!body.title || body.priceAmount === undefined || !body.categorySlug) {
      return res.status(400).json({ error: 'title, priceAmount, and categorySlug are required.' });
    }
    const row = await model.create(body);
    res.status(201).json(model.toPublic(row));
  })
);

// PATCH /api/assets/:id — Admin editing a listing (title/price/address/
// status/etc). Partial update: only send the fields that changed.
router.patch(
  '/:id',
  asyncHandler(async (req, res) => {
    const row = await model.update(req.params.id, req.body || {});
    if (!row) return res.status(404).json({ error: 'Not found.' });
    res.json(model.toPublic(row));
  })
);

// DELETE /api/assets/:id — Admin removing a listing outright.
router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const row = await model.remove(req.params.id);
    if (!row) return res.status(404).json({ error: 'Not found.' });
    res.json({ ok: true });
  })
);

// GET /api/assets/:id — fetch one (keep last: matches other :id routes)
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const row = await model.findById(req.params.id);
    if (!row) return res.status(404).json({ error: 'Not found.' });
    res.json(model.toPublic(row));
  })
);

module.exports = { router };
