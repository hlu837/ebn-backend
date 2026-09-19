const { query } = require('../db');

/**
 * Sell-request funnel counts by status, plus a conversion rate. "Converted"
 * here means reached `listed` (the terminal success state — see
 * models/sellRequests.js's status comments); `submission_rejected` and
 * `report_rejected` are terminal failures; everything else is still
 * in-flight (open_to_brokers/broadcasting/claimed/report_pending_approval).
 */
async function sellRequestFunnel() {
  const { rows } = await query(
    `SELECT status, COUNT(*)::int AS count FROM sell_requests GROUP BY status`
  );
  const byStatus = Object.fromEntries(rows.map((r) => [r.status, r.count]));
  const total = rows.reduce((sum, r) => sum + r.count, 0);
  const listed = byStatus.listed || 0;
  const rejected = (byStatus.submission_rejected || 0) + (byStatus.report_rejected || 0);
  const inProgress = total - listed - rejected;
  return {
    total,
    listed,
    rejected,
    inProgress,
    conversionRatePercent: total ? Math.round((listed / total) * 1000) / 10 : 0,
  };
}

/**
 * Order-request funnel counts by status, plus a conversion rate.
 * "Converted" means reached `closed` — the only terminal state order
 * requests have (see models/orderRequests.js); `disputed` also counts as
 * a temporary failure state (it can be reposted back into `broadcasting`),
 * so it's not counted as a hard rejection the way sell-request rejections
 * are.
 */
async function orderRequestFunnel() {
  const { rows } = await query(
    `SELECT status, COUNT(*)::int AS count FROM order_requests GROUP BY status`
  );
  const byStatus = Object.fromEntries(rows.map((r) => [r.status, r.count]));
  const total = rows.reduce((sum, r) => sum + r.count, 0);
  const closed = byStatus.closed || 0;
  return {
    total,
    closed,
    disputed: byStatus.disputed || 0,
    inProgress: total - closed - (byStatus.disputed || 0),
    conversionRatePercent: total ? Math.round((closed / total) * 1000) / 10 : 0,
  };
}

/** Current live catalog composition — active listings grouped by category. */
async function listingsByCategory() {
  const { rows } = await query(
    `SELECT category_slug, COUNT(*)::int AS count
     FROM assets
     WHERE status = 'active'::asset_status
     GROUP BY category_slug
     ORDER BY count DESC`
  );
  return rows.map((r) => ({ category: r.category_slug, count: r.count }));
}

/**
 * Sell-request submission volume per day, last 7 days (inclusive of
 * today). Zero-filled so the frontend bar chart doesn't have to guess
 * which days are missing.
 */
async function dailySubmissionVolume() {
  const { rows } = await query(
    `SELECT date_trunc('day', created_at) AS day, COUNT(*)::int AS count
     FROM sell_requests
     WHERE created_at >= now() - interval '6 days'
     GROUP BY day`
  );
  const byDay = new Map(rows.map((r) => [r.day.toISOString().slice(0, 10), r.count]));
  const out = [];
  for (let i = 6; i >= 0; i -= 1) {
    const d = new Date();
    d.setUTCHours(0, 0, 0, 0);
    d.setUTCDate(d.getUTCDate() - i);
    const key = d.toISOString().slice(0, 10);
    out.push({ date: key, count: byDay.get(key) || 0 });
  }
  return out;
}

/** Everything the admin Reports screen needs, in one call. */
async function overview() {
  const [sellRequests, orderRequests, byCategory, dailyVolume] = await Promise.all([
    sellRequestFunnel(),
    orderRequestFunnel(),
    listingsByCategory(),
    dailySubmissionVolume(),
  ]);
  return { sellRequests, orderRequests, listingsByCategory: byCategory, dailyVolume };
}

module.exports = { sellRequestFunnel, orderRequestFunnel, listingsByCategory, dailySubmissionVolume, overview };
