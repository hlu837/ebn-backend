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
const { router: propertyRequestsRouter } = require('./routes/propertyRequests');
const { router: maintenanceRequestsRouter } = require('./routes/maintenanceRequests');
const { router: serviceProvidersRouter } = require('./routes/serviceProviders');
const { router: maintenanceAssignmentsRouter } = require('./routes/maintenanceAssignments');
const { router: ownerBankAccountsRouter } = require('./routes/ownerBankAccounts');
const {
  router: rentalAgreementsRouter,
  armExpiry: armRentalAgreementExpiry,
  armPaymentReminder: armRentalAgreementPaymentReminder,
  armLeaseReminders: armRentalAgreementLeaseReminders,
} = require('./routes/rentalAgreements');
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
const { router: cronRouter } = require('./routes/cron');
const investmentPayoutScheduler = require('./models/investmentPayoutScheduler');

const PORT = Number(process.env.PORT || 4000);
const IS_PRODUCTION = process.env.NODE_ENV === 'production';

// CORS_ORIGIN is a comma-separated allowlist of exact origins, e.g.
//   CORS_ORIGIN=https://app.example.com,https://admin.example.com
//
// In production this MUST be set to real origins. Reflecting every
// origin ('*' / unset) means any page a logged-in admin happens to be
// visiting can script authenticated calls against this API from their
// browser, which defeats the auth added to the mutating routes. So we
// fail closed at boot rather than silently starting wide open.
//
// Outside production, unset falls back to reflecting the caller's
// origin so local Flutter web / device testing keeps working.
const CORS_ORIGIN = (process.env.CORS_ORIGIN || '').trim();
const allowedOrigins = CORS_ORIGIN.split(',')
  .map((s) => s.trim())
  .filter(Boolean);

// NOTE: previously this threw and crashed the whole server at boot when
// CORS_ORIGIN wasn't set in production. That's the safer default for a
// browser-facing app, but it took the entire API down (including the
// mobile-only routes that don't rely on CORS at all) whenever the env var
// was missing. Now we just warn and fall back to a placeholder origin so
// the server still boots. Set CORS_ORIGIN in your host's environment
// variables to your real web origin(s) as soon as you have one — e.g.
// CORS_ORIGIN=https://app.example.com — to properly lock this down again.
if (IS_PRODUCTION && (allowedOrigins.length === 0 || allowedOrigins.includes('*'))) {
  console.warn(
    'CORS_ORIGIN is not set to an explicit origin list in production. ' +
      'Falling back to a placeholder origin (no real browser origin is allowed). ' +
      'Set CORS_ORIGIN=https://your-real-domain.com in your environment variables when you have one.'
  );
  allowedOrigins.length = 0;
  allowedOrigins.push('https://placeholder.invalid');
}

const corsOrigin = allowedOrigins.includes('*') ? true : allowedOrigins;

const app = express();
app.use(cors({ origin: corsOrigin, credentials: true }));
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
app.use('/api/property-requests', propertyRequestsRouter);
app.use('/api/rental-agreements', rentalAgreementsRouter);
app.use('/api/maintenance-requests', maintenanceRequestsRouter);
app.use('/api/service-providers', serviceProvidersRouter);
app.use('/api/maintenance-assignments', maintenanceAssignmentsRouter);
app.use('/api/owner-bank-accounts', ownerBankAccountsRouter);
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
app.use('/api/cron', cronRouter);

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

  const pendingAgreements = await require('./models/rentalAgreements').listActive();
  for (const agreement of pendingAgreements) {
    armRentalAgreementExpiry(agreement);
    armRentalAgreementPaymentReminder(agreement);
  }
  if (pendingAgreements.length) {
    console.log(`[server] re-armed payment countdowns for ${pendingAgreements.length} sent rental agreement(s).`);
  }

  const trackedLeases = await require('./models/rentalAgreements').listLeaseTracking();
  for (const agreement of trackedLeases) {
    armRentalAgreementLeaseReminders(agreement);
  }
  if (trackedLeases.length) {
    console.log(`[server] re-armed lease reminders for ${trackedLeases.length} active rental(s).`);
  }
}

module.exports = {
  app,
  PORT,
  CORS_ORIGIN,
  rearmPendingExpiries,
  investmentPayoutScheduler,
};
