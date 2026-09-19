const { query } = require('../db');
const assetsModel = require('./assets');
const usersModel = require('./users');
const chatModel = require('./chat');
const notificationsModel = require('./notifications');
const { broadcastNotification } = require('../socket');

const REQUEST_TYPES = ['info', 'tour', 'rent_now'];

const TYPE_LABELS = {
  info: 'info request',
  tour: 'tour request',
  rent_now: 'rent request',
};

/**
 * Converts a DB row (snake_case) to the camelCase shape the client
 * expects. When the row came from [listForOwner]/[findByIdForOwner] it
 * carries extra joined columns (asset title/image, requester name, and
 * the linked thread's message/unread summary) — same "present only when
 * joined in" pattern as chat.js's threadToPublic.
 */
function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    assetId: row.asset_id,
    ownerId: row.owner_id,
    requesterId: row.requester_id,
    requestType: row.request_type,
    // Derived, not stored — see the migration's note on why "has the
    // owner replied yet" isn't tracked as its own column.
    status:
      row.status === 'closed'
        ? 'closed'
        : row.thread_last_sender_id && row.thread_last_sender_id === row.owner_id
        ? 'in_progress'
        : 'pending',
    threadId: row.thread_id,
    message: row.message,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    asset:
      row.asset_title !== undefined
        ? { id: row.asset_id, title: row.asset_title, imageUrl: row.asset_image_url }
        : undefined,
    requester:
      row.requester_name !== undefined
        ? { id: row.requester_id, fullName: row.requester_name }
        : undefined,
    lastMessageBody: row.thread_last_body !== undefined ? row.thread_last_body : undefined,
    lastMessageAt: row.thread_last_at !== undefined ? row.thread_last_at : undefined,
    unreadCount: row.unread_count !== undefined ? Number(row.unread_count) : undefined,
  };
}

/**
 * Creates a request against a listing: resolves the owner from the
 * asset's broker_id (same pattern chat.js uses for agents — accepts
 * either role since a Property Owner's self-listing and an Agent's
 * listing both set broker_id to their own user id), gets/creates the
 * underlying chat thread, posts the opening message into it, records the
 * request row, and notifies the owner.
 */
