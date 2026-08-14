const { Client } = require('pg');
const conn = process.env.DATABASE_URL || 'postgresql://neondb_owner:npg_zFLHG26dxScj@ep-polished-thunder-aw7ygxxv-pooler.c-12.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require';
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
