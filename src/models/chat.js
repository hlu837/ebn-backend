const { query, pool } = require('../db');

function threadToPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    customerId: row.customer_id,
    agentId: row.agent_id,
    assetId: row.asset_id,
    lastMessageBody: row.last_message_body,
    lastMessageSenderId: row.last_message_sender_id,
    lastMessageAt: row.last_message_at,
    customerLastReadAt: row.customer_last_read_at,
    agentLastReadAt: row.agent_last_read_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    // Present only when the caller's list query joined these in (see
    // listForUser below) — undefined keys are dropped by res.json anyway.
    asset:
      row.asset_title !== undefined
        ? { id: row.asset_id, title: row.asset_title, imageUrl: row.asset_image_url }
        : undefined,
    otherParty:
      row.other_party_name !== undefined
        ? { id: row.other_party_id, fullName: row.other_party_name }
        : undefined,
    unreadCount: row.unread_count !== undefined ? Number(row.unread_count) : undefined,
  };
}

function messageToPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    threadId: row.thread_id,
    senderId: row.sender_id,
    body: row.body,
    createdAt: row.created_at,
  };
}

/** Fetches a thread the caller (by id) is actually a participant in. */
function findByIdForUser(threadId, userId) {
  return query(
    `SELECT * FROM chat_threads WHERE id = $1 AND (customer_id = $2 OR agent_id = $2)`,
    [threadId, userId]
  ).then((r) => r.rows[0] || null);
}

/**
 * Gets the existing thread for (customerId, agentId, assetId), or creates
 * it. Single round trip via upsert-on-conflict rather than a
 * select-then-insert race.
 */
function getOrCreateThread({ customerId, agentId, assetId }) {
  return query(
    `INSERT INTO chat_threads (customer_id, agent_id, asset_id)
     VALUES ($1, $2, $3)
     ON CONFLICT (customer_id, agent_id, asset_id) DO UPDATE SET updated_at = chat_threads.updated_at
     RETURNING *`,
    [customerId, agentId, assetId]
  ).then((r) => r.rows[0]);
}

/**
 * Threads for the caller's inbox — either side (customer or agent),
 * newest activity first. Joins in the asset title/image and the other
 * party's name so the list screen doesn't need N follow-up requests, plus
 * an unread count based on the caller's own `*_last_read_at` watermark.
 */
function listForUser(userId) {
  return query(
    `SELECT
       t.*,
       a.title AS asset_title,
       a.image_url AS asset_image_url,
       (CASE WHEN t.customer_id = $1 THEN agent.full_name ELSE customer.full_name END) AS other_party_name,
       (CASE WHEN t.customer_id = $1 THEN t.agent_id ELSE t.customer_id END) AS other_party_id,
       (
         SELECT COUNT(*) FROM chat_messages m
         WHERE m.thread_id = t.id
           AND m.sender_id != $1
           AND m.created_at > COALESCE(
             CASE WHEN t.customer_id = $1 THEN t.customer_last_read_at ELSE t.agent_last_read_at END,
             'epoch'::timestamptz
           )
       ) AS unread_count
     FROM chat_threads t
     JOIN assets a ON a.id = t.asset_id
     JOIN users customer ON customer.id = t.customer_id
     JOIN users agent ON agent.id = t.agent_id
     WHERE t.customer_id = $1 OR t.agent_id = $1
     ORDER BY t.last_message_at DESC NULLS LAST, t.created_at DESC`,
    [userId]
  ).then((r) => r.rows);
}

function listMessages(threadId, { before, limit } = {}) {
  const cappedLimit = Math.min(Number(limit) || 100, 300);
  if (before) {
    return query(
      `SELECT * FROM chat_messages WHERE thread_id = $1 AND created_at < $2 ORDER BY created_at DESC LIMIT $3`,
      [threadId, before, cappedLimit]
    ).then((r) => r.rows.reverse());
  }
  return query(
    `SELECT * FROM chat_messages WHERE thread_id = $1 ORDER BY created_at DESC LIMIT $2`,
    [threadId, cappedLimit]
  ).then((r) => r.rows.reverse());
}

/** Inserts a message and bumps the thread's last-message summary in one transaction. */
async function sendMessage({ threadId, senderId, body }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const inserted = await client.query(
      `INSERT INTO chat_messages (thread_id, sender_id, body) VALUES ($1, $2, $3) RETURNING *`,
      [threadId, senderId, body]
    );
    const message = inserted.rows[0];
    const updated = await client.query(
      `UPDATE chat_threads
       SET last_message_body = $2, last_message_sender_id = $3, last_message_at = $4
       WHERE id = $1
       RETURNING *`,
      [threadId, body, senderId, message.created_at]
    );
    await client.query('COMMIT');
    return { message, thread: updated.rows[0] };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/** Marks everything up to now as read for whichever side `userId` is on. */
function markRead(threadId, userId) {
  return query(
    `UPDATE chat_threads
     SET customer_last_read_at = CASE WHEN customer_id = $2 THEN now() ELSE customer_last_read_at END,
         agent_last_read_at    = CASE WHEN agent_id = $2 THEN now() ELSE agent_last_read_at END
     WHERE id = $1 AND (customer_id = $2 OR agent_id = $2)
     RETURNING *`,
    [threadId, userId]
  ).then((r) => r.rows[0] || null);
}

module.exports = {
  threadToPublic,
  messageToPublic,
  findByIdForUser,
  getOrCreateThread,
  listForUser,
  listMessages,
  sendMessage,
  markRead,
};