async function create({ assetId, requesterId, requesterName, requestType, message }) {
  if (!REQUEST_TYPES.includes(requestType)) {
    throw Object.assign(new Error('Invalid request type'), { status: 400 });
  }

  const asset = await assetsModel.findById(assetId);
  if (!asset) throw Object.assign(new Error('Listing not found'), { status: 404 });
  if (!asset.broker_id) {
    throw Object.assign(new Error("This listing doesn't have an owner assigned yet"), { status: 422 });
  }

  const ownerRow = await query(
    `SELECT id, full_name, role FROM users WHERE id::text = $1 AND role IN ('property_owner', 'agent')`,
    [asset.broker_id]
  );
  const owner = ownerRow.rows[0];
  if (!owner) {
    throw Object.assign(new Error("This listing's owner is not set up for messaging yet"), { status: 422 });
  }
  if (requesterId === owner.id) {
    throw Object.assign(new Error("You can't send a request on your own listing"), { status: 400 });
  }

  const thread = await chatModel.getOrCreateThread({
    customerId: requesterId,
    agentId: owner.id,
    assetId: asset.id,
  });

  const trimmedMessage = (message || '').trim() || null;
  if (trimmedMessage) {
    await chatModel.sendMessage({ threadId: thread.id, senderId: requesterId, body: trimmedMessage });
  }

  const row = await query(
    `INSERT INTO property_requests (asset_id, owner_id, requester_id, request_type, thread_id, message)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [asset.id, owner.id, requesterId, requestType, thread.id, trimmedMessage]
  ).then((r) => r.rows[0]);

  try {
    const notifRow = await notificationsModel.create({
      recipientType: owner.role,
      recipientId: owner.id,
      kind: 'property_request',
      title: `New ${TYPE_LABELS[requestType]} — ${asset.title}`,
      body: trimmedMessage
        ? trimmedMessage.length > 140
          ? `${trimmedMessage.slice(0, 140)}…`
          : trimmedMessage
        : `${requesterName || 'A user'} sent a ${TYPE_LABELS[requestType]}`,
      relatedId: row.id,
    });
    broadcastNotification(owner.role, owner.id, notificationsModel.toPublic(notifRow));
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[propertyRequests] failed to notify owner of new request', err);
  }

  return { row, thread };
}

/** Base SELECT shared by [listForOwner] and [findByIdForOwner] — joins in
 *  everything toPublic needs to render a list/detail item without a
 *  follow-up request per row. */
const OWNER_SELECT = `
  SELECT
    pr.*,
    a.title AS asset_title,
    a.image_url AS asset_image_url,
    req.full_name AS requester_name,
    t.last_message_body AS thread_last_body,
    t.last_message_at AS thread_last_at,
    t.last_message_sender_id AS thread_last_sender_id,
    (
      SELECT COUNT(*) FROM chat_messages m
      WHERE m.thread_id = pr.thread_id
        AND m.sender_id != pr.owner_id
        AND m.created_at > COALESCE(t.agent_last_read_at, 'epoch'::timestamptz)
    ) AS unread_count
  FROM property_requests pr
  JOIN assets a ON a.id = pr.asset_id
  JOIN users req ON req.id = pr.requester_id
  LEFT JOIN chat_threads t ON t.id = pr.thread_id
`;

/**
 * The owner's Inbox — every request across all their listings, newest
 * activity first. `status` here is the client-facing derived value
 * ('pending' | 'in_progress' | 'closed'); 'closed' maps straight to the
 * stored column, 'pending'/'in_progress' both mean the stored column is
 * still 'pending' and are told apart by who sent the thread's last
 * message (see toPublic).
 */
function listForOwner(ownerId, { status, assetId, requestType } = {}) {
  const conditions = ['pr.owner_id = $1'];
  const params = [ownerId];

  if (assetId) conditions.push(`pr.asset_id = $${params.push(assetId)}`);
  if (requestType) conditions.push(`pr.request_type = $${params.push(requestType)}::property_request_type`);
  if (status === 'closed') {
    conditions.push(`pr.status = 'closed'::property_request_status`);
  } else if (status === 'pending' || status === 'in_progress') {
    conditions.push(`pr.status = 'pending'::property_request_status`);
    conditions.push(
      status === 'in_progress'
        ? `t.last_message_sender_id = pr.owner_id`
        : `(t.last_message_sender_id IS NULL OR t.last_message_sender_id != pr.owner_id)`
    );
  }

  return query(
    `${OWNER_SELECT}
     WHERE ${conditions.join(' AND ')}
     ORDER BY COALESCE(t.last_message_at, pr.created_at) DESC`,
    params
  ).then((r) => r.rows);
}

function findByIdForOwner(id, ownerId) {
  return query(`${OWNER_SELECT} WHERE pr.id = $1 AND pr.owner_id = $2`, [id, ownerId]).then(
    (r) => r.rows[0] || null
  );
}

/** Owner marks a request closed (dismissed from the active Inbox) or
 *  reopens it. The only transition this model supports for now — see
 *  the migration's note on the fuller Review-tab lifecycle being a
 *  separate follow-up. */
function setStatus(id, ownerId, status) {
  if (!['pending', 'closed'].includes(status)) {
    throw Object.assign(new Error('Invalid status'), { status: 400 });
  }
  return query(
    `UPDATE property_requests
     SET status = $3::property_request_status, updated_at = now()
     WHERE id = $1 AND owner_id = $2
     RETURNING *`,
    [id, ownerId, status]
  ).then((r) => r.rows[0] || null);
}

module.exports = {
  REQUEST_TYPES,
  toPublic,
  create,
  listForOwner,
  findByIdForOwner,
  setStatus,
};
