const { query } = require('../db');
const assetsModel = require('./assets');
const propertyRequestsModel = require('./propertyRequests');
const usersModel = require('./users');
const chatModel = require('./chat');
const notificationsModel = require('./notifications');
const { broadcastNotification } = require('../socket');
const { buildStandardLeaseTerms } = require('../services/leaseTemplate');

/** Looks up a user's role for notification recipientType — never assume
 *  a fixed role, since the requester could be any browsing account type. */
async function roleOf(userId) {
  const user = await usersModel.findById(userId);
  return user ? user.role : 'user';
}

/** How long the requester has to pay once the owner sends the agreement. */
const AGREEMENT_WINDOW_HOURS = Number(process.env.RENTAL_AGREEMENT_WINDOW_HOURS || 24);
/** How long before lease_end_at the "renew or vacate" nudge goes out —
 *  kept in sync with routes/rentalAgreements.js's own copy (used there
 *  by the timer-based path; this one backs the sweep-based path in
 *  runSweep below — see routes/cron.js). */
const LEASE_REMINDER_LEAD_MS = 7 * 24 * 60 * 60 * 1000;

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
    faydaIdNumber: row.fayda_id_number,
    requesterNote: row.requester_note,
    agreementTerms: row.agreement_terms,
    advanceMonths: row.advance_months !== null && row.advance_months !== undefined ? Number(row.advance_months) : null,
    rentAmount: row.rent_amount !== null && row.rent_amount !== undefined ? Number(row.rent_amount) : null,
    depositAmount: row.deposit_amount !== null && row.deposit_amount !== undefined ? Number(row.deposit_amount) : null,
    currency: row.currency,
    sentAt: row.sent_at,
    expiresAt: row.expires_at,
    acceptedAt: row.accepted_at,
    rejectedReason: row.rejected_reason,
    rejectedAt: row.rejected_at,
    paymentTxRef: row.payment_tx_ref,
    paymentMethod: row.payment_method,
    receiptUrl: row.receipt_url,
    receiptSubmittedAt: row.receipt_submitted_at,
    receiptRejectedReason: row.receipt_rejected_reason,
    markedPaidBy: row.marked_paid_by,
    paidAt: row.paid_at,
    leaseTermMonths: row.lease_term_months !== null && row.lease_term_months !== undefined ? Number(row.lease_term_months) : null,
    leaseEndAt: row.lease_end_at,
    vacatedAt: row.vacated_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    asset:
      row.asset_title !== undefined
        ? {
            id: row.asset_id,
            title: row.asset_title,
            imageUrl: row.asset_image_url,
            // The listing's own advertised monthly rent — what
            // advanceMonths gets multiplied against. Lets the client
            // show "X months x Y ETB/mo" without a second fetch.
            priceAmount:
              row.asset_price_amount !== null && row.asset_price_amount !== undefined
                ? Number(row.asset_price_amount)
                : null,
            priceCurrency: row.asset_price_currency,
          }
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
/** Fayda Identification Number: exactly 12 digits (NIDP FIN format). */
const FAYDA_ID_RE = /^\d{12}$/;

