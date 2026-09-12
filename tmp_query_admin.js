const { Client } = require('pg');
const conn = process.env.DATABASE_URL;
if (!conn) throw new Error('DATABASE_URL is required');
const client = new Client({ connectionString: conn });

client.connect()
  .then(() => client.query("SELECT id, email, role, full_name FROM users WHERE role::text = 'admin' ORDER BY created_at DESC LIMIT 10"))
  .then((res) => {
    console.log(JSON.stringify(res.rows, null, 2));
  })
  .catch((err) => {
    console.error(err.message);
    process.exit(1);
  })
  .finally(() => client.end());
