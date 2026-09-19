const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('[db] DATABASE_URL is required');
}

// Serverless-friendly pool settings. Without connectionTimeoutMillis a
// request that can't get a connection (cold database, stale socket after the
// function was frozen) just hangs until the platform kills it; with it, the
// failure surfaces fast and the client can retry. keepAlive lets the OS notice
// a connection the database side has already dropped.
const pool = new Pool({
  connectionString,
  connectionTimeoutMillis: 8000,
  keepAlive: true,
});

pool.on('error', (err) => {
  // Idle client errors (e.g. connection dropped) shouldn't crash the process.
  // eslint-disable-next-line no-console
  console.error('[db] unexpected error on idle client', err);
});

// Errors that mean "the connection was bad", not "the SQL was bad".
const TRANSIENT_DB_ERROR = /Connection terminated|ECONNRESET|EPIPE|ETIMEDOUT|timeout exceeded when trying to connect|server closed the connection/i;

/**
 * pool.query, plus one automatic retry for plain SELECTs that fail because
 * of a dropped/stale connection (the classic first-request-after-idle failure
 * on serverless + a database that auto-suspends). Writes are never retried
 * here — a lost response doesn't tell us whether the write happened — so
 * write routes make themselves retry-safe instead (see agentTasks.create).
 */
async function query(text, params) {
  try {
    return await pool.query(text, params);
  } catch (err) {
    const isPlainSelect = typeof text === 'string' && /^\s*select\b/i.test(text) && !/\bfor\s+update\b/i.test(text);
    if (isPlainSelect && TRANSIENT_DB_ERROR.test(String(err && err.message))) {
      return pool.query(text, params);
    }
    throw err;
  }
}

module.exports = {
  pool,
  query,
};
