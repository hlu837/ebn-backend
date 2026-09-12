const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    agentId: row.agent_id,
    clientName: row.client_name,
    propertyTitle: row.property_title,
    address: row.address,
    startAt: row.start_at,
    durationMinutes: row.duration_minutes,
    status: row.status,
    source: row.source,
    dispatchTourRequestId: row.dispatch_tour_request_id,
    createdAt: row.created_at,
  };
}

function listByAgent(agentId) {
  return query(
    `SELECT * FROM agent_bookings WHERE agent_id = $1 AND status != 'cancelled' ORDER BY start_at ASC`,
    [agentId]
  ).then((r) => r.rows);
}

function create(agentId, { clientName, propertyTitle, address, startAt, durationMinutes, status }) {
  return query(
    `INSERT INTO agent_bookings (agent_id, client_name, property_title, address, start_at, duration_minutes, status)
     VALUES ($1, $2, $3, $4, $5, $6, COALESCE($7, 'pending'))
     RETURNING *`,
    [agentId, clientName, propertyTitle, address || null, startAt, durationMinutes || 60, status || null]
  ).then((r) => r.rows[0]);
}

function update(agentId, id, fields) {
  const sets = [];
  const vals = [];
  let i = 1;
  const map = {
    clientName: 'client_name',
    propertyTitle: 'property_title',
    address: 'address',
    startAt: 'start_at',
    durationMinutes: 'duration_minutes',
    status: 'status',
  };
  for (const [key, col] of Object.entries(map)) {
    if (fields[key] !== undefined) {
      sets.push(`${col} = $${i++}`);
      vals.push(fields[key]);
    }
  }
  if (!sets.length) return findById(agentId, id);
  vals.push(id, agentId);
  return query(
    `UPDATE agent_bookings SET ${sets.join(', ')} WHERE id = $${i++} AND agent_id = $${i} RETURNING *`,
    vals
  ).then((r) => r.rows[0] || null);
}

function cancel(agentId, id) {
  return query(
    `UPDATE agent_bookings SET status = 'cancelled' WHERE id = $1 AND agent_id = $2 RETURNING *`,
    [id, agentId]
  ).then((r) => r.rows[0] || null);
}

function findById(agentId, id) {
  return query(`SELECT * FROM agent_bookings WHERE id = $1 AND agent_id = $2`, [id, agentId]).then(
    (r) => r.rows[0] || null
  );
}

module.exports = { toPublic, listByAgent, create, update, cancel, findById };
