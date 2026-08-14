const express = require('express');
const model = require('../models/sellRequests');
const notificationsModel = require('../models/notifications');
const { broadcastNotification } = require('../socket');
const { geocodeAddress, GeocodingError } = require('../services/geocoding');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

const REQUIRED_SUBMIT_FIELDS = [
  'ownerUserId',
  'ownerName',
  'ownerPhone',
  'category',
  'title',
  'description',
  'askingPrice',
  'city',
  'addressLine',
];

// ── Visitor ──────────────────────────────────────────────────────────────

// POST /api/sell-requests
// Visitor submits a new "sell my property" request. Payment is expected to
// already be confirmed client-side before this is called (feePaid defaults
// to true) — wire in a real payment check here if/when one exists.
router.post(
  '/',
  asyncHandler(async (req, res) => {
    const body = req.body || {};
    const missing = REQUIRED_SUBMIT_FIELDS.filter((f) => body[f] === undefined || body[f] === null || body[f] === '');
    if (missing.length) {
      return res.status(400).json({ error: `Missing required field(s): ${missing.join(', ')}.` });
    }

    // Best-effort: geocode the submitted address so approval can broadcast
    // to nearby agents (see models/sellRequests.js#approveSubmission). A
    // failure here (no API key configured, address didn't resolve) isn't
    // fatal — the request still gets created and just falls back to the
    // old "open to every agent" behavior on approval.
    let latitude = null;
    let longitude = null;
    try {
      const geocoded = await geocodeAddress(`${body.addressLine}, ${body.city}`);
      latitude = geocoded.latitude;
      longitude = geocoded.longitude;
    } catch (err) {
      if (!(err instanceof GeocodingError)) throw err;
      // eslint-disable-next-line no-console
      console.warn(`[sellRequests] geocoding failed for submission, will fall back to open_to_brokers: ${err.message}`);
    }

    const row = await model.create({ ...body, latitude, longitude });
    const created = model.toPublic(row);

    try {
      const notifRow = await notificationsModel.create({
        recipientType: 'admin',
        kind: 'system',
        title: 'New sell request submitted',
        body: `${created.ownerName || 'A visitor'} submitted "${created.title}" for approval.`,
        relatedId: created.id,
      });
      broadcastNotification('admin', null, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[sellRequests] failed to notify admins of new submission', err);
    }

    res.status(201).json(created);
  })
);

// ── Agent: self-listing submit ──────────────────────────────────────────

const REQUIRED_AGENT_SUBMIT_FIELDS = [...REQUIRED_SUBMIT_FIELDS, 'agentId', 'agentName', 'notes'];

// POST /api/sell-requests/agent-listing
// An Agent submits a property they own themselves — everything a Visitor
// submits, plus the media/notes a report would normally carry. Same
// 100 ETB fee (feePaid defaults true, same caveat as the Visitor route
// above). Lands in the same Admin submission queue, but approval publishes
// it directly under this Agent's name — see model#approveSubmission.
router.post(
  '/agent-listing',
  asyncHandler(async (req, res) => {
    const body = req.body || {};
    const missing = REQUIRED_AGENT_SUBMIT_FIELDS.filter((f) => body[f] === undefined || body[f] === null || body[f] === '');
    if (missing.length) {
      return res.status(400).json({ error: `Missing required field(s): ${missing.join(', ')}.` });
    }
    if (!Array.isArray(body.media) || body.media.length === 0) {
      return res.status(400).json({ error: 'At least one photo/video is required in media.' });
    }

    let latitude = null;
    let longitude = null;
    try {
      const geocoded = await geocodeAddress(`${body.addressLine}, ${body.city}`);
      latitude = geocoded.latitude;
      longitude = geocoded.longitude;
    } catch (err) {
      if (!(err instanceof GeocodingError)) throw err;
      // eslint-disable-next-line no-console
      console.warn(`[sellRequests] geocoding failed for agent listing, will fall back to null location: ${err.message}`);
    }

    const row = await model.createAgentListing({ ...body, notes: String(body.notes).trim(), latitude, longitude });
    const created = model.toPublic(row);

    try {
      const notifRow = await notificationsModel.create({
        recipientType: 'admin',
        kind: 'system',
        title: 'New agent self-listing submitted',
        body: `${created.agentName || 'An agent'} submitted their own property "${created.title}" for approval.`,
        relatedId: created.id,
      });
      broadcastNotification('admin', null, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[sellRequests] failed to notify admins of new agent listing', err);
    }

    res.status(201).json(created);
  })
);

// GET /api/sell-requests?ownerUserId=...  -> that owner's full history
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { ownerUserId } = req.query;
    if (!ownerUserId) {
      return res.status(400).json({ error: 'ownerUserId query param is required.' });
    }
    const rows = await model.listByOwner(String(ownerUserId));
    res.json(rows.map(model.toPublic));
  })
);

// ── Admin: submission screening ─────────────────────────────────────────

// GET /api/sell-requests/pending-submissions
router.get(
  '/pending-submissions',
  asyncHandler(async (req, res) => {
    const rows = await model.listPendingSubmissions();
    res.json(rows.map(model.toPublic));
  })
);

