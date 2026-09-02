const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const model = require('../models/users');
const settingsModel = require('../models/visitorSettings');
const affiliatesModel = require('../models/affiliates');
const agentNetworkModel = require('../models/agentNetwork');
const investorNetworkModel = require('../models/investorNetwork');
const paymentsModel = require('../models/payments');

const router = express.Router();

const JWT_SECRET = process.env.JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '30d';
const BCRYPT_ROUNDS = 10;

const VALID_ROLES = ['user', 'affiliater', 'agent', 'investor', 'admin'];
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function asyncHandler(fn) {
  return (req, res, next) => fn(req, res, next).catch(next);
}

function signToken(user) {
  return jwt.sign({ sub: user.id, role: user.role }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

/**
 * Verifies the Bearer token on the request and loads the current user onto
 * req.user (public shape). 401s on anything wrong — missing header, bad
 * token, or a user that no longer exists.
 */
const requireAuth = asyncHandler(async (req, res, next) => {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Missing or malformed Authorization header.' });
  }
  let payload;
  try {
    payload = jwt.verify(token, JWT_SECRET);
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token.' });
  }
  const row = await model.findById(payload.sub);
  if (!row) return res.status(401).json({ error: 'User no longer exists.' });
  req.user = model.toPublic(row);
  next();
});

// POST /api/auth/signup
// Registers a new account and immediately signs it in (returns a token).
router.post(
  '/signup',
  asyncHandler(async (req, res) => {
    const {
      fullName,
      email,
      password,
      role,
      phone,
      agencyOrLicense,
      interestedInFractionalInvesting,
      referralCode,
      agentReferralCode,
      investorReferralCode,
      requestedRole,
    } = req.body || {};

    if (!fullName || !String(fullName).trim()) {
      return res.status(400).json({ error: 'fullName is required.' });
    }
    if (!email || !EMAIL_RE.test(String(email).trim())) {
      return res.status(400).json({ error: 'A valid email is required.' });
    }
    if (!password || String(password).length < 6) {
      return res.status(400).json({ error: 'password must be at least 6 characters.' });
    }
    const normalizedRole = role && VALID_ROLES.includes(role) ? role : 'user';
    const pendingRole = requestedRole && ['agent', 'investor'].includes(requestedRole)
      ? requestedRole
      : null;

    if (normalizedRole === 'agent' || normalizedRole === 'investor') {
      return res.status(400).json({
        error: 'Paid roles must be submitted as requestedRole and activated after payment or admin approval.',
      });
    }

    if (normalizedRole === 'admin') {
      return res.status(400).json({
        error: 'Admin accounts cannot be self-registered. They are provisioned by the team.',
      });
    }

    const existing = await model.findByEmail(String(email).trim());
    if (existing) {
      if (existing.pending_role || existing.account_status === 'pending_payment') {
        return res.status(409).json({
          error: 'An account with this email is pending payment confirmation. Please sign in to complete payment.',
          accountStatus: 'pending_payment',
          pendingRole: existing.pending_role || 'agent',
          user: model.toPublic(existing),
        });
      }
      return res.status(409).json({ error: 'An account with this email already exists.' });
    }

    if (requestedRole && ['agent', 'investor'].includes(requestedRole)) {
      const passwordHash = await bcrypt.hash(String(password), BCRYPT_ROUNDS);
      const row = await model.createPending({
        fullName: String(fullName).trim(),
        email: String(email).trim(),
        passwordHash,
        pendingRole: requestedRole,
        phone: phone ? String(phone).trim() : null,
        agencyOrLicense: agencyOrLicense ? String(agencyOrLicense).trim() : null,
        interestedInFractionalInvesting: Boolean(interestedInFractionalInvesting),
        referralCode: referralCode ? String(referralCode).trim() : null,
      });

      // Guard: if the DB insert returned nothing (schema mismatch, constraint
      // error swallowed by the driver, etc.) surface a hard 500 immediately
      // rather than silently falling through to model.create() below and
      // creating a fully-active visitor account instead of a pending one.
      if (!row) {
        console.error('[auth/signup] createPending returned no row — possible DB schema mismatch');
        return res.status(500).json({ error: 'Failed to create pending account. Please try again.' });
      }

      const user = model.toPublic(row);

      return res.status(200).json({
        isPendingPayment: true,
        user,
        token: signToken(user),
        pendingUserData: {
          fullName: String(fullName).trim(),
          email: String(email).trim(),
          password: String(password),
          role: requestedRole,
          phone: phone ? String(phone).trim() : null,
          agencyOrLicense: agencyOrLicense ? String(agencyOrLicense).trim() : null,
          interestedInFractionalInvesting: Boolean(interestedInFractionalInvesting),
          referralCode: referralCode ? String(referralCode).trim() : null,
          agentReferralCode: agentReferralCode ? String(agentReferralCode).trim() : null,
          investorReferralCode: investorReferralCode ? String(investorReferralCode).trim() : null,
        }
      });
    }

    const passwordHash = await bcrypt.hash(String(password), BCRYPT_ROUNDS);

    const row = await model.create({
      fullName: String(fullName).trim(),
      email: String(email).trim(),
      passwordHash,
      role: normalizedRole,
      phone: phone ? String(phone).trim() : null,
      agencyOrLicense: agencyOrLicense ? String(agencyOrLicense).trim() : null,
      interestedInFractionalInvesting: Boolean(interestedInFractionalInvesting),
      referralCode: referralCode ? String(referralCode).trim() : null,
      pendingRole: null,
    });

    const user = model.toPublic(row);

    // If a referral code was supplied and it matches an existing
    // affiliate's shareable code, credit that affiliate with their signup
    // bonus tokens and notify them — "someone registered using your
    // referral link" (see affiliatesModel.creditSignupTokens). Best-effort:
    // never let this block or fail the signup response itself.
    if (user.referralCode) {
      try {
        const affiliateId = await affiliatesModel.findUserIdByCode(user.referralCode);
        if (affiliateId && affiliateId !== user.id) {
          await affiliatesModel.creditSignupTokens({
            affiliateId,
            referredUserId: user.id,
            referredUserName: user.fullName,
          });
        }
      } catch (err) {
        // eslint-disable-next-line no-console
        console.error('[auth] failed to credit affiliate signup tokens', err);
      }
    }

    res.status(201).json({ user, token: signToken(user) });
  })
);

// POST /api/auth/signin
// Plain email + password login. Looks up the account's saved role and
// returns it so the client's smart router can send them to the right
// workspace — same contract MockAuthService.login() had.
router.post(
  '/signin',
  asyncHandler(async (req, res) => {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ error: 'email and password are required.' });
    }

    const row = await model.findByEmail(String(email).trim());
    if (!row) {
      const pendingPayment = await paymentsModel.findPendingByEmail(String(email).trim());
      if (pendingPayment?.pending_user_payload) {
        const payload = typeof pendingPayment.pending_user_payload === 'string'
          ? JSON.parse(pendingPayment.pending_user_payload)
          : pendingPayment.pending_user_payload;
        if (payload.password === String(password)) {
          const pendingRole = pendingPayment.purpose.startsWith('agent_') ? 'agent' : 'investor';
          const pendingUser = {
            id: '',
            fullName: payload.fullName,
            email: payload.email,
            role: 'user',
            phone: payload.phone || null,
            agencyOrLicense: payload.agencyOrLicense || null,
            interestedInFractionalInvesting: Boolean(payload.interestedInFractionalInvesting),
            referralCode: payload.referralCode || null,
            accountStatus: 'pending_payment',
            pendingRole,
          };
          return res.status(403).json({
            error: 'Your registration is waiting for payment confirmation.',
            accountStatus: 'pending_payment',
            pendingRole,
            pendingUserPayload: payload,
            user: pendingUser,
          });
        }
      }
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const matches = await bcrypt.compare(String(password), row.password_hash);
    if (!matches) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    if ((row.account_status && row.account_status !== 'active') || row.pending_role) {
      const publicUser = model.toPublic(row);
      const status = (row.account_status && row.account_status !== 'active') ? row.account_status : 'pending_payment';
      const pendingRole = row.pending_role || 'agent';
      return res.status(403).json({
        error: status === 'pending_payment'
          ? 'Your registration is waiting for payment confirmation.'
          : 'Your registration is waiting for admin approval.',
        accountStatus: status,
        pendingRole: pendingRole,
        user: publicUser,
        token: signToken(publicUser),
      });
    }

    const user = model.toPublic(row);
    res.json({ user, token: signToken(user) });
  })
);

