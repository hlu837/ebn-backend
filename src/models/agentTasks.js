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

/**
 * `id` is optional. The app generates one per "Add task" tap and reuses it
 * if it has to retry, so a request that was saved but whose response got
 * lost can be sent again without creating a duplicate: the second insert
 * hits the conflict and we hand back the row that's already there.
 * Returns null only if that id already belongs to a different agent.
 */
async function create({ id, agentId, title, dueAt, linkedTourRequestId, linkedOrderRequestId, createdBy }) {
  if (id) {
    const inserted = await query(
      `INSERT INTO agent_tasks
         (id, agent_id, title, due_at, linked_tour_request_id, linked_order_request_id, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (id) DO NOTHING
       RETURNING *`,
      [id, agentId, title, dueAt || null, linkedTourRequestId || null, linkedOrderRequestId || null, createdBy || 'agent']
    );
    if (inserted.rows[0]) return inserted.rows[0];
    const existing = await query(`SELECT * FROM agent_tasks WHERE id = $1 AND agent_id = $2`, [id, agentId]);
    return existing.rows[0] || null;
  }
  return query(
    `INSERT INTO agent_tasks
       (agent_id, title, due_at, linked_tour_request_id, linked_order_request_id, created_by)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [agentId, title, dueAt || null, linkedTourRequestId || null, linkedOrderRequestId || null, createdBy || 'agent']
  ).then((r) => r.rows[0]);
}

/**
 * Every task for this agent, open ones first, done ones last — so the
 * list reads as "what's left to do" without the agent having to filter.
 * Within each group, newest-placed first (by `created_at`), matching how
 * the agent actually adds/receives tasks, not by due date — a task added
 * a minute ago should show up at the top of the list right away instead
 * of getting buried under older tasks that happen to have an earlier due
 * date.
 */
function listForAgent(agentId) {
  return query(
    `SELECT * FROM agent_tasks
     WHERE agent_id = $1
     ORDER BY done ASC, created_at DESC`,
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
