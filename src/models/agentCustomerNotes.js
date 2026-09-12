const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    customerUserId: row.customer_user_id,
    body: row.body,
    createdAt: row.created_at,
  };
}

/** Every note entry this agent has ever written, across every customer,
 *  newest first — keyed by customer_user_id on the client so each row on
 *  the Customers screen can show its own log without an extra call per
 *  customer. */
async function listForAgent(agentId) {
  const { rows } = await query(
    `SELECT * FROM agent_customer_note_entries
     WHERE agent_id = $1
     ORDER BY customer_user_id, created_at DESC`,
    [agentId]
  );
  return rows;
}

/** All entries for one (agent, customer) pair, newest first — used when
 *  opening a single customer's note log. */
async function listForCustomer(agentId, customerUserId) {
  const { rows } = await query(
    `SELECT * FROM agent_customer_note_entries
     WHERE agent_id = $1 AND customer_user_id = $2
     ORDER BY created_at DESC`,
    [agentId, customerUserId]
  );
  return rows;
}

/** Appends a new timestamped entry to this (agent, customer) pair's log.
 *  Entries are never edited or overwritten once added — that's the whole
 *  point of the log — so this is a plain insert, not an upsert. */
async function addEntry(agentId, customerUserId, body) {
  const { rows } = await query(
    `INSERT INTO agent_customer_note_entries (agent_id, customer_user_id, body)
     VALUES ($1, $2, $3)
     RETURNING *`,
    [agentId, customerUserId, body]
  );
  return rows[0];
}

module.exports = { toPublic, listForAgent, listForCustomer, addEntry };
