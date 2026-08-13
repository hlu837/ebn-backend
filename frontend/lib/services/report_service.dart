import 'dart:convert';

import 'package:http/http.dart' as http;

/// Thrown for any /api/reports call the backend rejects (auth, network
/// errors, etc). [message] is safe to show directly in a SnackBar.
class ReportServiceException implements Exception {
  final String message;
  const ReportServiceException(this.message);

  @override
  String toString() => message;
}

/// Talks to the real backend's `GET /api/reports/overview` — admin-only.
class ReportService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mlmpropertyebn.vercel.app',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> fetchOverview({required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/api/reports/overview'), headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const ReportServiceException("Couldn't reach the server. Check your connection and try again.");
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ReportServiceException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ReportServiceException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
