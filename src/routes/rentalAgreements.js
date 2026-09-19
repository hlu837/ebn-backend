const express = require('express');
const { requireAuth, requireAuthQueryOk } = require('./auth');
const model = require('../models/rentalAgreements');
const ownerBankAccountsModel = require('../models/ownerBankAccounts');
const scheduler = require('../scheduler');
const { broadcastNotification } = require('../socket');
const { renderLeaseAgreementPdf } = require('../services/leaseDocument');

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function sendModelError(res, err) {
  if (err && err.status) return res.status(err.status).json({ error: err.message });
  throw err;
}

const router = express.Router();

/** Arms (or re-arms) the payment-window expiry timer for a sent agreement. */
function armExpiry(agreement) {
  if (!agreement.expires_at) return;
  scheduler.schedule(agreement.id, agreement.expires_at, async (id) => {
    const expired = await model.expire(id);
    if (!expired) return; // already paid/rejected just before the timer fired
    broadcastNotification('property_owner', expired.owner_id, { kind: 'rental_agreement_expired', id: expired.id });
  });
}

/**
 * Arms (or re-arms) a one-shot reminder at the midpoint of the payment
 * countdown — the gap between "agreement sent" and "paid/expired" where
 * nothing used to happen at all. Works for any window length since it's
 * relative to sent_at, not a fixed lead time. Cancelled at the same
 * three points armExpiry's timer is cancelled (reject, manual-pay, the
 * Chapa webhook) — see cancelPaymentReminder.
 */
function armPaymentReminder(agreement) {
  if (!agreement.expires_at || !agreement.sent_at) return;
  const sentAt = new Date(agreement.sent_at).getTime();
  const expiresAt = new Date(agreement.expires_at).getTime();
  const warnAt = new Date(sentAt + (expiresAt - sentAt) / 2);
  scheduler.schedule(`payment-warn-${agreement.id}`, warnAt, () => model.notifyPaymentWindowHalfway(agreement.id));
}

function cancelPaymentReminder(id) {
  scheduler.cancel(`payment-warn-${id}`);
}

/** How long before lease_end_at the "renew or vacate" nudge goes out. */
const LEASE_REMINDER_LEAD_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Arms (or re-arms) the two one-shot lease-lifecycle reminders for a row
 * that's paid and has a fixed lease_end_at — a "renew or vacate" nudge
 * ~7 days out, and an "the term has ended" notice on the day itself.
 * No-op for month-to-month rows (lease_end_at is null) or rows already
 * marked vacated. Both timers key off the row id with a suffix so they
 * don't collide with armExpiry's timer for the same id.
 */
function armLeaseReminders(agreement) {
  if (!agreement.lease_end_at || agreement.vacated_at) return;
  const leaseEndAt = new Date(agreement.lease_end_at);
  const warnAt = new Date(leaseEndAt.getTime() - LEASE_REMINDER_LEAD_MS);

  scheduler.schedule(`lease-warn-${agreement.id}`, warnAt, () => model.notifyLeaseEndingSoon(agreement.id));
  scheduler.schedule(`lease-end-${agreement.id}`, leaseEndAt, () => model.notifyLeaseEnded(agreement.id));
}

/** Cancels both lease reminder timers for a row — call this wherever a
 *  row stops being tracked toward a lease end (markVacated). */
function cancelLeaseReminders(id) {
  scheduler.cancel(`lease-warn-${id}`);
  scheduler.cancel(`lease-end-${id}`);
}

/**
 * POST /api/rental-agreements
 * body: { propertyRequestId, idDocumentUrl, documentUrls?, faydaIdNumber, note? }
 * Requester-side: submits their digital ID + Fayda ID number + supporting
 * documents against a rent_now request they already sent. Reserves the
 * listing for review.
 */
router.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { propertyRequestId, idDocumentUrl, documentUrls, faydaIdNumber, note } = req.body || {};
    if (!propertyRequestId) return res.status(400).json({ error: 'propertyRequestId is required' });
    try {
      const row = await model.submitDocuments({
        propertyRequestId,
        requesterId: req.user.id,
        idDocumentUrl,
        documentUrls,
        faydaIdNumber,
        note,
      });
      res.status(201).json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/** GET /api/rental-agreements/queue — the caller's Review tab, as an owner.
 *  Query: status ('active' | 'documents_submitted' | 'agreement_sent' |
 *  'paid' | 'rejected' | 'expired'), defaults to 'active'. */
router.get(
  '/queue',
  requireAuth,
  asyncHandler(async (req, res) => {
    const status = req.query.status || 'active';
    const rows = await model.listForOwner(req.user.id, { status });
    res.json(rows.map(model.toPublic));
  })
);

/** GET /api/rental-agreements/mine — the caller's own pipeline rows, as a requester. */
router.get(
  '/mine',
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await model.listForRequester(req.user.id);
    res.json(rows.map(model.toPublic));
  })
);

