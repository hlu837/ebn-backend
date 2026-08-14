const express = require('express');
const model = require('../models/orderRequests');
const { geocodeAddress, GeocodingError } = require('../services/geocoding');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

const REQUIRED_SUBMIT_FIELDS = [
  'requesterUserId',
  'requesterName',
  'requesterPhone',
  'category',
  'title',
  'description',
  'budgetSummary',
  'locationSource',
];

// ── Visitor ──────────────────────────────────────────────────────────────

// POST /api/order-requests
// Visitor submits a new "Order Us" requirement, with a location captured
// either from GPS (locationSource: 'gps', latitude/longitude provided
// directly) or a manually typed address (locationSource: 'manual',
// addressText provided — geocoded here server-side). The request is
// created already broadcast to nearby agents.
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const body = req.body || {};
    const missing = REQUIRED_SUBMIT_FIELDS.filter((f) => body[f] === undefined || body[f] === null || body[f] === '');
    if (missing.length) {
      return res.status(400).json({ error: `Missing required field(s): ${missing.join(', ')}.` });
    }
    if (!['gps', 'manual'].includes(body.locationSource)) {
      return res.status(400).json({ error: "locationSource must be 'gps' or 'manual'." });
    }

    let latitude;
    let longitude;
    let addressText = null;

    if (body.locationSource === 'gps') {
      latitude = Number(body.latitude);
      longitude = Number(body.longitude);
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
        return res.status(400).json({ error: 'latitude and longitude are required for locationSource "gps".' });
      }
    } else {
      if (!body.addressText || !String(body.addressText).trim()) {
        return res.status(400).json({ error: 'addressText is required for locationSource "manual".' });
      }
      try {
        const geocoded = await geocodeAddress(String(body.addressText).trim());
        latitude = geocoded.latitude;
        longitude = geocoded.longitude;
        addressText = geocoded.formattedAddress;
      } catch (err) {
        const status = err instanceof GeocodingError ? 422 : 500;
        return res.status(status).json({ error: err.message });
      }
    }

    const { row, agentsNotified } = await model.create({ ...body, latitude, longitude, addressText });
    res.status(201).json({ ...model.toPublic(row), agentsNotified });
  })
);

// GET /api/order-requests?requesterUserId=...  -> that requester's full history
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { requesterUserId } = req.query;
    if (!requesterUserId) {
      return res.status(400).json({ error: 'requesterUserId query param is required.' });
    }
    const rows = await model.listByRequester(String(requesterUserId));
    res.json(rows.map(model.toPublic));
  })
);

// POST /api/order-requests/:id/report
// Visitor reports that they and the assigned agent couldn't work it out.
// Body: { requesterUserId, reason? }
router.post(
  '/:id/report',
  asyncHandler(async (req, res) => {
    const { requesterUserId, reason } = req.body || {};
    if (!requesterUserId) {
      return res.status(400).json({ error: 'requesterUserId is required.' });
    }
    const row = await model.report(req.params.id, { requesterUserId, reason });
    if (!row) return res.status(409).json({ error: 'This request cannot be reported right now.' });
    res.json(model.toPublic(row));
  })
);

// ── Agent ────────────────────────────────────────────────────────────────

// GET /api/order-requests/agent/:agentId/available
// Requests currently broadcasting to this agent, awaiting a claim.
router.get(
  '/agent/:agentId/available',
  asyncHandler(async (req, res) => {
    const rows = await model.listBroadcastingForAgent(req.params.agentId);
    res.json(rows.map(model.toPublic));
  })
);

// GET /api/order-requests/agent/:agentId/assigned
// Everything currently or previously assigned to this agent.
router.get(
  '/agent/:agentId/assigned',
  asyncHandler(async (req, res) => {
    const rows = await model.listAssignedToAgent(req.params.agentId);
    res.json(rows.map(model.toPublic));
  })
);

