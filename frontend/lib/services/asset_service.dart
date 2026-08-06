import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/asset.dart';

/// Thrown for any assets call the backend rejects (validation, network
/// errors, etc). [message] is safe to show directly in a SnackBar.
class AssetException implements Exception {
  final String message;
  const AssetException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/assets/*` routes — mirrors
/// [SellRequestService]'s shape/conventions.
///
/// Base URL:
/// - Flutter web / desktop: `localhost` reaches the backend directly.
/// - Android emulator: change [baseUrl] to `http://10.0.2.2:4000`.
/// - Physical device / deployed: point it at your backend's real host.
class AssetService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// GET /api/assets — the visitor's listing feed (Top Picks, category
  /// tabs, search). Defaults to only `active` listings server-side; pass
  /// [status] (e.g. `'all'`) for an Admin view that needs every status.
  Future<List<Asset>> fetchAssets({
    AssetCategorySlug? category,
    String? city,
    String? query,
    int? limit,
    String? status,
  }) async {
    final params = <String, String>{
      if (category != null) 'category': category.slug,
      if (city != null && city.isNotEmpty) 'city': city,
      if (query != null && query.isNotEmpty) 'q': query,
      if (limit != null) 'limit': '$limit',
      if (status != null) 'status': status,
    };
    final rows = await _getList('/api/assets', params);
    return rows.map(Asset.fromJson).toList();
  }

  /// GET /api/assets/broker/:brokerId — every listing by one broker
  /// (any status), used on a broker's own profile page.
  Future<List<Asset>> fetchByBroker(String brokerId) async {
    final rows = await _getList('/api/assets/broker/$brokerId', const {});
    return rows.map(Asset.fromJson).toList();
  }

  /// GET /api/assets/:id — a single listing's full detail.
  Future<Asset> fetchById(String id) async {
    final json = await _get('/api/assets/$id');
    return Asset.fromJson(json);
  }

  /// POST /api/assets — creates a real, persisted listing. Used by Admin
  /// when publishing an approved inspection report (see
  /// `SellRequestController.adminApproveReport`) — this is the only place
  /// a listing is meant to come from; the visitor app never calls this.
  Future<Asset> createAsset({
    required String title,
    required double priceAmount,
    required AssetCategorySlug category,
    String priceCurrency = 'ETB',
    AssetStatus status = AssetStatus.active,
    String? addressLine,
    String? city,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? attributes,
    String? imageUrl,
    String? postedLabel,
    String? brokerId,
    double? rating,
    int? reviewCount,
    double? roiPercent,
  }) async {
    final json = await _post('/api/assets', {
      'title': title,
      'priceAmount': priceAmount,
      'priceCurrency': priceCurrency,
      'categorySlug': category.slug,
      'status': _statusToApi(status),
      if (addressLine != null) 'addressLine': addressLine,
      if (city != null) 'city': city,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (attributes != null) 'attributes': attributes,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (postedLabel != null) 'postedLabel': postedLabel,
      if (brokerId != null) 'brokerId': brokerId,
      if (rating != null) 'rating': rating,
      if (reviewCount != null) 'reviewCount': reviewCount,
      if (roiPercent != null) 'roiPercent': roiPercent,
    });
    return Asset.fromJson(json);
  }

  /// PATCH /api/assets/:id — partial update (e.g. Admin editing a
  /// listing's title/price/address, or changing its status). Only pass
  /// the fields that changed; omitted ones are left alone server-side.
  Future<Asset> updateAsset(
    String id, {
    String? title,
    double? priceAmount,
    String? priceCurrency,
    AssetCategorySlug? category,
    AssetStatus? status,
    String? addressLine,
    String? city,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? attributes,
    String? imageUrl,
    String? postedLabel,
  }) async {
    final json = await _patch('/api/assets/$id', {
      if (title != null) 'title': title,
      if (priceAmount != null) 'priceAmount': priceAmount,
      if (priceCurrency != null) 'priceCurrency': priceCurrency,
      if (category != null) 'categorySlug': category.slug,
      if (status != null) 'status': _statusToApi(status),
      if (addressLine != null) 'addressLine': addressLine,
      if (city != null) 'city': city,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (attributes != null) 'attributes': attributes,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (postedLabel != null) 'postedLabel': postedLabel,
    });
    return Asset.fromJson(json);
  }

  /// DELETE /api/assets/:id — Admin removing a listing outright.
  Future<void> deleteAsset(String id) async {
    http.Response res;
    try {
      res = await http.delete(_uri('/api/assets/$id')).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AssetException("Couldn't reach the server. Check your connection and try again.");
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      dynamic json;
      try {
        json = jsonDecode(res.body);
      } catch (_) {
        json = null;
      }
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw AssetException(error ?? 'Something went wrong (${res.statusCode}).');
    }
  }

  static String _statusToApi(AssetStatus status) {
    switch (status) {
      case AssetStatus.draft:
        return 'draft';
      case AssetStatus.active:
        return 'active';
      case AssetStatus.underInspection:
        return 'under_inspection';
      case AssetStatus.sold:
        return 'sold';
      case AssetStatus.archived:
        return 'archived';
    }
  }

  // ── internals ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path) async {
    http.Response res;
    try {
      res = await http.get(_uri(path)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AssetException("Couldn't reach the server. Check your connection and try again.");
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const AssetException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw AssetException(error ?? 'Something went wrong (${res.statusCode}).');
    }
    return json as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await http
          .post(_uri(path), headers: const {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AssetException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await http
          .patch(_uri(path), headers: const {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AssetException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const AssetException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw AssetException(error ?? 'Something went wrong (${res.statusCode}).');
    }
    return json as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> _getList(String path, Map<String, String> queryParams) async {
    final uri = _uri(path).replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    http.Response res;
    try {
      res = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AssetException("Couldn't reach the server. Check your connection and try again.");
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const AssetException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw AssetException(error ?? 'Something went wrong (${res.statusCode}).');
    }
    return (json as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
