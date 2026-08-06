import 'dart:convert';

import 'package:http/http.dart' as http;

/// The map API key + style, fetched from the backend at runtime instead
/// of being hardcoded into the app. See `backend/src/routes/config.js`
/// (GET /api/config/map) — the key itself lives only in `backend/.env`.
class MapConfig {
  final String apiKey;
  final String styleUrl;
  final double defaultLat;
  final double defaultLng;

  const MapConfig({
    required this.apiKey,
    required this.styleUrl,
    required this.defaultLat,
    required this.defaultLng,
  });

  factory MapConfig.fromJson(Map<String, dynamic> json) {
    final center = json['defaultCenter'] as Map<String, dynamic>? ?? const {};
    return MapConfig(
      apiKey: json['apiKey'] as String,
      styleUrl: json['styleUrl'] as String? ?? 'https://tiles.gebeta.app/styles/standard/style.json',
      defaultLat: (center['latitude'] as num?)?.toDouble() ?? 9.0192,
      defaultLng: (center['longitude'] as num?)?.toDouble() ?? 38.7525,
    );
  }
}

class MapConfigException implements Exception {
  final String message;
  const MapConfigException(this.message);
  @override
  String toString() => message;
}

/// Talks to `/api/config/map`. Mirrors the other services' baseUrl
/// conventions (see [AssetService]).
class MapConfigService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  // Cached in memory for the life of the app — no need to refetch this
  // on every map screen visit.
  static MapConfig? _cached;

  Future<MapConfig> fetchConfig() async {
    if (_cached != null) return _cached!;

    http.Response res;
    try {
      res = await http
          .get(Uri.parse('$baseUrl/api/config/map'))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const MapConfigException("Couldn't reach the server for the map key.");
    }

    dynamic json;
    try {
      json = jsonDecode(res.body);
    } catch (_) {
      throw const MapConfigException('Unexpected response from the server.');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = json is Map<String, dynamic> ? json['error'] as String? : null;
      throw MapConfigException(error ?? 'Map isn\'t configured on the server yet.');
    }

    final config = MapConfig.fromJson(json as Map<String, dynamic>);
    _cached = config;
    return config;
  }
}
