// Runs every .sql file in ../migrations, in filename order, against the
// database configured via DATABASE_URL (or the PG* env vars — see db.js).
// Usage: npm run migrate

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/db');

async function main() {
  const dir = path.join(__dirname, '..', 'migrations');
  const files = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  if (!files.length) {
    console.log('No migration files found in', dir);
    return;
  }

  for (const file of files) {
    const sql = fs.readFileSync(path.join(dir, file), 'utf8');
    console.log(`Applying ${file}...`);
    await pool.query(sql);
  }

  console.log(`Applied ${files.length} migration file(s) successfully.`);
}

main()
  .catch((err) => {
    console.error('Migration failed:', err);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
