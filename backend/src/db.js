const { Pool } = require('pg');

// Supports either a single DATABASE_URL, or discrete PGHOST/PGUSER/etc,
// which `pg` reads automatically from the environment if DATABASE_URL is
// absent. Explicit is better here so `npm start` fails loudly if
// misconfigured rather than silently connecting to the wrong thing.
const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  // eslint-disable-next-line no-console
  console.warn(
    '[db] DATABASE_URL is not set — falling back to default local Postgres ' +
      'connection params (see .env.example).'
  );
}

const pool = new Pool(
  connectionString
    ? { connectionString }
    : {
        host: process.env.PGHOST || 'localhost',
        port: Number(process.env.PGPORT || 5432),
        user: process.env.PGUSER || 'ebn_app',
        password: process.env.PGPASSWORD || 'ebn_app_pw',
        database: process.env.PGDATABASE || 'ebn_tours',
      }
);

pool.on('error', (err) => {
  // Idle client errors (e.g. connection dropped) shouldn't crash the process.
  // eslint-disable-next-line no-console
  console.error('[db] unexpected error on idle client', err);
});

module.exports = {
  pool,
  query: (text, params) => pool.query(text, params),
};