// POST /api/sell-requests/:id/approve-submission
// Body: { listedAssetId? } — only meaningful for Agent self-listings
// (see model#approveSubmission), which publish straight away instead of
// broadcasting to the claim pool; ignored for ordinary Visitor submissions.
router.post(
  '/:id/approve-submission',
  asyncHandler(async (req, res) => {
    const row = await model.approveSubmission(req.params.id, { listedAssetId: req.body?.listedAssetId || null });
    if (!row) return res.status(409).json({ error: 'Request is not awaiting submission approval.' });
    res.json(model.toPublic(row));
  })
);

// POST /api/sell-requests/:id/reject-submission
// Body: { reason? }
router.post(
  '/:id/reject-submission',
  asyncHandler(async (req, res) => {
    const row = await model.rejectSubmission(req.params.id, req.body?.reason);
    if (!row) return res.status(409).json({ error: 'Request is not awaiting submission approval.' });
    res.json(model.toPublic(row));
  })
);

// ── Agent/Broker: claim ──────────────────────────────────────────────────

// GET /api/sell-requests/open
router.get(
  '/open',
  asyncHandler(async (req, res) => {
    const rows = await model.listOpenToBrokers();
    res.json(rows.map(model.toPublic));
  })
);

// GET /api/sell-requests/agent/:agentId/broadcasting -> nearby requests
// this agent hasn't claimed (or lost) yet
router.get(
  '/agent/:agentId/broadcasting',
  asyncHandler(async (req, res) => {
    const rows = await model.listBroadcastingForAgent(req.params.agentId);
    res.json(rows.map(model.toPublic));
  })
);

// GET /api/sell-requests/agent/:agentId/claimed
router.get(
  '/agent/:agentId/claimed',
  asyncHandler(async (req, res) => {
    const rows = await model.listClaimedByAgent(req.params.agentId);
    res.json(rows.map(model.toPublic));
  })
);

// GET /api/sell-requests/agent/:agentId/pending-reports
router.get(
  '/agent/:agentId/pending-reports',
  asyncHandler(async (req, res) => {
    const rows = await model.listPendingReportsByAgent(req.params.agentId);
    res.json(rows.map(model.toPublic));
  })
);

// GET /api/sell-requests/agent/:agentId/listed
router.get(
  '/agent/:agentId/listed',
  asyncHandler(async (req, res) => {
    const rows = await model.listListedByAgent(req.params.agentId);
    res.json(rows.map(model.toPublic));
  })
);

// POST /api/sell-requests/:id/claim
// First-come-first-served. Body: { agentId, agentName }.
router.post(
  '/:id/claim',
  asyncHandler(async (req, res) => {
    const { agentId, agentName } = req.body || {};
    if (!agentId || !agentName) {
      return res.status(400).json({ error: 'agentId and agentName are required.' });
    }
    const row = await model.claim(req.params.id, { agentId, agentName });
    if (!row) return res.status(409).json({ error: 'Request is no longer open — someone else may have claimed it.' });
    res.json(model.toPublic(row));
  })
);

// ── Agent/Broker: inspection report ─────────────────────────────────────

// POST /api/sell-requests/:id/report
// Body: { agentId, media: [{ id, isVideo }], notes }
router.post(
  '/:id/report',
  asyncHandler(async (req, res) => {
    const { agentId, media, notes } = req.body || {};
    if (!agentId) return res.status(400).json({ error: 'agentId is required.' });
    if (!Array.isArray(media) || media.length === 0) {
      return res.status(400).json({ error: 'At least one photo/video is required in media.' });
    }
    if (!notes || !String(notes).trim()) {
      return res.status(400).json({ error: 'notes is required.' });
    }
    const row = await model.submitReport(req.params.id, { agentId, media, notes: String(notes).trim() });
    if (!row) {
      return res.status(409).json({
        error: "Request isn't claimed by this agent, or isn't awaiting a report.",
      });
    }
    res.json(model.toPublic(row));
  })
);

// ── Admin: report screening → publish ───────────────────────────────────

// GET /api/sell-requests/pending-reports
router.get(
  '/pending-reports',
  asyncHandler(async (req, res) => {
    const rows = await model.listPendingReports();
    res.json(rows.map(model.toPublic));
  })
);

// POST /api/sell-requests/:id/approve-report
// Body: { listedAssetId? } — this service doesn't own listings/assets, so
// the caller (or a downstream assets service) supplies the id it created;
// omit it and the request is still marked `listed` with a null asset id.
router.post(
  '/:id/approve-report',
  asyncHandler(async (req, res) => {
    const { listedAssetId } = req.body || {};
    const row = await model.approveReport(req.params.id, { listedAssetId: listedAssetId || null });
    if (!row) return res.status(409).json({ error: 'Request is not awaiting report approval.' });
    res.json(model.toPublic(row));
  })
);

// POST /api/sell-requests/:id/reject-report
// Body: { reason? }
router.post(
  '/:id/reject-report',
  asyncHandler(async (req, res) => {
    const row = await model.rejectReport(req.params.id, req.body?.reason);
    if (!row) return res.status(409).json({ error: 'Request is not awaiting report approval.' });
    res.json(model.toPublic(row));
  })
);

// GET /api/sell-requests/:id — fetch one (keep last: matches other :id routes)
router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const row = await model.findById(req.params.id);
    if (!row) return res.status(404).json({ error: 'Not found.' });
    res.json(model.toPublic(row));
  })
);

module.exports = { router };