async function submitDocuments({ propertyRequestId, requesterId, idDocumentUrl, documentUrls, faydaIdNumber, note }) {
  if (!idDocumentUrl) {
    throw Object.assign(new Error('A digital ID document is required.'), { status: 400 });
  }
  const normalizedFaydaId = String(faydaIdNumber || '').replace(/\s+/g, '');
  if (!FAYDA_ID_RE.test(normalizedFaydaId)) {
    throw Object.assign(new Error('A valid 12-digit Fayda ID number is required.'), { status: 400 });
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
    `SELECT id FROM rental_agreements WHERE asset_id = $1 AND status IN ('documents_submitted', 'agreement_sent', 'accepted', 'payment_submitted')`,
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

  // Closes the occupied-unit double-booking path: the one-active-per-asset
  // partial index (070_rental_agreements_one_active_per_asset.sql) only
  // covers 'documents_submitted'/'agreement_sent', so once an agreement
  // hits 'paid' and the asset flips to 'rented', a second requester who
  // reaches the listing directly (out of search, but still linkable via
  // favorites/direct link) could otherwise open a brand-new pipeline on
  // an occupied unit. Only a still-`active` listing can start one.
  if (asset.status !== 'active') {
    throw Object.assign(
      new Error('This listing is no longer available for rent.'),
      { status: 409 }
    );
  }

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
         (property_request_id, asset_id, owner_id, requester_id, id_document_url, document_urls, fayda_id_number, requester_note)
       VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7, $8)
       RETURNING *`,
      [
        propertyRequestId,
        pr.asset_id,
        pr.owner_id,
        requesterId,
        idDocumentUrl,
        JSON.stringify(Array.isArray(documentUrls) ? documentUrls.filter(Boolean) : []),
        normalizedFaydaId,
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
    a.price_amount AS asset_price_amount,
    a.price_currency AS asset_price_currency,
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
    conditions.push(`ra.status IN ('documents_submitted', 'agreement_sent', 'accepted', 'payment_submitted')`);
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

/**
 * Reopens a listing after a pipeline step that no longer holds it
 * (reject / expire / markVacated). Only flips the asset back to `active`
 * if it's still sitting in a status the rental pipeline itself owns
 * (`reserved` or `rented`) — if an admin has since moved it to something
 * else (e.g. archived it while the pipeline was live), that choice is
 * left alone instead of being silently overwritten.
 * See finding: admin-picker / rental-pipeline status collision.
 */
async function reopenAssetIfPipelineOwned(assetId) {
  const asset = await assetsModel.findById(assetId);
  if (!asset) return;
  if (asset.status === 'reserved' || asset.status === 'rented') {
    await assetsModel.update(assetId, { status: 'active' });
  }
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

/** Every row still counting down — used to rebuild expiry timers on boot.
 *  Covers 'accepted' too: accepting doesn't reset or pause the payment
 *  window, so an accepted-but-unpaid row can still expire. */
function listActive() {
  return query(
    `SELECT * FROM rental_agreements WHERE status IN ('agreement_sent', 'accepted') AND expires_at IS NOT NULL`
  ).then((r) => r.rows);
}

/** How many months of advance rent an owner may require in one go —
 *  generous upper bound just to catch fat-fingered input (e.g. 300
 *  instead of 3), not a real business limit. */
const MAX_ADVANCE_MONTHS = 36;

/**
 * Owner approves the documents and sends the rental agreement — starts
 * the payment countdown. The owner no longer types a rent figure OR
 * the agreement terms by hand: they only pick how many months of rent
 * to collect up front (plus optional deposit/lease term), and:
 *   - the total due (rent_amount) is computed here from the listing's
 *     own advertised monthly price (assets.price_amount), so it can
 *     never drift from what the listing actually says.
 *   - the full agreement text (agreement_terms) is generated here from
 *     the standard lease template (see services/leaseTemplate.js), so
 *     every tenant is shown the same fixed clauses — landlord and
 *     tenant obligations included — instead of whatever an owner
 *     happened to type that day.
 * Also drops a copy of the terms into the existing chat thread so it's
 * visible there too, same as a normal message.
 */
async function sendAgreement({ id, ownerId, advanceMonths, depositAmount, hours, termMonths }) {
  const current = await findByIdForOwner(id, ownerId);
  if (!current) throw Object.assign(new Error('Not found.'), { status: 404 });
  if (current.status !== 'documents_submitted') {
    throw Object.assign(new Error('This request has already been decided.'), { status: 409 });
  }
  const months = Number(advanceMonths);
  if (!Number.isInteger(months) || months <= 0 || months > MAX_ADVANCE_MONTHS) {
    throw Object.assign(
      new Error(`How many months of advance rent to collect — a whole number between 1 and ${MAX_ADVANCE_MONTHS}.`),
      { status: 400 }
    );
  }

  // The listing's own price is the only source of truth for what a
  // month of rent costs — never something the owner re-types here.
  const asset = await assetsModel.findById(current.asset_id);
  if (!asset) throw Object.assign(new Error('Listing not found.'), { status: 404 });
  const monthlyPrice = Number(asset.price_amount);
  if (!Number.isFinite(monthlyPrice) || monthlyPrice <= 0) {
    throw Object.assign(
      new Error("This listing doesn't have a valid monthly price set — fix the listing price before sending an agreement."),
      { status: 422 }
    );
  }
  const currency = asset.price_currency || 'ETB';
  // Round to 2dp so e.g. 3 x 12,345.5 doesn't carry a long float tail
  // into what the tenant is asked to pay.
  const amount = Math.round(monthlyPrice * months * 100) / 100;

  const windowHours = Number(hours) > 0 ? Number(hours) : AGREEMENT_WINDOW_HOURS;
  // NULL = month-to-month / no fixed term, in which case lease_end_at is
  // never computed and no lease-lifecycle reminders fire for this row.
  let leaseTermMonths = null;
  if (termMonths !== undefined && termMonths !== null && String(termMonths).trim() !== '') {
    const parsed = Number(termMonths);
    if (!Number.isInteger(parsed) || parsed <= 0 || parsed > 120) {
      throw Object.assign(new Error('termMonths must be a whole number of months between 1 and 120.'), { status: 400 });
    }
    leaseTermMonths = parsed;
  }

  const deposit = depositAmount ? Number(depositAmount) : null;

  // The standard template, filled in with this deal's own facts — the
  // owner never types this text, so it can't diverge from what's
  // actually being charged/agreed above.
  const terms = buildStandardLeaseTerms({
    ownerName: current.owner_name,
    requesterName: current.requester_name,
    propertyTitle: asset.title,
    addressLine: asset.address_line,
    city: asset.city,
    monthlyRent: monthlyPrice,
    currency,
    advanceMonths: months,
    totalDue: amount,
    depositAmount: deposit,
    leaseTermMonths,
  });

  const row = await query(
    `UPDATE rental_agreements
     SET status = 'agreement_sent',
         agreement_terms = $3,
         advance_months = $4,
         rent_amount = $5,
         deposit_amount = $6,
         currency = $7,
         sent_at = now(),
         expires_at = now() + make_interval(hours => $8::int),
         payment_reminder_sent_at = NULL,
         lease_term_months = $9,
         updated_at = now()
     WHERE id = $1 AND owner_id = $2
     RETURNING *`,
    [id, ownerId, terms, months, amount, deposit, currency, windowHours, leaseTermMonths]
  ).then((r) => r.rows[0]);

  if (current.thread_id) {
    try {
      // Every figure below is calculated here from the listing's own
      // price — nothing is typed by the owner. Total due = advance rent +
      // deposit, the same sum the app's payment screens use.
      const money = (n) => Number(n).toLocaleString('en-US', { maximumFractionDigits: 2 });
      const depositNum = deposit && Number.isFinite(deposit) ? deposit : null;
      const totalDue = Math.round((amount + (depositNum || 0)) * 100) / 100;
      await chatModel.sendMessage({
        threadId: current.thread_id,
        senderId: ownerId,
        // Plain-text version of the card: used for the inbox preview and
        // by older app builds that don't know how to draw the card.
        body: [
          'Rental agreement sent',
          `Monthly rent: ${money(monthlyPrice)} ${currency}`,
          `Advance rent (${months} month${months === 1 ? '' : 's'}): ${money(amount)} ${currency}`,
          ...(depositNum ? [`Deposit: ${money(depositNum)} ${currency}`] : []),
          `Lease term: ${leaseTermMonths ? `${leaseTermMonths} month${leaseTermMonths === 1 ? '' : 's'}` : 'Month-to-month'}`,
          `Total due: ${money(totalDue)} ${currency} — pay within ${windowHours}h to confirm.`,
        ].join('\n'),
        // Renders as a summary card + "Open agreement" button for the
        // tenant (see broker_chat_screen.dart).
        kind: 'rental_agreement',
        relatedId: id,
        meta: {
          monthlyRent: monthlyPrice,
          advanceMonths: months,
          advanceAmount: amount,
          depositAmount: depositNum,
          totalDue,
          currency,
          leaseTermMonths,
          windowHours,
        },
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
      title: `Rental agreement sent — ${current.asset_title || 'your request'}`,
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

/**
 * Requester accepts the terms the owner sent — the missing step between
 * agreement_sent and paid. Records a timestamp independent of payment,
 * so there's a record the tenant actually agreed to *this* version of
 * the terms before any money moved (markPaid/markPaidManually now both
 * require this status). Doesn't touch expires_at — acceptance doesn't
 * buy extra time, the original payment window keeps counting down.
 */
async function accept({ id, requesterId }) {
  const current = await findByIdForRequester(id, requesterId);
  if (!current) throw Object.assign(new Error('Not found.'), { status: 404 });
  if (current.status !== 'agreement_sent') {
    throw Object.assign(new Error('This agreement is not awaiting acceptance.'), { status: 409 });
  }

  const row = await query(
    `UPDATE rental_agreements
     SET status = 'accepted', accepted_at = now(), updated_at = now()
     WHERE id = $1 AND requester_id = $2 AND status = 'agreement_sent'
     RETURNING *`,
    [id, requesterId]
  ).then((r) => r.rows[0]);

  if (current.thread_id) {
    try {
      await chatModel.sendMessage({
        threadId: current.thread_id,
        senderId: requesterId,
        body: 'Accepted the rental agreement terms — proceeding to payment.',
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[rentalAgreements] failed to post acceptance to chat thread', err);
    }
  }

  try {
    const notifRow = await notificationsModel.create({
      recipientType: 'property_owner',
      recipientId: row.owner_id,
      kind: 'rental_agreement',
      title: `Terms accepted — ${current.asset_title || 'your listing'}`,
      body: 'The requester accepted the rental agreement and is proceeding to payment.',
      relatedId: row.id,
    });
    broadcastNotification('property_owner', row.owner_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify owner of acceptance', err);
  }

  return row;
}

/** Grace window given after a bounced receipt for the tenant to
 *  re-upload — separate from the initial AGREEMENT_WINDOW_HOURS so a
 *  quick "wrong screenshot, try again" doesn't eat the tenant's whole
 *  original payment window if little of it was left. */
const RECEIPT_RETRY_WINDOW_HOURS = Number(process.env.RENTAL_RECEIPT_RETRY_WINDOW_HOURS || 12);

/**
 * Tenant-side counterpart to markPaidManually: the tenant has already
 * transferred the money (see GET /:id/bank-accounts) and now attaches
 * their own proof — a photo or PDF of the bank/cash receipt, same data
 * URI convention as idDocumentUrl — instead of relying on a chat
 * message and trusting the owner to sort it out. Moves the row to
 * 'payment_submitted' and notifies the owner there's a receipt waiting
 * on their review (see confirmReceipt / rejectReceipt for what happens
 * next). Cancels the payment-window countdown for this row — the
 * tenant acted before any deadline that matters here, so it shouldn't
 * silently expire out from under the owner while they're reviewing it
 * (see routes/rentalAgreements.js POST /:id/submit-receipt, which does
 * the actual timer cancellation).
 */
async function submitReceipt({ id, requesterId, receiptUrl }) {
  const current = await findByIdForRequester(id, requesterId);
  if (!current) throw Object.assign(new Error('Not found.'), { status: 404 });
  if (current.status !== 'accepted') {
    throw Object.assign(new Error('This agreement is not awaiting payment.'), { status: 409 });
  }
  if (!receiptUrl || !String(receiptUrl).trim()) {
    throw Object.assign(new Error('Attach a photo or file of your payment receipt.'), { status: 400 });
  }

  const row = await query(
    `UPDATE rental_agreements
     SET status = 'payment_submitted', payment_method = 'manual_bank', receipt_url = $3,
         receipt_submitted_at = now(), receipt_rejected_reason = NULL, updated_at = now()
     WHERE id = $1 AND requester_id = $2 AND status = 'accepted'
     RETURNING *`,
    [id, requesterId, String(receiptUrl).trim()]
  ).then((r) => r.rows[0]);
  if (!row) return null;

  if (current.thread_id) {
    try {
      await chatModel.sendMessage({
        threadId: current.thread_id,
        senderId: requesterId,
        body: 'Uploaded a payment receipt — waiting on the owner to review and confirm it.',
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[rentalAgreements] failed to post receipt-submitted notice to chat thread', err);
    }
  }

  try {
    const notifRow = await notificationsModel.create({
      recipientType: 'property_owner',
      recipientId: row.owner_id,
      kind: 'rental_agreement',
      title: `Payment receipt submitted — ${current.asset_title || 'your listing'}`,
      body: 'The tenant paid and uploaded a receipt. Review it and confirm to close the deal.',
      relatedId: row.id,
    });
    broadcastNotification('property_owner', row.owner_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify owner of submitted receipt', err);
  }

  return row;
}

/**
 * Owner reviewed the tenant-submitted receipt (see submitReceipt) and
 * it checks out — closes the deal the same way markPaid/markPaidManually
 * do (asset -> 'rented', property_request -> 'closed', lease_end_at
 * computed). marked_paid_by records which owner confirmed it, same as
 * markPaidManually. Once this succeeds, the signed lease document
 * becomes downloadable (see routes/rentalAgreements.js GET
 * /:id/document) — the notification below points the tenant at it.
 */
async function confirmReceipt({ id, ownerId }) {
  const current = await findByIdForOwner(id, ownerId);
  if (!current) throw Object.assign(new Error('Not found.'), { status: 404 });
  if (current.status !== 'payment_submitted') {
    throw Object.assign(new Error('There is no submitted receipt awaiting confirmation.'), { status: 409 });
  }

  const row = await query(
    `UPDATE rental_agreements
     SET status = 'paid', marked_paid_by = $2, paid_at = now(),
         lease_end_at = CASE WHEN lease_term_months IS NOT NULL THEN now() + make_interval(months => lease_term_months) ELSE NULL END,
         updated_at = now()
     WHERE id = $1 AND owner_id = $2 AND status = 'payment_submitted'
     RETURNING *`,
    [id, ownerId]
  ).then((r) => r.rows[0] || null);
  if (!row) return null;

  await _closeOutPaidAgreement(row);

  if (current.thread_id) {
    try {
      await chatModel.sendMessage({
        threadId: current.thread_id,
        senderId: ownerId,
        body: 'Payment receipt confirmed — the rental agreement is now closed. Message here for anything else.',
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[rentalAgreements] failed to post receipt-confirmed notice to chat thread', err);
    }
  }

  try {
    const requesterRole = await roleOf(row.requester_id);
    const notifRow = await notificationsModel.create({
      recipientType: requesterRole,
      recipientId: row.requester_id,
      kind: 'rental_agreement',
      title: `Payment confirmed — ${current.asset_title || 'your rental'}`,
      body: 'The owner confirmed your receipt and the deal is closed. Download your signed lease agreement from the app to bring to legal/documentation offices.',
      relatedId: row.id,
    });
    broadcastNotification(requesterRole, row.requester_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify requester of confirmed receipt', err);
  }

  return row;
}

/**
 * Owner looked at the tenant's receipt and something's wrong with it
 * (wrong amount, wrong account, unreadable, etc) — sends it back for a
 * re-upload rather than killing the whole deal (that's what reject() is
 * for). Drops back to 'accepted' so the tenant lands back on the
 * payment screen and can submit a fresh receipt via submitReceipt.
 * Grants a fresh RECEIPT_RETRY_WINDOW_HOURS-long payment window — the
 * original one may already be spent by the time a receipt gets
 * reviewed and bounced, and a tenant who genuinely paid shouldn't lose
 * their spot over an owner's decision cycle. See
 * routes/rentalAgreements.js POST /:id/reject-receipt, which re-arms
 * the expiry/reminder timers against the new expires_at this returns.
 */
async function rejectReceipt({ id, ownerId, reason }) {
  const current = await findByIdForOwner(id, ownerId);
  if (!current) throw Object.assign(new Error('Not found.'), { status: 404 });
  if (current.status !== 'payment_submitted') {
    throw Object.assign(new Error('There is no submitted receipt awaiting review.'), { status: 409 });
  }

  const trimmedReason = (reason || '').trim() || null;
  const row = await query(
    `UPDATE rental_agreements
     SET status = 'accepted', receipt_rejected_reason = $3, receipt_url = NULL, receipt_submitted_at = NULL,
         expires_at = now() + make_interval(hours => $4::int), payment_reminder_sent_at = NULL, updated_at = now()
     WHERE id = $1 AND owner_id = $2 AND status = 'payment_submitted'
     RETURNING *`,
    [id, ownerId, trimmedReason, RECEIPT_RETRY_WINDOW_HOURS]
  ).then((r) => r.rows[0] || null);
  if (!row) return null;

  if (current.thread_id) {
    try {
      await chatModel.sendMessage({
        threadId: current.thread_id,
        senderId: ownerId,
        body: trimmedReason
          ? `Receipt couldn't be confirmed: ${trimmedReason}. Please re-upload a valid receipt.`
          : "Receipt couldn't be confirmed — please re-upload a valid receipt.",
        kind: 'rental_agreement',
        relatedId: id,
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[rentalAgreements] failed to post receipt-rejected notice to chat thread', err);
    }
  }

  try {
    const requesterRole = await roleOf(row.requester_id);
    const notifRow = await notificationsModel.create({
      recipientType: requesterRole,
      recipientId: row.requester_id,
      kind: 'rental_agreement',
      title: `Receipt needs another look — ${current.asset_title || 'your rental'}`,
      body: trimmedReason || 'The owner could not confirm your receipt. Please re-upload it.',
      relatedId: row.id,
    });
    broadcastNotification(requesterRole, row.requester_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify requester of rejected receipt', err);
  }

  return row;
}

