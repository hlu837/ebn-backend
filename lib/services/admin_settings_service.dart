import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/admin_settings_models.dart';
import '../models/membership_pricing_models.dart';

/// Thrown for any admin-settings call the backend rejects. [message] is
/// safe to show directly in a SnackBar.
class AdminSettingsServiceException implements Exception {
  final String message;
  const AdminSettingsServiceException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/admin-settings/*` routes — mirrors
/// [AdminService]'s shape and conventions.
class AdminSettingsService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mlmpropertyebn.vercel.app',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // ── Categories ──────────────────────────────────────────────────────

  Future<List<AdminCategory>> fetchCategories({required String token}) async {
    final json = await _get('/api/admin-settings/categories', token: token);
    final rows =
        (json['categories'] as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(AdminCategory.fromJson).toList();
  }

  Future<AdminCategory> createCategory({
    required String label,
    required int listingFeeCents,
    required String token,
  }) async {
    final json = await _post(
      '/api/admin-settings/categories',
      {'label': label, 'listingFeeCents': listingFeeCents},
      token: token,
    );
    return AdminCategory.fromJson(json);
  }

  Future<AdminCategory> updateCategory(
    String id, {
    String? label,
    int? listingFeeCents,
    bool? isActive,
    required String token,
  }) async {
    final json = await _patch(
      '/api/admin-settings/categories/$id',
      {
        if (label != null) 'label': label,
        if (listingFeeCents != null) 'listingFeeCents': listingFeeCents,
        if (isActive != null) 'isActive': isActive,
      },
      token: token,
    );
    return AdminCategory.fromJson(json);
  }

  Future<List<AdminCategory>> reorderCategories(List<String> orderedIds,
      {required String token}) async {
    final json = await _put(
        '/api/admin-settings/categories/reorder', {'orderedIds': orderedIds},
        token: token);
    final rows =
        (json['categories'] as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(AdminCategory.fromJson).toList();
  }

  Future<void> archiveCategory(String id, {required String token}) async {
    await _delete('/api/admin-settings/categories/$id', token: token);
  }

  // ── Cities ──────────────────────────────────────────────────────────

  Future<List<AdminCity>> fetchCities({required String token}) async {
    final json = await _get('/api/admin-settings/cities', token: token);
    final rows = (json['cities'] as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(AdminCity.fromJson).toList();
  }

  Future<AdminCity> createCity(
      {required String name, bool isLive = true, required String token}) async {
    final json = await _post(
        '/api/admin-settings/cities', {'name': name, 'isLive': isLive},
        token: token);
    return AdminCity.fromJson(json);
  }

  Future<AdminCity> updateCity(String id,
      {String? name, bool? isLive, required String token}) async {
    final json = await _patch(
      '/api/admin-settings/cities/$id',
      {if (name != null) 'name': name, if (isLive != null) 'isLive': isLive},
      token: token,
    );
    return AdminCity.fromJson(json);
  }

  Future<void> removeCity(String id, {required String token}) async {
    await _delete('/api/admin-settings/cities/$id', token: token);
  }

  // ── FAQ ─────────────────────────────────────────────────────────────

  Future<List<AdminFaqEntry>> fetchFaq({required String token}) async {
    final json = await _get('/api/admin-settings/faq', token: token);
    final rows = (json['faq'] as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(AdminFaqEntry.fromJson).toList();
  }

  Future<AdminFaqEntry> createFaq(
      {required String question,
      required String answer,
      required String token}) async {
    final json = await _post(
        '/api/admin-settings/faq', {'question': question, 'answer': answer},
        token: token);
    return AdminFaqEntry.fromJson(json);
  }

  Future<AdminFaqEntry> updateFaq(
    String id, {
    String? question,
    String? answer,
    bool? isActive,
    required String token,
  }) async {
    final json = await _patch(
      '/api/admin-settings/faq/$id',
      {
        if (question != null) 'question': question,
        if (answer != null) 'answer': answer,
        if (isActive != null) 'isActive': isActive,
      },
      token: token,
    );
    return AdminFaqEntry.fromJson(json);
  }

  Future<void> removeFaq(String id, {required String token}) async {
    await _delete('/api/admin-settings/faq/$id', token: token);
  }

  // ── Content pages (About Us / Features) ────────────────────────────

  Future<List<AdminContentPage>> fetchContentPages(
      {required String token}) async {
    final json = await _get('/api/admin-settings/content-pages', token: token);
    final rows = (json['pages'] as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(AdminContentPage.fromJson).toList();
  }

  Future<AdminContentPage> updateContentPage(
    String pageKey, {
    required String title,
    required String body,
    required String token,
  }) async {
    final json = await _put('/api/admin-settings/content-pages/$pageKey',
        {'title': title, 'body': body},
        token: token);
    return AdminContentPage.fromJson(json);
  }

  // ── Admin accounts ──────────────────────────────────────────────────

  Future<List<AdminAccountSummary>> fetchAdmins({required String token}) async {
    final json = await _get('/api/admin-settings/admins', token: token);
    final rows = (json['admins'] as List<dynamic>).cast<Map<String, dynamic>>();
    return rows.map(AdminAccountSummary.fromJson).toList();
  }

  Future<AdminAccountSummary> inviteAdmin({
    required String fullName,
    required String email,
    required String password,
    String? phone,
    required String token,
  }) async {
    final json = await _post(
      '/api/admin-settings/admins',
      {
        'fullName': fullName,
        'email': email,
        'password': password,
        if (phone != null) 'phone': phone
      },
      token: token,
    );
    return AdminAccountSummary.fromJson(json);
  }

  Future<void> revokeAdmin(String id, {required String token}) async {
    await _delete('/api/admin-settings/admins/$id', token: token);
  }

  // ── General settings ────────────────────────────────────────────────

  Future<AdminGeneralSettings> fetchGeneralSettings(
      {required String token}) async {
    final json = await _get('/api/admin-settings/general', token: token);
    return AdminGeneralSettings.fromJson(json);
  }

  Future<AdminGeneralSettings> updateGeneralSettings({
    String? appName,
    String? logoUrl,
    String? supportEmail,
    String? supportPhone,
    required String token,
  }) async {
    final json = await _patch(
      '/api/admin-settings/general',
      {
        if (appName != null) 'appName': appName,
        if (logoUrl != null) 'logoUrl': logoUrl,
        if (supportEmail != null) 'supportEmail': supportEmail,
        if (supportPhone != null) 'supportPhone': supportPhone,
      },
      token: token,
    );
    return AdminGeneralSettings.fromJson(json);
  }

  // ── Membership Pricing ────────────────────────────────────────────────

  /// GET /api/admin-settings/membership-pricing — fetches all tier prices
  Future<MembershipPricing> fetchMembershipPricing(
      {required String token}) async {
    final json =
        await _get('/api/admin-settings/membership-pricing', token: token);
    return MembershipPricing.fromJson(json);
  }

  /// PATCH /api/admin-settings/membership-pricing/:role/:tier
  Future<MembershipTierPrice> updateMembershipPrice({
    required String role,
    required String tier,
    required double monthlyFeeEtb,
    required String token,
  }) async {
    final json = await _patch(
      '/api/admin-settings/membership-pricing/$role/$tier',
      {'monthlyFeeEtb': monthlyFeeEtb},
      token: token,
    );
    return MembershipTierPrice.fromJson(json);
  }

  // ── HTTP helpers — mirrors AdminService's _get/_patch/_decode ────────

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _get(String path, {String? token}) async {
    http.Response res;
    try {
      res = await http
          .get(_uri(path), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AdminSettingsServiceException(
          "Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {String? token}) async {
    http.Response res;
    try {
      res = await http
          .post(_uri(path), headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AdminSettingsServiceException(
          "Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body,
      {String? token}) async {
    http.Response res;
    try {
      res = await http
          .patch(_uri(path), headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AdminSettingsServiceException(
          "Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body,
      {String? token}) async {
    http.Response res;
    try {
      res = await http
          .put(_uri(path), headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AdminSettingsServiceException(
          "Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _delete(String path, {String? token}) async {
    http.Response res;
    try {
      res = await http
          .delete(_uri(path), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AdminSettingsServiceException(
          "Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(res.body.isEmpty ? '{}' : res.body);
      json = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      throw const AdminSettingsServiceException(
          'Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AdminSettingsServiceException(json['error'] as String? ??
          'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
