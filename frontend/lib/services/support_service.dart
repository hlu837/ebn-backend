import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/agent_account.dart' show SupportTicket;

/// Thrown for any support-ticket call the backend rejects (validation,
/// auth, network errors, etc). [message] is safe to show directly in a
/// SnackBar.
class SupportServiceException implements Exception {
  final String message;
  const SupportServiceException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/support-tickets` routes. These
/// routes just require *any* signed-in user (`requireAuth`, no role
/// check) — [AgentService] already has its own copy of this for the
/// Agent Support screen; this is the same API surface, factored out so
/// Visitor / Affiliater / Investor support screens can use it too
/// without depending on the agent-specific service.
class SupportService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mlmpropertyebn.vercel.app',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// POST /api/support-tickets — Body: { category, subject, body }.
  /// [category] should be one of: account, payments, listings, bug,
  /// other (the backend falls back to "other" for anything else).
  Future<SupportTicket> submitTicket({
    required String category,
    required String subject,
    required String body,
    required String token,
  }) async {
    final json = await _post('/api/support-tickets', {
      'category': category,
      'subject': subject,
      'body': body,
    }, token: token);
    return SupportTicket.fromJson(json);
  }

  /// GET /api/support-tickets/me — the caller's own ticket history,
  /// newest first.
  Future<List<SupportTicket>> myTickets({required String token}) async {
    final rows = await _getList('/api/support-tickets/me', token: token);
    return rows.map(SupportTicket.fromJson).toList();
  }

  /// GET /api/support-tickets?status= — Admin inbox: every ticket from
  /// every role, optionally filtered to 'open' or 'resolved'. 403s
  /// server-side for a non-admin token.
  Future<List<SupportTicket>> adminList({required String token, String? status}) async {
    final path = status != null ? '/api/support-tickets?status=$status' : '/api/support-tickets';
    final rows = await _getList(path, token: token);
    return rows.map(SupportTicket.fromJson).toList();
  }

  /// GET /api/support-tickets/:id — Admin single-ticket detail view.
  Future<SupportTicket> adminGet({required String token, required String id}) async {
    final json = await _get('/api/support-tickets/$id', token: token);
    return SupportTicket.fromJson(json);
  }

  /// POST /api/support-tickets/:id/resolve — Admin marks a ticket
  /// resolved.
  Future<SupportTicket> adminResolve({required String token, required String id}) async {
    final json = await _post('/api/support-tickets/$id/resolve', const {}, token: token);
    return SupportTicket.fromJson(json);
  }

  /// POST /api/support-tickets/:id/reply — Admin sends an answer. It's
  /// saved on the ticket and delivered to whoever submitted it as a
  /// notification containing the answer text.
  Future<SupportTicket> adminReply({required String token, required String id, required String response}) async {
    final json = await _post('/api/support-tickets/$id/reply', {'response': response}, token: token);
    return SupportTicket.fromJson(json);
  }

  // ── internals ────────────────────────────────────────────────────────

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {required String token}) async {
    http.Response res;
    try {
      res = await http
          .post(_uri(path), headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const SupportServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _get(String path, {required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri(path), headers: _headers(token)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const SupportServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<List<Map<String, dynamic>>> _getList(String path, {required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri(path), headers: _headers(token)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const SupportServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const SupportServiceException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw SupportServiceException(error ?? 'Something went wrong (${res.statusCode}).');
    }
    return (json as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const SupportServiceException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SupportServiceException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