// POST /api/order-requests/:id/claim
// First agent to call this wins — Body: { agentId, agentName, agentPhone }
router.post(
  '/:id/claim',
  asyncHandler(async (req, res) => {
    const { agentId, agentName, agentPhone } = req.body || {};
    if (!agentId || !agentName || !agentPhone) {
      return res.status(400).json({ error: 'agentId, agentName, and agentPhone are required.' });
    }
    const row = await model.claim(req.params.id, { agentId, agentName, agentPhone });
    if (!row) {
      return res.status(409).json({ error: 'Someone else already claimed this request, or it is no longer available to you.' });
    }
    res.json(model.toPublic(row));
  })
);

// POST /api/order-requests/:id/complete
// The assigned agent closes out a request they've confirmed — Body: { agentId }
router.post(
  '/:id/complete',
  asyncHandler(async (req, res) => {
    const { agentId } = req.body || {};
    if (!agentId) {
      return res.status(400).json({ error: 'agentId is required.' });
    }
    const row = await model.complete(req.params.id, { agentId });
    if (!row) {
      return res.status(409).json({ error: 'This request is not currently confirmed to you, so it cannot be completed.' });
    }
    res.json(model.toPublic(row));
  })
);

// POST /api/order-requests/:id/agent-report
// The assigned agent flags that a confirmed request couldn't be worked
// out on their end (client unreachable, deal fell through, etc) — same
// outcome as the visitor's /report, just from the agent's side. Puts it
// back in front of Admin as 'disputed' for a repost. Body: { agentId, reason? }
router.post(
  '/:id/agent-report',
  asyncHandler(async (req, res) => {
    const { agentId, reason } = req.body || {};
    if (!agentId) {
      return res.status(400).json({ error: 'agentId is required.' });
    }
    const row = await model.reportByAgent(req.params.id, { agentId, reason });
    if (!row) {
      return res.status(409).json({ error: 'This request is not currently confirmed to you, so it cannot be reported.' });
    }
    res.json(model.toPublic(row));
  })
);

// ── Admin ────────────────────────────────────────────────────────────────

// GET /api/order-requests/admin/broadcasting — awaiting an agent
router.get(
  '/admin/broadcasting',
  asyncHandler(async (req, res) => {
    const rows = await model.listByStatus('broadcasting');
    res.json(rows.map(model.toPublic));
  })
);

// GET /api/order-requests/admin/confirmed — an agent has it
router.get(
  '/admin/confirmed',
  asyncHandler(async (req, res) => {
    const rows = await model.listByStatus('agent_confirmed');
    res.json(rows.map(model.toPublic));
  })
);

// GET /api/order-requests/admin/disputed — needs a repost
router.get(
  '/admin/disputed',
  asyncHandler(async (req, res) => {
    const rows = await model.listByStatus('disputed');
    res.json(rows.map(model.toPublic));
  })
);

// POST /api/order-requests/:id/repost
// Re-broadcasts a disputed request to nearby agents again (excluding
// whoever it was assigned to before) — same data, no re-filled form.
router.post(
  '/:id/repost',
  asyncHandler(async (req, res) => {
    const result = await model.repost(req.params.id);
    if (!result) return res.status(409).json({ error: 'Only a disputed request can be reposted.' });
    res.json({ ...model.toPublic(result.row), agentsNotified: result.agentsNotified });
  })
);

// POST /api/order-requests/:id/close
router.post(
  '/:id/close',
  asyncHandler(async (req, res) => {
    const row = await model.close(req.params.id);
    if (!row) return res.status(409).json({ error: 'Request is already closed.' });
    res.json(model.toPublic(row));
  })
);

// GET /api/order-requests/:id — fetch one (keep last: matches other :id routes)
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const row = await model.findById(req.params.id);
    if (!row) return res.status(404).json({ error: 'Not found.' });
    res.json(model.toPublic(row));
  })
);

module.exports = { router };
