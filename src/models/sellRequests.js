const { query } = require('../db');
const usersModel = require('./users');
const agentSettingsModel = require('./agentSettings');
const notificationsModel = require('./notifications');
const { broadcastNotification } = require('../socket');

/** Statuses that make a request show up in Admin's submission-screening queue. */
const PENDING_SUBMISSION_STATUS = 'pending_admin_approval';
/** Statuses that make a request show up in Admin's report-screening queue. */
const PENDING_REPORT_STATUS = 'report_pending_approval';
/** Status sent to nearby agents first — first to claim wins. Falls back to
 *  OPEN_TO_BROKERS_STATUS when the submission has no usable location or no
 *  agent is within radius (see `approveSubmission`). */
const BROADCASTING_STATUS = 'broadcasting';
/** Fallback status that makes a request claimable by any Agent/Broker. */
const OPEN_TO_BROKERS_STATUS = 'open_to_brokers';
/** Statuses an Agent's "my claimed requests" list includes — a rejected
 *  report goes back to the same agent to revise, not back into the open pool. */
const AGENT_CLAIMED_STATUSES = ['claimed', 'report_rejected'];

/** Radius nearby agents are broadcast within — same default as tour/order requests. */
const BROADCAST_RADIUS_KM = Number(process.env.SELL_REQUEST_BROADCAST_RADIUS_KM || 7);

/**
 * Writes a `new_dispatch` notification for each agent a request was just
 * broadcast to, respecting their `notifyNewDispatches` preference. Best
 * effort — a failure here shouldn't fail the approval that triggered it.
 */
