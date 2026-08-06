import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/visitor_account.dart';

/// Thrown for any visitor-account call the backend rejects (validation,
/// auth, network errors, etc). [message] is safe to show directly in a
/// SnackBar.
class VisitorServiceException implements Exception {
  final String message;
  const VisitorServiceException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/auth/me/*` routes for the signed-in
/// Visitor's own account — mirrors [AgentService]'s shape/conventions so
/// the two stay easy to compare. Unlike agents, these are self-scoped via
/// the Bearer token rather than `/agents/:agentId/...`, matching how
/// `/api/auth/me` and `/api/auth/me/change-password` already work.
///
/// Base URL:
/// - Flutter web / desktop: `localhost` reaches the backend directly.
/// - Android emulator: change [baseUrl] to `http://10.0.2.2:4000`.
/// - Physical device / deployed: point it at your backend's real host.
class VisitorService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // ── Settings ─────────────────────────────────────────────────────────

  /// GET /api/auth/me/settings
  Future<VisitorSettingsData> getSettings(String userId, {required String token}) async {
    final json = await _get('/api/auth/me/settings', token: token);
    return VisitorSettingsData.fromJson(json);
  }

  /// PATCH /api/auth/me/settings
  Future<VisitorSettingsData> updateSettings(
    String userId, {
    bool? notifyRequestUpdates,
    bool? notifyChatMessages,
    bool? notifyPriceDrops,
    bool? notifyPromotions,
    String? language,
    required String token,
  }) async {
    final json = await _patch('/api/auth/me/settings', {
      if (notifyRequestUpdates != null) 'notifyRequestUpdates': notifyRequestUpdates,
      if (notifyChatMessages != null) 'notifyChatMessages': notifyChatMessages,
      if (notifyPriceDrops != null) 'notifyPriceDrops': notifyPriceDrops,
      if (notifyPromotions != null) 'notifyPromotions': notifyPromotions,
      if (language != null) 'language': language,
    }, token: token);
    return VisitorSettingsData.fromJson(json);
  }

  // ── Profile (name / phone) ──────────────────────────────────────────

  /// PATCH /api/auth/me — updates basic profile fields. Returns the
  /// updated user object as raw JSON, under a `user` key
  /// (decode with `AppUser.fromJson(json['user'])`).
  Future<Map<String, dynamic>> updateProfile(
    String userId, {
    String? fullName,
    String? phone,
    required String token,
  }) async {
    return _patch('/api/auth/me', {
      if (fullName != null) 'fullName': fullName,
      if (phone != null) 'phone': phone,
    }, token: token);
  }

  /// POST /api/auth/me/change-password
  Future<void> changePassword(
    String userId, {
    required String currentPassword,
    required String newPassword,
    required String token,
  }) async {
    await _post('/api/auth/me/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
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
      throw const VisitorServiceException("Couldn't reach the server. Check your connection and try again.");
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
      throw const VisitorServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    http.Response res;
    try {
      res = await http.get(_uri(path), headers: _headers(token)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const VisitorServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const VisitorServiceException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw VisitorServiceException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
