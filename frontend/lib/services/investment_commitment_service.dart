import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/investment_commitment.dart';

/// Thrown for any investment-commitment call the backend rejects or that
/// fails to reach the server. [message] is safe to show directly in a
/// SnackBar.
class InvestmentCommitmentException implements Exception {
  final String message;
  const InvestmentCommitmentException(this.message);

  @override
  String toString() => message;
}

/// Talks to `/api/investment-commitments`. All endpoints require a
/// Bearer token — POST/me are investor-only, pending/approve/reject are
/// admin-only, matching the backend's `requireRole` checks.
class InvestmentCommitmentService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<InvestmentCommitment> create({
    required String token,
    required String opportunityId,
    required double amount,
  }) async {
    final res = await _send(
      'POST',
      '/api/investment-commitments',
      body: {'opportunityId': opportunityId, 'amount': amount},
      token: token,
    );
    return InvestmentCommitment.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  /// This investor's full commitment history, newest first.
  Future<List<InvestmentCommitment>> listMine({required String token}) async {
    final res = await _get('/api/investment-commitments/me', token: token);
    return (jsonDecode(res) as List)
        .map((e) => InvestmentCommitment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Admin queue — every pending commitment.
  Future<List<InvestmentCommitment>> listPending({required String token}) async {
    final res = await _get('/api/investment-commitments/pending', token: token);
    return (jsonDecode(res) as List)
        .map((e) => InvestmentCommitment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Admin: every confirmed commitment (active investor holding).
  Future<List<InvestmentCommitment>> listConfirmed({required String token}) async {
    final res = await _get('/api/investment-commitments/confirmed', token: token);
    return (jsonDecode(res) as List)
        .map((e) => InvestmentCommitment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InvestmentCommitment> approve({required String token, required String id, String? adminNote}) async {
    final res = await _send(
      'POST',
      '/api/investment-commitments/$id/approve',
      body: {if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote},
      token: token,
    );
    return InvestmentCommitment.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  Future<InvestmentCommitment> reject({required String token, required String id, String? adminNote}) async {
    final res = await _send(
      'POST',
      '/api/investment-commitments/$id/reject',
      body: {if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote},
      token: token,
    );
    return InvestmentCommitment.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  // ── internals ────────────────────────────────────────────────────────

  Future<String> _get(String path, {required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri(path), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const InvestmentCommitmentException(
          "Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<String> _send(String method, String path, {Map<String, dynamic>? body, required String token}) async {
    http.Response res;
    final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
    try {
      res = await http
          .post(_uri(path), headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const InvestmentCommitmentException(
          "Couldn't reach the server. Check your connection and try again.");
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
      throw InvestmentCommitmentException(message);
    }
    return res.body;
  }
}
