// Automated payout schedule for confirmed investment commitments — this
// is what makes "get paid based on the investment agreement" actually
// automatic, rather than an admin manually typing in a payout amount
// (see AdminConfirmedInvestmentsScreen for that manual path, which still
// exists for one-off/ad-hoc credits and still works fine alongside this).
//
// The agreement is simple and entirely derived from fields that already
// exist on the opportunity + commitment — no new "plan" concept needed:
//   - the opportunity's expected_return_pct is the *total* return over
//     the whole term, split evenly across term_months monthly payouts
//   - the final (term_months-th) payout also returns the principal
//     (the original commitment amount), which is when the commitment
//     "matures" and the scheduler stops touching it
//
// Runs as a periodic sweep (see runDuePayouts, wired up in server.js) that
// re-reads state from Postgres every time — same restart-safe idea as
// scheduler.js's rearmPendingExpiries, just on a monthly timescale where a
// sweep is a better fit than a single long-lived setTimeout per commitment
// (Node's setTimeout can't reliably wait months at a time).

const commitmentsModel = require('./investmentCommitments');
const walletModel = require('./investorWallet');
const notificationsModel = require('./notifications');
const { broadcastNotification } = require('../socket');

/** How often the sweep re-checks every open commitment for a due payout. */
const SWEEP_INTERVAL_MS = 60 * 60 * 1000; // hourly — cheap, and payouts are only ever monthly at the soonest

function addMonths(date, months) {
  const d = new Date(date);
  d.setUTCMonth(d.getUTCMonth() + months);
  return d;
}

/**
 * Splits the opportunity's total expected return across term_months
 * equal monthly payouts, folding any rounding remainder into the last
 * one so the sum always exactly equals the agreed total — never more,
 * never less than what expected_return_pct promises.
 */
function computeSchedule({ amount, expectedReturnPct, termMonths }) {
  const totalInterest = Math.round(amount * (expectedReturnPct / 100) * 100) / 100;
  const perPeriod = Math.round((totalInterest / termMonths) * 100) / 100;
  const lastPeriodInterest = Math.round((totalInterest - perPeriod * (termMonths - 1)) * 100) / 100;
  return { perPeriod, lastPeriodInterest, totalInterest };
}

/**
 * How many monthly periods have elapsed since confirmation, clamped to
 * the term — e.g. 3.4 months elapsed on a 12-month term returns 3, and
 * 14 months elapsed on the same term returns 12 (the term is over).
 */
function elapsedPeriods({ decidedAt, termMonths }) {
  if (!decidedAt) return 0;
  let count = 0;
  while (count < termMonths && addMonths(decidedAt, count + 1).getTime() <= Date.now()) {
    count += 1;
  }
  return count;
}

/**
 * The core sweep: for every Confirmed, not-yet-matured commitment, credit
 * any payout period(s) that have come due since the last run — one period
 * at a time so a crash mid-loop can only under-count (safe to re-run on
 * the next sweep) rather than double-pay. Best-effort per commitment: one
 * commitment failing doesn't stop the rest from being processed.
 */
async function runDuePayouts() {
  let commitments;
  try {
    commitments = await commitmentsModel.listConfirmedForScheduling();
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[investmentPayoutScheduler] failed to load commitments due for payout', err);
    return;
  }

  for (const row of commitments) {
    try {
      await processCommitment(row);
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(`[investmentPayoutScheduler] failed to process commitment ${row.id}`, err);
    }
  }
}

async function processCommitment(row) {
  const termMonths = Number(row.term_months);
  const amount = Number(row.amount);
  const expectedReturnPct = Number(row.expected_return_pct);
  if (!termMonths || termMonths <= 0) return; // malformed opportunity data — skip rather than throw

  const due = elapsedPeriods({ decidedAt: row.decided_at, termMonths });
  const alreadyPaid = Number(row.payouts_made) || 0;
  if (due <= alreadyPaid) return; // nothing due yet

  const { perPeriod, lastPeriodInterest } = computeSchedule({ amount, expectedReturnPct, termMonths });

  // Credit one period at a time, persisting progress after each so a
  // mid-loop crash never re-pays a period already recorded.
  for (let period = alreadyPaid + 1; period <= due; period += 1) {
    const isFinalPeriod = period === termMonths;
    const interest = isFinalPeriod ? lastPeriodInterest : perPeriod;
    const payoutAmount = isFinalPeriod ? interest + amount : interest;
    const label = isFinalPeriod
      ? `Final return + principal — "${row.opportunity_title}" (month ${period} of ${termMonths})`
      : `Monthly return — "${row.opportunity_title}" (month ${period} of ${termMonths})`;

    const tx = await walletModel.addPayout(row.user_id, {
      amount: payoutAmount,
      label,
      status: 'cleared',
      commitmentId: row.id,
    });

    await commitmentsModel.recordScheduledPayout(row.id, { matured: isFinalPeriod });

    try {
      const notifRow = await notificationsModel.create({
        recipientType: 'investor',
        recipientId: row.user_id,
        kind: 'payout',
        title: isFinalPeriod ? 'Investment matured — final payout sent' : 'Payout credited',
        body: `${label} — ETB ${payoutAmount.toLocaleString('en-US')} was credited to your wallet.`,
        relatedId: tx.id,
      });
      broadcastNotification('investor', row.user_id, notificationsModel.toPublic(notifRow));
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(`[investmentPayoutScheduler] failed to notify investor ${row.user_id} of scheduled payout`, err);
    }
  }
}

/** Starts the periodic sweep — call once at server boot. */
function start() {
  runDuePayouts().catch((err) => {
    // eslint-disable-next-line no-console
    console.error('[investmentPayoutScheduler] initial sweep failed', err);
  });
  return setInterval(() => {
    runDuePayouts().catch((err) => {
      // eslint-disable-next-line no-console
      console.error('[investmentPayoutScheduler] scheduled sweep failed', err);
    });
  }, SWEEP_INTERVAL_MS);
}

module.exports = { start, runDuePayouts, computeSchedule, elapsedPeriods, SWEEP_INTERVAL_MS };
