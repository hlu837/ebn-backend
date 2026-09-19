const express = require('express');
const { requireAuth } = require('./auth');
const model = require('../models/agentTasks');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

function requireAgent(req, res, next) {
  if (req.user.role !== 'agent') {
    return res.status(403).json({ error: 'Only agent accounts have a task list.' });
  }
  next();
}

// GET /api/agent-tasks — the caller's own task list.
router.get(
  '/',
  requireAuth,
  requireAgent,
  asyncHandler(async (req, res) => {
    const rows = await model.listForAgent(req.user.id);
    res.json(rows.map(model.toPublic));
  })
);

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

// POST /api/agent-tasks — create a task for yourself. Body: { id?, title,
// dueAt?, linkedTourRequestId?, linkedOrderRequestId? }. `id` is a
// client-generated UUID that makes the call safe to retry (see model.create).
router.post(
  '/',
  requireAuth,
  requireAgent,
  asyncHandler(async (req, res) => {
    const { id, title, dueAt, linkedTourRequestId, linkedOrderRequestId } = req.body || {};
    if (!title || !String(title).trim()) {
      return res.status(400).json({ error: 'title is required.' });
    }
    if (id != null && !UUID_RE.test(String(id))) {
      return res.status(400).json({ error: 'id must be a UUID.' });
    }
    const row = await model.create({
      id: id ? String(id).toLowerCase() : null,
      agentId: req.user.id,
      title: String(title).trim(),
      dueAt: dueAt || null,
      linkedTourRequestId: linkedTourRequestId || null,
      linkedOrderRequestId: linkedOrderRequestId || null,
      createdBy: 'agent',
    });
    if (!row) return res.status(409).json({ error: 'That task id is already in use.' });
    res.status(201).json(model.toPublic(row));
  })
);

// PATCH /api/agent-tasks/:id — toggle done. Body: { done }.
router.patch(
  '/:id',
  requireAuth,
  requireAgent,
  asyncHandler(async (req, res) => {
    const { done } = req.body || {};
    if (typeof done !== 'boolean') {
      return res.status(400).json({ error: 'done (boolean) is required.' });
    }
    const row = await model.setDone(req.params.id, req.user.id, done);
    if (!row) return res.status(404).json({ error: 'Task not found.' });
    res.json(model.toPublic(row));
  })
);

// DELETE /api/agent-tasks/:id
router.delete(
  '/:id',
  requireAuth,
  requireAgent,
  asyncHandler(async (req, res) => {
    const row = await model.remove(req.params.id, req.user.id);
    if (!row) return res.status(404).json({ error: 'Task not found.' });
    res.json({ ok: true });
  })
);

module.exports = { router };
