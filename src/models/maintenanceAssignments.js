const { query } = require('../db');
const maintenanceRequestsModel = require('./maintenanceRequests');
const serviceProvidersModel = require('./serviceProviders');
const specialistWalletModel = require('./specialistWallet');
const notificationsModel = require('./notifications');
const { broadcastNotification } = require('../socket');

/** Converts a DB row (snake_case) to the camelCase shape the client expects.
 *  Rows from [findById]/[listForTenant] carry extra joined columns
 *  (provider name/category/phone, asset title) -- same "present only when
 *  joined in" pattern as maintenanceRequests.js's toPublic. */
function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    maintenanceRequestId: row.maintenance_request_id,
    serviceProviderId: row.service_provider_id,
    tenantId: row.tenant_id,
    quotedCostCents: row.quoted_cost_cents,
    currency: row.currency,
    escrowStatus: row.escrow_status,
    paymentTxRef: row.payment_tx_ref,
    heldAt: row.held_at,
    releasedAt: row.released_at,
    refundedAt: row.refunded_at,
    refundNote: row.refund_note,
    completedAt: row.completed_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    provider:
      row.provider_name !== undefined
        ? {
            id: row.service_provider_id,
            name: row.provider_name,
            category: row.provider_category,
            phone: row.provider_phone,
          }
        : undefined,
    asset:
      row.asset_title !== undefined
        ? { id: row.asset_id, title: row.asset_title, imageUrl: row.asset_image_url }
        : undefined,
  };
}

const JOIN_SELECT = `
  SELECT ma.*, sp.name AS provider_name, sp.category AS provider_category, sp.phone AS provider_phone,
         mr.asset_id AS asset_id, a.title AS asset_title, a.image_url AS asset_image_url
  FROM maintenance_assignments ma
  JOIN service_providers sp ON sp.id = ma.service_provider_id
  JOIN maintenance_requests mr ON mr.id = ma.maintenance_request_id
  JOIN assets a ON a.id = mr.asset_id
`;

/**
 * Tenant picks a specialist from the directory for a request the owner
 * rejected. Re-verifies server-side (not trusted from the client) that:
 * the request belongs to this tenant, is 'rejected' (Phase 1/2 handed
 * resolution back to them), doesn't already have an assignment, and the
 * provider is a real, active directory entry.
 */
async function assign({ tenantId, maintenanceRequestId, serviceProviderId, quotedCostCents }) {
  const cost = Number(quotedCostCents);
  if (!Number.isFinite(cost) || cost <= 0) {
    throw Object.assign(new Error('Enter a valid quoted cost.'), { status: 400 });
  }

  const request = await maintenanceRequestsModel.findById(maintenanceRequestId);
  if (!request || request.tenant_id !== tenantId) {
    throw Object.assign(new Error('Not found.'), { status: 404 });
  }
  if (request.status !== 'rejected') {
    throw Object.assign(
      new Error('You can only assign a specialist once the owner has declined this request.'),
      { status: 409 }
    );
  }

  const provider = await serviceProvidersModel.findById(serviceProviderId);
  if (!provider || !provider.is_active) {
    throw Object.assign(new Error('That specialist is not available.'), { status: 404 });
  }

  const existing = await findByRequestId(maintenanceRequestId);
  if (existing) {
    throw Object.assign(new Error('A specialist is already assigned to this request.'), { status: 409 });
  }

  const row = await query(
    `INSERT INTO maintenance_assignments
       (maintenance_request_id, service_provider_id, tenant_id, quoted_cost_cents, currency)
     VALUES ($1, $2, $3, $4, 'ETB')
     RETURNING *`,
    [maintenanceRequestId, serviceProviderId, tenantId, Math.round(cost)]
  ).then((r) => r.rows[0]);

  await query(`UPDATE maintenance_requests SET status = 'assigned', updated_at = now() WHERE id = $1`, [
    maintenanceRequestId,
  ]);

  return row;
}

function findByRequestId(maintenanceRequestId) {
  return query(`SELECT * FROM maintenance_assignments WHERE maintenance_request_id = $1`, [
    maintenanceRequestId,
  ]).then((r) => r.rows[0] || null);
}

function findById(id) {
  return query(`${JOIN_SELECT} WHERE ma.id = $1`, [id]).then((r) => r.rows[0] || null);
}

function listForTenant(tenantId) {
  return query(`${JOIN_SELECT} WHERE ma.tenant_id = $1 ORDER BY ma.created_at DESC`, [tenantId]).then(
    (r) => r.rows
  );
}

