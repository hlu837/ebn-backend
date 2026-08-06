import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/order_request.dart';

/// Thrown for any order-request call the backend rejects (validation,
/// network errors, etc). [message] is safe to show directly in a SnackBar.
class OrderRequestException implements Exception {
  final String message;
  const OrderRequestException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/order-requests/*` routes.
///
/// Base URL:
/// - Flutter web / desktop: `localhost` reaches the backend directly.
/// - Android emulator: change [baseUrl] to `http://10.0.2.2:4000`.
/// - Physical device / deployed: point it at your backend's real host.
class OrderRequestService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // ── Visitor ──────────────────────────────────────────────────────────
  /// POST /api/order-requests — submits a new "Order Us" requirement,
  /// already broadcast to nearby agents server-side. Exactly one of
  /// ([latitude], [longitude]) or [addressText] should be provided,
  /// matching [locationSource].
  Future<OrderRequest> submit({
    required String requesterUserId,
    required String requesterName,
    required String requesterPhone,
    required String category,
    required String title,
    required String description,
    required String budgetSummary,
    required OrderLocationSource locationSource,
    double? latitude,
    double? longitude,
    String? addressText,
  }) async {
    final json = await _post('/api/order-requests', {
      'requesterUserId': requesterUserId,
      'requesterName': requesterName,
      'requesterPhone': requesterPhone,
      'category': category,
      'title': title,
      'description': description,
      'budgetSummary': budgetSummary,
      'locationSource': locationSource.toApi,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (addressText != null) 'addressText': addressText,
    });
    return OrderRequest.fromJson(json);
  }

  /// GET /api/order-requests?requesterUserId=... — a Visitor's own submissions.
  Future<List<OrderRequest>> byRequester(String requesterUserId) async {
    final rows = await _getList('/api/order-requests?requesterUserId=${Uri.encodeQueryComponent(requesterUserId)}');
    return rows.map(OrderRequest.fromJson).toList();
  }

  /// POST /api/order-requests/:id/report — Visitor reports the assigned
  /// agent didn't work out. Admin will re-broadcast it.
  Future<OrderRequest> report(String id, {required String requesterUserId, String? reason}) async {
    final json = await _post('/api/order-requests/$id/report', {
      'requesterUserId': requesterUserId,
      if (reason != null) 'reason': reason,
    });
    return OrderRequest.fromJson(json);
  }

  // ── Agent ────────────────────────────────────────────────────────────
  /// GET /api/order-requests/agent/:agentId/available — broadcasting to this agent.
  Future<List<OrderRequest>> availableForAgent(String agentId) async {
    final rows = await _getList('/api/order-requests/agent/$agentId/available');
    return rows.map(OrderRequest.fromJson).toList();
  }

  /// GET /api/order-requests/agent/:agentId/assigned — this agent's claimed requests.
  Future<List<OrderRequest>> assignedToAgent(String agentId) async {
    final rows = await _getList('/api/order-requests/agent/$agentId/assigned');
    return rows.map(OrderRequest.fromJson).toList();
  }

  /// POST /api/order-requests/:id/claim — first agent to call this wins.
  Future<OrderRequest> claim(String id, {required String agentId, required String agentName, required String agentPhone}) async {
    final json = await _post('/api/order-requests/$id/claim', {
      'agentId': agentId,
      'agentName': agentName,
      'agentPhone': agentPhone,
    });
    return OrderRequest.fromJson(json);
  }

  /// POST /api/order-requests/:id/complete — the assigned agent closes the
  /// request out themselves once the work is done.
  Future<OrderRequest> complete(String id, {required String agentId}) async {
    final json = await _post('/api/order-requests/$id/complete', {
      'agentId': agentId,
    });
    return OrderRequest.fromJson(json);
  }

  /// POST /api/order-requests/:id/agent-report — the assigned agent flags
  /// that a confirmed request couldn't be worked out on their end (client
  /// unreachable, deal fell through, etc). Puts it back in front of Admin
  /// as disputed, same as the visitor's [report] — just from the agent's
  /// side, for when the agent (not the client) is the one who needs to
  /// raise it.
  Future<OrderRequest> agentReport(String id, {required String agentId, String? reason}) async {
    final json = await _post('/api/order-requests/$id/agent-report', {
      'agentId': agentId,
      if (reason != null) 'reason': reason,
    });
    return OrderRequest.fromJson(json);
  }

  // ── Admin ─────────────────────────────────────────────────────────────
  /// GET /api/order-requests/admin/broadcasting
  Future<List<OrderRequest>> adminBroadcasting() async {
    final rows = await _getList('/api/order-requests/admin/broadcasting');
    return rows.map(OrderRequest.fromJson).toList();
  }

  /// GET /api/order-requests/admin/confirmed
  Future<List<OrderRequest>> adminConfirmed() async {
    final rows = await _getList('/api/order-requests/admin/confirmed');
    return rows.map(OrderRequest.fromJson).toList();
  }

  /// GET /api/order-requests/admin/disputed
  Future<List<OrderRequest>> adminDisputed() async {
    final rows = await _getList('/api/order-requests/admin/disputed');
    return rows.map(OrderRequest.fromJson).toList();
  }

  /// POST /api/order-requests/:id/repost — re-broadcasts a disputed
  /// request to nearby agents again (same data, no re-filled form).
  Future<OrderRequest> repost(String id) async {
    final json = await _post('/api/order-requests/$id/repost', {});
    return OrderRequest.fromJson(json);
  }

  /// POST /api/order-requests/:id/close
  Future<OrderRequest> close(String id) async {
    final json = await _post('/api/order-requests/$id/close', {});
    return OrderRequest.fromJson(json);
  }

  // ── internals ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await http
          .post(_uri(path), headers: const {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const OrderRequestException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    http.Response res;
    try {
      res = await http.get(_uri(path)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const OrderRequestException("Couldn't reach the server. Check your connection and try again.");
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const OrderRequestException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw OrderRequestException(error ?? 'Something went wrong (${res.statusCode}).');
    }
    return (json as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const OrderRequestException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw OrderRequestException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
