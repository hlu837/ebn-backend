import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/agent_task.dart';

/// Thrown for any agent-tasks call the backend rejects or that fails to
/// reach the server. [message] is safe to show directly in a SnackBar.
class AgentTaskException implements Exception {
  final String message;
  const AgentTaskException(this.message);

  @override
  String toString() => message;
}

/// Talks to `/api/agent-tasks` — the real to-do list behind the dashboard's
/// "Tasks" quick action.
class AgentTaskService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<List<AgentTask>> list({required String token}) async {
    final res = await _get('/api/agent-tasks', token: token);
    return (jsonDecode(res) as List).map((e) => AgentTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AgentTask> create({
    required String token,
    required String title,
    DateTime? dueAt,
  }) async {
    final res = await _send(
      'POST',
      '/api/agent-tasks',
      body: {
        'title': title,
        if (dueAt != null) 'dueAt': dueAt.toIso8601String(),
      },
      token: token,
    );
    return AgentTask.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  Future<AgentTask> setDone({required String token, required String id, required bool done}) async {
    final res = await _send('PATCH', '/api/agent-tasks/$id', body: {'done': done}, token: token);
    return AgentTask.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  Future<void> delete({required String token, required String id}) async {
    await _send('DELETE', '/api/agent-tasks/$id', token: token);
  }

  // ── internals ────────────────────────────────────────────────────────

  Future<String> _get(String path, {required String token}) async {
    http.Response res;
    try {
      res = await http
          .get(_uri(path), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AgentTaskException("Couldn't reach the server. Check your connection and try again.");
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
        case 'PATCH':
          res = await http.patch(_uri(path), headers: headers, body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          res = await http.delete(_uri(path), headers: headers).timeout(const Duration(seconds: 15));
          break;
        default:
          throw ArgumentError('Unsupported method: $method');
      }
    } catch (_) {
      throw const AgentTaskException("Couldn't reach the server. Check your connection and try again.");
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
      throw AgentTaskException(message);
    }
    return res.body;
  }
}
