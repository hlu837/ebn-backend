const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const express = require('express');
const cors = require('cors');

const { pool } = require('./db');
const { router: tourRequestsRouter, armExpiry } = require('./routes/tourRequests');
const { router: authRouter } = require('./routes/auth');
const { router: reportsRouter } = require('./routes/reports');
const { router: activityLogRouter } = require('./routes/activityLog');
const { router: sellRequestsRouter } = require('./routes/sellRequests');
const { router: orderRequestsRouter } = require('./routes/orderRequests');
const { router: paymentsRouter } = require('./routes/payments');
const { router: assetsRouter } = require('./routes/assets');
const { router: favoritesRouter } = require('./routes/favorites');
const { router: affiliatesRouter } = require('./routes/affiliates');
const { router: configRouter } = require('./routes/config');
const { router: agentsRouter } = require('./routes/agents');
const { router: supportTicketsRouter } = require('./routes/supportTickets');
const { router: agentTasksRouter } = require('./routes/agentTasks');
const { router: chatRouter } = require('./routes/chat');
const { router: notificationsRouter } = require('./routes/notifications');
const { router: roleUpgradeRequestsRouter } = require('./routes/roleUpgradeRequests');
const { router: announcementsRouter } = require('./routes/announcements');
const { router: companyAdsRouter } = require('./routes/companyAds');
const { router: investmentOpportunitiesRouter } = require('./routes/investmentOpportunities');
const { router: investmentCommitmentsRouter } = require('./routes/investmentCommitments');
const { router: investorWalletRouter } = require('./routes/investorWallet');
const { router: usersRouter } = require('./routes/users');
const { router: transactionsRouter } = require('./routes/transactions');
const { router: adminSettingsRouter } = require('./routes/adminSettings');
const { router: referralsRouter } = require('./routes/referrals');
const investmentPayoutScheduler = require('./models/investmentPayoutScheduler');

const PORT = Number(process.env.PORT || 4000);
const CORS_ORIGIN = process.env.CORS_ORIGIN || '*';

const app = express();
app.use(cors({ origin: CORS_ORIGIN === '*' ? true : CORS_ORIGIN.split(',').map((s) => s.trim()) }));
app.use(express.json({ limit: '50mb' }));

app.get('/', (req, res) => {
  res.json({ status: 'online', message: 'EBN API Server is running' });
});

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true, db: 'connected' });
  } catch (err) {
    res.status(503).json({ ok: false, db: 'unreachable', error: err.message });
  }
});

app.use('/api/auth', authRouter);
app.use('/api/reports', reportsRouter);
app.use('/api/activity-log', activityLogRouter);
app.use('/api/tour-requests', tourRequestsRouter);
app.use('/api/sell-requests', sellRequestsRouter);
app.use('/api/order-requests', orderRequestsRouter);
app.use('/api/payments', paymentsRouter);
app.use('/api/assets', assetsRouter);
app.use('/api/favorites', favoritesRouter);
app.use('/api/affiliates', affiliatesRouter);
app.use('/api/config', configRouter);
app.use('/api/agents', agentsRouter);
app.use('/api/support-tickets', supportTicketsRouter);
app.use('/api/agent-tasks', agentTasksRouter);
app.use('/api/chat', chatRouter);
app.use('/api/notifications', notificationsRouter);
app.use('/api/role-upgrade-requests', roleUpgradeRequestsRouter);
app.use('/api/announcements', announcementsRouter);
app.use('/api/company-ads', companyAdsRouter);
app.use('/api/investment-opportunities', investmentOpportunitiesRouter);
app.use('/api/investment-commitments', investmentCommitmentsRouter);
app.use('/api/investors', investorWalletRouter);
app.use('/api/users', usersRouter);
app.use('/api/transactions', transactionsRouter);
app.use('/api/admin-settings', adminSettingsRouter);
app.use('/api/referrals', referralsRouter);

app.use((err, req, res, next) => {
  console.error(err);
  const status = err.status || err.statusCode || 500;
  res.status(status).json({ error: err.message || 'Internal server error.' });
});

async function rearmPendingExpiries() {
  const dispatched = await require('./models/tourRequests').listDispatched();
  for (const request of dispatched) {
    armExpiry(request);
  }
  if (dispatched.length) {
    console.log(`[server] re-armed expiry timers for ${dispatched.length} dispatched request(s).`);
  }
}

module.exports = {
  app,
  PORT,
  CORS_ORIGIN,
  rearmPendingExpiries,
  investmentPayoutScheduler,
};