/**
 * Stateless replacement for scheduler.js's in-memory timers — re-checks
 * every row that might be due for an expiry or reminder right now and
 * fires whatever's due. Where the timer-based path (routes/rentalAgreements.js
 * armExpiry/armPaymentReminder/armLeaseReminders) reacts to a single
 * row's own deadline the instant it arrives, this reacts to however
 * long it's been since the last time something called it — safe to
 * call as often or as rarely as the host allows, and safe to call more
 * than once for the same row (expire/notify* are all self-guarding).
 * See routes/cron.js, the only intended caller — designed for a
 * platform (e.g. Vercel) that can't keep a Node process alive between
 * requests to let setTimeout fire on its own.
 */
async function runSweep() {
  const now = Date.now();
  let expired = 0;
  let paymentReminders = 0;
  let leaseEndingReminders = 0;
  let leaseEndedNotices = 0;

  const active = await listActive();
  for (const row of active) {
    if (new Date(row.expires_at).getTime() <= now) {
      const result = await expire(row.id);
      if (result) {
        expired += 1;
        broadcastNotification('property_owner', result.owner_id, { kind: 'rental_agreement_expired', id: result.id });
      }
      continue;
    }
    if (!row.payment_reminder_sent_at && row.sent_at) {
      const sentAt = new Date(row.sent_at).getTime();
      const expiresAt = new Date(row.expires_at).getTime();
      const warnAt = sentAt + (expiresAt - sentAt) / 2;
      if (now >= warnAt) {
        await notifyPaymentWindowHalfway(row.id);
        paymentReminders += 1;
      }
    }
  }

  const leaseTracking = await listLeaseTracking();
  for (const row of leaseTracking) {
    const leaseEndAt = new Date(row.lease_end_at).getTime();
    if (!row.lease_ending_reminder_sent_at && now >= leaseEndAt - LEASE_REMINDER_LEAD_MS) {
      await notifyLeaseEndingSoon(row.id);
      leaseEndingReminders += 1;
    }
    if (!row.lease_ended_notice_sent_at && now >= leaseEndAt) {
      await notifyLeaseEnded(row.id);
      leaseEndedNotices += 1;
    }
  }

  return { expired, paymentReminders, leaseEndingReminders, leaseEndedNotices };
}

