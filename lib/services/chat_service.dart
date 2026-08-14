import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import 'auth_service.dart';

/// Thrown for any /api/chat/* failure — bad request, not-found thread,
/// network error, etc. [message] is safe to show directly in a SnackBar.
class ChatException implements Exception {
  final String message;
  const ChatException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/chat/*` routes. Replaces the
/// canned/randomized replies that used to live inside
/// `BrokerChatScreen` — messages are now persisted and shared between
/// the customer and the agent.
///
/// There's no socket client wired up on the Flutter side yet (the app's
/// existing real-time-ish screens all poll on a `Timer.periodic` instead
/// — see `loop_controller.dart`), so [messagesForThread] is meant to be
/// called on an interval by the screen, the same way.
class ChatService {
  static const String baseUrl = AuthService.baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// POST /api/chat/threads — gets or creates the thread for this
  /// listing. The agent is derived server-side from the asset's broker,
  /// so this can 422 if that listing isn't linked to a real agent
  /// account yet — surface [ChatException.message] to the user as-is,
  /// it's already written to be shown directly.
  Future<ChatThread> openThreadForAsset({required String token, required String assetId}) async {
    final res = await _post('/api/chat/threads', {'assetId': assetId}, token: token);
    return ChatThread.fromJson(res);
  }

  /// GET /api/chat/threads — the caller's inbox, either role, newest
  /// activity first.
  Future<List<ChatThread>> listThreads({required String token}) async {
    final res = await _getList('/api/chat/threads', token: token);
    return res.map((e) => ChatThread.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// GET /api/chat/threads/:id/messages — pass [before] to page
  /// backwards; omit it to just get the latest [limit] messages.
  Future<List<ChatMessage>> messagesForThread({
    required String token,
    required String threadId,
    DateTime? before,
    int limit = 100,
  }) async {
    final query = <String, String>{'limit': '$limit', if (before != null) 'before': before.toIso8601String()};
    final path = Uri(path: '/api/chat/threads/$threadId/messages', queryParameters: query).toString();
    final res = await _getList(path, token: token);
    return res.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// POST /api/chat/threads/:id/messages
  Future<ChatMessage> sendMessage({required String token, required String threadId, required String body}) async {
    final res = await _post('/api/chat/threads/$threadId/messages', {'body': body}, token: token);
    return ChatMessage.fromJson(res);
  }

  /// POST /api/chat/threads/:id/read
  Future<void> markRead({required String token, required String threadId}) async {
    await _post('/api/chat/threads/$threadId/read', const {}, token: token);
  }

  // ── internals ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {required String token}) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri(path),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ChatException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decodeObject(res);
  }

  Future<List<dynamic>> _getList(String path, {required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri(path), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ChatException("Couldn't reach the server. Check your connection and try again.");
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ChatException(_errorFrom(res));
    }
    try {
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      throw const ChatException('Unexpected response from the server.');
    }
  }

  Map<String, dynamic> _decodeObject(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ChatException(_errorFrom(res));
    }
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ChatException('Unexpected response from the server.');
    }
  }

  String _errorFrom(http.Response res) {
    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json['error'] as String? ?? 'Something went wrong (${res.statusCode}).';
    } catch (_) {
      return 'Something went wrong (${res.statusCode}).';
    }
  }
}
