const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const { Pool } = require('pg');

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('[db] DATABASE_URL is required');
}

const pool = new Pool({ connectionString });

pool.on('error', (err) => {
  // Idle client errors (e.g. connection dropped) shouldn't crash the process.
  // eslint-disable-next-line no-console
  console.error('[db] unexpected error on idle client', err);
});

module.exports = {
  pool,
  query: (text, params) => pool.query(text, params),
};
