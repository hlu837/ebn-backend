import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown for any /api/notifications failure — bad request, network
/// error, etc.
class NotificationException implements Exception {
  final String message;
  const NotificationException(this.message);

  @override
  String toString() => message;
}

enum AppNotificationKind { newDispatch, chatMessage, payout, system }

AppNotificationKind _kindFromApi(String? raw) {
  switch (raw) {
    case 'new_dispatch':
      return AppNotificationKind.newDispatch;
    case 'chat_message':
      return AppNotificationKind.chatMessage;
    case 'payout':
      return AppNotificationKind.payout;
    default:
      return AppNotificationKind.system;
  }
}

class AppNotification {
  final String id;
  final AppNotificationKind kind;
  final String title;
  final String body;
  final bool isRead;
  final String? relatedId;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.relatedId,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      kind: _kindFromApi(json['kind'] as String?),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      relatedId: json['relatedId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Talks to the generic `/api/notifications/*` routes — shared across
/// every role (agent, customer, affiliater, admin), unlike the older
/// affiliate-only `/api/affiliates/me/notifications` (see
/// AffiliateService), which still exists separately and is untouched.
///
/// There's no socket client wired into the Flutter app yet (see the note
/// in chat_service.dart), so — same as chat and the tour-request loop —
/// screens using this service should poll on a `Timer.periodic` rather
/// than expect a live push.
class NotificationService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// GET /api/notifications
  Future<List<AppNotification>> getNotifications(String token) async {
    final res = await _getRaw('/api/notifications', token: token);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((item) => AppNotification.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// POST /api/notifications/:id/read
  Future<AppNotification> markRead(String token, String id) async {
    final json = await _post('/api/notifications/$id/read', {}, token: token);
    return AppNotification.fromJson(json);
  }

  /// POST /api/notifications/read-all
  Future<int> markAllRead(String token) async {
    final json = await _post('/api/notifications/read-all', {}, token: token);
    return (json['markedRead'] as num?)?.toInt() ?? 0;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<http.Response> _getRaw(String path, {required String token}) async {
    try {
      return await http.get(
        _uri(path),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const NotificationException("Couldn't reach the server. Check connection.");
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {required String token}) async {
    http.Response res;
    try {
      res = await http.post(
        _uri(path),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const NotificationException("Couldn't reach the server. Check connection.");
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const NotificationException('Unexpected server response.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw NotificationException(json['error'] as String? ?? 'Error (${res.statusCode})');
    }
    return json;
  }
}
