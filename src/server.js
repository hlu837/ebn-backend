const { createServer } = require('http');

const { app, PORT, CORS_ORIGIN, rearmPendingExpiries, investmentPayoutScheduler } = require('./app');
const { initSocket } = require('./socket');

const httpServer = createServer(app);
initSocket(httpServer, { corsOrigin: CORS_ORIGIN });

httpServer.listen(PORT, async () => {
  console.log(`[server] listening on http://localhost:${PORT}`);
  try {
    await rearmPendingExpiries();
  } catch (err) {
    console.error('[server] failed to re-arm pending expiries on boot', err);
  }
  investmentPayoutScheduler.start();
});
