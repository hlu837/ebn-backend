const express = require('express');
const { requireAuth } = require('./auth');
const chat = require('../models/chat');
const assets = require('../models/assets');
const { query } = require('../db');
const { broadcastChatMessage, broadcastNotification } = require('../socket');
const notificationsModel = require('../models/notifications');
const agentSettingsModel = require('../models/agentSettings');

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

const router = express.Router();

/**
 * POST /api/chat/threads
 * body: { assetId }
 * Customer-only entry point — matches the client, which always opens
 * chat from a listing's "Chat about this listing" button. The agent is
 * derived from the asset's broker_id, not taken from the request body,
 * so a customer can't be tricked into messaging someone else's agent id.
 */
router.post(
  '/threads',
  requireAuth,
  asyncHandler(async (req, res) => {
    const { assetId } = req.body || {};
    if (!assetId) return res.status(400).json({ error: 'assetId is required' });

    const asset = await assets.findById(assetId);
    if (!asset) return res.status(404).json({ error: 'Listing not found' });
    if (!asset.broker_id) {
      return res.status(422).json({ error: "This listing doesn't have an agent assigned yet" });
    }

    // broker_id is a loose TEXT column — for older/seeded listings it can
    // still hold a legacy mock id (e.g. "b1") rather than a real user id.
    const agentRow = await query(
      `SELECT id FROM users WHERE id::text = $1 AND role = 'agent'`,
      [asset.broker_id]
    );
    const agent = agentRow.rows[0];
    if (!agent) {
      return res.status(422).json({ error: 'This listing\'s agent is not set up for messaging yet' });
    }

    if (req.user.id === agent.id) {
      return res.status(400).json({ error: "You can't start a chat with yourself" });
    }

    const thread = await chat.getOrCreateThread({
      customerId: req.user.id,
      agentId: agent.id,
      assetId: asset.id,
    });
    res.status(201).json(chat.threadToPublic(thread));
  })
);

/** GET /api/chat/threads — inbox for the logged-in user, either role. */
router.get(
  '/threads',
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await chat.listForUser(req.user.id);
    res.json(rows.map(chat.threadToPublic));
  })
);

/** GET /api/chat/threads/:id/messages?before=ISO_TIMESTAMP&limit=100 */
router.get(
  '/threads/:id/messages',
  requireAuth,
  asyncHandler(async (req, res) => {
    const thread = await chat.findByIdForUser(req.params.id, req.user.id);
    if (!thread) return res.status(404).json({ error: 'Thread not found' });

    const rows = await chat.listMessages(thread.id, {
      before: req.query.before,
      limit: req.query.limit,
    });
    res.json(rows.map(chat.messageToPublic));
  })
);

/** POST /api/chat/threads/:id/messages — body: { body } */
router.post(
  '/threads/:id/messages',
  requireAuth,
  asyncHandler(async (req, res) => {
    const thread = await chat.findByIdForUser(req.params.id, req.user.id);
    if (!thread) return res.status(404).json({ error: 'Thread not found' });

    const body = (req.body && req.body.body ? String(req.body.body) : '').trim();
    if (!body) return res.status(400).json({ error: 'Message body is required' });
    if (body.length > 4000) return res.status(400).json({ error: 'Message is too long' });

    const { message, thread: updatedThread } = await chat.sendMessage({
      threadId: thread.id,
      senderId: req.user.id,
      body,
    });

    const recipientId = req.user.id === thread.customer_id ? thread.agent_id : thread.customer_id;
    broadcastChatMessage(recipientId, {
      thread: chat.threadToPublic(updatedThread),
      message: chat.messageToPublic(message),
    });

    const recipientType = recipientId === thread.agent_id ? 'agent' : 'user';
    try {
      let shouldNotify = true;
      if (recipientType === 'agent') {
        const settings = agentSettingsModel.toPublic(await agentSettingsModel.getOrCreate(recipientId));
        shouldNotify = !settings || settings.notifyChatMessages !== false;
      }
      if (shouldNotify) {
        const notifRow = await notificationsModel.create({
          recipientType,
          recipientId,
          kind: 'chat_message',
          title: `New message from ${req.user.fullName || 'a user'}`,
          body: body.length > 140 ? `${body.slice(0, 140)}…` : body,
          relatedId: thread.id,
        });
        broadcastNotification(recipientType, recipientId, notificationsModel.toPublic(notifRow));
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error('[chat] failed to create chat_message notification', err);
    }

    res.status(201).json(chat.messageToPublic(message));
  })
);

/** POST /api/chat/threads/:id/read — marks the caller's side caught up. */
router.post(
  '/threads/:id/read',
  requireAuth,
  asyncHandler(async (req, res) => {
    const thread = await chat.markRead(req.params.id, req.user.id);
    if (!thread) return res.status(404).json({ error: 'Thread not found' });
    res.json(chat.threadToPublic(thread));
  })
);

module.exports = { router };
