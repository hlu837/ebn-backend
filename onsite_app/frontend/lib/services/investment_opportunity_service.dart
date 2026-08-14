import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/investment_opportunity.dart';

/// Thrown for any investment-opportunities call the backend rejects or
/// that fails to reach the server. [message] is safe to show directly in
/// a SnackBar.
class InvestmentOpportunityException implements Exception {
  final String message;
  const InvestmentOpportunityException(this.message);

  @override
  String toString() => message;
}

/// Talks to `/api/investment-opportunities`. GET / is public (open deals
/// first, no token needed) — used by the investor feed. GET /all,
/// POST, PATCH, DELETE require an admin token, matching the backend's
/// `requireAuth` + admin-role check.
class InvestmentOpportunityService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mlmpropertyebn.vercel.app',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// Investor-facing feed: open deals first, then newest first.
  Future<List<InvestmentOpportunity>> list() async {
    final res = await _get('/api/investment-opportunities');
    return (jsonDecode(res) as List)
        .map((e) => InvestmentOpportunity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Admin management list: every opportunity, newest first.
  Future<List<InvestmentOpportunity>> listAll({required String token}) async {
    final res = await _get('/api/investment-opportunities/all', token: token);
    return (jsonDecode(res) as List)
        .map((e) => InvestmentOpportunity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InvestmentOpportunity> create({
    required String token,
    required String title,
    required String description,
    required String category,
    required double targetAmount,
    required double minInvestment,
    required double expectedReturnPct,
    required int termMonths,
    String? imageUrl,
  }) async {
    final res = await _send(
      'POST',
      '/api/investment-opportunities',
      body: {
        'title': title,
        'description': description,
        'category': category,
        'targetAmount': targetAmount,
        'minInvestment': minInvestment,
        'expectedReturnPct': expectedReturnPct,
        'termMonths': termMonths,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      },
      token: token,
    );
    return InvestmentOpportunity.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  Future<InvestmentOpportunity> updateStatus({
    required String token,
    required String id,
    required String status,
  }) async {
    final res = await _send(
      'PATCH',
      '/api/investment-opportunities/$id',
      body: {'status': status},
      token: token,
    );
    return InvestmentOpportunity.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  Future<void> delete({required String token, required String id}) async {
    await _send('DELETE', '/api/investment-opportunities/$id', token: token);
  }

  // ── internals ────────────────────────────────────────────────────────

  Future<String> _get(String path, {String? token}) async {
    http.Response res;
    try {
      final headers = token != null ? {'Authorization': 'Bearer $token'} : null;
      res = await http.get(_uri(path), headers: headers).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const InvestmentOpportunityException(
          "Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<String> _send(String method, String path, {Map<String, dynamic>? body, required String token}) async {
    http.Response res;
    final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
    try {
      switch (method) {
        case 'POST':
          res = await http
              .post(_uri(path), headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 15));
          break;
        case 'PATCH':
          res = await http
              .patch(_uri(path), headers: headers, body: jsonEncode(body ?? {}))
              .timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          res = await http.delete(_uri(path), headers: headers).timeout(const Duration(seconds: 15));
          break;
        default:
          throw ArgumentError('Unsupported method: $method');
      }
    } catch (_) {
      throw const InvestmentOpportunityException(
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
      throw InvestmentOpportunityException(message);
    }
    return res.body;
  }
}
