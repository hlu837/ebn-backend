import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/house_property_details.dart';
import '../models/machinery_details.dart';
import '../models/sell_request.dart';
import '../models/vehicle_details.dart';

/// Thrown for any sell-request call the backend rejects (validation,
/// network errors, etc). [message] is safe to show directly in a SnackBar.
class SellRequestException implements Exception {
  final String message;
  const SellRequestException(this.message);

  @override
  String toString() => message;
}

/// Thrown specifically when a claim loses a race to another agent (the
/// backend answers 409 when the row is no longer `open_to_brokers`) — kept
/// separate from [SellRequestException] so callers can special-case it
/// instead of showing a generic error.
class SellRequestConflictException implements Exception {
  final String message;
  const SellRequestConflictException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/sell-requests/*` routes — mirrors
/// [AuthService]'s shape/conventions.
///
/// Base URL:
/// - Flutter web / desktop: `localhost` reaches the backend directly.
/// - Android emulator: change [baseUrl] to `http://10.0.2.2:4000`.
/// - Physical device / deployed: point it at your backend's real host.
class SellRequestService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // ── Visitor ──────────────────────────────────────────────────────────
  /// POST /api/sell-requests — submits a new property for sale.
  Future<SellRequest> submit({
    required String ownerUserId,
    required String ownerName,
    required String ownerPhone,
    required String category,
    required String title,
    required String description,
    required double askingPrice,
    required String city,
    required String addressLine,
    HousePropertyDetails? houseDetails,
    VehicleDetails? vehicleDetails,
    MachineryDetails? machineryDetails,
  }) async {
    final json = await _post('/api/sell-requests', {
      'ownerUserId': ownerUserId,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'category': category,
      'title': title,
      'description': description,
      'askingPrice': askingPrice,
      'city': city,
      'addressLine': addressLine,
      if (houseDetails != null) 'houseDetails': houseDetails.toJson(),
      if (vehicleDetails != null) 'vehicleDetails': vehicleDetails.toJson(),
      if (machineryDetails != null) 'machineryDetails': machineryDetails.toJson(),
    });
    return SellRequest.fromJson(json);
  }

  // ── Agent: self-listing ─────────────────────────────────────────────
  /// POST /api/sell-requests/agent-listing — an Agent submits a property
  /// they own themselves: same fields as [submit] plus the media/notes a
  /// report would normally only carry. Same 100 ETB fee. Admin's approval
  /// publishes it directly under this Agent's name — no claim/inspection
  /// hand-off to another Agent.
  Future<SellRequest> submitAgentListing({
    required String ownerUserId,
    required String ownerName,
    required String ownerPhone,
    required String category,
    required String title,
    required String description,
    required double askingPrice,
    required String city,
    required String addressLine,
    required String agentId,
    required String agentName,
    required List<ReportMediaItem> media,
    required String notes,
    HousePropertyDetails? houseDetails,
    VehicleDetails? vehicleDetails,
    MachineryDetails? machineryDetails,
  }) async {
    final json = await _post('/api/sell-requests/agent-listing', {
      'ownerUserId': ownerUserId,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'category': category,
      'title': title,
      'description': description,
      'askingPrice': askingPrice,
      'city': city,
      'addressLine': addressLine,
      'agentId': agentId,
      'agentName': agentName,
      'media': media.map((m) => m.toJson()).toList(),
      'notes': notes,
      if (houseDetails != null) 'houseDetails': houseDetails.toJson(),
      if (vehicleDetails != null) 'vehicleDetails': vehicleDetails.toJson(),
      if (machineryDetails != null) 'machineryDetails': machineryDetails.toJson(),
    });
    return SellRequest.fromJson(json);
  }

  /// GET /api/sell-requests?ownerUserId=... — a Visitor's own submissions.
  Future<List<SellRequest>> byOwner(String ownerUserId) async {
    final rows = await _getList('/api/sell-requests?ownerUserId=${Uri.encodeQueryComponent(ownerUserId)}');
    return rows.map(SellRequest.fromJson).toList();
  }

  // ── Admin: submission screening ─────────────────────────────────────
  /// GET /api/sell-requests/pending-submissions
  Future<List<SellRequest>> pendingSubmissions() async {
    final rows = await _getList('/api/sell-requests/pending-submissions');
    return rows.map(SellRequest.fromJson).toList();
  }

  /// POST /api/sell-requests/:id/approve-submission — [listedAssetId] only
  /// matters for an Agent self-listing, which publishes immediately.
  Future<SellRequest> approveSubmission(String id, {String? listedAssetId}) async {
    final json = await _post('/api/sell-requests/$id/approve-submission', {
      if (listedAssetId != null) 'listedAssetId': listedAssetId,
    });
    return SellRequest.fromJson(json);
  }

  /// POST /api/sell-requests/:id/reject-submission
  Future<SellRequest> rejectSubmission(String id, {String? reason}) async {
    final json = await _post('/api/sell-requests/$id/reject-submission', {
      if (reason != null) 'reason': reason,
    });
    return SellRequest.fromJson(json);
  }

  // ── Agent/Broker: claim ──────────────────────────────────────────────
  /// GET /api/sell-requests/open
  Future<List<SellRequest>> openToBrokers() async {
    final rows = await _getList('/api/sell-requests/open');
    return rows.map(SellRequest.fromJson).toList();
  }

  /// GET /api/sell-requests/agent/:agentId/broadcasting — nearby requests
  /// this agent hasn't claimed (or lost) yet.
  Future<List<SellRequest>> broadcastingForAgent(String agentId) async {
    final rows = await _getList('/api/sell-requests/agent/$agentId/broadcasting');
    return rows.map(SellRequest.fromJson).toList();
  }

  /// GET /api/sell-requests/agent/:agentId/claimed
  Future<List<SellRequest>> claimedByAgent(String agentId) async {
    final rows = await _getList('/api/sell-requests/agent/$agentId/claimed');
    return rows.map(SellRequest.fromJson).toList();
  }

  /// GET /api/sell-requests/agent/:agentId/pending-reports
  Future<List<SellRequest>> pendingReportsByAgent(String agentId) async {
    final rows = await _getList('/api/sell-requests/agent/$agentId/pending-reports');
    return rows.map(SellRequest.fromJson).toList();
  }

  /// GET /api/sell-requests/agent/:agentId/listed
  Future<List<SellRequest>> listedByAgent(String agentId) async {
    final rows = await _getList('/api/sell-requests/agent/$agentId/listed');
    return rows.map(SellRequest.fromJson).toList();
  }

  /// POST /api/sell-requests/:id/claim — first-come-first-served; throws
  /// [SellRequestConflictException] if someone else already claimed it.
  Future<SellRequest> claim(String id, {required String agentId, required String agentName}) async {
    final json = await _post(
      '/api/sell-requests/$id/claim',
      {'agentId': agentId, 'agentName': agentName},
      conflictMessage: 'Someone else just claimed this one.',
    );
    return SellRequest.fromJson(json);
  }

  // ── Agent/Broker: inspection report ─────────────────────────────────
  /// POST /api/sell-requests/:id/report
  Future<SellRequest> submitReport(
    String id, {
    required String agentId,
    required List<ReportMediaItem> media,
    required String notes,
  }) async {
    final json = await _post('/api/sell-requests/$id/report', {
      'agentId': agentId,
      'media': media.map((m) => m.toJson()).toList(),
      'notes': notes,
    });
    return SellRequest.fromJson(json);
  }

  // ── Admin: report screening → publish ───────────────────────────────
  /// GET /api/sell-requests/pending-reports
  Future<List<SellRequest>> pendingReports() async {
    final rows = await _getList('/api/sell-requests/pending-reports');
    return rows.map(SellRequest.fromJson).toList();
  }

  /// POST /api/sell-requests/:id/approve-report
  Future<SellRequest> approveReport(String id, {required String listedAssetId}) async {
    final json = await _post('/api/sell-requests/$id/approve-report', {
      'listedAssetId': listedAssetId,
    });
    return SellRequest.fromJson(json);
  }

  /// POST /api/sell-requests/:id/reject-report
  Future<SellRequest> rejectReport(String id, {String? reason}) async {
    final json = await _post('/api/sell-requests/$id/reject-report', {
      if (reason != null) 'reason': reason,
    });
    return SellRequest.fromJson(json);
  }

  // ── internals ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? conflictMessage,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(_uri(path), headers: const {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const SellRequestException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res, conflictMessage: conflictMessage);
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    http.Response res;
    try {
      res = await http.get(_uri(path)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const SellRequestException("Couldn't reach the server. Check your connection and try again.");
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const SellRequestException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw SellRequestException(error ?? 'Something went wrong (${res.statusCode}).');
    }
    return (json as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> _decode(http.Response res, {String? conflictMessage}) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const SellRequestException('Unexpected response from the server.');
    }
    if (res.statusCode == 409 && conflictMessage != null) {
      throw SellRequestConflictException(conflictMessage);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SellRequestException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
