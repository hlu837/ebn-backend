const { query } = require('../db');
const usersModel = require('./users');
const agentSettingsModel = require('./agentSettings');
const notificationsModel = require('./notifications');
const { broadcastNotification } = require('../socket');

/** Radius agents are broadcast within — see `submit`'s call to findNearbyAgents. */
const BROADCAST_RADIUS_KM = 7;

/**
 * Writes a `new_dispatch` notification for each agent a request was just
 * broadcast to, respecting their `notifyNewDispatches` preference (agent
 * settings screen) — an agent who's opted out gets neither the row nor
 * the live push. Best-effort: a failure here shouldn't fail the request
 * that triggered it, so errors are logged and swallowed.
 */
async function notifyAgentsOfDispatch(orderRequestRow, agentIds) {
  await Promise.all(
    agentIds.map(async (agentId) => {
      try {
        const settings = agentSettingsModel.toPublic(await agentSettingsModel.getOrCreate(agentId));
        if (settings && settings.notifyNewDispatches === false) return;

        const row = await notificationsModel.create({
          recipientType: 'agent',
          recipientId: agentId,
          kind: 'new_dispatch',
          title: 'New order request nearby',
          body: `${orderRequestRow.title} — ${orderRequestRow.budget_summary || 'budget not specified'}`,
          relatedId: orderRequestRow.id,
        });
        broadcastNotification('agent', agentId, notificationsModel.toPublic(row));
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error(`[orderRequests] failed to notify agent ${agentId} of dispatch`, err);
      }
    })
  );
}

/** Converts a DB row (snake_case) to the camelCase shape the client expects. */
function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    submittedAt: row.created_at,
    requesterUserId: row.requester_user_id,
    requesterName: row.requester_name,
    requesterPhone: row.requester_phone,
    category: row.category,
    title: row.title,
    description: row.description,
    budgetSummary: row.budget_summary,
    status: row.status,

    locationSource: row.location_source,
    latitude: row.latitude,
    longitude: row.longitude,
    addressText: row.address_text,

    broadcastAgentIds: row.broadcast_agent_ids || [],
    excludedAgentIds: row.excluded_agent_ids || [],
    assignedAgentId: row.assigned_agent_id,
    assignedAgentName: row.assigned_agent_name,
    assignedAgentPhone: row.assigned_agent_phone,
    confirmedAt: row.confirmed_at,
    disputeReason: row.dispute_reason,

    updatedAt: row.updated_at,
  };
}

// ── Visitor: submit ───────────────────────────────────────────────────────
/**
 * Creates a request already broadcast to whichever agents are within
 * [BROADCAST_RADIUS_KM] of ([latitude], [longitude]) — the caller
 * (routes/orderRequests.js) resolves latitude/longitude first, either
 * straight from GPS or via geocoding a manual address.
 */
async function create({
  requesterUserId,
  requesterName,
  requesterPhone,
  category,
  title,
  description,
  budgetSummary,
  locationSource,
  latitude,
  longitude,
  addressText,
}) {
  const nearbyAgents = await usersModel.findNearbyAgents({
    latitude,
    longitude,
    radiusKm: BROADCAST_RADIUS_KM,
  });
  const broadcastAgentIds = nearbyAgents.map((a) => a.id);

  const row = await query(
    `INSERT INTO order_requests (
       requester_user_id, requester_name, requester_phone, category,
       title, description, budget_summary,
       location_source, latitude, longitude, address_text,
       broadcast_agent_ids
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     RETURNING *`,
    [
      requesterUserId,
      requesterName,
      requesterPhone,
      category,
      title,
      description,
      budgetSummary,
      locationSource,
      latitude,
      longitude,
      addressText || null,
      broadcastAgentIds,
    ]
  ).then((r) => r.rows[0]);

  await notifyAgentsOfDispatch(row, broadcastAgentIds);

  return { row, agentsNotified: broadcastAgentIds.length };
}

