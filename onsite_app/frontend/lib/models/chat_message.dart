/// Mirrors the JSON shapes returned by `/api/chat/*` on the real backend
/// (`backend/src/models/chat.js` → `threadToPublic` / `messageToPublic`).
library;

class ChatThreadOtherParty {
  final String id;
  final String fullName;
  const ChatThreadOtherParty({required this.id, required this.fullName});

  factory ChatThreadOtherParty.fromJson(Map<String, dynamic> json) {
    return ChatThreadOtherParty(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? '',
    );
  }
}

class ChatThreadAsset {
  final String id;
  final String title;
  final String? imageUrl;
  const ChatThreadAsset({required this.id, required this.title, this.imageUrl});

  factory ChatThreadAsset.fromJson(Map<String, dynamic> json) {
    return ChatThreadAsset(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

class ChatThread {
  final String id;
  final String customerId;
  final String agentId;
  final String assetId;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final ChatThreadAsset? asset;
  final ChatThreadOtherParty? otherParty;

  const ChatThread({
    required this.id,
    required this.customerId,
    required this.agentId,
    required this.assetId,
    this.lastMessageBody,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.asset,
    this.otherParty,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] as String,
      customerId: json['customerId'] as String,
      agentId: json['agentId'] as String,
      assetId: json['assetId'] as String,
      lastMessageBody: json['lastMessageBody'] as String?,
      lastMessageAt: json['lastMessageAt'] != null ? DateTime.tryParse(json['lastMessageAt'] as String) : null,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      asset: json['asset'] != null ? ChatThreadAsset.fromJson(json['asset'] as Map<String, dynamic>) : null,
      otherParty:
          json['otherParty'] != null ? ChatThreadOtherParty.fromJson(json['otherParty'] as Map<String, dynamic>) : null,
    );
  }
}

class ChatMessage {
  final String id;
  final String threadId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      senderId: json['senderId'] as String,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