/** Owner rejects — reopens the listing for other users. */
async function reject({ id, ownerId, reason }) {
  const current = await findByIdForOwner(id, ownerId);
  if (!current) throw Object.assign(new Error('Not found.'), { status: 404 });
  if (!['documents_submitted', 'agreement_sent', 'accepted', 'payment_submitted'].includes(current.status)) {
    throw Object.assign(new Error('This request has already been decided.'), { status: 409 });
  }

  const row = await query(
    `UPDATE rental_agreements
     SET status = 'rejected', rejected_reason = $3, rejected_at = now(), updated_at = now()
     WHERE id = $1 AND owner_id = $2
     RETURNING *`,
    [id, ownerId, (reason || '').trim() || null]
  ).then((r) => r.rows[0]);

  await reopenAssetIfPipelineOwned(row.asset_id);

  if (current.thread_id && reason) {
    try {
      await chatModel.sendMessage({ threadId: current.thread_id, senderId: ownerId, body: `Request declined: ${reason.trim()}` });
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
      title: `Request declined — ${current.asset_title || 'your request'}`,
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

/** The payment window lapsed with no payment — reopens the listing.
 *  Mirrors tourRequests.expire's "no-op if it already moved on" guard:
 *  only touches a row still sitting in 'agreement_sent' or 'accepted'
 *  (accepting the terms doesn't pause the countdown). Returns null if
 *  there was nothing to expire (already paid/rejected just before the
 *  timer fired). */
async function expire(id) {
  const row = await query(
    `UPDATE rental_agreements
     SET status = 'expired', updated_at = now()
     WHERE id = $1 AND status IN ('agreement_sent', 'accepted')
     RETURNING *`,
    [id]
  ).then((r) => r.rows[0] || null);
  if (!row) return null;

  await reopenAssetIfPipelineOwned(row.asset_id);

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
 * Shared close-out for a row that just flipped to 'paid', regardless of
 * which path got it there: moves the listing to 'rented' and closes the
 * underlying property_request. Both markPaid and markPaidManually call
 * this with the same row shape; only the chat message and notification
 * differ between them.
 */
async function _closeOutPaidAgreement(row) {
  await assetsModel.update(row.asset_id, { status: 'rented' });
  await propertyRequestsModel.setStatus(row.property_request_id, row.owner_id, 'closed');
  return assetsModel.findById(row.asset_id);
}

async function _threadIdFor(propertyRequestId) {
  const r = await query(`SELECT thread_id FROM property_requests WHERE id = $1`, [propertyRequestId]);
  return r.rows[0]?.thread_id || null;
}

/**
 * Called once a payment with purpose `rental_agreement_<id>` verifies as
 * successful (see routes/payments.js). Closes the loop: marks this row
 * paid, closes the underlying property_request, and moves the listing
 * to 'rented'. Requires 'accepted' — the requester must have accepted
 * the terms (see accept()) before a payment can close the deal, so
 * paying is no longer the only signal they ever agreed to anything.
 * No-ops (returns null) if the row already moved on (e.g. the timer
 * fired a beat before the payment settled, or the requester never
 * accepted at all).
 */
async function markPaid(id, txRef) {
  const row = await query(
    `UPDATE rental_agreements
     SET status = 'paid', payment_tx_ref = $2, payment_method = 'chapa', paid_at = now(),
         lease_end_at = CASE WHEN lease_term_months IS NOT NULL THEN now() + make_interval(months => lease_term_months) ELSE NULL END,
         updated_at = now()
     WHERE id = $1 AND status = 'accepted'
     RETURNING *`,
    [id, txRef || null]
  ).then((r) => r.rows[0] || null);
  if (!row) return null;

  const asset = await _closeOutPaidAgreement(row);

  const threadId = await _threadIdFor(row.property_request_id);
  if (threadId) {
    try {
      await chatModel.sendMessage({
        threadId,
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
      body: 'The tenant paid and the deal is closed. The signed lease agreement is now downloadable from the app.',
      relatedId: row.id,
    });
    broadcastNotification('property_owner', row.owner_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify owner of payment', err);
  }

  return row;
}

/**
 * Owner-side counterpart to markPaid, for a tenant who paid outside
 * Chapa (bank transfer, cash) — no `payments` row exists for these at
 * all, so this is the only way that money ever gets reflected here.
 * Requires a receipt (data URI or hosted URL, same convention as
 * id_document_url) so there's something to point to if the tenant
 * disputes it later. Only the owning owner can call this, and only
 * once the requester has accepted the terms (see accept()) — same gate
 * as the Chapa path in markPaid.
 */
async function markPaidManually({ id, ownerId, receiptUrl }) {
  const current = await findByIdForOwner(id, ownerId);
  if (!current) throw Object.assign(new Error('Not found.'), { status: 404 });
  if (current.status !== 'accepted') {
    throw Object.assign(new Error('This agreement is not awaiting payment.'), { status: 409 });
  }
  if (!receiptUrl || !String(receiptUrl).trim()) {
    throw Object.assign(new Error('A receipt is required to mark this paid manually.'), { status: 400 });
  }

  const row = await query(
    `UPDATE rental_agreements
     SET status = 'paid', payment_method = 'manual_bank', receipt_url = $3,
         marked_paid_by = $2, paid_at = now(),
         lease_end_at = CASE WHEN lease_term_months IS NOT NULL THEN now() + make_interval(months => lease_term_months) ELSE NULL END,
         updated_at = now()
     WHERE id = $1 AND owner_id = $2 AND status = 'accepted'
     RETURNING *`,
    [id, ownerId, String(receiptUrl).trim()]
  ).then((r) => r.rows[0] || null);
  if (!row) return null;

  await _closeOutPaidAgreement(row);

  if (current.thread_id) {
    try {
      await chatModel.sendMessage({
        threadId: current.thread_id,
        senderId: ownerId,
        body: 'Payment received (bank transfer) — the rental agreement is now closed. Message here for anything else.',
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[rentalAgreements] failed to post manual payment confirmation to chat thread', err);
    }
  }

  try {
    const requesterRole = await roleOf(row.requester_id);
    const notifRow = await notificationsModel.create({
      recipientType: requesterRole,
      recipientId: row.requester_id,
      kind: 'rental_agreement',
      title: `Payment confirmed — ${current.asset_title || 'your rental'}`,
      body: 'The owner confirmed your payment and the deal is closed. Download your signed lease agreement from the app to bring to legal/documentation offices.',
      relatedId: row.id,
    });
    broadcastNotification(requesterRole, row.requester_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify requester of manual payment', err);
  }

  return row;
}

/**
 * Owner explicitly confirms the tenant has moved out — the only trigger
 * that reopens a 'paid' listing. Deliberately not automatic: a lease
 * hitting its lease_end_at on paper doesn't mean anyone actually moved
 * out, so auto-flipping assets.status back to 'active' could make a
 * still-occupied unit bookable by someone else. This just closes that
 * loop with an explicit owner action instead.
 */
async function markVacated({ id, ownerId }) {
  const current = await findByIdForOwner(id, ownerId);
  if (!current) throw Object.assign(new Error('Not found.'), { status: 404 });
  if (current.status !== 'paid') {
    throw Object.assign(new Error('This rental is not currently active.'), { status: 409 });
  }
  if (current.vacated_at) {
    throw Object.assign(new Error('This rental has already been marked vacated.'), { status: 409 });
  }

  const row = await query(
    `UPDATE rental_agreements
     SET vacated_at = now(), updated_at = now()
     WHERE id = $1 AND owner_id = $2 AND status = 'paid' AND vacated_at IS NULL
     RETURNING *`,
    [id, ownerId]
  ).then((r) => r.rows[0]);

  await reopenAssetIfPipelineOwned(row.asset_id);

  if (current.thread_id) {
    try {
      await chatModel.sendMessage({
        threadId: current.thread_id,
        senderId: ownerId,
        body: 'The owner marked this rental as vacated — the listing is open to other users again.',
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[rentalAgreements] failed to post vacate notice to chat thread', err);
    }
  }

  try {
    const requesterRole = await roleOf(row.requester_id);
    const notifRow = await notificationsModel.create({
      recipientType: requesterRole,
      recipientId: row.requester_id,
      kind: 'rental_agreement',
      title: `Marked vacated — ${current.asset_title || 'your rental'}`,
      body: 'The owner marked this rental as vacated.',
      relatedId: row.id,
    });
    broadcastNotification(requesterRole, row.requester_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to notify requester of vacate', err);
  }

  return row;
}

/** Every 'paid' row still being tracked toward a lease end — used to
 *  re-arm the two one-shot lease reminders on boot, same pattern as
 *  listActive() does for the payment countdown. Excludes rows already
 *  marked vacated and rows with no fixed term (lease_end_at IS NULL). */
function listLeaseTracking() {
  return query(
    `SELECT * FROM rental_agreements WHERE status = 'paid' AND vacated_at IS NULL AND lease_end_at IS NOT NULL`
  ).then((r) => r.rows);
}

/**
 * Fires ~7 days before lease_end_at (see routes/rentalAgreements.js
 * armLeaseReminders) — nudges the owner to decide whether to renew or
 * plan for the tenant to leave. No-ops silently if the row already
 * moved on (vacated, or somehow no longer paid) by the time this fires.
 */
async function notifyLeaseEndingSoon(id) {
  const row = await findById(id);
  if (!row || row.status !== 'paid' || row.vacated_at || !row.lease_end_at) return;
  // Atomic claim: only proceed if this reminder hasn't already gone out
  // for this row. Matters once this can be invoked repeatedly by a
  // stateless sweep (see routes/cron.js) instead of a one-shot timer.
  const claimed = await query(
    `UPDATE rental_agreements SET lease_ending_reminder_sent_at = now()
     WHERE id = $1 AND lease_ending_reminder_sent_at IS NULL
     RETURNING id`,
    [id]
  ).then((r) => r.rows[0]);
  if (!claimed) return;
  try {
    const notifRow = await notificationsModel.create({
      recipientType: 'property_owner',
      recipientId: row.owner_id,
      kind: 'rental_agreement',
      title: `Lease ending soon — ${row.asset_title || 'your listing'}`,
      body: `This lease ends ${new Date(row.lease_end_at).toDateString()}. Send a renewal, or mark the unit vacated once the tenant moves out.`,
      relatedId: row.id,
    });
    broadcastNotification('property_owner', row.owner_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to send lease-ending-soon reminder', err);
  }
}

/**
 * Fires at lease_end_at itself. Deliberately doesn't touch assets.status
 * or rental_agreements.status — see markVacated for why reopening the
 * listing stays an explicit owner action.
 */
async function notifyLeaseEnded(id) {
  const row = await findById(id);
  if (!row || row.status !== 'paid' || row.vacated_at || !row.lease_end_at) return;
  const claimed = await query(
    `UPDATE rental_agreements SET lease_ended_notice_sent_at = now()
     WHERE id = $1 AND lease_ended_notice_sent_at IS NULL
     RETURNING id`,
    [id]
  ).then((r) => r.rows[0]);
  if (!claimed) return;
  try {
    const notifRow = await notificationsModel.create({
      recipientType: 'property_owner',
      recipientId: row.owner_id,
      kind: 'rental_agreement',
      title: `Lease term ended — ${row.asset_title || 'your listing'}`,
      body: 'The lease term has ended. Mark the unit vacated to reopen the listing, or send a renewal if the tenant is staying.',
      relatedId: row.id,
    });
    broadcastNotification('property_owner', row.owner_id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to send lease-ended reminder', err);
  }
}

/**
 * Fires once, at the midpoint of the payment countdown (see
 * routes/rentalAgreements.js armPaymentReminder) — the gap this closes:
 * previously nothing happened between the agreement being sent and it
 * either getting paid or expiring, so an owner watching a deal go quiet
 * had no chance to nudge the tenant before it silently reopened.
 * Notifies both sides since both can act: the owner might follow up
 * directly, the requester is the one who actually needs to pay. No-ops
 * if the row already moved on (paid/rejected/expired) by the time this
 * fires.
 */
async function notifyPaymentWindowHalfway(id) {
  const row = await findById(id);
  if (!row || !['agreement_sent', 'accepted'].includes(row.status) || !row.expires_at) return;
  const claimed = await query(
    `UPDATE rental_agreements SET payment_reminder_sent_at = now()
     WHERE id = $1 AND payment_reminder_sent_at IS NULL
     RETURNING id`,
    [id]
  ).then((r) => r.rows[0]);
  if (!claimed) return;
  const hoursLeft = Math.max(0, Math.round((new Date(row.expires_at).getTime() - Date.now()) / 3600000));

  try {
    const ownerNotif = await notificationsModel.create({
      recipientType: 'property_owner',
      recipientId: row.owner_id,
      kind: 'rental_agreement',
      title: `Payment still pending — ${row.asset_title || 'your listing'}`,
      body: `The tenant hasn't paid yet — about ${hoursLeft}h left before this offer expires and the listing reopens.`,
      relatedId: row.id,
    });
    broadcastNotification('property_owner', row.owner_id, notificationsModel.toPublic(ownerNotif));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to send owner payment-window reminder', err);
  }

  try {
    const requesterRole = await roleOf(row.requester_id);
    const requesterNotif = await notificationsModel.create({
      recipientType: requesterRole,
      recipientId: row.requester_id,
      kind: 'rental_agreement',
      title: `Payment window closing soon — ${row.asset_title || 'this rental'}`,
      body:
        row.status === 'agreement_sent'
          ? `Accept the terms and pay soon — about ${hoursLeft}h left before this offer expires.`
          : `Pay soon — about ${hoursLeft}h left before this offer expires.`,
      relatedId: row.id,
    });
    broadcastNotification(requesterRole, row.requester_id, notificationsModel.toPublic(requesterNotif));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[rentalAgreements] failed to send requester payment-window reminder', err);
  }
}

module.exports = {
  AGREEMENT_WINDOW_HOURS,
  RECEIPT_RETRY_WINDOW_HOURS,
  toPublic,
  submitDocuments,
  listForOwner,
  listForRequester,
  findByIdForOwner,
  findByIdForRequester,
  findById,
  listActive,
  sendAgreement,
  accept,
  submitReceipt,
  confirmReceipt,
  rejectReceipt,
  reject,
  expire,
  markPaid,
  markPaidManually,
  markVacated,
  listLeaseTracking,
  notifyLeaseEndingSoon,
  notifyLeaseEnded,
  notifyPaymentWindowHalfway,
  runSweep,
};
