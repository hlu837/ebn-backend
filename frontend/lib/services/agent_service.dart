import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/agent_account.dart';
import '../models/customer_note_entry.dart';

/// Thrown for any agent-account call the backend rejects (validation,
/// auth, network errors, etc). [message] is safe to show directly in a
/// SnackBar.
class AgentServiceException implements Exception {
  final String message;
  const AgentServiceException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/agents/:agentId/*` routes (wallet,
/// schedule, settings, membership, profile) plus `/api/support-tickets` —
/// mirrors [AuthService] / [SellRequestService]'s shape and conventions.
///
/// Base URL:
/// - Flutter web / desktop: `localhost` reaches the backend directly.
/// - Android emulator: change [baseUrl] to `http://10.0.2.2:4000`.
/// - Physical device / deployed: point it at your backend's real host.
class AgentService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mlmpropertyebn.vercel.app',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // ── Wallet ───────────────────────────────────────────────────────────

  /// GET /api/agents/:agentId/wallet
  Future<AgentWallet> getWallet(String agentId, {required String token}) async {
    final json = await _get('/api/agents/$agentId/wallet', token: token);
    return AgentWallet.fromJson(json);
  }

  /// POST /api/agents/:agentId/wallet/withdraw
  ///
  /// The payout destination is always the agent's saved bank details on
  /// the server (see PATCH .../settings) — there's no bankAccountLast4
  /// param here anymore, since accepting one from the client would let it
  /// override the destination with an arbitrary, unverified value.
  Future<AgentWalletTransaction> requestWithdrawal(
    String agentId, {
    required double amount,
    required String token,
  }) async {
    final json = await _post('/api/agents/$agentId/wallet/withdraw', {
      'amount': amount,
    }, token: token);
    return AgentWalletTransaction.fromJson(json);
  }

  // ── Schedule ─────────────────────────────────────────────────────────

  /// GET /api/agents/:agentId/schedule
  Future<List<AgentBooking>> getSchedule(String agentId, {required String token}) async {
    final rows = await _getList('/api/agents/$agentId/schedule', token: token);
    return rows.map(AgentBooking.fromJson).toList();
  }

  /// POST /api/agents/:agentId/schedule
  Future<AgentBooking> createBooking(
    String agentId, {
    required String clientName,
    required String propertyTitle,
    String? address,
    required DateTime startAt,
    int? durationMinutes,
    required String token,
  }) async {
    final json = await _post('/api/agents/$agentId/schedule', {
      'clientName': clientName,
      'propertyTitle': propertyTitle,
      if (address != null) 'address': address,
      'startAt': startAt.toIso8601String(),
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
    }, token: token);
    return AgentBooking.fromJson(json);
  }

  /// PATCH /api/agents/:agentId/schedule/:id
  Future<AgentBooking> updateBooking(
    String agentId,
    String bookingId, {
    DateTime? startAt,
    String? status,
    required String token,
  }) async {
    final json = await _patch('/api/agents/$agentId/schedule/$bookingId', {
      if (startAt != null) 'startAt': startAt.toIso8601String(),
      if (status != null) 'status': status,
    }, token: token);
    return AgentBooking.fromJson(json);
  }

  /// DELETE /api/agents/:agentId/schedule/:id
  Future<void> cancelBooking(String agentId, String bookingId, {required String token}) async {
    await _delete('/api/agents/$agentId/schedule/$bookingId', token: token);
  }

  // ── Settings ─────────────────────────────────────────────────────────

  /// GET /api/agents/:agentId/settings
  Future<AgentSettingsData> getSettings(String agentId, {required String token}) async {
    final json = await _get('/api/agents/$agentId/settings', token: token);
    return AgentSettingsData.fromJson(json);
  }

  /// PATCH /api/agents/:agentId/settings
  ///
  /// [bankAccountNumber] is the FULL number the user typed — it's sent up
  /// once, and the server only ever stores/returns the last 4 digits (see
  /// AgentSettingsData.bankAccountLast4 below).
  Future<AgentSettingsData> updateSettings(
    String agentId, {
    bool? notifyNewDispatches,
    bool? notifyChatMessages,
    bool? notifyPromotions,
    bool? notifyPayouts,
    String? language,
    String? bankName,
    String? bankAccountHolder,
    String? bankAccountNumber,
    required String token,
  }) async {
    final json = await _patch('/api/agents/$agentId/settings', {
      if (notifyNewDispatches != null) 'notifyNewDispatches': notifyNewDispatches,
      if (notifyChatMessages != null) 'notifyChatMessages': notifyChatMessages,
      if (notifyPromotions != null) 'notifyPromotions': notifyPromotions,
      if (notifyPayouts != null) 'notifyPayouts': notifyPayouts,
      if (language != null) 'language': language,
      if (bankName != null) 'bankName': bankName,
      if (bankAccountHolder != null) 'bankAccountHolder': bankAccountHolder,
      if (bankAccountNumber != null) 'bankAccountNumber': bankAccountNumber,
    }, token: token);
    return AgentSettingsData.fromJson(json);
  }

  // ── Membership ───────────────────────────────────────────────────────

  /// GET /api/agents/:agentId/membership
  Future<AgentMembershipData> getMembership(String agentId, {required String token}) async {
    final json = await _get('/api/agents/$agentId/membership', token: token);
    return AgentMembershipData.fromJson(json);
  }

  /// POST /api/agents/:agentId/membership/upgrade
  Future<AgentMembershipData> upgradeMembership(String agentId, {required String tier, required String token}) async {
    final json = await _post('/api/agents/$agentId/membership/upgrade', {'tier': tier}, token: token);
    return AgentMembershipData.fromJson(json);
  }

  // ── Profile (Visibility) ────────────────────────────────────────────

  /// GET /api/agents/:agentId/profile — public.
  Future<AgentProfileData> getProfile(String agentId, {String? token}) async {
    final json = await _get('/api/agents/$agentId/profile', token: token);
    return AgentProfileData.fromJson(json);
  }

  /// PATCH /api/agents/:agentId/profile
  Future<AgentProfileData> updateProfile(
    String agentId, {
    String? bio,
    String? city,
    List<String>? specialties,
    required String token,
  }) async {
    final json = await _patch('/api/agents/$agentId/profile', {
      if (bio != null) 'bio': bio,
      if (city != null) 'city': city,
      if (specialties != null) 'specialties': specialties,
    }, token: token);
    return AgentProfileData.fromJson(json);
  }

  /// POST /api/agents/:agentId/profile/boost
  Future<AgentProfileData> boostProfile(String agentId, {int days = 7, required String token}) async {
    final json = await _post('/api/agents/$agentId/profile/boost', {'days': days}, token: token);
    return AgentProfileData.fromJson(json);
  }

  // ── Support tickets ─────────────────────────────────────────────────

  /// POST /api/support-tickets
  Future<SupportTicket> submitSupportTicket({
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

  /// GET /api/support-tickets/me
  Future<List<SupportTicket>> mySupportTickets({required String token}) async {
    final rows = await _getList('/api/support-tickets/me', token: token);
    return rows.map(SupportTicket.fromJson).toList();
  }

  // ── Customer notes ───────────────────────────────────────────────────
  // A running, timestamped log per customer rather than a single
  // overwritable note — every call to a customer can be logged as its
  // own entry instead of replacing whatever was written last time.

  /// Every note entry this agent has ever written, across every customer,
  /// grouped by customer user id and newest-first within each group — one
  /// call to populate the whole Customers screen instead of one per row.
  /// Backed by `GET /api/agents/:agentId/customer-notes`.
  Future<Map<String, List<CustomerNoteEntry>>> fetchCustomerNotes(String agentId, {required String token}) async {
    final rows = await _getList('/api/agents/$agentId/customer-notes', token: token);
    final entries = rows.map(CustomerNoteEntry.fromJson).toList();
    final byCustomer = <String, List<CustomerNoteEntry>>{};
    for (final e in entries) {
      (byCustomer[e.customerUserId] ??= []).add(e);
    }
    return byCustomer;
  }

  /// Appends a new timestamped entry to one customer's note log — it
  /// never edits or replaces an earlier entry. Backed by
  /// `POST /api/agents/:agentId/customer-notes/:customerUserId/entries`.
  Future<CustomerNoteEntry> addCustomerNoteEntry(String agentId, String customerUserId, String body, {required String token}) async {
    final json = await _post('/api/agents/$agentId/customer-notes/$customerUserId/entries', {'body': body}, token: token);
    return CustomerNoteEntry.fromJson(json);
  }

  // ── Network (agent-to-agent referral program) ───────────────────────

  /// GET /api/agents/:agentId/network — this agent's "AGT-" referral
  /// code/link, their downline, and override commission totals earned
  /// from that downline. Separate from the Affiliater program.
  Future<AgentNetworkData> getNetwork(String agentId, {required String token}) async {
    final json = await _get('/api/agents/$agentId/network', token: token);
    return AgentNetworkData.fromJson(json);
  }

  // ── Broker Network directory ────────────────────────────────────────

  /// GET /api/agents?specialty=&city=&search=&excludeUserId=&userId= —
  /// public, no [token] needed: this is the Broker Network / map, browsed
  /// by visitors before they ever sign up. Pass [userId] alone to look up
  /// one specific agent (e.g. a listing's assigned broker) — returns a
  /// single-item list, or empty if that id isn't a real agent account.
  Future<List<Map<String, dynamic>>> fetchDirectory({
    String? specialty,
    String? city,
    String? search,
    String? excludeUserId,
    String? userId,
  }) async {
    final params = <String, String>{
      if (specialty != null && specialty.isNotEmpty) 'specialty': specialty,
      if (city != null && city.isNotEmpty) 'city': city,
      if (search != null && search.isNotEmpty) 'search': search,
      if (excludeUserId != null) 'excludeUserId': excludeUserId,
      if (userId != null) 'userId': userId,
    };
    final uri = _uri('/api/agents').replace(queryParameters: params.isEmpty ? null : params);
    http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AgentServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const AgentServiceException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw AgentServiceException(error ?? 'Something went wrong (${res.statusCode}).');
    }
    return (json as List).cast<Map<String, dynamic>>();
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
      throw const AgentServiceException("Couldn't reach the server. Check your connection and try again.");
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
      throw const AgentServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body, {String? token}) async {
    http.Response res;
    try {
      res = await http
          .put(_uri(path), headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AgentServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    http.Response res;
    try {
      res = await http.get(_uri(path), headers: _headers(token)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AgentServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<List<Map<String, dynamic>>> _getList(String path, {String? token}) async {
    http.Response res;
    try {
      res = await http.get(_uri(path), headers: _headers(token)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AgentServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const AgentServiceException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw AgentServiceException(error ?? 'Something went wrong (${res.statusCode}).');
    }
    return (json as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> _delete(String path, {String? token}) async {
    http.Response res;
    try {
      res = await http.delete(_uri(path), headers: _headers(token)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AgentServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      Map<String, dynamic>? json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        // ignore
      }
      throw AgentServiceException(json?['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AgentServiceException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AgentServiceException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
