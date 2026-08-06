import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/investor_network.dart';
import '../models/investor_wallet.dart';

/// Thrown for any investor-wallet call the backend rejects or that fails
/// to reach the server. [message] is safe to show directly in a SnackBar.
class InvestorWalletException implements Exception {
  final String message;
  const InvestorWalletException(this.message);

  @override
  String toString() => message;
}

/// Talks to `/api/investors/:investorId/wallet`. Every endpoint requires
/// a Bearer token — the investor themself or an admin, matching the
/// backend's `requireSelfOrAdmin` check. Crediting a payout is admin-only.
class InvestorWalletService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<InvestorWalletSummary> getWallet({required String token, required String investorId}) async {
    final res = await _get('/api/investors/$investorId/wallet', token: token);
    return InvestorWalletSummary.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  Future<InvestorWalletTransaction> withdraw({
    required String token,
    required String investorId,
    required double amount,
    String? bankAccountLast4,
  }) async {
    final res = await _post(
      '/api/investors/$investorId/wallet/withdraw',
      token: token,
      body: {
        'amount': amount,
        if (bankAccountLast4 != null && bankAccountLast4.isNotEmpty) 'bankAccountLast4': bankAccountLast4,
      },
    );
    return InvestorWalletTransaction.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  Future<InvestorWalletTransaction> creditPayout({
    required String token,
    required String investorId,
    required double amount,
    required String label,
    String? commitmentId,
  }) async {
    final res = await _post(
      '/api/investors/$investorId/wallet/payout',
      token: token,
      body: {
        'amount': amount,
        'label': label,
        if (commitmentId != null) 'commitmentId': commitmentId,
      },
    );
    return InvestorWalletTransaction.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  Future<InvestorWalletTransaction> clearTransaction({
    required String token,
    required String investorId,
    required String txId,
  }) async {
    final res = await _post('/api/investors/$investorId/wallet/transactions/$txId/clear', token: token);
    return InvestorWalletTransaction.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  // ── Network (investor-to-investor referral program) ───────────────────

  /// GET /api/investors/:investorId/network — this investor's "INV-"
  /// referral code/link, their downline, and reward totals earned from
  /// it. Separate from the agent network and Affiliater program.
  Future<InvestorNetworkData> getNetwork({required String token, required String investorId}) async {
    final res = await _get('/api/investors/$investorId/network', token: token);
    return InvestorNetworkData.fromJson(jsonDecode(res) as Map<String, dynamic>);
  }

  // ── internals ────────────────────────────────────────────────────────

  Future<String> _get(String path, {required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri(path), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const InvestorWalletException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<String> _post(String path, {Map<String, dynamic>? body, required String token}) async {
    http.Response res;
    final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
    try {
      res = await http
          .post(_uri(path), headers: headers, body: jsonEncode(body ?? {}))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const InvestorWalletException("Couldn't reach the server. Check your connection and try again.");
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
      throw InvestorWalletException(message);
    }
    return res.body;
  }
}
