const express = require('express');
const crypto = require('crypto');
const model = require('../models/payments');
const usersModel = require('../models/users');

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

function chapaCallbackUrl() {
  const configured = process.env.CHAPA_CALLBACK_URL;
  if (configured && !configured.includes('example.com')) return configured;
  return process.env.VERCEL_URL
    ? `https://${process.env.VERCEL_URL}/api/payments/chapa/webhook`
    : undefined;
}

const { query } = require('../db');

const bcrypt = require('bcryptjs');
const affiliatesModel = require('../models/affiliates');
const agentNetworkModel = require('../models/agentNetwork');
const investorNetworkModel = require('../models/investorNetwork');

async function activatePaidSignup(payment) {
  if (payment.status !== 'success') return;
  const isAgent = payment.purpose.startsWith('agent_');
  const isInvestor = payment.purpose.startsWith('investor_');
  const role = isAgent ? 'agent' : isInvestor ? 'investor' : null;
  if (!role) return;

  let userId = payment.owner_user_id;
  let payload;
  if (payment.pending_user_payload) {
    payload = typeof payment.pending_user_payload === 'string'
      ? JSON.parse(payment.pending_user_payload)
      : payment.pending_user_payload;
  }

  // The payment may have been created before the pending user ID was known,
  // or may contain a stale owner ID from a previous client session. Resolve
  // the account by ID first and fall back to the email in the saved payload.
  let existing = userId ? await usersModel.findById(userId) : null;
  if (!existing && payload?.email) {
    existing = await usersModel.findByEmail(payload.email);
  }

  if (existing) {
    userId = existing.id;
    if (existing.role !== role) {
      const activated = await usersModel.activatePendingRole(userId, role);
      if (!activated) {
        console.error('[payments] payment succeeded but pending role activation matched no eligible user', {
          userId,
          role,
          accountStatus: existing.account_status,
          pendingRole: existing.pending_role,
        });
        return;
      }
    }
  } else if (payload) {
      const passwordHash = await bcrypt.hash(payload.password, 10);
      const newUser = await usersModel.create({
        fullName: payload.fullName,
        email: payload.email,
        passwordHash,
        role: role,
        phone: payload.phone,
        agencyOrLicense: payload.agencyOrLicense,
        interestedInFractionalInvesting: payload.interestedInFractionalInvesting,
        referralCode: payload.referralCode,
      });
      userId = newUser.id;

      if (payload.referralCode) {
        try {
          const affiliateId = await affiliatesModel.findUserIdByCode(payload.referralCode);
          if (affiliateId && affiliateId !== userId) {
            await affiliatesModel.creditSignupTokens({
              affiliateId,
              referredUserId: userId,
              referredUserName: newUser.full_name,
            });
          }
        } catch (e) {
          console.error('[payments] failed to credit affiliate signup tokens', e);
        }
      }

      if (role === 'agent' && payload.agentReferralCode) {
        try {
          const sponsorId = await agentNetworkModel.findAgentIdByCode(payload.agentReferralCode);
          if (sponsorId && sponsorId !== userId) {
            await agentNetworkModel.setSponsor(userId, sponsorId);
          }
        } catch (e) {
          console.error('[payments] failed to link agent sponsor', e);
        }
      }

      if (role === 'investor' && payload.investorReferralCode) {
        try {
          const sponsorId = await investorNetworkModel.findInvestorIdByCode(payload.investorReferralCode);
          if (sponsorId && sponsorId !== userId) {
            await investorNetworkModel.setSponsor(userId, sponsorId);
          }
        } catch (e) {
          console.error('[payments] failed to link investor sponsor', e);
        }
      }
  }

  if (!userId) return;

  if (isAgent) {
    let tier = 'bronze';
    if (payment.purpose.includes('silver')) tier = 'silver';
    else if (payment.purpose.includes('gold')) tier = 'gold';

    try {
      await query(
        `INSERT INTO agent_memberships (user_id, tier, renewal_date)
         VALUES ($1, $2, CURRENT_DATE + INTERVAL '30 days')
         ON CONFLICT (user_id) DO UPDATE
         SET tier = EXCLUDED.tier, renewal_date = CURRENT_DATE + INTERVAL '30 days', updated_at = now()`,
        [userId, tier]
      );

      const billingLabel = `Agent Membership (${tier.toUpperCase()})`;
      const existing = await query(
        `SELECT 1 FROM agent_membership_billing
         WHERE user_id = $1 AND label = $2 AND amount = $3 AND status = 'paid'
           AND billed_on = CURRENT_DATE
         LIMIT 1`,
        [userId, billingLabel, payment.amount || 0]
      );

      if (!existing.rows[0]) {
        await query(
          `INSERT INTO agent_membership_billing (user_id, label, amount, status, billed_on)
           VALUES ($1, $2, $3, 'paid', CURRENT_DATE)`,
          [userId, billingLabel, payment.amount || 0]
        );
      }
    } catch (err) {
      console.error('[payments] failed to update agent_memberships table:', err);
    }
  }
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

    let customerEmail = String(body.email).trim();
    if (!customerEmail.includes('@') || !customerEmail.includes('.')) {
      customerEmail = 'customer@ebn.et';
    }

    const chapaPayload = {
      amount: String(amount),
      currency: body.currency || 'ETB',
      email: customerEmail,
      first_name: body.firstName || undefined,
      last_name: body.lastName || undefined,
      tx_ref: txRef,
      callback_url: chapaCallbackUrl(),
      return_url: process.env.CHAPA_RETURN_URL || undefined,
      customization: {
        title: 'EBN Membership',
        description: String(body.description || 'EBN Membership Fee')
          .replace(/[^a-zA-Z0-9\-_ .]/g, ' ')  // strip chars Chapa disallows
          .replace(/\s+/g, ' ')                  // collapse multiple spaces
          .trim()
          .slice(0, 60),
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
      pendingUserPayload: body.pendingUserPayload,
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
    await activatePaidSignup(updated);

    res.json(model.toPublic(updated));
  })
);

// Chapa server-to-server callback. The payment is still verified against
// Chapa before a pending agent/investor account is activated.
router.post(
  '/chapa/webhook',
  asyncHandler(async (req, res) => {
    const txRef = req.body?.tx_ref || req.body?.trx_ref || req.body?.data?.tx_ref;
    if (!txRef) return res.status(400).json({ error: 'tx_ref is required.' });
    const local = await model.findByTxRef(String(txRef));
    if (!local) return res.status(404).json({ error: 'Unknown payment reference.' });

    const secretKey = requireChapaSecretKey(res);
    if (!secretKey) return;
    const chapaRes = await fetch(`${CHAPA_BASE_URL}/transaction/verify/${encodeURIComponent(txRef)}`, {
      headers: { Authorization: `Bearer ${secretKey}` },
    });
    const chapaJson = await chapaRes.json().catch(() => null);
    const nextStatus = chapaJson?.data?.status === 'success' ? 'success' : 'failed';
    const updated = await model.markStatus(txRef, nextStatus, chapaJson);
    await activatePaidSignup(updated);
    res.json({ received: true, status: updated.status });
  })
);

module.exports = { router };
