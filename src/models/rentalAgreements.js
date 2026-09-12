const { query } = require('../db');
const assetsModel = require('./assets');
const propertyRequestsModel = require('./propertyRequests');
const usersModel = require('./users');
const chatModel = require('./chat');
const notificationsModel = require('./notifications');
const { broadcastNotification } = require('../socket');

/** Looks up a user's role for notification recipientType — never assume
 *  a fixed role, since the requester could be any browsing account type. */
async function roleOf(userId) {
  const user = await usersModel.findById(userId);
  return user ? user.role : 'user';
}

/** How long the requester has to pay once the owner sends the agreement. */
const AGREEMENT_WINDOW_HOURS = Number(process.env.RENTAL_AGREEMENT_WINDOW_HOURS || 24);

/** Converts a DB row (snake_case) to the camelCase shape the client expects.
 *  Rows from [listForOwner]/[listForRequester]/[findById] carry extra
 *  joined columns (asset title/image, owner/requester name) — same
 *  "present only when joined in" pattern as propertyRequests.js's toPublic. */
function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    propertyRequestId: row.property_request_id,
    assetId: row.asset_id,
    ownerId: row.owner_id,
    requesterId: row.requester_id,
    status: row.status,
    idDocumentUrl: row.id_document_url,
    documentUrls: row.document_urls || [],
    requesterNote: row.requester_note,
    agreementTerms: row.agreement_terms,
    rentAmount: row.rent_amount !== null && row.rent_amount !== undefined ? Number(row.rent_amount) : null,
    depositAmount: row.deposit_amount !== null && row.deposit_amount !== undefined ? Number(row.deposit_amount) : null,
    currency: row.currency,
    sentAt: row.sent_at,
    expiresAt: row.expires_at,
    rejectedReason: row.rejected_reason,
    rejectedAt: row.rejected_at,
    paymentTxRef: row.payment_tx_ref,
    paidAt: row.paid_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    asset:
      row.asset_title !== undefined
        ? { id: row.asset_id, title: row.asset_title, imageUrl: row.asset_image_url }
        : undefined,
    owner: row.owner_name !== undefined ? { id: row.owner_id, fullName: row.owner_name } : undefined,
    requester:
      row.requester_name !== undefined ? { id: row.requester_id, fullName: row.requester_name } : undefined,
    threadId: row.thread_id,
  };
}

/**
 * Requester submits their digital ID + supporting documents against a
 * 'rent_now' request they already sent (see propertyRequests.create).
 * Creates the pipeline row, drops the listing to 'reserved' (invisible
 * to other users — assets.list() only shows 'active' by default), and
 * notifies the owner. One row per property_request — calling this again
 * on the same request just 400s (they've already submitted).
 */
