/**
 * A single endpoint a scheduler (Vercel Cron, or any external cron
 * service) can hit periodically to do the work that scheduler.js's
 * in-memory setTimeout timers do on a normal, always-running Node
 * process. On a serverless host, nothing keeps that process alive
 * between requests, so a setTimeout scheduled for hours or days from
 * now simply never fires — this sweep re-derives "what's due right
 * now" straight from Postgres every time it's called instead.
 *
 * IMPORTANT — read this before wiring this up as your only safety net:
 * rentalAgreements.runSweep() and investmentPayoutScheduler.runDuePayouts()
 * are genuinely fine to run on any cadence from every few minutes up to
 * once a day — their windows are measured in hours/days, so a sweep
 * that's an hour or so late barely matters. tourRequests dispatch is a
 * different story: its response window defaults to 30 SECONDS
 * (DISPATCH_WINDOW_SECONDS). No cron product — Vercel's included, even
 * on its fastest paid tier — runs sub-minute, so a dispatched tour
 * request that goes unanswered will NOT reliably fall through to the
 * next agent on a serverless deployment; see backend/README.md's
 * "Vercel deployment" section for what that means for you. This sweep
 * still expires those rows on whatever cadence it does run, as a
 * coarse safety net, but it is not a fix for that feature's real-time
 * requirement.
 *
 * Auth: this route requires the CRON_SECRET env var to be set — it is
 * NOT auto-provisioned by Vercel, contrary to what you may read
 * elsewhere. You must create it yourself (Project Settings > Environment
 * Variables > CRON_SECRET, any random string of 16+ chars). Once it's
 * set, Vercel automatically sends it back as
 * `Authorization: Bearer $CRON_SECRET` on every scheduled invocation
 * (see the `crons` entry in vercel.json) — this route just verifies
 * that header matches. Without it set, this route always returns 503
 * and the daily sweep silently never runs. Set CRON_SECRET yourself
 * the same way if triggering this from anywhere else (a GitHub Actions
 * schedule, cron-job.org, etc) — same header, same value.
 */
const express = require('express');
const rentalAgreementsModel = require('../models/rentalAgreements');
const tourRequestsModel = require('../models/tourRequests');
const investmentPayoutScheduler = require('../models/investmentPayoutScheduler');

const router = express.Router();

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

function requireCronSecret(req, res, next) {
  const secret = process.env.CRON_SECRET;
  if (!secret) {
    // Not configured — refuse rather than run unauthenticated on a
    // publicly reachable URL. Set CRON_SECRET to enable this route.
    return res.status(503).json({ error: 'CRON_SECRET is not configured.' });
  }
  const header = req.headers.authorization || '';
  if (header !== `Bearer ${secret}`) {
    return res.status(401).json({ error: 'Unauthorized.' });
  }
  next();
}

/**
 * GET /api/cron/sweep
 * Runs every due expiry/reminder/payout check once. Idempotent — see
 * the dedupe columns added in migration 091 and the status guards
 * already on expire()/tourRequests.expire() — so it's always safe to
 * trigger this again by hand (e.g. `curl -H "Authorization: Bearer
 * $CRON_SECRET" https://your-app.vercel.app/api/cron/sweep`) if you
 * suspect a scheduled run was missed.
 */
router.get(
  '/sweep',
  requireCronSecret,
  asyncHandler(async (req, res) => {
    const rental = await rentalAgreementsModel.runSweep();

    const dispatched = await tourRequestsModel.listDispatched();
    let tourRequestsExpired = 0;
    for (const request of dispatched) {
      if (request.expires_at && new Date(request.expires_at).getTime() <= Date.now()) {
        const result = await tourRequestsModel.expire(request.id);
        if (result) tourRequestsExpired += 1;
      }
    }

    let investmentPayoutsError = null;
    try {
      await investmentPayoutScheduler.runDuePayouts();
    } catch (err) {
      investmentPayoutsError = err.message;
      // eslint-disable-next-line no-console
      console.error('[cron/sweep] investment payout sweep failed', err);
    }

    res.json({
      ok: true,
      ranAt: new Date().toISOString(),
      rentalAgreements: rental,
      tourRequestsExpired,
      investmentPayoutsError,
    });
  })
);

module.exports = { router };
