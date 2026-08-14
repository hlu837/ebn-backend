const express = require('express');
const crypto = require('crypto');
const model = require('../models/payments');

const router = express.Router();

const CHAPA_BASE_URL = 'https://api.chapa.co/v1';

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

function requireChapaSecretKey(res) {
  const key = process.env.CHAPA_SECRET_KEY;
  if (!key) {
    res.status(503).json({ error: 'Payments are not configured on this server (missing CHAPA_SECRET_KEY).' });
    return null;
  }
  return key;
}

const REQUIRED_INIT_FIELDS = ['purpose', 'amount', 'email'];

// ── POST /api/payments/chapa/initialize ────────────────────────────────────
// Starts a Chapa checkout for `amount` ETB and returns the hosted checkout
// page the client should open. The client is expected to poll
// GET /:txRef/verify afterwards — Chapa's own webhook (`callback_url` below)
// isn't wired to anything in this build, since it can't reach a localhost
// backend anyway.
router.post(
  '/chapa/initialize',
  asyncHandler(async (req, res) => {
    const body = req.body || {};
    const missing = REQUIRED_INIT_FIELDS.filter((f) => body[f] === undefined || body[f] === null || body[f] === '');
    if (missing.length) {
      return res.status(400).json({ error: `Missing required field(s): ${missing.join(', ')}.` });
    }

    const secretKey = requireChapaSecretKey(res);
    if (!secretKey) return;
    const shortUuid = crypto.randomUUID().replace(/-/g, '').slice(0, 20);
    const txRef = `${String(body.purpose).slice(0, 10)}-${shortUuid}`; // max ~31 chars, well under Chapa's 50-char limit
    const amount = Number(body.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({ error: 'amount must be a positive number.' });
    }

    const chapaPayload = {
      amount: String(amount),
      currency: body.currency || 'ETB',
      email: body.email,
      first_name: body.firstName || undefined,
      last_name: body.lastName || undefined,
      tx_ref: txRef,
      callback_url: process.env.CHAPA_CALLBACK_URL || undefined,
      return_url: process.env.CHAPA_RETURN_URL || undefined,
      customization: {
        title: 'Onsite fee',
        description: String(body.description || 'Onsite listing fee').slice(0, 60),
      },
    };
    console.log('[chapa] sending payload:', JSON.stringify(chapaPayload));

    const chapaRes = await fetch(`${CHAPA_BASE_URL}/transaction/initialize`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secretKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(chapaPayload),
    });
    const chapaJson = await chapaRes.json().catch(() => null);
    console.log('[chapa] response status:', chapaRes.status, '| body:', JSON.stringify(chapaJson));

    if (!chapaRes.ok || !chapaJson || chapaJson.status !== 'success' || !chapaJson.data?.checkout_url) {
      const raw = chapaJson?.message;
      const detail = typeof raw === 'string' ? raw : raw ? JSON.stringify(raw) : `Chapa responded with ${chapaRes.status}.`;
      return res.status(502).json({ error: `Couldn't start the payment: ${detail}` });
    }

    const checkoutUrl = chapaJson.data.checkout_url;
    await model.create({
      txRef,
      purpose: body.purpose,
      ownerUserId: body.ownerUserId,
      amount,
      currency: body.currency || 'ETB',
      email: body.email,
      firstName: body.firstName,
      lastName: body.lastName,
      checkoutUrl,
    });

    res.status(201).json({ txRef, checkoutUrl });
  })
);

// ── GET /api/payments/chapa/:txRef/verify ───────────────────────────────
// Authoritative check — calls Chapa's own verify endpoint (never trusts a
// client-reported "I paid") and persists the result. Safe to call
// repeatedly; the client polls this after opening the checkout page.
router.get(
  '/chapa/:txRef/verify',
  asyncHandler(async (req, res) => {
    const { txRef } = req.params;
    const local = await model.findByTxRef(txRef);
    if (!local) {
      return res.status(404).json({ error: 'Unknown payment reference.' });
    }

    // Already settled — no need to re-hit Chapa.
    if (local.status !== 'pending') {
      return res.json(model.toPublic(local));
    }

    const secretKey = requireChapaSecretKey(res);
    if (!secretKey) return;
    const chapaRes = await fetch(`${CHAPA_BASE_URL}/transaction/verify/${encodeURIComponent(txRef)}`, {
      headers: { Authorization: `Bearer ${secretKey}` },
    });
    const chapaJson = await chapaRes.json().catch(() => null);

    if (!chapaRes.ok || !chapaJson) {
      return res.status(502).json({ error: "Couldn't reach Chapa to verify this payment. Try again shortly." });
    }

    const paymentStatus = chapaJson.data?.status; // 'success' | 'failed' | others
    const nextStatus = paymentStatus === 'success' ? 'success' : chapaJson.status === 'success' ? 'pending' : 'failed';
    const updated = await model.markStatus(txRef, nextStatus, chapaJson);

    res.json(model.toPublic(updated));
  })
);

module.exports = { router };
