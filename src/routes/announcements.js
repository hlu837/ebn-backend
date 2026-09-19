const express = require('express');
const { query } = require('../db');
const { requireAuth } = require('./auth');

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function requireAdmin(req, res, next) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required.' });
  }
  next();
}

const VALID_CATEGORIES = ['General', 'Payout', 'Update'];

function toPublic(row) {
  return {
    id: row.id,
    title: row.title,
    content: row.content,
    category: row.category,
    isPinned: row.is_pinned,
    createdAt: row.created_at,
  };
}

const router = express.Router();

// GET /api/announcements
// Public/investor feed — pinned posts first, then newest first.
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { rows } = await query(
      'SELECT * FROM announcements ORDER BY is_pinned DESC, created_at DESC'
    );
    res.json(rows.map(toPublic));
  })
);

// POST /api/announcements
// Admin-only: create a new announcement.
router.post(
  '/',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const { title, content, category, isPinned } = req.body;

    if (!title || !title.trim() || !content || !content.trim()) {
      return res.status(400).json({ error: 'title and content are required.' });
    }
    if (category && !VALID_CATEGORIES.includes(category)) {
      return res.status(400).json({ error: `category must be one of: ${VALID_CATEGORIES.join(', ')}` });
    }

    const { rows } = await query(
      `INSERT INTO announcements (title, content, category, is_pinned)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [title.trim(), content.trim(), category || 'General', !!isPinned]
    );
    res.status(201).json(toPublic(rows[0]));
  })
);

// DELETE /api/announcements/:id
// Admin-only: remove an announcement.
router.delete(
  '/:id',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const { rows } = await query('DELETE FROM announcements WHERE id = $1 RETURNING id', [
      req.params.id,
    ]);
    if (!rows.length) return res.status(404).json({ error: 'Announcement not found.' });
    res.json({ deleted: rows[0].id });
  })
);

module.exports = { router };
