const { Client } = require('pg');
const conn = process.env.DATABASE_URL;
if (!conn) throw new Error('DATABASE_URL is required');
const client = new Client({ connectionString: conn });

client.connect()
  .then(() => client.query("SELECT password_hash FROM users WHERE email = 'admin@onsite.com'"))
  .then((res) => {
    console.log(res.rows[0]?.password_hash || 'NO_HASH');
  })
  .catch((err) => {
    console.error(err.message);
    process.exit(1);
  })
  .finally(() => client.end());
