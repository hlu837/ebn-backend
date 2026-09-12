const { Server } = require('socket.io');

let io = null;

/**
 * Room naming:
 *   admin              — every Admin client joins this one room
 *   customer:<id>       — a Customer only cares about their own requests
 *   agent:<id>          — an Agent only cares about things dispatched to them
 *
 * Clients join by emitting 'join', e.g.
 *   socket.emit('join', { role: 'admin' })
 *   socket.emit('join', { role: 'customer', id: customerId })
 *   socket.emit('join', { role: 'agent', id: agentId })
 */
function initSocket(httpServer, { corsOrigin }) {
  io = new Server(httpServer, {
    cors: {
      origin: corsOrigin === '*' ? true : corsOrigin.split(',').map((s) => s.trim()),
    },
  });

  io.on('connection', (socket) => {
    socket.on('join', ({ role, id } = {}) => {
      if (role === 'admin') {
        socket.join('admin');
      } else if ((role === 'customer' || role === 'user') && id) {
        socket.join(`customer:${id}`);
        socket.join(`user:${id}`);
      } else if (role === 'agent' && id) {
        socket.join(`agent:${id}`);
      } else if (role && id) {
        socket.join(`${role}:${id}`);
      }
    });
  });

  return io;
}

/** Push a tour_request row to everyone who should see it change. */
function broadcastTourRequest(eventName, request) {
  if (!io) return;
  io.to('admin').emit(eventName, request);
  io.to(`customer:${request.customer_id}`).emit(eventName, request);
  io.to(`user:${request.customer_id}`).emit(eventName, request);
  if (request.agent_id) {
    io.to(`agent:${request.agent_id}`).emit(eventName, request);
  }
}

/**
 * Push a new chat message to its recipient. The recipient could be either
 * a customer or an agent depending on who sent it, and this is called
 * from a generic route handler that doesn't know which room that maps
 * to — so just target both; the id will only be joined to one of them.
 */
function broadcastChatMessage(recipientId, payload) {
  if (!io) return;
  io.to(`customer:${recipientId}`).emit('chat_message', payload);
  io.to(`user:${recipientId}`).emit('chat_message', payload);
  io.to(`agent:${recipientId}`).emit('chat_message', payload);
}

/**
 * Pushes a notification row to whichever room its recipient is in, if
 * they're currently connected. Recipients that aren't connected simply
 * miss the live push — they'll still see it next time they pull
 * GET /api/notifications, since the row is written to the DB regardless.
 *
 * Admin is a special case: admin sockets all join one shared `admin`
 * room (see initSocket) rather than a per-id room like `admin:<id>`,
 * same as broadcastTourRequest above — so an admin notification goes to
 * that shared room instead of `admin:<recipientId>`, which nothing ever
 * joins.
 */
function broadcastNotification(recipientType, recipientId, payload) {
  if (!io) return;
  if (recipientType === 'admin') {
    io.to('admin').emit('notification', payload);
    return;
  }
  io.to(`${recipientType}:${recipientId}`).emit('notification', payload);
  if (recipientType === 'user') {
    io.to(`customer:${recipientId}`).emit('notification', payload);
  } else if (recipientType === 'customer') {
    io.to(`user:${recipientId}`).emit('notification', payload);
  }
}

module.exports = { initSocket, broadcastTourRequest, broadcastChatMessage, broadcastNotification };