async function submitDocuments({ propertyRequestId, requesterId, idDocumentUrl, documentUrls, note }) {
  if (!idDocumentUrl) {
    throw Object.assign(new Error('A digital ID document is required.'), { status: 400 });
  }

  const pr = await query(`SELECT * FROM property_requests WHERE id = $1`, [propertyRequestId]).then(
    (r) => r.rows[0]
  );
  if (!pr) throw Object.assign(new Error('Request not found.'), { status: 404 });
  if (pr.requester_id !== requesterId) {
    throw Object.assign(new Error("This isn't your request."), { status: 403 });
  }
  if (pr.request_type !== 'rent_now') {
    throw Object.assign(new Error('Only a rent request can go through document review.'), { status: 400 });
  }

  const existing = await query(`SELECT id FROM rental_agreements WHERE property_request_id = $1`, [
    propertyRequestId,
  ]).then((r) => r.rows[0]);
  if (existing) {
    throw Object.assign(new Error("You've already submitted documents for this request."), { status: 409 });
  }

  // Only one live pipeline per asset at a time — otherwise two different
  // requesters could both get past this point before the asset flips to
  // 'reserved' below, and end up with competing agreements on the same
  // listing. This check narrows the window; the partial unique index
  // from 070_rental_agreements_one_active_per_asset.sql is what actually
  // closes it (see the catch around the INSERT below).
  const activePipeline = await query(
    `SELECT id FROM rental_agreements WHERE asset_id = $1 AND status IN ('documents_submitted', 'agreement_sent')`,
    [pr.asset_id]
  ).then((r) => r.rows[0]);
  if (activePipeline) {
    throw Object.assign(
      new Error('Another request for this property is already being reviewed. Try again once it\'s decided.'),
      { status: 409 }
    );
  }

  const asset = await assetsModel.findById(pr.asset_id);
  if (!asset) throw Object.assign(new Error('Listing not found.'), { status: 404 });

  // The Review tab (document review -> agreement -> payment) is a
  // Property Owner feature — an Agent-listed rent_now request still
  // works as a plain chat request, it just doesn't get this pipeline.
  const ownerRole = await roleOf(pr.owner_id);
  if (ownerRole !== 'property_owner') {
    throw Object.assign(
      new Error("This listing isn't set up for online document review yet — use the chat to arrange things directly."),
      { status: 422 }
    );
  }

  let row;
  try {
    row = await query(
      `INSERT INTO rental_agreements
         (property_request_id, asset_id, owner_id, requester_id, id_document_url, document_urls, requester_note)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7)
       RETURNING *`,
      [
        propertyRequestId,
        pr.asset_id,
        pr.owner_id,
        requesterId,
        idDocumentUrl,
        JSON.stringify(Array.isArray(documentUrls) ? documentUrls.filter(Boolean) : []),
        (note || '').trim() || null,
      ]
    ).then((r) => r.rows[0]);
  } catch (err) {
    // 23505 = unique_violation. Either the property_request_id UNIQUE
    // constraint (duplicate submission that slipped past the `existing`
    // check above) or the one-active-per-asset partial index (the race
    // the `activePipeline` check above narrows but can't fully close) —
    // both map to the same "someone got there first" message.
    if (err && err.code === '23505') {
      throw Object.assign(
        new Error('Another request for this property is already being reviewed. Try again once it\'s decided.'),
        { status: 409 }
      );
    }
    throw err;
  }

  // Hide the listing from other users while this pipeline is live.
  await assetsModel.update(asset.id, { status: 'reserved' });

  try {
    const notifRow = await notificationsModel.create({
      recipientType: 'property_owner',
      recipientId: pr.owner_id,
      kind: 'rental_agreement',
      title: `Documents submitted — ${asset.title}`,
      body: 'A requester sent their ID and documents. Review them to send the rental agreement.',
      relatedId: row.id,
    });
    broadcastNotification('property_owner', pr.owner_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify owner of submitted documents', err);
  }

  return row;
}

/** Base SELECT shared by the owner- and requester-facing queries. */
const BASE_SELECT = `
  SELECT
    ra.*,
    a.title AS asset_title,
    a.image_url AS asset_image_url,
    own.full_name AS owner_name,
    req.full_name AS requester_name,
    pr.thread_id AS thread_id
  FROM rental_agreements ra
  JOIN assets a ON a.id = ra.asset_id
  JOIN users own ON own.id = ra.owner_id
  JOIN users req ON req.id = ra.requester_id
  JOIN property_requests pr ON pr.id = ra.property_request_id
`;

/** The owner's Review queue, newest activity first. `status` filters to
 *  an exact rental_agreement_status, or 'active' for everything still
 *  needing attention/in flight (not yet paid/rejected/expired). */
function listForOwner(ownerId, { status } = {}) {
  const conditions = ['ra.owner_id = $1'];
  const params = [ownerId];
  if (status === 'active') {
    conditions.push(`ra.status IN ('documents_submitted', 'agreement_sent')`);
  } else if (status) {
    conditions.push(`ra.status = $${params.push(status)}::rental_agreement_status`);
  }
  return query(
    `${BASE_SELECT} WHERE ${conditions.join(' AND ')} ORDER BY ra.updated_at DESC`,
    params
  ).then((r) => r.rows);
}

/** The requester's own pipeline rows — "my rental agreements". */
function listForRequester(requesterId) {
  return query(`${BASE_SELECT} WHERE ra.requester_id = $1 ORDER BY ra.updated_at DESC`, [requesterId]).then(
    (r) => r.rows
  );
}

function findByIdForOwner(id, ownerId) {
  return query(`${BASE_SELECT} WHERE ra.id = $1 AND ra.owner_id = $2`, [id, ownerId]).then(
    (r) => r.rows[0] || null
  );
}

function findByIdForRequester(id, requesterId) {
  return query(`${BASE_SELECT} WHERE ra.id = $1 AND ra.requester_id = $2`, [id, requesterId]).then(
    (r) => r.rows[0] || null
  );
}

function findById(id) {
  return query(`${BASE_SELECT} WHERE ra.id = $1`, [id]).then((r) => r.rows[0] || null);
}

/** Every row still counting down — used to rebuild expiry timers on boot. */
function listActive() {
  return query(
    `SELECT * FROM rental_agreements WHERE status = 'agreement_sent' AND expires_at IS NOT NULL`
  ).then((r) => r.rows);
}

/**
 * Owner approves the documents and sends the rental agreement — starts
 * the payment countdown. Also drops a copy of the terms into the
 * existing chat thread so it's visible there too, same as a normal
 * message.
 */
async function sendAgreement({ id, ownerId, terms, rentAmount, depositAmount, currency, hours }) {
  const current = await findByIdForOwner(id, ownerId);
  if (!current) throw Object.assign(new Error('Not found.'), { status: 404 });
  if (current.status !== 'documents_submitted') {
    throw Object.assign(new Error('This request has already been decided.'), { status: 409 });
  }
  if (!terms || !String(terms).trim()) {
    throw Object.assign(new Error('Agreement terms are required.'), { status: 400 });
  }
  const amount = Number(rentAmount);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw Object.assign(new Error('rentAmount must be a positive number.'), { status: 400 });
  }
  const windowHours = Number(hours) > 0 ? Number(hours) : AGREEMENT_WINDOW_HOURS;

  const row = await query(
    `UPDATE rental_agreements
     SET status = 'agreement_sent',
         agreement_terms = $3,
         rent_amount = $4,
         deposit_amount = $5,
         currency = $6,
         sent_at = now(),
         expires_at = now() + make_interval(hours => $7::int),
         updated_at = now()
     WHERE id = $1 AND owner_id = $2
     RETURNING *`,
    [id, ownerId, String(terms).trim(), amount, depositAmount ? Number(depositAmount) : null, currency || 'ETB', windowHours]
  ).then((r) => r.rows[0]);

  if (current.threadId) {
    try {
      await chatModel.sendMessage({
        threadId: current.threadId,
        senderId: ownerId,
        body: `Rental agreement sent: ${String(terms).trim()}\nRent: ${amount} ${currency || 'ETB'}${
          depositAmount ? ` + deposit ${Number(depositAmount)} ${currency || 'ETB'}` : ''
        }\nYou have ${windowHours}h to pay to confirm.`,
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[rentalAgreements] failed to post agreement to chat thread', err);
    }
  }

  try {
    const requesterRole = await roleOf(row.requester_id);
    const notifRow = await notificationsModel.create({
      recipientType: requesterRole,
      recipientId: row.requester_id,
      kind: 'rental_agreement',
      title: `Rental agreement sent — ${current.asset?.title || 'your request'}`,
      body: `Pay within ${windowHours}h to confirm this rental, or it reopens to other users.`,
      relatedId: row.id,
    });
    broadcastNotification(requesterRole, row.requester_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify requester of sent agreement', err);
  }

  return row;
}

/** Owner rejects — reopens the listing for other users. */
async function reject({ id, ownerId, reason }) {
  const current = await findByIdForOwner(id, ownerId);
  if (!current) throw Object.assign(new Error('Not found.'), { status: 404 });
  if (!['documents_submitted', 'agreement_sent'].includes(current.status)) {
    throw Object.assign(new Error('This request has already been decided.'), { status: 409 });
  }

  const row = await query(
    `UPDATE rental_agreements
     SET status = 'rejected', rejected_reason = $3, rejected_at = now(), updated_at = now()
     WHERE id = $1 AND owner_id = $2
     RETURNING *`,
    [id, ownerId, (reason || '').trim() || null]
  ).then((r) => r.rows[0]);

  await assetsModel.update(row.asset_id, { status: 'active' });

  if (current.threadId && reason) {
    try {
      await chatModel.sendMessage({ threadId: current.threadId, senderId: ownerId, body: `Request declined: ${reason.trim()}` });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[rentalAgreements] failed to post rejection to chat thread', err);
    }
  }

  try {
    const requesterRole = await roleOf(row.requester_id);
    const notifRow = await notificationsModel.create({
      recipientType: requesterRole,
      recipientId: row.requester_id,
      kind: 'rental_agreement',
      title: `Request declined — ${current.asset?.title || 'your request'}`,
      body: reason && reason.trim() ? reason.trim() : 'The owner declined this rental request.',
      relatedId: row.id,
    });
    broadcastNotification(requesterRole, row.requester_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify requester of rejection', err);
  }

  return row;
}

/** The 24h window lapsed with no payment — reopens the listing. Mirrors
 *  tourRequests.expire's "no-op if it already moved on" guard: only
 *  touches a row still sitting in 'agreement_sent'. Returns null if
 *  there was nothing to expire (already paid/rejected just before the
 *  timer fired). */
async function expire(id) {
  const row = await query(
    `UPDATE rental_agreements
     SET status = 'expired', updated_at = now()
     WHERE id = $1 AND status = 'agreement_sent'
     RETURNING *`,
    [id]
  ).then((r) => r.rows[0] || null);
  if (!row) return null;

  await assetsModel.update(row.asset_id, { status: 'active' });

  try {
    const requesterRole = await roleOf(row.requester_id);
    const notifRow = await notificationsModel.create({
      recipientType: requesterRole,
      recipientId: row.requester_id,
      kind: 'rental_agreement',
      title: 'Rental agreement expired',
      body: "The payment window closed before you paid, so the listing is open to other users again.",
      relatedId: row.id,
    });
    broadcastNotification(requesterRole, row.requester_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify requester of expiry', err);
  }

  return row;
}

/**
 * Called once a payment with purpose `rental_agreement_<id>` verifies as
 * successful (see routes/payments.js). Closes the loop: marks this row
 * paid, closes the underlying property_request, and moves the listing
 * to 'rented'. No-ops (returns null) if the row already moved on (e.g.
 * the 24h timer fired a beat before the payment settled).
 */
async function markPaid(id, txRef) {
  const row = await query(
    `UPDATE rental_agreements
     SET status = 'paid', payment_tx_ref = $2, paid_at = now(), updated_at = now()
     WHERE id = $1 AND status = 'agreement_sent'
     RETURNING *`,
    [id, txRef || null]
  ).then((r) => r.rows[0] || null);
  if (!row) return null;

  await assetsModel.update(row.asset_id, { status: 'rented' });
  await propertyRequestsModel.setStatus(row.property_request_id, row.owner_id, 'closed');

  const asset = await assetsModel.findById(row.asset_id);
  const threadRow = await query(`SELECT thread_id FROM property_requests WHERE id = $1`, [
    row.property_request_id,
  ]).then((r) => r.rows[0]);
  if (threadRow?.thread_id) {
    try {
      await chatModel.sendMessage({
        threadId: threadRow.thread_id,
        senderId: row.requester_id,
        body: 'Payment confirmed — the rental agreement is now closed. Message here for anything else.',
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[rentalAgreements] failed to post payment confirmation to chat thread', err);
    }
  }

  try {
    const notifRow = await notificationsModel.create({
      recipientType: 'property_owner',
      recipientId: row.owner_id,
      kind: 'rental_agreement',
      title: `Payment received — ${asset?.title || 'your listing'}`,
      body: 'The tenant paid and the deal is closed.',
      relatedId: row.id,
    });
    broadcastNotification('property_owner', row.owner_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify owner of payment', err);
  }

  return row;
}

module.exports = {
  AGREEMENT_WINDOW_HOURS,
  toPublic,
  submitDocuments,
  listForOwner,
  listForRequester,
  findByIdForOwner,
  findByIdForRequester,
  findById,
  listActive,
  sendAgreement,
  reject,
  expire,
  markPaid,
};