// GET /api/auth/me
// Returns the caller's own profile, resolved from the Bearer token —
// lets the client restore a session on app restart without re-prompting.
router.get(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    res.json({ user: req.user });
  })
);

// PATCH /api/auth/me/location
// Agent-only — records the agent's current position so order requests can
// be broadcast to whoever's nearby. Requires the agent's own token (rather
// than trusting a body-supplied id) since this writes to their profile.
//
// Also doubles as the "go offline" endpoint: passing { latitude: null,
// longitude: null } clears the agent's location, which is what the
// dashboard's online/offline switch does when turned off. findNearbyAgents
// only ever matches agents with a non-null location, so clearing it is
// enough to stop new requests being broadcast to this agent — there's no
// separate "is_online" flag in the schema, location presence *is* the
// online signal.
router.patch(
  '/me/location',
  requireAuth,
  asyncHandler(async (req, res) => {
    if (req.user.role !== 'agent') {
      return res.status(403).json({ error: 'Only agent accounts have a location to set.' });
    }
    const { latitude, longitude } = req.body || {};
    const bothNumbers = typeof latitude === 'number' && typeof longitude === 'number';
    const bothNull = latitude === null && longitude === null;
    if (!bothNumbers && !bothNull) {
      return res.status(400).json({
        error: 'latitude and longitude must either both be numbers (going online) or both be null (going offline).',
      });
    }
    const row = await model.setAgentLocation(req.user.id, { latitude, longitude });
    if (!row) return res.status(404).json({ error: 'Agent not found.' });
    res.json({ user: model.toPublic(row) });
  })
);

