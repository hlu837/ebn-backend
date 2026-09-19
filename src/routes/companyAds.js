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

function toPublic(row) {
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    imageUrl: row.image_url,
    linkUrl: row.link_url,
    sortOrder: row.sort_order,
    isActive: row.is_active,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

const router = express.Router();

// GET /api/company-ads
// Public — the landing page's ad carousel. Active ads only, in display
// order. Admins hit this same route with ?all=1 to see inactive ones too
// (management screen needs to show/edit everything, not just what's live).
router.get(
  '/',
  asyncHandler(async (req, res) => {
    const includeInactive = req.query.all === '1' || req.query.all === 'true';
    const { rows } = includeInactive
      ? await query('SELECT * FROM company_ads ORDER BY sort_order ASC, created_at DESC')
      : await query(
          'SELECT * FROM company_ads WHERE is_active = true ORDER BY sort_order ASC, created_at DESC'
        );
    res.json(rows.map(toPublic));
  })
);

// POST /api/company-ads
// Admin-only: create a new ad. `linkUrl` is optional — when omitted,
// tapping the card in the app should just zoom the image instead of
// navigating anywhere.
router.post(
  '/',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const { title, description, imageUrl, linkUrl, sortOrder, isActive } = req.body || {};

    if (!title || !String(title).trim()) {
      return res.status(400).json({ error: 'title is required.' });
    }
    if (!imageUrl || !String(imageUrl).trim()) {
      return res.status(400).json({ error: 'imageUrl is required.' });
    }

    const maxOrder = await query('SELECT COALESCE(MAX(sort_order), -1) AS max FROM company_ads');
    const nextOrder = Number.isFinite(sortOrder) ? sortOrder : maxOrder.rows[0].max + 1;

    const { rows } = await query(
      `INSERT INTO company_ads (title, description, image_url, link_url, sort_order, is_active)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        String(title).trim(),
        description ? String(description).trim() : '',
        String(imageUrl).trim(),
        linkUrl && String(linkUrl).trim() ? String(linkUrl).trim() : null,
        nextOrder,
        isActive === undefined ? true : !!isActive,
      ]
    );
    res.status(201).json(toPublic(rows[0]));
  })
);

// PUT /api/company-ads/:id
// Admin-only: edit an existing ad (title/description/image/link/order/active).
router.put(
  '/:id',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const { title, description, imageUrl, linkUrl, sortOrder, isActive } = req.body || {};

    const map = {
      title: ['title', title !== undefined ? String(title).trim() : undefined],
      description: [
        'description',
        description !== undefined ? String(description).trim() : undefined,
      ],
      imageUrl: ['image_url', imageUrl !== undefined ? String(imageUrl).trim() : undefined],
      linkUrl: [
        'link_url',
        linkUrl !== undefined ? (String(linkUrl).trim() ? String(linkUrl).trim() : null) : undefined,
      ],
      sortOrder: ['sort_order', sortOrder !== undefined ? sortOrder : undefined],
      isActive: ['is_active', isActive !== undefined ? !!isActive : undefined],
    };

    const sets = [];
    const vals = [];
    let i = 1;
    for (const [column, value] of Object.values(map)) {
      if (value !== undefined) {
        sets.push(`${column} = $${i++}`);
        vals.push(value);
      }
    }

    if (!sets.length) {
      const existing = await query('SELECT * FROM company_ads WHERE id = $1', [req.params.id]);
      if (!existing.rows.length) return res.status(404).json({ error: 'Ad not found.' });
      return res.json(toPublic(existing.rows[0]));
    }

    sets.push(`updated_at = now()`);
    vals.push(req.params.id);
    const { rows } = await query(
      `UPDATE company_ads SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`,
      vals
    );
    if (!rows.length) return res.status(404).json({ error: 'Ad not found.' });
    res.json(toPublic(rows[0]));
  })
);

// DELETE /api/company-ads/:id
// Admin-only: remove an ad.
router.delete(
  '/:id',
  requireAuth,
  requireAdmin,
  asyncHandler(async (req, res) => {
    const { rows } = await query('DELETE FROM company_ads WHERE id = $1 RETURNING id', [
      req.params.id,
    ]);
    if (!rows.length) return res.status(404).json({ error: 'Ad not found.' });
    res.json({ deleted: rows[0].id });
  })
);

module.exports = { router };
