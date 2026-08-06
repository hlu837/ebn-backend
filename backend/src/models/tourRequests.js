const { query } = require('../db');
const usersModel = require('./users');
const assetsModel = require('./assets');

const DISPATCH_WINDOW_SECONDS = Number(process.env.DISPATCH_WINDOW_SECONDS || 30);

/** Radius nearby agents are broadcast within once the credited agent falls
 *  through (expires or declines) — same default as order_requests. */
const BROADCAST_RADIUS_KM = Number(process.env.TOUR_BROADCAST_RADIUS_KM || 7);

/** Statuses that make a request show up in the Admin queue. */
const QUEUE_STATUSES = ['pending_approval', 'broadcasting', 'declined', 'expired'];

/**
 * Creates a request. If `assets.broker_id` for this listing resolves to a
 * real agent account, the request is dispatched straight to them
 * (status 'dispatched', countdown already running) — Admin never has to
 * touch it unless that agent falls through. Otherwise it falls back to
 * the old behavior: 'pending_approval', Admin picks an agent manually.
 */
async function create({ customerId, customerName, assetId, assetTitle }) {
  const asset = await assetsModel.findById(assetId);
  const latitude = asset && asset.latitude ? Number(asset.latitude) : null;
  const longitude = asset && asset.longitude ? Number(asset.longitude) : null;

  // `broker_id` is free text (it can still hold a mock-data id from
  // mock_brokers.dart on older/seed listings) — only trust it as a real
  // credited agent if it actually resolves to an agent account.
  let creditedAgent = null;
  if (asset && asset.broker_id) {
    const candidate = await usersModel.findById(asset.broker_id).catch(() => null);
    if (candidate && candidate.role === 'agent') creditedAgent = candidate;
  }

  if (creditedAgent) {
    const row = await query(
      `INSERT INTO tour_requests (
         customer_id, customer_name, asset_id, asset_title,
         status, agent_id, agent_name, credited_agent_id,
         dispatch_window_seconds, dispatched_at, expires_at,
         latitude, longitude
       )
       VALUES (
         $1, $2, $3, $4,
         'dispatched', $5, $6, $5,
         $7, now(), now() + make_interval(secs => $7::int),
         $8, $9
       )
       RETURNING *`,
      [customerId, customerName, assetId, assetTitle, creditedAgent.id, creditedAgent.full_name, DISPATCH_WINDOW_SECONDS, latitude, longitude]
    ).then((r) => r.rows[0]);
    return row;
  }

  // No credited agent on file for this listing — same as before, Admin
  // has to pick one manually via /:id/approve.
  return query(
    `INSERT INTO tour_requests (customer_id, customer_name, asset_id, asset_title, latitude, longitude)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [customerId, customerName, assetId, assetTitle, latitude, longitude]
  ).then((r) => r.rows[0]);
}

function findById(id) {
  return query(`SELECT * FROM tour_requests WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

function listForCustomer(customerId) {
  return query(
    `SELECT * FROM tour_requests WHERE customer_id = $1 ORDER BY created_at DESC`,
    [customerId]
  ).then((r) => r.rows);
}

function listQueue() {
  return query(
    `SELECT * FROM tour_requests WHERE status = ANY($1::tour_request_status[])
     ORDER BY created_at ASC`,
    [QUEUE_STATUSES]
  ).then((r) => r.rows);
}

/** Requests currently ringing for a given agent (i.e. awaiting their response). */
function listActiveForAgent(agentId) {
  return query(
    `SELECT * FROM tour_requests WHERE agent_id = $1 AND status = 'dispatched'
     ORDER BY created_at ASC`,
    [agentId]
  ).then((r) => r.rows);
}

function listHistoryForAgent(agentId) {
  return query(
    `SELECT * FROM tour_requests WHERE agent_id = $1 ORDER BY created_at DESC`,
    [agentId]
  ).then((r) => r.rows);
}

/** Requests currently broadcasting to this agent (credited agent fell
 *  through, this agent is one of the nearby candidates) that no one has
 *  claimed yet. */
function listBroadcastingForAgent(agentId) {
  return query(
    `SELECT * FROM tour_requests
     WHERE status = 'broadcasting' AND $1 = ANY(broadcast_agent_ids)
     ORDER BY created_at ASC`,
    [agentId]
  ).then((r) => r.rows);
}

/** All requests currently in-flight (dispatched) — used to rebuild timers on boot. */
function listDispatched() {
  return query(`SELECT * FROM tour_requests WHERE status = 'dispatched'`).then((r) => r.rows);
}

/**
 * Admin approves a request that is pending / declined / expired, dispatching
 * it to a specific agent with a fresh countdown window.
 * Returns null (no-op) if the row isn't in a dispatchable state, so the
 * caller can distinguish "already handled" from a real error.
 */
function dispatch(id, { agentId, agentName }) {
  return query(
    `UPDATE tour_requests
     SET status = 'dispatched',
         agent_id = $2,
         agent_name = $3,
         dispatch_window_seconds = $4::int,
         dispatched_at = now(),
         expires_at = now() + make_interval(secs => $4::int),
         responded_at = NULL
     WHERE id = $1
       AND status = ANY(ARRAY['pending_approval','broadcasting','declined','expired']::tour_request_status[])
     RETURNING *`,
    [id, agentId, agentName, DISPATCH_WINDOW_SECONDS]
  ).then((r) => r.rows[0] || null);
}

/** Agent accepts — only succeeds if it's still dispatched to *this* agent. */
function accept(id, agentId) {
  return query(
    `UPDATE tour_requests
     SET status = 'accepted', responded_at = now()
     WHERE id = $1 AND agent_id = $2 AND status = 'dispatched'
     RETURNING *`,
    [id, agentId]
  ).then((r) => r.rows[0] || null);
}

/** Agent declines — only succeeds if it's still dispatched to *this* agent. */
function decline(id, agentId) {
  return query(
    `UPDATE tour_requests
     SET status = 'declined', responded_at = now()
     WHERE id = $1 AND agent_id = $2 AND status = 'dispatched'
     RETURNING *`,
    [id, agentId]
  ).then((r) => r.rows[0] || null);
}

/**
 * Server-side countdown expiry. Guarded by `status = 'dispatched'` so a race
 * with a near-simultaneous accept/decline can't clobber the real outcome.
 */
function expire(id) {
  return query(
    `UPDATE tour_requests
     SET status = 'expired', responded_at = now()
     WHERE id = $1 AND status = 'dispatched'
     RETURNING *`,
    [id]
  ).then((r) => r.rows[0] || null);
}

/**
 * Falls through from a `declined` or `expired` request (the credited
 * agent didn't answer, or said no) to broadcasting the same request to
 * whichever agents are nearby — same "first to claim wins" shape as
 * order_requests. No-op (returns null) if the request isn't actually in
 * one of those states anymore, or has no location on file to search
 * around (e.g. the listing itself never had coordinates) — in that case
 * it just stays visible in Admin's queue for a manual pick, same as before.
 */
async function broadcastToNearby(id) {
  const existing = await findById(id);
  if (!existing) return null;
  if (!['declined', 'expired'].includes(existing.status)) return null;
  if (existing.latitude == null || existing.longitude == null) return null;

  const excludedAgentIds = existing.credited_agent_id
    ? [...new Set([...(existing.excluded_agent_ids || []), existing.credited_agent_id])]
    : existing.excluded_agent_ids || [];

  const nearbyAgents = await usersModel.findNearbyAgents({
    latitude: existing.latitude,
    longitude: existing.longitude,
    radiusKm: BROADCAST_RADIUS_KM,
    excludeAgentIds: excludedAgentIds,
  });
  const broadcastAgentIds = nearbyAgents.map((a) => a.id);

  const row = await query(
    `UPDATE tour_requests
     SET status = 'broadcasting',
         broadcast_agent_ids = $2,
         excluded_agent_ids = $3,
         agent_id = NULL,
         agent_name = NULL,
         dispatched_at = NULL,
         expires_at = NULL,
         responded_at = NULL
     WHERE id = $1 AND status = ANY(ARRAY['declined','expired']::tour_request_status[])
     RETURNING *`,
    [id, broadcastAgentIds, excludedAgentIds]
  ).then((r) => r.rows[0] || null);

  if (!row) return null;
  return { row, agentsNotified: broadcastAgentIds.length };
}

/**
 * First nearby agent to claim a broadcasting request wins — atomic: only
 * succeeds if it's still `broadcasting` AND this agent was actually one
 * it was sent to.
 */
function claim(id, { agentId, agentName }) {
  return query(
    `UPDATE tour_requests
     SET status = 'accepted', agent_id = $2, agent_name = $3, responded_at = now()
     WHERE id = $1 AND status = 'broadcasting' AND $2 = ANY(broadcast_agent_ids)
     RETURNING *`,
    [id, agentId, agentName]
  ).then((r) => r.rows[0] || null);
}

module.exports = {
  DISPATCH_WINDOW_SECONDS,
  BROADCAST_RADIUS_KM,
  create,
  findById,
  listForCustomer,
  listQueue,
  listActiveForAgent,
  listBroadcastingForAgent,
  listHistoryForAgent,
  listDispatched,
  dispatch,
  accept,
  decline,
  expire,
  broadcastToNearby,
  claim,
};
