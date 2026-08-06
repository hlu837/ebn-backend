require('dotenv').config();
const { pool } = require('../src/db');

async function main() {
  // 1. Get latest sell requests
  const sellRes = await pool.query(
    "SELECT id, owner_name, title, fee_paid, status, created_at FROM sell_requests ORDER BY created_at DESC LIMIT 5"
  );
  console.log('Latest sell requests:', JSON.stringify(sellRes.rows, null, 2));

  if (sellRes.rows.length === 0) {
    console.log('No sell requests found.');
    await pool.end();
    return;
  }

  const latest = sellRes.rows[0];
  console.log(`Updating sell request "${latest.title}" (${latest.id})...`);

  // Update sell request to fee_paid = true and status = pending_admin_approval
  await pool.query(
    "UPDATE sell_requests SET fee_paid = true, status = 'pending_admin_approval' WHERE id = $1",
    [latest.id]
  );
  console.log('Sell request updated: fee_paid = true, status = pending_admin_approval.');

  // Check and update payments for this owner
  const payRes = await pool.query(
    "SELECT tx_ref, status FROM payments WHERE owner_user_id = $1 ORDER BY created_at DESC LIMIT 1",
    [latest.owner_user_id]
  );

  if (payRes.rows.length > 0) {
    await pool.query(
      "UPDATE payments SET status = 'success', updated_at = now() WHERE tx_ref = $1",
      [payRes.rows[0].tx_ref]
    );
    console.log(`Payment ${payRes.rows[0].tx_ref} marked as success.`);
  }

  await pool.end();
}

main().catch(e => { console.error(e.message); pool.end(); });
