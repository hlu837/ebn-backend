import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/asset.dart';

/// Thrown for any favorites call the backend rejects (auth, network
/// errors, etc). [message] is safe to show directly in a SnackBar.
class FavoriteException implements Exception {
  final String message;
  const FavoriteException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/favorites/*` routes — mirrors
/// [AssetService]'s shape/conventions. Every call needs the signed-in
/// visitor's Bearer token; there's no favorites concept for a guest.
class FavoriteService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mlmpropertyebn.vercel.app',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// GET /api/favorites — full saved listings, newest-saved first. Powers
  /// the Favorites / Saved Listings screen.
  Future<List<Asset>> fetchFavorites(String token) async {
    final rows = await _getList('/api/favorites', token);
    return rows.map(Asset.fromJson).toList();
  }

  /// GET /api/favorites/ids — just the saved asset ids, for hydrating the
  /// heart-icon state across the app (not just the Favorites screen).
  Future<List<String>> fetchFavoriteIds(String token) async {
    http.Response res;
    try {
      res = await http
          .get(_uri('/api/favorites/ids'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const FavoriteException("Couldn't reach the server. Check your connection and try again.");
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const FavoriteException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw FavoriteException(error ?? 'Something went wrong (${res.statusCode}).');
    }
    return (json as List<dynamic>).cast<String>();
  }

  /// POST /api/favorites/:assetId — saves a listing. Idempotent.
  Future<void> addFavorite(String token, String assetId) async {
    http.Response res;
    try {
      res = await http
          .post(_uri('/api/favorites/$assetId'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const FavoriteException("Couldn't reach the server. Check your connection and try again.");
    }
    _checkOk(res);
  }

  /// DELETE /api/favorites/:assetId — un-saves a listing.
  Future<void> removeFavorite(String token, String assetId) async {
    http.Response res;
    try {
      res = await http
          .delete(_uri('/api/favorites/$assetId'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const FavoriteException("Couldn't reach the server. Check your connection and try again.");
    }
    _checkOk(res);
  }

  // ── internals ────────────────────────────────────────────────────────

  void _checkOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      dynamic json;
      try {
        json = jsonDecode(res.body);
      } catch (_) {
        json = null;
      }
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw FavoriteException(error ?? 'Something went wrong (${res.statusCode}).');
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path, String token) async {
    http.Response res;
    try {
      res = await http
          .get(_uri(path), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const FavoriteException("Couldn't reach the server. Check your connection and try again.");
    }
    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const FavoriteException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw FavoriteException(error ?? 'Something went wrong (${res.statusCode}).');
    }
    return (json as List<dynamic>).cast<Map<String, dynamic>>();
  }
}