function findById(id) {
  return query(`SELECT * FROM order_requests WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

function listByRequester(requesterUserId) {
  return query(
    `SELECT * FROM order_requests WHERE requester_user_id = $1 ORDER BY created_at DESC`,
    [requesterUserId]
  ).then((r) => r.rows);
}

// ── Agent ────────────────────────────────────────────────────────────────
/** Broadcasting requests this agent was notified about and hasn't lost to someone else. */
function listBroadcastingForAgent(agentId) {
  return query(
    `SELECT * FROM order_requests
     WHERE status = 'broadcasting'::order_request_status AND $1 = ANY(broadcast_agent_ids)
     ORDER BY created_at ASC`,
    [agentId]
  ).then((r) => r.rows);
}

/** Everything this agent currently has (or has had) assigned to them. */
function listAssignedToAgent(agentId) {
  return query(
    `SELECT * FROM order_requests WHERE assigned_agent_id = $1 ORDER BY created_at DESC`,
    [agentId]
  ).then((r) => r.rows);
}

/**
 * First agent to claim wins — atomic: only succeeds if the request is
 * still `broadcasting` AND this agent was actually one it was sent to.
 */
function claim(id, { agentId, agentName, agentPhone }) {
  return query(
    `UPDATE order_requests
     SET status = 'agent_confirmed'::order_request_status,
         assigned_agent_id = $2,
         assigned_agent_name = $3,
         assigned_agent_phone = $4,
         confirmed_at = now()
     WHERE id = $1
       AND status = 'broadcasting'::order_request_status
       AND $2 = ANY(broadcast_agent_ids)
     RETURNING *`,
    [id, agentId, agentName, agentPhone]
  ).then((r) => r.rows[0] || null);
}

/**
 * Agent closes out a request they're assigned to — atomic: only succeeds
 * if the request is still `agent_confirmed` AND this agent is the one it's
 * assigned to (same guard pattern as [claim]).
 */
function complete(id, { agentId }) {
  return query(
    `UPDATE order_requests
     SET status = 'closed'::order_request_status
     WHERE id = $1
       AND status = 'agent_confirmed'::order_request_status
       AND assigned_agent_id = $2
     RETURNING *`,
    [id, agentId]
  ).then((r) => r.rows[0] || null);
}

// ── Visitor: report a dispute ───────────────────────────────────────────
/** Only a confirmed (agent-assigned) request can be reported. */
function report(id, { requesterUserId, reason }) {
  return query(
    `UPDATE order_requests
     SET status = 'disputed'::order_request_status, dispute_reason = $3
     WHERE id = $1 AND requester_user_id = $2 AND status = 'agent_confirmed'::order_request_status
     RETURNING *`,
    [id, requesterUserId, reason || null]
  ).then((r) => r.rows[0] || null);
}

// ── Agent: report a dispute ─────────────────────────────────────────────
/**
 * Same effect as [report], but for the assigned agent's side of a
 * confirmed request instead of the requester's — e.g. the client went
 * unreachable, or the deal fell through for reasons outside the agent's
 * control. Same guard shape as [complete]: only the agent this request is
 * actually assigned to can report it, and only while it's still
 * `agent_confirmed`.
 */
function reportByAgent(id, { agentId, reason }) {
  return query(
    `UPDATE order_requests
     SET status = 'disputed'::order_request_status, dispute_reason = $3
     WHERE id = $1 AND assigned_agent_id = $2 AND status = 'agent_confirmed'::order_request_status
     RETURNING *`,
    [id, agentId, reason || null]
  ).then((r) => r.rows[0] || null);
}

// ── Admin ────────────────────────────────────────────────────────────────
function listByStatus(status) {
  return query(
    `SELECT * FROM order_requests WHERE status = $1::order_request_status ORDER BY created_at ASC`,
    [status]
  ).then((r) => r.rows);
}

/**
 * Re-broadcasts a disputed request to nearby agents again — same
 * submitted data, no need for the Visitor to fill the form out again.
 * The previously assigned agent is excluded so they can't be reassigned
 * the same request that just fell through.
 */
async function repost(id) {
  const existing = await findById(id);
  if (!existing || existing.status !== 'disputed') return null;

  const excludedAgentIds = existing.assigned_agent_id
    ? [...new Set([...(existing.excluded_agent_ids || []), existing.assigned_agent_id])]
    : existing.excluded_agent_ids || [];

  const nearbyAgents = await usersModel.findNearbyAgents({
    latitude: existing.latitude,
    longitude: existing.longitude,
    radiusKm: BROADCAST_RADIUS_KM,
    excludeAgentIds: excludedAgentIds,
  });
  const broadcastAgentIds = nearbyAgents.map((a) => a.id);

  const row = await query(
    `UPDATE order_requests
     SET status = 'broadcasting'::order_request_status,
         broadcast_agent_ids = $2,
         excluded_agent_ids = $3,
         assigned_agent_id = NULL,
         assigned_agent_name = NULL,
         assigned_agent_phone = NULL,
         confirmed_at = NULL
     WHERE id = $1 AND status = 'disputed'::order_request_status
     RETURNING *`,
    [id, broadcastAgentIds, excludedAgentIds]
  ).then((r) => r.rows[0] || null);

  if (row) await notifyAgentsOfDispatch(row, broadcastAgentIds);

  return { row, agentsNotified: broadcastAgentIds.length };
}

/** Any non-closed status -> closed. */
function close(id) {
  return query(
    `UPDATE order_requests
     SET status = 'closed'::order_request_status
     WHERE id = $1 AND status <> 'closed'::order_request_status
     RETURNING *`,
    [id]
  ).then((r) => r.rows[0] || null);
}

module.exports = {
  BROADCAST_RADIUS_KM,
  toPublic,
  create,
  findById,
  listByRequester,
  listBroadcastingForAgent,
  listAssignedToAgent,
  claim,
  complete,
  report,
  reportByAgent,
  listByStatus,
  repost,
  close,
};
