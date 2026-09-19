const { app, CORS_ORIGIN, rearmPendingExpiries, investmentPayoutScheduler } = require('./src/app');
const { createServer } = require('http');

// Fresh deploy trigger for Vercel [2026-08-22]: force rebuild to pick up
// pending-signup fix — createPending null-guard in auth.js, updated toPublic
// fields (accountStatus, pendingRole), and signin pending_payment enforcement.
// Vercel provides an auto-handled HTTP server for serverless functions.
// We can still create a server for Socket.IO when running locally, but
// in Vercel serverless mode, only the request handler is used.
const server = createServer(app);

let started = false;

async function initBackgroundJobs() {
  if (started) return;
  started = true;
  try {
    await rearmPendingExpiries();
  } catch (err) {
    console.error('[server] failed to re-arm pending expiries on boot', err);
  }
  investmentPayoutScheduler.start();
}

// In production on Vercel, `req` and `res` are handled per invocation.
module.exports = async (req, res) => {
  if (process.env.NODE_ENV !== 'production') {
    await initBackgroundJobs();
  }

  app(req, res);
};
