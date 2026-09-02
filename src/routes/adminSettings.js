const express = require('express');
const bcrypt = require('bcryptjs');

const categoriesModel = require('../models/categories');
const citiesModel = require('../models/cities');
const contentModel = require('../models/appContent');
const generalModel = require('../models/generalSettings');
const adminAccountsModel = require('../models/adminAccounts');
const usersModel = require('../models/users');
const activityLogModel = require('../models/activityLog');
const membershipPricingModel = require('../models/membershipPricing');
const investorMembershipPlanModel = require('../models/investorMembershipPlan');
const { requireAuth } = require('./auth');

const router = express.Router();
const BCRYPT_ROUNDS = 10;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

function requireAdmin(req, res, next) {
  if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin only.' });
  next();
}

router.use(requireAuth, requireAdmin);

/** Best-effort audit log write — never fails the action that triggered it. */
async function logAction(req, { action, targetType, targetId, detail }) {
  try {
    await activityLogModel.create({
      actorId: req.user.id,
      actorName: req.user.fullName || req.user.email,
      action,
      targetType,
      targetId,
      detail,
    });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error(`[adminSettings] failed to log ${action}`, err);
  }
}

function slugify(label) {
  return String(label)
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

// ── Categories & Pricing ──────────────────────────────────────────────

router.get(
  '/categories',
  asyncHandler(async (req, res) => {
    const rows = await categoriesModel.list();
    res.json({ categories: rows.map(categoriesModel.toPublic) });
  })
);

router.post(
  '/categories',
  asyncHandler(async (req, res) => {
    const { label, listingFeeCents } = req.body || {};
    if (!label || !String(label).trim()) {
      return res.status(400).json({ error: 'label is required.' });
    }
    const slug = slugify(label);
    if (!slug) return res.status(400).json({ error: 'label must contain at least one letter or number.' });
    const existing = await categoriesModel.findBySlug(slug);
    if (existing) return res.status(409).json({ error: 'A category with a matching slug already exists.' });

    const row = await categoriesModel.create({
      slug,
      label: String(label).trim(),
      listingFeeCents: Number.isFinite(listingFeeCents) ? listingFeeCents : 0,
    });
    await logAction(req, { action: 'category_created', targetType: 'category', targetId: row.id, detail: row.label });
    res.status(201).json(categoriesModel.toPublic(row));
  })
);

router.patch(
  '/categories/:id',
  asyncHandler(async (req, res) => {
    const existing = await categoriesModel.findById(req.params.id);
    if (!existing) return res.status(404).json({ error: 'Category not found.' });

    const { label, listingFeeCents, isActive } = req.body || {};
    const row = await categoriesModel.update(req.params.id, { label, listingFeeCents, isActive });
    await logAction(req, { action: 'category_updated', targetType: 'category', targetId: row.id, detail: row.label });
    res.json(categoriesModel.toPublic(row));
  })
);

router.put(
  '/categories/reorder',
  asyncHandler(async (req, res) => {
    const { orderedIds } = req.body || {};
    if (!Array.isArray(orderedIds) || !orderedIds.length) {
      return res.status(400).json({ error: 'orderedIds (non-empty array) is required.' });
    }
    const rows = await categoriesModel.reorder(orderedIds);
    res.json({ categories: rows.map(categoriesModel.toPublic) });
  })
);

router.delete(
  '/categories/:id',
  asyncHandler(async (req, res) => {
    const existing = await categoriesModel.findById(req.params.id);
    if (!existing) return res.status(404).json({ error: 'Category not found.' });
    const row = await categoriesModel.remove(req.params.id);
    await logAction(req, { action: 'category_archived', targetType: 'category', targetId: row.id, detail: row.label });
    res.json(categoriesModel.toPublic(row));
  })
);

// ── Cities ──────────────────────────────────────────────────────────────

router.get(
  '/cities',
  asyncHandler(async (req, res) => {
    const rows = await citiesModel.list();
    res.json({ cities: rows.map(citiesModel.toPublic) });
  })
);

router.post(
  '/cities',
  asyncHandler(async (req, res) => {
    const { name, isLive } = req.body || {};
    if (!name || !String(name).trim()) return res.status(400).json({ error: 'name is required.' });
    const existing = await citiesModel.findByName(String(name).trim());
    if (existing) return res.status(409).json({ error: 'This city already exists.' });

    const row = await citiesModel.create({ name: String(name).trim(), isLive });
    await logAction(req, { action: 'city_created', targetType: 'city', targetId: row.id, detail: row.name });
    res.status(201).json(citiesModel.toPublic(row));
  })
);

router.patch(
  '/cities/:id',
  asyncHandler(async (req, res) => {
    const existing = await citiesModel.findById(req.params.id);
    if (!existing) return res.status(404).json({ error: 'City not found.' });
    const { name, isLive, sortOrder } = req.body || {};
    const row = await citiesModel.update(req.params.id, { name, isLive, sortOrder });
    await logAction(req, { action: 'city_updated', targetType: 'city', targetId: row.id, detail: row.name });
    res.json(citiesModel.toPublic(row));
  })
);

router.delete(
  '/cities/:id',
  asyncHandler(async (req, res) => {
    const existing = await citiesModel.findById(req.params.id);
    if (!existing) return res.status(404).json({ error: 'City not found.' });
    await citiesModel.remove(req.params.id);
    await logAction(req, { action: 'city_removed', targetType: 'city', targetId: req.params.id, detail: existing.name });
    res.json({ ok: true });
  })
);

// ── App Content: FAQ ─────────────────────────────────────────────────

router.get(
  '/faq',
  asyncHandler(async (req, res) => {
    const rows = await contentModel.listFaq();
    res.json({ faq: rows.map(contentModel.faqToPublic) });
  })
);

router.post(
  '/faq',
  asyncHandler(async (req, res) => {
    const { question, answer } = req.body || {};
    if (!question || !String(question).trim()) return res.status(400).json({ error: 'question is required.' });
    if (!answer || !String(answer).trim()) return res.status(400).json({ error: 'answer is required.' });
    const row = await contentModel.createFaq({ question: String(question).trim(), answer: String(answer).trim() });
    await logAction(req, { action: 'faq_created', targetType: 'faq_entry', targetId: row.id, detail: row.question });
    res.status(201).json(contentModel.faqToPublic(row));
  })
);

router.patch(
  '/faq/:id',
  asyncHandler(async (req, res) => {
    const existing = await contentModel.findFaqById(req.params.id);
    if (!existing) return res.status(404).json({ error: 'FAQ entry not found.' });
    const { question, answer, sortOrder, isActive } = req.body || {};
    const row = await contentModel.updateFaq(req.params.id, { question, answer, sortOrder, isActive });
    await logAction(req, { action: 'faq_updated', targetType: 'faq_entry', targetId: row.id, detail: row.question });
    res.json(contentModel.faqToPublic(row));
  })
);

router.delete(
  '/faq/:id',
  asyncHandler(async (req, res) => {
    const existing = await contentModel.findFaqById(req.params.id);
    if (!existing) return res.status(404).json({ error: 'FAQ entry not found.' });
    await contentModel.removeFaq(req.params.id);
    await logAction(req, { action: 'faq_removed', targetType: 'faq_entry', targetId: req.params.id, detail: existing.question });
    res.json({ ok: true });
  })
);

// ── App Content: static pages (About Us / Features) ───────────────────

router.get(
  '/content-pages',
  asyncHandler(async (req, res) => {
    const rows = await contentModel.listPages();
    res.json({ pages: rows.map(contentModel.pageToPublic) });
  })
);

router.put(
  '/content-pages/:pageKey',
  asyncHandler(async (req, res) => {
    if (!contentModel.PAGE_KEYS.includes(req.params.pageKey)) {
      return res.status(404).json({ error: 'Unknown content page.' });
    }
    const { title, body } = req.body || {};
    const row = await contentModel.updatePage(req.params.pageKey, { title, body });
    await logAction(req, { action: 'content_page_updated', targetType: 'app_content_page', targetId: req.params.pageKey, detail: row.title });
    res.json(contentModel.pageToPublic(row));
  })
);

// ── Admin Accounts ──────────────────────────────────────────────────────

router.get(
  '/admins',
  asyncHandler(async (req, res) => {
    const rows = await adminAccountsModel.list();
    res.json({ admins: rows.map(adminAccountsModel.toPublic) });
  })
);

router.post(
  '/admins',
  asyncHandler(async (req, res) => {
    const { fullName, email, phone, password } = req.body || {};
    if (!fullName || !String(fullName).trim()) return res.status(400).json({ error: 'fullName is required.' });
    if (!email || !EMAIL_RE.test(String(email).trim())) {
      return res.status(400).json({ error: 'A valid email is required.' });
    }
    if (!password || String(password).length < 6) {
      return res.status(400).json({ error: 'password must be at least 6 characters.' });
    }
    const existing = await usersModel.findByEmail(String(email).trim());
    if (existing) return res.status(409).json({ error: 'An account with this email already exists.' });

    const passwordHash = await bcrypt.hash(String(password), BCRYPT_ROUNDS);
    const row = await adminAccountsModel.createAdmin({
      fullName: String(fullName).trim(),
      email: String(email).trim(),
      passwordHash,
      phone,
    });
    await logAction(req, { action: 'admin_invited', targetType: 'user', targetId: row.id, detail: row.email });
    res.status(201).json(adminAccountsModel.toPublic(row));
  })
);

router.delete(
  '/admins/:id',
  asyncHandler(async (req, res) => {
    if (req.params.id === req.user.id) {
      return res.status(403).json({ error: "You can't revoke your own admin access." });
    }
    const row = await adminAccountsModel.revoke(req.params.id);
    if (!row) return res.status(404).json({ error: 'Admin account not found.' });
    await logAction(req, { action: 'admin_revoked', targetType: 'user', targetId: row.id, detail: row.email });
    res.json({ ok: true });
  })
);

// ── General settings ────────────────────────────────────────────────────

router.get(
  '/general',
  asyncHandler(async (req, res) => {
    const row = await generalModel.get();
    res.json(generalModel.toPublic(row));
  })
);

router.patch(
  '/general',
  asyncHandler(async (req, res) => {
    const { appName, logoUrl, supportEmail, supportPhone } = req.body || {};
    const row = await generalModel.update({ appName, logoUrl, supportEmail, supportPhone });
    await logAction(req, { action: 'general_settings_updated', targetType: 'general_settings', targetId: 'general' });
    res.json(generalModel.toPublic(row));
  })
);

// ── Membership Pricing ──────────────────────────────────────────────────

router.get(
  '/membership-pricing',
  asyncHandler(async (req, res) => {
    const pricing = await membershipPricingModel.getAll();
    res.json(pricing);
  })
);

router.patch(
  '/membership-pricing/:role/:tier',
  asyncHandler(async (req, res) => {
    const { role, tier } = req.params;
    const { monthlyFeeEtb } = req.body || {};
    
    if (!['agent', 'affiliate'].includes(role)) {
      return res.status(400).json({ error: 'role must be "agent" or "affiliate".' });
    }
    if (!['bronze', 'silver', 'gold', 'diamond'].includes(tier)) {
      return res.status(400).json({ error: 'tier must be bronze, silver, gold, or diamond.' });
    }
    if (monthlyFeeEtb === undefined || !Number.isFinite(monthlyFeeEtb) || monthlyFeeEtb < 0) {
      return res.status(400).json({ error: 'monthlyFeeEtb must be a non-negative number.' });
    }

    const row = await membershipPricingModel.updateTierPrice(role, tier, monthlyFeeEtb);
    await logAction(req, {
      action: 'membership_pricing_updated',
      targetType: 'membership_pricing',
      targetId: `${role}_${tier}`,
      detail: `${role} ${tier}: ${monthlyFeeEtb} ETB`,
    });
    res.json(row);
  })
);

// ── Investor Membership Plan ─────────────────────────────────────────────

router.get(
  '/investor-membership-plan',
  asyncHandler(async (req, res) => {
    const row = await investorMembershipPlanModel.get();
    res.json(investorMembershipPlanModel.toPublic(row));
  })
);

router.put(
  '/investor-membership-plan',
  asyncHandler(async (req, res) => {
    const { title, description, priceEtb, benefits, footerNote, tierKey } = req.body || {};

    if (title !== undefined && !String(title).trim()) {
      return res.status(400).json({ error: 'title cannot be empty.' });
    }
    if (priceEtb !== undefined && (!Number.isFinite(priceEtb) || priceEtb < 0)) {
      return res.status(400).json({ error: 'priceEtb must be a non-negative number.' });
    }
    if (benefits !== undefined) {
      if (!Array.isArray(benefits) || benefits.some((b) => typeof b !== 'string')) {
        return res.status(400).json({ error: 'benefits must be an array of strings.' });
      }
    }

    const row = await investorMembershipPlanModel.update({
      title: title !== undefined ? String(title).trim() : undefined,
      description: description !== undefined ? String(description).trim() : undefined,
      priceEtb,
      benefits,
      footerNote: footerNote !== undefined ? String(footerNote).trim() : undefined,
      tierKey,
    });
    await logAction(req, {
      action: 'investor_membership_plan_updated',
      targetType: 'investor_membership_plan',
      targetId: 'investor_shareholder',
    });
    res.json(investorMembershipPlanModel.toPublic(row));
  })
);

module.exports = { router };