// PATCH /api/auth/me
// Updates the caller's own name/phone (Settings screen "Account details").
// Email is not editable here — see users.updateProfile for why.
router.patch(
  '/me',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { fullName, phone } = req.body || {};
    if (fullName !== undefined && !String(fullName).trim()) {
      return res.status(400).json({ error: 'fullName cannot be empty.' });
    }
    const row = await model.updateProfile(req.user.id, {
      fullName: fullName !== undefined ? String(fullName).trim() : undefined,
      phone: phone !== undefined ? String(phone).trim() : undefined,
    });
    res.json({ user: model.toPublic(row) });
  })
);

// POST /api/auth/me/change-password
// Body: { currentPassword, newPassword }
router.post(
  '/me/change-password',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { currentPassword, newPassword } = req.body || {};
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'currentPassword and newPassword are required.' });
    }
    if (String(newPassword).length < 6) {
      return res.status(400).json({ error: 'newPassword must be at least 6 characters.' });
    }
    const row = await model.findById(req.user.id);
    const matches = await bcrypt.compare(String(currentPassword), row.password_hash);
    if (!matches) {
      return res.status(401).json({ error: 'Current password is incorrect.' });
    }
    const newHash = await bcrypt.hash(String(newPassword), BCRYPT_ROUNDS);
    await model.updatePasswordHash(req.user.id, newHash);
    res.json({ ok: true });
  })
);

// GET /api/auth/me/settings
// Notification preferences + app language for the signed-in user's own
// "Account & Settings" screen — mirrors /api/agents/:agentId/settings but
// self-scoped via the token (no id in the URL) since every role, not just
// agents, has one of these. Row is created lazily on first access.
router.get(
  '/me/settings',
  requireAuth,
  asyncHandler(async (req, res) => {
    const row = await settingsModel.getOrCreate(req.user.id);
    res.json(settingsModel.toPublic(row));
  })
);

// PATCH /api/auth/me/settings
// Body: any of notifyRequestUpdates, notifyChatMessages, notifyPriceDrops,
// notifyPromotions (booleans), language ('english' | 'amharic').
router.patch(
  '/me/settings',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { notifyRequestUpdates, notifyChatMessages, notifyPriceDrops, notifyPromotions, language } =
      req.body || {};
    if (language !== undefined && !['english', 'amharic'].includes(language)) {
      return res.status(400).json({ error: "language must be 'english' or 'amharic'." });
    }
    for (const [key, val] of Object.entries({
      notifyRequestUpdates,
      notifyChatMessages,
      notifyPriceDrops,
      notifyPromotions,
    })) {
      if (val !== undefined && typeof val !== 'boolean') {
        return res.status(400).json({ error: `${key} must be a boolean.` });
      }
    }
    const row = await settingsModel.update(req.user.id, {
      notifyRequestUpdates,
      notifyChatMessages,
      notifyPriceDrops,
      notifyPromotions,
      language,
    });
    res.json(settingsModel.toPublic(row));
  })
);

module.exports = { router, requireAuth };
