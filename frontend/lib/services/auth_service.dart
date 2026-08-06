import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_response.dart';
import '../models/user_role.dart';

/// Thrown for any signup/signin failure the backend reports (bad
/// credentials, duplicate email, validation errors, network errors, etc).
/// [message] is safe to show directly in a SnackBar.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend in `/backend` (`/api/auth/*`) — replaces
/// [MockAuthService] now that the server actually persists users and
/// checks passwords.
///
/// Base URL:
/// - Flutter web / desktop: `localhost` reaches the backend directly.
/// - Android emulator: change [baseUrl] to `http://10.0.2.2:4000`.
/// - Physical device / deployed: point it at your backend's real host.
class AuthService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// POST /api/auth/signup — registers a new account and returns it
  /// already signed in (with a token).
  Future<AppUser> signUp({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    String? phone,
    String? agencyOrLicense,
    bool interestedInFractionalInvesting = false,
    String? referralCode,
    // Separate from [referralCode] (the Affiliater program's code): this
    // is an "AGT-" code from another *agent's* network link, only
    // meaningful when role is agent. Keeping the two params distinct
    // means an agent signup link can never accidentally credit the
    // affiliate program, or vice versa.
    String? agentReferralCode,
    // Same idea as [agentReferralCode] but for the investor network: an
    // "INV-" code from another *investor's* referral link, only
    // meaningful when role is investor. Kept distinct from both
    // [referralCode] and [agentReferralCode] so an investor signup link
    // can never accidentally credit the wrong program.
    String? investorReferralCode,
  }) async {
    final res = await _post('/api/auth/signup', {
      'fullName': fullName.trim(),
      'email': email.trim(),
      'password': password,
      'role': role.apiValue,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (agencyOrLicense != null && agencyOrLicense.trim().isNotEmpty)
        'agencyOrLicense': agencyOrLicense.trim(),
      'interestedInFractionalInvesting': interestedInFractionalInvesting,
      if (referralCode != null && referralCode.trim().isNotEmpty) 'referralCode': referralCode.trim(),
      if (agentReferralCode != null && agentReferralCode.trim().isNotEmpty)
        'agentReferralCode': agentReferralCode.trim(),
      if (investorReferralCode != null && investorReferralCode.trim().isNotEmpty)
        'investorReferralCode': investorReferralCode.trim(),
    });
    return AppUser.fromJson(res['user'] as Map<String, dynamic>, token: res['token'] as String?);
  }

  /// POST /api/auth/signin — plain email + password login. Used by the
  /// public smart-router [LoginScreen]; whatever role the account was
  /// saved under is returned so the caller can route accordingly.
  Future<AppUser> login({required String email, required String password}) async {
    final res = await _post('/api/auth/signin', {
      'email': email.trim(),
      'password': password,
    });
    return AppUser.fromJson(res['user'] as Map<String, dynamic>, token: res['token'] as String?);
  }

  /// Explicit-role sign in — used only by the Admin portal. Authenticates
  /// exactly like [login], but additionally rejects the attempt if the
  /// account's saved role doesn't match [role] — an account's admin
  /// status shouldn't be reachable just by guessing right on this form.
  Future<AppUser> signIn({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final user = await login(email: email, password: password);
    if (user.role != role) {
      throw AuthException('This account is not registered as ${role.label}.');
    }
    return user;
  }

  /// GET /api/auth/me — resolves the current user from a saved token, so a
  /// session can be restored without re-prompting for a password.
  Future<AppUser> me(String token) async {
    final res = await _get('/api/auth/me', token: token);
    return AppUser.fromJson(res['user'] as Map<String, dynamic>, token: token);
  }

  /// PATCH /api/auth/me/location — Agent-only. Records where they
  /// currently are so order requests can be broadcast to whoever's nearby.
  Future<AppUser> updateAgentLocation({
    required String token,
    required double latitude,
    required double longitude,
  }) async {
    final res = await _patch('/api/auth/me/location', {'latitude': latitude, 'longitude': longitude}, token: token);
    return AppUser.fromJson(res['user'] as Map<String, dynamic>, token: token);
  }

  /// PATCH /api/auth/me/location with both fields null — the "go offline"
  /// counterpart to [updateAgentLocation]. Clearing the location is what
  /// actually stops findNearbyAgents from broadcasting new requests to this
  /// agent, since there's no separate online/offline flag on the backend.
  Future<AppUser> clearAgentLocation({required String token}) async {
    final res = await _patch('/api/auth/me/location', {'latitude': null, 'longitude': null}, token: token);
    return AppUser.fromJson(res['user'] as Map<String, dynamic>, token: token);
  }

  /// PATCH /api/auth/me — updates the caller's own name/phone. Used by the
  /// various "Account Settings" screens (email is not editable here).
  Future<AppUser> updateProfile({
    required String token,
    String? fullName,
    String? phone,
  }) async {
    final res = await _patch('/api/auth/me', {
      if (fullName != null) 'fullName': fullName,
      if (phone != null) 'phone': phone,
    }, token: token);
    return AppUser.fromJson(res['user'] as Map<String, dynamic>, token: token);
  }

  // ── internals ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body, {String? token}) async {
    http.Response res;
    try {
      res = await http
          .patch(
            _uri(path),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AuthException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await http
          .post(_uri(path), headers: const {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AuthException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    http.Response res;
    try {
      res = await http.get(
        _uri(path),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AuthException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AuthException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AuthException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
