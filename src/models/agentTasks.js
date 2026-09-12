const { query } = require('../db');

function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    agentId: row.agent_id,
    title: row.title,
    done: row.done,
    dueAt: row.due_at,
    linkedTourRequestId: row.linked_tour_request_id,
    linkedOrderRequestId: row.linked_order_request_id,
    createdBy: row.created_by,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function create({ agentId, title, dueAt, linkedTourRequestId, linkedOrderRequestId, createdBy }) {
  return query(
    `INSERT INTO agent_tasks
       (agent_id, title, due_at, linked_tour_request_id, linked_order_request_id, created_by)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [agentId, title, dueAt || null, linkedTourRequestId || null, linkedOrderRequestId || null, createdBy || 'agent']
  ).then((r) => r.rows[0]);
}

/**
 * Every task for this agent, open ones first (oldest due date first among
 * those), done ones last (most recently completed first) — so the list
 * reads as "what's left to do" without the agent having to filter.
 */
function listForAgent(agentId) {
  return query(
    `SELECT * FROM agent_tasks
     WHERE agent_id = $1
     ORDER BY done ASC, due_at ASC NULLS LAST, created_at DESC`,
    [agentId]
  ).then((r) => r.rows);
}

function findById(id) {
  return query(`SELECT * FROM agent_tasks WHERE id = $1`, [id]).then((r) => r.rows[0] || null);
}

/** Scoped to agentId so one agent can't toggle/delete another's task. */
function setDone(id, agentId, done) {
  return query(`UPDATE agent_tasks SET done = $3 WHERE id = $1 AND agent_id = $2 RETURNING *`, [id, agentId, done]).then(
    (r) => r.rows[0] || null
  );
}

function remove(id, agentId) {
  return query(`DELETE FROM agent_tasks WHERE id = $1 AND agent_id = $2 RETURNING id`, [id, agentId]).then(
    (r) => r.rows[0] || null
  );
}

module.exports = { toPublic, create, listForAgent, findById, setDone, remove };