async function notifyAgentsOfDispatch(row, agentIds) {
  await Promise.all(
    agentIds.map(async (agentId) => {
      try {
        const settings = agentSettingsModel.toPublic(await agentSettingsModel.getOrCreate(agentId));
        if (settings && settings.notifyNewDispatches === false) return;

        const notifRow = await notificationsModel.create({
          recipientType: 'agent',
          recipientId: agentId,
          kind: 'new_dispatch',
          title: 'Sell request nearby',
          body: `A visitor near you wants "${row.title}" inspected — first to claim gets it.`,
          relatedId: row.id,
        });
        broadcastNotification('agent', agentId, notificationsModel.toPublic(notifRow));
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error(`[sellRequests] failed to notify agent ${agentId} of broadcast`, err);
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
    ownerUserId: row.owner_user_id,
    ownerName: row.owner_name,
    ownerPhone: row.owner_phone,
    category: row.category,
    title: row.title,
    description: row.description,
    askingPrice: Number(row.asking_price),
    city: row.city,
    addressLine: row.address_line,
    latitude: row.latitude,
    longitude: row.longitude,
    broadcastAgentIds: row.broadcast_agent_ids || [],
    feeAmount: Number(row.fee_amount),
    feePaid: row.fee_paid,
    houseDetails: row.house_details,
    vehicleDetails: row.vehicle_details,
    machineryDetails: row.machinery_details,
    isAgentListing: row.is_agent_listing,
    status: row.status,
    submissionRejectionReason: row.submission_rejection_reason,
    agentId: row.agent_id,
    agentName: row.agent_name,
    claimedAt: row.claimed_at,
    reportMedia: row.report_media,
    reportNotes: row.report_notes,
    reportSubmittedAt: row.report_submitted_at,
    reportRejectionReason: row.report_rejection_reason,
    listedAssetId: row.listed_asset_id,
    updatedAt: row.updated_at,
  };
}

// ── Visitor: submit ───────────────────────────────────────────────────────
function create({
  ownerUserId,
  ownerName,
  ownerPhone,
  category,
  title,
  description,
  askingPrice,
  city,
  addressLine,
  latitude,
  longitude,
  feeAmount,
  feePaid,
  houseDetails,
  vehicleDetails,
  machineryDetails,
  media,
}) {
  return query(
    `INSERT INTO sell_requests (
       owner_user_id, owner_name, owner_phone, category, title, description,
       asking_price, city, address_line, latitude, longitude, fee_amount, fee_paid,
       house_details, vehicle_details, machinery_details, report_media
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17::jsonb)
     RETURNING *`,
    [
      ownerUserId,
      ownerName,
      ownerPhone,
      category,
      title,
      description,
      askingPrice,
      city,
      addressLine,
      latitude ?? null,
      longitude ?? null,
      feeAmount ?? 100,
      feePaid ?? true,
      houseDetails ? JSON.stringify(houseDetails) : null,
      vehicleDetails ? JSON.stringify(vehicleDetails) : null,
      machineryDetails ? JSON.stringify(machineryDetails) : null,
      JSON.stringify(media || []),
    ]
  ).then((r) => r.rows[0]);
}

// ── Agent: self-listing submit ──────────────────────────────────────────
/**
 * An Agent submitting a property they own themselves — same fields a
 * Visitor fills in, plus the photos/video + written notes a report
 * normally only gets *after* some other Agent claims and inspects it.
 * Since the submitting Agent already *is* the on-the-ground source,
 * `agent_id`/`agent_name`/`report_media`/`report_notes` are all populated
 * immediately and `is_agent_listing` is set so `approveSubmission` knows
 * to publish it directly under this Agent's name instead of broadcasting
 * it to the claim pool. Still lands in the same `pending_admin_approval`
 * queue Admin already screens Visitor submissions from.
 */
function createAgentListing({
  ownerUserId,
  ownerName,
  ownerPhone,
  category,
  title,
  description,
  askingPrice,
  city,
  addressLine,
  latitude,
  longitude,
  feeAmount,
  feePaid,
  houseDetails,
  vehicleDetails,
  machineryDetails,
  agentId,
  agentName,
  media,
  notes,
}) {
  return query(
    `INSERT INTO sell_requests (
       owner_user_id, owner_name, owner_phone, category, title, description,
       asking_price, city, address_line, latitude, longitude, fee_amount, fee_paid,
       house_details, vehicle_details, machinery_details,
       is_agent_listing, agent_id, agent_name,
       report_media, report_notes, report_submitted_at
     )
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16,
             true, $17, $18, $19::jsonb, $20, now())
     RETURNING *`,
    [
      ownerUserId,
      ownerName,
      ownerPhone,
      category,
      title,
      description,
      askingPrice,
      city,
      addressLine,
      latitude ?? null,
      longitude ?? null,
      feeAmount ?? 100,
      feePaid ?? true,
      houseDetails ? JSON.stringify(houseDetails) : null,
      vehicleDetails ? JSON.stringify(vehicleDetails) : null,
      machineryDetails ? JSON.stringify(machineryDetails) : null,
      agentId,
      agentName,
      JSON.stringify(media || []),
      notes,
    ]
  ).then((r) => r.rows[0]);
}

function findById(id) {
  return query(`SELECT * FROM sell_requests WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

function listByOwner(ownerUserId) {
  return query(
    `SELECT * FROM sell_requests WHERE owner_user_id = $1 ORDER BY created_at DESC`,
    [ownerUserId]
  ).then((r) => r.rows);
}

// ── Admin: submission screening ─────────────────────────────────────────
function listPendingSubmissions() {
  return query(
    `SELECT * FROM sell_requests WHERE status = $1::sell_request_status ORDER BY created_at ASC`,
    [PENDING_SUBMISSION_STATUS]
  ).then((r) => r.rows);
}

/**
 * Approves a pending submission. Tries the nearest-agent broadcast first
 * (same pattern as tour/order requests) using the location captured at
 * submission — falls back to the old global `open_to_brokers` behavior
 * when the request has no usable location (address didn't geocode) or no
 * agent is within radius, so it's never stuck unclaimable.
 */
async function approveSubmission(id, { listedAssetId } = {}) {
  const existing = await findById(id);
  if (!existing || existing.status !== PENDING_SUBMISSION_STATUS) return null;

  // Agent self-listings already carry their own report (media + notes) —
  // there's no one else to claim/inspect it, so approval publishes it
  // straight away under the submitting Agent's name instead of entering
  // the broadcasting/claimed/report_pending_approval pipeline.
  if (existing.is_agent_listing) {
    return query(
      `UPDATE sell_requests
       SET status = 'listed'::sell_request_status, listed_asset_id = $2
       WHERE id = $1 AND status = $3::sell_request_status
       RETURNING *`,
      [id, listedAssetId || null, PENDING_SUBMISSION_STATUS]
    ).then((r) => r.rows[0] || null);
  }

  let targetStatus = OPEN_TO_BROKERS_STATUS;
  let broadcastAgentIds = [];
  if (existing.latitude != null && existing.longitude != null) {
    const nearbyAgents = await usersModel.findNearbyAgents({
      latitude: existing.latitude,
      longitude: existing.longitude,
      radiusKm: BROADCAST_RADIUS_KM,
    });
    if (nearbyAgents.length) {
      targetStatus = BROADCASTING_STATUS;
      broadcastAgentIds = nearbyAgents.map((a) => a.id);
    }
  }

  const row = await query(
    `UPDATE sell_requests
     SET status = $2::sell_request_status, broadcast_agent_ids = $3
     WHERE id = $1 AND status = $4::sell_request_status
     RETURNING *`,
    [id, targetStatus, broadcastAgentIds, PENDING_SUBMISSION_STATUS]
  ).then((r) => r.rows[0] || null);

  if (row && targetStatus === BROADCASTING_STATUS) {
    await notifyAgentsOfDispatch(row, broadcastAgentIds);
  }

  return row;
}

function rejectSubmission(id, reason) {
  return query(
    `UPDATE sell_requests
     SET status = 'submission_rejected'::sell_request_status, submission_rejection_reason = $2
     WHERE id = $1 AND status = $3::sell_request_status
     RETURNING *`,
    [id, reason || 'Did not meet listing requirements.', PENDING_SUBMISSION_STATUS]
  ).then((r) => r.rows[0] || null);
}

// ── Agent/Broker: claim ──────────────────────────────────────────────────
function listOpenToBrokers() {
  return query(
    `SELECT * FROM sell_requests WHERE status = $1::sell_request_status ORDER BY created_at ASC`,
    [OPEN_TO_BROKERS_STATUS]
  ).then((r) => r.rows);
}

/** Requests currently broadcasting to this agent (nearby, unclaimed) — same
 *  shape as tour/order requests' broadcasting lists. */
function listBroadcastingForAgent(agentId) {
  return query(
    `SELECT * FROM sell_requests
     WHERE status = $1::sell_request_status AND $2 = ANY(broadcast_agent_ids)
     ORDER BY created_at ASC`,
    [BROADCASTING_STATUS, agentId]
  ).then((r) => r.rows);
}

function listClaimedByAgent(agentId) {
  return query(
    `SELECT * FROM sell_requests
     WHERE agent_id = $1 AND status = ANY($2::sell_request_status[])
     ORDER BY created_at DESC`,
    [agentId, AGENT_CLAIMED_STATUSES]
  ).then((r) => r.rows);
}

function listPendingReportsByAgent(agentId) {
  return query(
    `SELECT * FROM sell_requests WHERE agent_id = $1 AND status = $2::sell_request_status
     ORDER BY created_at DESC`,
    [agentId, PENDING_REPORT_STATUS]
  ).then((r) => r.rows);
}

function listListedByAgent(agentId) {
  return query(
    `SELECT * FROM sell_requests WHERE agent_id = $1 AND status = 'listed'::sell_request_status
     ORDER BY created_at DESC`,
    [agentId]
  ).then((r) => r.rows);
}

async function notifyOwnerOfClaim(row) {
  if (!row || !row.owner_user_id) return;
  try {
    const user = await usersModel.findById(row.owner_user_id).catch(() => null);
    const recipientType = user && user.role ? user.role : 'user';

    const notifRow = await notificationsModel.create({
      recipientType,
      recipientId: String(row.owner_user_id),
      kind: 'system',
      title: 'Listing Request Claimed',
      body: `Agent ${row.agent_name || 'an agent'} has claimed your property listing request "${row.title}" for inspection.`,
      relatedId: String(row.id),
    });

    broadcastNotification(recipientType, String(row.owner_user_id), notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(`[sellRequests] failed to notify owner ${row.owner_user_id} of claim`, err);
  }
}

/**
 * First-come-first-served claim. Succeeds while the row is still
 * `open_to_brokers` (anyone), or while it's `broadcasting` and this agent
 * is one of the ones it was sent to. Returns null if someone else already
 * claimed it, or this agent wasn't in the broadcast pool (caller reports
 * that as 409, not a 500).
 */
async function claim(id, { agentId, agentName }) {
  const row = await query(
    `UPDATE sell_requests
     SET status = 'claimed'::sell_request_status, agent_id = $2, agent_name = $3, claimed_at = now()
     WHERE id = $1
       AND (
         status = $4::sell_request_status
         OR (status = $5::sell_request_status AND $2 = ANY(broadcast_agent_ids))
       )
     RETURNING *`,
    [id, agentId, agentName, OPEN_TO_BROKERS_STATUS, BROADCASTING_STATUS]
  ).then((r) => r.rows[0] || null);

  if (row) {
    await notifyOwnerOfClaim(row);
  }

  return row;
}

// ── Agent/Broker: inspection report ─────────────────────────────────────
/**
 * Only succeeds if the request is `claimed` or `report_rejected` AND
 * belongs to this agent — guards against submitting a report for a
 * request someone else claimed.
 */
function submitReport(id, { agentId, media, notes }) {
  return query(
    `UPDATE sell_requests
     SET status = $5::sell_request_status,
         report_media = $3::jsonb,
         report_notes = $4,
         report_submitted_at = now(),
         report_rejection_reason = NULL
     WHERE id = $1
       AND agent_id = $2
       AND status = ANY(ARRAY['claimed','report_rejected']::sell_request_status[])
     RETURNING *`,
    [id, agentId, JSON.stringify(media || []), notes, PENDING_REPORT_STATUS]
  ).then((r) => r.rows[0] || null);
}

// ── Admin: report screening → publish ───────────────────────────────────
function listPendingReports() {
  return query(
    `SELECT * FROM sell_requests WHERE status = $1::sell_request_status ORDER BY created_at ASC`,
    [PENDING_REPORT_STATUS]
  ).then((r) => r.rows);
}

/**
 * Approves the inspection report and marks the request `listed`.
 * `listedAssetId` is caller-supplied (e.g. from an assets service) — this
 * backend doesn't own listings/assets, only the sell-request pipeline.
 */
function approveReport(id, { listedAssetId }) {
  return query(
    `UPDATE sell_requests
     SET status = 'listed'::sell_request_status, listed_asset_id = $2
     WHERE id = $1 AND status = $3::sell_request_status
     RETURNING *`,
    [id, listedAssetId, PENDING_REPORT_STATUS]
  ).then((r) => r.rows[0] || null);
}

function rejectReport(id, reason) {
  return query(
    `UPDATE sell_requests
     SET status = 'report_rejected'::sell_request_status, report_rejection_reason = $2
     WHERE id = $1 AND status = $3::sell_request_status
     RETURNING *`,
    [id, reason || 'Report needs more detail before this can go live.', PENDING_REPORT_STATUS]
  ).then((r) => r.rows[0] || null);
}

module.exports = {
  toPublic,
  create,
  createAgentListing,
  findById,
  listByOwner,
  listPendingSubmissions,
  approveSubmission,
  rejectSubmission,
  listOpenToBrokers,
  listBroadcastingForAgent,
  listClaimedByAgent,
  listPendingReportsByAgent,
  listListedByAgent,
  claim,
  submitReport,
  listPendingReports,
  approveReport,
  rejectReport,
};