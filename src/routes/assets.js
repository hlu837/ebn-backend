const express = require('express');
const { requireAuth } = require('./auth');
const model = require('../models/assets');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

// Same pattern as routes/users.js — runs after requireAuth, so req.user
// is always populated by the time this sees it.
//
// Admin-only for now. Widening this to let a property owner edit their
// own listing is a deliberate follow-up: it needs an ownership check
// against the asset row (assets.broker_id / owner), not just a role
// test, and PATCH must stay closed to `reserved`/`rented` regardless of
// who is calling (those belong to the rental state machine in
// models/rentalAgreements.js). Do not relax this by adding roles here.
function requireAdmin(req, res, next) {
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
  next();
}

// The deliberate follow-up flagged above: lets an agent edit their own
// listing (title/description/price/address/city/photos), not just admin.
// Ownership is checked against the asset row's broker_id, loaded once here
// and stashed on req.asset so the PATCH handler doesn't fetch it twice.
// Fields an owning agent must not be able to touch (status, category,
// broker_id, rating/review_count/roi_percent) are stripped from req.body
// before it reaches model.update — admin keeps full access to every field.
const AGENT_EDITABLE_FIELDS = new Set([
  'title',
  'description',
  'priceAmount',
  'priceCurrency',
  'addressLine',
  'city',
  'latitude',
  'longitude',
  'imageUrl',
  'imageUrls',
  'postedLabel',
]);

const requireAdminOrOwner = asyncHandler(async (req, res, next) => {
  const asset = await model.findById(req.params.id);
  if (!asset) return res.status(404).json({ error: 'Not found.' });
  req.asset = asset;

  if (req.user.role === 'admin') return next();

  if (asset.broker_id && asset.broker_id === req.user.id) {
    const body = req.body || {};
    for (const key of Object.keys(body)) {
      if (!AGENT_EDITABLE_FIELDS.has(key)) delete body[key];
    }
    req.body = body;
    return next();
  }

  return res.status(403).json({ error: 'Admin only.' });
});

// `reserved` and `rented` are written exclusively by the rental state
// machine in models/rentalAgreements.js (submitDocuments, reject, expire,
// markVacated, etc.) as a side effect of a rental_agreements row changing
// state. They must never be reachable through this generic PATCH — an
// admin hand-setting one here has no rental_agreements row behind it, so
// there's no automatic path back (markVacated requires a paid agreement),
// and the rental pipeline's own unconditional { status: 'active' } resets
// can stomp on it in the other direction. See finding: admin-picker /
// rental-pipeline status collision.
const RENTAL_MANAGED_STATUSES = new Set(['reserved', 'rented']);

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
    // toPublicList (not toPublic): this feed can return dozens/hundreds of
    // listings in one response, and every card/rail that renders it only
    // ever shows the single cover photo — see models/assets.js for why
    // sending the full base64 image (and gallery) here was making the
    // response many MB and timing out on mobile connections.
    res.json(rows.map(model.toPublicList));
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

// POST /api/assets — Admin creating a listing (e.g. approving a
// sell-request's inspection report into a live listing). Not called by
// the visitor app. Admin-only: see requireAdmin above.
router.post(
  '/',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const body = req.body || {};
    if (!body.title || body.priceAmount === undefined || !body.categorySlug) {
      return res.status(400).json({ error: 'title, priceAmount, and categorySlug are required.' });
    }
    const row = await model.create(body);
    res.status(201).json(model.toPublic(row));
  })
);

// PATCH /api/assets/:id — Admin editing any field of a listing, or the
// owning agent editing their own listing's basic details (title/price/
// address/city/photos — see AGENT_EDITABLE_FIELDS in requireAdminOrOwner).
// Partial update: only send the fields that changed.
router.patch(
  '/:id',
  requireAuth,
  requireAdminOrOwner,
  asyncHandler(async (req, res) => {
    const body = req.body || {};
    if (body.status !== undefined && RENTAL_MANAGED_STATUSES.has(String(body.status))) {
      return res.status(422).json({
        error:
          "'reserved' and 'rented' are set automatically by the rental pipeline and can't be set directly. " +
          'To free a stuck listing, resolve or cancel the underlying rental agreement instead.',
      });
    }
    const row = await model.update(req.params.id, body);
    if (!row) return res.status(404).json({ error: 'Not found.' });
    res.json(model.toPublic(row));
  })
);

// DELETE /api/assets/:id — Admin removing a listing outright.
// Admin-only: see requireAdmin above.
router.delete(
  '/:id',
  requireAuth,
  requireAdmin,
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