/**
 * An Expert's (Affiliater-with-a-linked-provider-row's) own job list --
 * GET /api/affiliates/me/expert-jobs. Same join shape as listForTenant,
 * just filtered by provider instead of tenant.
 */
function listForProvider(serviceProviderId) {
  return query(`${JOIN_SELECT} WHERE ma.service_provider_id = $1 ORDER BY ma.created_at DESC`, [
    serviceProviderId,
  ]).then((r) => r.rows);
}

/** Admin oversight (Phase 7): every assignment, newest first, optionally by escrow_status. */
function listAll({ escrowStatus } = {}) {
  if (escrowStatus) {
    return query(`${JOIN_SELECT} WHERE ma.escrow_status = $1 ORDER BY ma.created_at DESC`, [escrowStatus]).then(
      (r) => r.rows
    );
  }
  return query(`${JOIN_SELECT} ORDER BY ma.created_at DESC`).then((r) => r.rows);
}

/**
 * Called from payments.js's Chapa dispatch once the escrow checkout
 * succeeds -- same shape as rentalAgreements.markPaid: a guarded UPDATE
 * that no-ops (returns null) if the row already moved on. Purpose tag is
 * `maintenance_escrow_<assignment id>`, set on the assignment as
 * payment_tx_ref for reference.
 */
async function markHeld(id, txRef) {
  const row = await query(
    `UPDATE maintenance_assignments
     SET escrow_status = 'held', payment_tx_ref = $2, held_at = now(), updated_at = now()
     WHERE id = $1 AND escrow_status = 'pending_payment'
     RETURNING *`,
    [id, txRef || null]
  ).then((r) => r.rows[0] || null);
  return row;
}

/**
 * Tenant's single "confirm job done, release payment" action -- see
 * 084_maintenance_assignments.sql for why there's no separate provider
 * "mark complete" step. Credits specialist_wallet_transactions and closes
 * out the parent maintenance_requests row in the same call.
 */
async function confirmComplete({ id, tenantId }) {
  const existing = await query(`SELECT * FROM maintenance_assignments WHERE id = $1`, [id]).then(
    (r) => r.rows[0]
  );
  if (!existing || existing.tenant_id !== tenantId) {
    throw Object.assign(new Error('Not found.'), { status: 404 });
  }
  if (existing.escrow_status !== 'held') {
    throw Object.assign(
      new Error(
        existing.escrow_status === 'released'
          ? 'This job was already confirmed.'
          : 'Pay into escrow before confirming the job is done.'
      ),
      { status: 409 }
    );
  }

  const row = await query(
    `UPDATE maintenance_assignments
     SET escrow_status = 'released', released_at = now(), completed_at = now(), updated_at = now()
     WHERE id = $1 AND escrow_status = 'held'
     RETURNING *`,
    [id]
  ).then((r) => r.rows[0] || null);
  if (!row) return null;

  await query(`UPDATE maintenance_requests SET status = 'completed', updated_at = now() WHERE id = $1`, [
    row.maintenance_request_id,
  ]);

  const provider = await serviceProvidersModel.findById(row.service_provider_id);
  await specialistWalletModel.creditFromEscrow(row.service_provider_id, {
    amountCents: row.quoted_cost_cents,
    label: `Job payout — ${provider ? provider.name : 'maintenance job'}`,
    maintenanceAssignmentId: row.id,
  });

  try {
    await notificationsModel.create({
      recipientType: 'admin',
      kind: 'maintenance_request',
      title: 'Specialist payout ready',
      body: `${provider ? provider.name : 'A specialist'} is owed ${(row.quoted_cost_cents / 100).toFixed(2)} ${row.currency} — pay out from the service providers wallet tab.`,
      relatedId: row.id,
    });
    broadcastNotification('admin', 'all', { kind: 'maintenance_request', id: row.id });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[maintenanceAssignments] failed to notify admin of payout-ready escrow release', err);
  }

  return row;
}

/** Admin dispute-path refund (Phase 7) -- releases escrow back to the tenant instead of the specialist. */
async function refund({ id, note }) {
  const row = await query(
    `UPDATE maintenance_assignments
     SET escrow_status = 'refunded', refunded_at = now(), refund_note = $2, updated_at = now()
     WHERE id = $1 AND escrow_status = 'held'
     RETURNING *`,
    [id, note || null]
  ).then((r) => r.rows[0] || null);
  return row;
}

module.exports = {
  toPublic,
  assign,
  findByRequestId,
  findById,
  listForTenant,
  listForProvider,
  listAll,
  markHeld,
  confirmComplete,
  refund,
};
