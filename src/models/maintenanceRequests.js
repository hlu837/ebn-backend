const { query } = require('../db');
const notificationsModel = require('./notifications');
const { broadcastNotification } = require('../socket');

const CATEGORIES = ['electrical', 'plumbing', 'structural', 'appliance', 'other'];

/** Converts a DB row (snake_case) to the camelCase shape the client expects.
 *  Rows from [listForTenant]/[listForOwner]/[findById] carry extra joined
 *  columns (asset title/image) — same "present only when joined in"
 *  pattern as rentalAgreements.js's toPublic. */
function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    rentalAgreementId: row.rental_agreement_id,
    assetId: row.asset_id,
    ownerId: row.owner_id,
    tenantId: row.tenant_id,
    category: row.category,
    description: row.description,
    photoUrls: row.photo_urls || [],
    status: row.status,
    decidedAt: row.decided_at,
    decisionNote: row.decision_note,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    asset:
      row.asset_title !== undefined
        ? { id: row.asset_id, title: row.asset_title, imageUrl: row.asset_image_url }
        : undefined,
  };
}

/**
 * Tenant files a new maintenance request against a unit they're actively
 * renting. "Actively renting" is verified here, not trusted from the
 * client: the caller must have a rental_agreements row for this asset
 * that is 'paid' and not yet vacated — the same active-lease check that
 * gates whether the "Report a maintenance issue" button is even shown,
 * done again server-side so a request can't be filed by editing the
 * request instead of clicking the button.
 */
async function create({ tenantId, assetId, category, description, photoUrls }) {
  if (!CATEGORIES.includes(category)) {
    throw Object.assign(new Error('Not a recognized issue category.'), { status: 400 });
  }
  if (!description || !description.trim()) {
    throw Object.assign(new Error('Describe the issue before submitting.'), { status: 400 });
  }

  const lease = await query(
    `SELECT * FROM rental_agreements
     WHERE asset_id = $1 AND requester_id = $2 AND status = 'paid' AND vacated_at IS NULL
     ORDER BY paid_at DESC LIMIT 1`,
    [assetId, tenantId]
  ).then((r) => r.rows[0]);
  if (!lease) {
    throw Object.assign(
      new Error('You can only report an issue on a unit you currently rent.'),
      { status: 403 }
    );
  }

  const row = await query(
    `INSERT INTO maintenance_requests
       (rental_agreement_id, asset_id, owner_id, tenant_id, category, description, photo_urls)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [lease.id, assetId, lease.owner_id, tenantId, category, description.trim(), JSON.stringify(photoUrls || [])]
  ).then((r) => r.rows[0]);

  await notificationsModel.create({
    recipientType: 'property_owner',
    recipientId: lease.owner_id,
    kind: 'maintenance_request',
    title: 'New maintenance request',
    body: `A tenant reported a ${category} issue.`,
    relatedId: row.id,
  });
  broadcastNotification('property_owner', lease.owner_id, { kind: 'maintenance_request', id: row.id });

  return row;
}

/** GET .../mine — the caller's own filed requests, as a tenant. */
async function listForTenant(tenantId) {
  const rows = await query(
    `SELECT mr.*, a.title AS asset_title, a.image_url AS asset_image_url
     FROM maintenance_requests mr
     JOIN assets a ON a.id = mr.asset_id
     WHERE mr.tenant_id = $1
     ORDER BY mr.created_at DESC`,
    [tenantId]
  );
  return rows.rows;
}

/** GET .../queue — the caller's incoming requests, as an owner. */
async function listForOwner(ownerId, { status } = {}) {
  const params = [ownerId];
  let where = 'mr.owner_id = $1';
  if (status) {
    params.push(status);
    where += ` AND mr.status = $${params.length}`;
  }
  const rows = await query(
    `SELECT mr.*, a.title AS asset_title, a.image_url AS asset_image_url
     FROM maintenance_requests mr
     JOIN assets a ON a.id = mr.asset_id
     WHERE ${where}
     ORDER BY mr.created_at DESC`,
    params
  );
  return rows.rows;
}

async function findById(id) {
  const row = await query(
    `SELECT mr.*, a.title AS asset_title, a.image_url AS asset_image_url
     FROM maintenance_requests mr
     JOIN assets a ON a.id = mr.asset_id
     WHERE mr.id = $1`,
    [id]
  ).then((r) => r.rows[0]);
  return row;
}

/**
 * Owner accepts or rejects an open request. Accept means the owner is
 * taking responsibility (handling it directly or assigning an external
 * specialist themselves — Phase 1 doesn't track who yet). Reject hands
 * resolution back to the tenant, who can then assign a specialist from
 * the service directory once that exists (Phase 3/4).
 */
async function decide({ id, ownerId, accept, note }) {
  const existing = await findById(id);
  if (!existing || existing.owner_id !== ownerId) {
    throw Object.assign(new Error('Not found.'), { status: 404 });
  }
  if (existing.status !== 'submitted') {
    throw Object.assign(new Error('This request has already been decided.'), { status: 409 });
  }

  const status = accept ? 'accepted' : 'rejected';
  const row = await query(
    `UPDATE maintenance_requests
     SET status = $2, decided_at = now(), decision_note = $3, updated_at = now()
     WHERE id = $1
     RETURNING *`,
    [id, status, note || null]
  ).then((r) => r.rows[0]);

  await notificationsModel.create({
    recipientType: 'user',
    recipientId: existing.tenant_id,
    kind: 'maintenance_request',
    title: accept ? 'Maintenance request accepted' : 'Maintenance request declined',
    body: accept
      ? "The property owner is handling this. They'll follow up directly."
      : 'The property owner declined this — you can assign a specialist yourself from the service directory.',
    relatedId: row.id,
  });
  broadcastNotification('user', existing.tenant_id, { kind: 'maintenance_request', id: row.id });

  return row;
}

module.exports = { toPublic, create, listForTenant, listForOwner, findById, decide, CATEGORIES };