/** GET /api/rental-agreements/:id — either party may view their own row. */
router.get(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    const row = await model.findById(req.params.id);
    if (!row || (row.owner_id !== req.user.id && row.requester_id !== req.user.id)) {
      return res.status(404).json({ error: 'Not found.' });
    }
    res.json(model.toPublic(row));
  })
);

/**
 * POST /api/rental-agreements/:id/send
 * body: { advanceMonths, depositAmount?, hours?, termMonths? }
 * Owner approves the documents and sends the rental agreement, starting
 * the payment countdown (default 24h). advanceMonths is how many months
 * of rent to collect up front — the total due is computed server-side
 * from the listing's own monthly price, not typed in by the owner.
 * The agreement text itself is generated from the standard lease
 * template (see services/leaseTemplate.js) — the owner no longer
 * supplies `terms` at all. termMonths is optional — omit it for a
 * month-to-month arrangement with no fixed lease end.
 */
router.post(
  '/:id/send',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { advanceMonths, depositAmount, hours, termMonths } = req.body || {};
    try {
      const row = await model.sendAgreement({
        id: req.params.id,
        ownerId: req.user.id,
        advanceMonths,
        depositAmount,
        hours,
        termMonths,
      });
      armExpiry(row);
      armPaymentReminder(row);
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/**
 * GET /api/rental-agreements/:id/bank-accounts
 * Requester-side: the owner's bank accounts to transfer rent into,
 * shown on the payment screen once the tenant has accepted the terms.
 * Only exposed once status is 'accepted' or 'paid' — before that the
 * tenant hasn't agreed to anything yet, so there's nothing to pay
 * against. The owner can call this too (e.g. to double-check what their
 * tenant is seeing).
 */
router.get(
  '/:id/bank-accounts',
  requireAuth,
  asyncHandler(async (req, res) => {
    const row = await model.findById(req.params.id);
    if (!row || (row.owner_id !== req.user.id && row.requester_id !== req.user.id)) {
      return res.status(404).json({ error: 'Not found.' });
    }
    if (!['accepted', 'payment_submitted', 'paid'].includes(row.status)) {
      return res.status(409).json({ error: 'Accept the agreement terms first.' });
    }
    const accounts = await ownerBankAccountsModel.listActiveForOwner(row.owner_id);
    res.json(accounts.map(ownerBankAccountsModel.toPublic));
  })
);

/**
 * POST /api/rental-agreements/:id/accept
 * Requester-side: accepts the terms the owner sent. Required before
 * payment can close the deal — see model.markPaid/markPaidManually,
 * which now both require status 'accepted' instead of 'agreement_sent'.
 */
router.post(
  '/:id/accept',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const row = await model.accept({ id: req.params.id, requesterId: req.user.id });
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/**
 * POST /api/rental-agreements/:id/submit-receipt
 * body: { receiptUrl }
 * Requester-side: after transferring rent via one of the owner's bank
 * accounts (GET /:id/bank-accounts), the tenant attaches their own
 * proof of payment — a photo or PDF, same data-URI convention as
 * idDocumentUrl. Moves the row to 'payment_submitted' and notifies the
 * owner. Cancels this row's payment-window countdown, since the tenant
 * has acted — see model.submitReceipt.
 */
router.post(
  '/:id/submit-receipt',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const row = await model.submitReceipt({
        id: req.params.id,
        requesterId: req.user.id,
        receiptUrl: req.body?.receiptUrl,
      });
      if (!row) return res.status(409).json({ error: 'This agreement is not awaiting payment.' });
      scheduler.cancel(row.id);
      cancelPaymentReminder(row.id);
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/**
 * POST /api/rental-agreements/:id/confirm-receipt
 * Owner-side: reviewed the tenant-submitted receipt (see
 * GET /:id — receiptUrl) and it checks out. Closes the deal exactly
 * like mark-paid-manual does. Once this succeeds, GET /:id/document
 * becomes available.
 */
router.post(
  '/:id/confirm-receipt',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const row = await model.confirmReceipt({ id: req.params.id, ownerId: req.user.id });
      if (!row) return res.status(409).json({ error: 'There is no submitted receipt awaiting confirmation.' });
      armLeaseReminders(row);
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/**
 * POST /api/rental-agreements/:id/reject-receipt
 * body: { reason? }
 * Owner-side: the submitted receipt doesn't check out — sends it back
 * for a re-upload (drops to 'accepted' with a fresh payment window)
 * rather than killing the whole deal. Use POST /:id/reject instead to
 * reject the deal outright.
 */
router.post(
  '/:id/reject-receipt',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const row = await model.rejectReceipt({
        id: req.params.id,
        ownerId: req.user.id,
        reason: req.body?.reason,
      });
      if (!row) return res.status(409).json({ error: 'There is no submitted receipt awaiting review.' });
      armExpiry(row);
      armPaymentReminder(row);
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/** POST /api/rental-agreements/:id/reject — body: { reason? } */
router.post(
  '/:id/reject',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const row = await model.reject({ id: req.params.id, ownerId: req.user.id, reason: req.body?.reason });
      scheduler.cancel(row.id);
      cancelPaymentReminder(row.id);
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/**
 * POST /api/rental-agreements/:id/mark-paid-manual
 * body: { receiptUrl }
 * Owner confirms a payment that happened outside Chapa (bank transfer,
 * cash) and attaches proof themselves — for a payment the owner
 * collected directly (e.g. cash in person) with no tenant-submitted
 * receipt in the loop. Only valid while status is 'accepted'. If the
 * tenant already submitted their own receipt instead, use
 * POST /:id/confirm-receipt or POST /:id/reject-receipt.
 */
router.post(
  '/:id/mark-paid-manual',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const row = await model.markPaidManually({
        id: req.params.id,
        ownerId: req.user.id,
        receiptUrl: req.body?.receiptUrl,
      });
      if (!row) return res.status(409).json({ error: 'This agreement is not awaiting payment.' });
      scheduler.cancel(row.id);
      cancelPaymentReminder(row.id);
      armLeaseReminders(row);
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

/**
 * GET /api/rental-agreements/:id/document
 * Either party may download the signed lease agreement as a PDF — the
 * document to print and take to a legal/documentation office (see
 * services/leaseDocument.js). Only available once status is 'paid':
 * before that there's nothing signed yet, and the tenant can already
 * read the same terms in-app via GET /:id (agreementTerms). Accepts the
 * token either as a normal Authorization header or as `?token=` — the
 * latter so the app can open this URL directly (e.g. via url_launcher)
 * without needing a custom header (see routes/auth.js requireAuthQueryOk).
 */
router.get(
  '/:id/document',
  requireAuthQueryOk,
  asyncHandler(async (req, res) => {
    const row = await model.findById(req.params.id);
    if (!row || (row.owner_id !== req.user.id && row.requester_id !== req.user.id)) {
      return res.status(404).json({ error: 'Not found.' });
    }
    if (row.status !== 'paid') {
      return res.status(409).json({ error: 'This agreement is not yet paid and closed.' });
    }
    const pdf = await renderLeaseAgreementPdf(row);
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="lease-agreement-${row.id}.pdf"`);
    res.setHeader('Content-Length', pdf.length);
    res.end(pdf);
  })
);

/**
 * POST /api/rental-agreements/:id/vacate
 * Owner-only: explicitly confirms the tenant has moved out. The sole
 * trigger that reopens the listing after a 'paid' agreement — see
 * model.markVacated for why this isn't automatic even once lease_end_at
 * has passed.
 */
router.post(
  '/:id/vacate',
  requireAuth,
  asyncHandler(async (req, res) => {
    try {
      const row = await model.markVacated({ id: req.params.id, ownerId: req.user.id });
      cancelLeaseReminders(row.id);
      res.json(model.toPublic(await model.findById(row.id)));
    } catch (err) {
      sendModelError(res, err);
    }
  })
);

module.exports = { router, armExpiry, armPaymentReminder, cancelPaymentReminder, armLeaseReminders, cancelLeaseReminders };
