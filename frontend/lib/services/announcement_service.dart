import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/announcement.dart';

/// Thrown for any announcements call the backend rejects or that fails to
/// reach the server. [message] is safe to show directly in a SnackBar.
class AnnouncementException implements Exception {
  final String message;
  const AnnouncementException(this.message);

  @override
  String toString() => message;
}

/// Talks to `/api/announcements` — the admin-authored News & Announcements
/// feed. GET is public (no token needed); POST/DELETE require an admin
/// token, matching the backend's `requireAuth` + admin-role check.
class AnnouncementService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<List<Announcement>> list() async {
    final res = await _get('/api/announcements');
    return (jsonDecode(res) as List)
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Announcement> create({
    required String token,
    required String title,
    required String content,
    required String category,
    bool isPinned = false,
  }) async {
    final res = await _send(
      'POST',
      '/api/announcements',
      body: {
        'title': title,
        'content': content,
        'category': category,
        'isPinned': isPinned,
      },
      token: token,
    );
    return Announcement.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  Future<void> delete({required String token, required String id}) async {
    await _send('DELETE', '/api/announcements/$id', token: token);
  }

  // ── internals ────────────────────────────────────────────────────────

  Future<String> _get(String path) async {
    http.Response res;
    try {
      res = await http.get(_uri(path)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AnnouncementException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<String> _send(String method, String path, {Map<String, dynamic>? body, required String token}) async {
    http.Response res;
    final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
    try {
      switch (method) {
        case 'POST':
          res = await http.post(_uri(path), headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          res = await http.delete(_uri(path), headers: headers).timeout(const Duration(seconds: 15));
          break;
        default:
          throw ArgumentError('Unsupported method: $method');
      }
    } catch (_) {
      throw const AnnouncementException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  String _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message = 'Something went wrong (${res.statusCode}).';
      try {
        final json = jsonDecode(res.body);
        if (json is Map<String, dynamic> && json['error'] is String) message = json['error'] as String;
      } catch (_) {}
      throw AnnouncementException(message);
    }
    return res.body;
  }
}
