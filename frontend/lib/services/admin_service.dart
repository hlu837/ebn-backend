import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/admin_transaction.dart';
import '../models/admin_user.dart';

/// Thrown for any admin call the backend rejects (validation, auth,
/// network errors, etc). [message] is safe to show directly in a SnackBar.
class AdminServiceException implements Exception {
  final String message;
  const AdminServiceException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/users/*` and `/api/transactions`
/// routes — mirrors [AgentService]'s shape and conventions.
class AdminService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mlmpropertyebn.vercel.app',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// GET /api/users?role=&search= — [limit] is generous (200) since the
  /// Users screen filters/searches client-side, same pattern as
  /// AdminAgentsScreen's use of AgentService.fetchDirectory.
  Future<List<AdminUser>> fetchUsers({required String token}) async {
    final json = await _get('/api/users?limit=200', token: token);
    final rows = (json['users'] as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(AdminUser.fromJson).toList();
  }

  /// PATCH /api/users/:id/suspend — Body: { suspended }.
  Future<AdminUser> setUserSuspended(String userId, bool suspended, {required String token}) async {
    final json = await _patch('/api/users/$userId/suspend', {'suspended': suspended}, token: token);
    return AdminUser.fromJson(json);
  }

  /// GET /api/transactions?status=&search=
  Future<List<AdminTransaction>> fetchTransactions({required String token}) async {
    final json = await _get('/api/transactions?limit=200', token: token);
    final rows = (json['transactions'] as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(AdminTransaction.fromJson).toList();
  }

  // ── HTTP helpers — mirrors AgentService's _get/_patch/_decode ──────────

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    http.Response res;
    try {
      res = await http.get(_uri(path), headers: _headers(token)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AdminServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body, {String? token}) async {
    http.Response res;
    try {
      res = await http
          .patch(_uri(path), headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AdminServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AdminServiceException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AdminServiceException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
