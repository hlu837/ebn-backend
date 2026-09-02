const express = require('express');
const model = require('../models/tourRequests');
const scheduler = require('../scheduler');
const { broadcastTourRequest } = require('../socket');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

/** Arms (or re-arms) the expiry timer for a freshly-dispatched request. */
function armExpiry(request) {
  scheduler.schedule(request.id, request.expires_at, async (id) => {
    const expired = await model.expire(id);
    // `expired` is null if it was already accepted/declined just before
    // the timer fired — nothing to broadcast in that case.
    if (!expired) return;
    broadcastTourRequest('tour_request:updated', expired);

    // The (credited or manually-dispatched) agent didn't answer in time —
    // try nearby agents instead of just leaving it in Admin's queue.
    const broadcast = await model.broadcastToNearby(id);
    if (broadcast) broadcastTourRequest('tour_request:updated', broadcast.row);
  });
}

// POST /api/tour-requests
// Customer submits a new tour request.
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const { customerId, customerName, assetId, assetTitle } = req.body || {};
    if (!customerId || !customerName || !assetId || !assetTitle) {
      return res.status(400).json({
        error: 'customerId, customerName, assetId and assetTitle are all required.',
      });
    }
    const request = await model.create({ customerId, customerName, assetId, assetTitle });
    // The model dispatches straight to the listing's credited agent when
    // one's on file — if it did, start that agent's response countdown
    // the same way /:id/approve does.
    if (request.status === 'dispatched') armExpiry(request);
    broadcastTourRequest('tour_request:created', request);
    res.status(201).json(request);
  })
);

// GET /api/tour-requests?customerId=...   -> that customer's history
// GET /api/tour-requests/queue            -> Admin's queue (see below, separate route)
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { customerId } = req.query;
    if (!customerId) {
      return res.status(400).json({ error: 'customerId query param is required.' });
    }
    const rows = await model.listForCustomer(String(customerId));
    res.json(rows);
  })
);

// GET /api/tour-requests/queue -> Admin queue (pending_approval/declined/expired)
router.get(
  '/queue',
  asyncHandler(async (req, res) => {
    const rows = await model.listQueue();
    res.json(rows);
  })
);

// GET /api/tour-requests/agent/:agentId/active -> currently ringing for this agent
router.get(
  '/agent/:agentId/active',
  asyncHandler(async (req, res) => {
    const rows = await model.listActiveForAgent(req.params.agentId);
    res.json(rows);
  })
);

// GET /api/tour-requests/agent/:agentId -> this agent's full history
router.get(
  '/agent/:agentId',
  asyncHandler(async (req, res) => {
    const rows = await model.listHistoryForAgent(req.params.agentId);
    res.json(rows);
  })
);

// GET /api/tour-requests/:id
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const row = await model.findById(req.params.id);
    if (!row) return res.status(404).json({ error: 'Not found.' });
    res.json(row);
  })
);

// POST /api/tour-requests/:id/approve
// Admin dispatches the request to a specific agent, starting the countdown.
router.post(
  '/:id/approve',
  asyncHandler(async (req, res) => {
    const { agentId, agentName } = req.body || {};
    if (!agentId || !agentName) {
      return res.status(400).json({ error: 'agentId and agentName are required.' });
    }
    const request = await model.dispatch(req.params.id, { agentId, agentName });
    if (!request) {
      return res.status(409).json({
        error: 'Request is not in a dispatchable state (already dispatched/accepted, or missing).',
      });
    }
    armExpiry(request);
    broadcastTourRequest('tour_request:updated', request);
    res.json(request);
  })
);

// POST /api/tour-requests/:id/accept
router.post(
  '/:id/accept',
  asyncHandler(async (req, res) => {
    const { agentId } = req.body || {};
    if (!agentId) return res.status(400).json({ error: 'agentId is required.' });
    const request = await model.accept(req.params.id, agentId);
    if (!request) {
      return res.status(409).json({ error: 'Request is no longer awaiting this agent\'s response.' });
    }
    scheduler.cancel(request.id);
    broadcastTourRequest('tour_request:updated', request);
    res.json(request);
  })
);

// POST /api/tour-requests/:id/decline
router.post(
  '/:id/decline',
  asyncHandler(async (req, res) => {
    const { agentId } = req.body || {};
    if (!agentId) return res.status(400).json({ error: 'agentId is required.' });
    const request = await model.decline(req.params.id, agentId);
    if (!request) {
      return res.status(409).json({ error: 'Request is no longer awaiting this agent\'s response.' });
    }
    scheduler.cancel(request.id);
    broadcastTourRequest('tour_request:updated', request);

    // Credited/dispatched agent said no — try nearby agents instead of
    // just leaving it for Admin.
    const broadcast = await model.broadcastToNearby(request.id);
    if (broadcast) broadcastTourRequest('tour_request:updated', broadcast.row);

    res.json(request);
  })
);

// GET /api/tour-requests/agent/:agentId/broadcasting -> nearby requests
// this agent hasn't claimed (or lost) yet
router.get(
  '/agent/:agentId/broadcasting',
  asyncHandler(async (req, res) => {
    const rows = await model.listBroadcastingForAgent(req.params.agentId);
    res.json(rows);
  })
);

// POST /api/tour-requests/:id/claim
// A nearby agent claims a broadcasting request — first to claim wins.
router.post(
  '/:id/claim',
  asyncHandler(async (req, res) => {
    const { agentId, agentName } = req.body || {};
    if (!agentId || !agentName) {
      return res.status(400).json({ error: 'agentId and agentName are required.' });
    }
    const request = await model.claim(req.params.id, { agentId, agentName });
    if (!request) {
      return res.status(409).json({
        error: 'Someone else already claimed this, it\'s no longer broadcasting, or you weren\'t one of the agents it was sent to.',
      });
    }
    broadcastTourRequest('tour_request:updated', request);
    res.json(request);
  })
);

module.exports = { router, armExpiry };
