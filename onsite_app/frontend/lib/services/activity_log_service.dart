import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown for any /api/activity-log call the backend rejects (auth,
/// network errors, etc). [message] is safe to show directly in a SnackBar.
class ActivityLogServiceException implements Exception {
  final String message;
  const ActivityLogServiceException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `GET /api/activity-log` — admin-only,
/// paginated. Scope is deliberately narrow: approve/reject decisions on
/// investment commitments and role upgrade requests only, for now — see
/// the backend migration's comment for why sell-request actions aren't
/// included yet.
class ActivityLogService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mlmpropertyebn.vercel.app',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> fetchEntries({
    required String token,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = _uri('/api/activity-log').replace(queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
    });
    http.Response res;
    try {
      res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ActivityLogServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ActivityLogServiceException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ActivityLogServiceException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
