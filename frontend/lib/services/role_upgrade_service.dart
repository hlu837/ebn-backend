import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/role_upgrade_request.dart';
import '../models/user_role.dart';

/// Thrown for any role-upgrade call the backend rejects (validation,
/// already-pending request, auth, network errors, etc). [message] is safe
/// to show directly in a SnackBar.
class RoleUpgradeServiceException implements Exception {
  final String message;
  const RoleUpgradeServiceException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/role-upgrade-requests` routes — lets a
/// signed-in Visitor request to become an Affiliater, Agent / Broker, or
/// Investor, and track the status of that request. Mirrors
/// [VisitorService]'s shape/conventions.
class RoleUpgradeService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// POST /api/role-upgrade-requests
  Future<RoleUpgradeRequest> submitRequest({
    required UserRole requestedRole,
    String? message,
    String? agencyOrLicense,
    bool interestedInFractionalInvesting = false,
    required String token,
  }) async {
    final json = await _post('/api/role-upgrade-requests', {
      'requestedRole': requestedRole.apiValue,
      if (message != null && message.trim().isNotEmpty) 'message': message.trim(),
      if (agencyOrLicense != null && agencyOrLicense.trim().isNotEmpty) 'agencyOrLicense': agencyOrLicense.trim(),
      'interestedInFractionalInvesting': interestedInFractionalInvesting,
    }, token: token);
    return RoleUpgradeRequest.fromJson(json);
  }

  /// GET /api/role-upgrade-requests/me — this visitor's full history.
  Future<List<RoleUpgradeRequest>> myRequests({required String token}) async {
    final rows = await _getList('/api/role-upgrade-requests/me', token: token);
    return rows.map(RoleUpgradeRequest.fromJson).toList();
  }

  // ── Admin ────────────────────────────────────────────────────────────

  /// GET /api/role-upgrade-requests/pending — admin review queue, oldest first.
  Future<List<RoleUpgradeRequest>> fetchPending({required String token}) async {
    final rows = await _getList('/api/role-upgrade-requests/pending', token: token);
    return rows.map(RoleUpgradeRequest.fromJson).toList();
  }

  /// POST /api/role-upgrade-requests/:id/approve — flips the user's role.
  Future<void> approve(String id, {String? adminNote, required String token}) async {
    await _post('/api/role-upgrade-requests/$id/approve', {
      if (adminNote != null && adminNote.trim().isNotEmpty) 'adminNote': adminNote.trim(),
    }, token: token);
  }

  /// POST /api/role-upgrade-requests/:id/reject
  Future<void> reject(String id, {String? adminNote, required String token}) async {
    await _post('/api/role-upgrade-requests/$id/reject', {
      if (adminNote != null && adminNote.trim().isNotEmpty) 'adminNote': adminNote.trim(),
    }, token: token);
  }

  // ── internals ────────────────────────────────────────────────────────

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {String? token}) async {
    http.Response res;
    try {
      res = await http
          .post(_uri(path), headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const RoleUpgradeServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<List<Map<String, dynamic>>> _getList(String path, {String? token}) async {
    http.Response res;
    try {
      res = await http.get(_uri(path), headers: _headers(token)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const RoleUpgradeServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      Map<String, dynamic> json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw const RoleUpgradeServiceException('Unexpected response from the server.');
      }
      throw RoleUpgradeServiceException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    try {
      return (jsonDecode(res.body) as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      throw const RoleUpgradeServiceException('Unexpected response from the server.');
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const RoleUpgradeServiceException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw RoleUpgradeServiceException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
