const express = require('express');
const { requireAuth } = require('./auth');
const model = require('../models/supportTickets');
const usersModel = require('../models/users');
const notificationsModel = require('../models/notifications');
const { broadcastNotification } = require('../socket');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

const VALID_CATEGORIES = ['account', 'payments', 'listings', 'bug', 'other'];

// POST /api/support-tickets
// Any signed-in user (agent Support screen today; open to other roles'
// future support screens too). Body: { category, subject, body }.
router.post(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { category, subject, body } = req.body || {};
    if (!subject || !String(subject).trim()) {
      return res.status(400).json({ error: 'subject is required.' });
    }
    if (!body || !String(body).trim()) {
      return res.status(400).json({ error: 'body is required.' });
    }
    const normalizedCategory = VALID_CATEGORIES.includes(category) ? category : 'other';
    const row = await model.create({
      userId: req.user.id,
      senderName: req.user.fullName,
      senderContact: req.user.phone || req.user.email,
      category: normalizedCategory,
      subject: String(subject).trim(),
      body: String(body).trim(),
    });
    const created = model.toPublic(row);

    try {
      const notifRow = await notificationsModel.create({
        recipientType: 'admin',
        kind: 'system',
        title: 'New support ticket',
        body: `${req.user.fullName || 'A user'}: ${created.subject}`,
        relatedId: created.id,
      });
      broadcastNotification('admin', null, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[supportTickets] failed to notify admins of new ticket', err);
    }

    res.status(201).json(created);
  })
);

// GET /api/support-tickets/me — caller's own ticket history
router.get(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await model.listByUser(req.user.id);
    res.json(rows.map(model.toPublic));
  })
);

// GET /api/support-tickets?status=open|resolved — admin inbox
router.get(
  '/',
  requireAuth,
  asyncHandler(async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
    const { status } = req.query;
    const rows = await model.list({ status: status ? String(status) : undefined });
    res.json(rows.map(model.toPublic));
  })
);

// GET /api/support-tickets/:id — admin detail view
router.get(
  '/:id',
  requireAuth,
  asyncHandler(async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
    const row = await model.findById(req.params.id);
    if (!row) return res.status(404).json({ error: 'Not found.' });
    res.json(model.toPublic(row));
  })
);

// POST /api/support-tickets/:id/resolve — admin marks resolved
router.post(
  '/:id/resolve',
  requireAuth,
  asyncHandler(async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
    const row = await model.resolve(req.params.id);
    if (!row) return res.status(404).json({ error: 'Not found.' });
    res.json(model.toPublic(row));
  })
);

// POST /api/support-tickets/:id/reply — admin answers the ticket. Body: { response }.
// Persists the answer on the ticket itself and notifies whoever submitted
// it, with the answer text in the notification body — that's the
// delivery channel for the reply (there's no ticket-thread UI yet), so
// the notification IS the answer, not just a pointer to go read it
// somewhere else.
router.post(
  '/:id/reply',
  requireAuth,
  asyncHandler(async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
    const { response } = req.body || {};
    if (!response || !String(response).trim()) {
      return res.status(400).json({ error: 'response is required.' });
    }

    const ticket = await model.findById(req.params.id);
    if (!ticket) return res.status(404).json({ error: 'Not found.' });

    const row = await model.reply(req.params.id, String(response).trim());
    const updated = model.toPublic(row);

    // Best-effort, same pattern as the other notification triggers: a
    // failure here shouldn't fail the reply that was just saved.
    try {
      if (ticket.user_id) {
        const owner = await usersModel.findById(ticket.user_id);
        if (owner) {
          const notifRow = await notificationsModel.create({
            recipientType: owner.role,
            recipientId: owner.id,
            kind: 'system',
            title: `Support replied: ${updated.subject}`,
            body: updated.adminResponse,
            relatedId: updated.id,
          });
          broadcastNotification(owner.role, owner.id, notificationsModel.toPublic(notifRow));
        }
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(`[supportTickets] failed to notify ticket owner of reply ${req.params.id}`, err);
    }

    res.json(updated);
  })
);

module.exports = { router };
