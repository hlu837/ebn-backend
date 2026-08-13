import 'dart:convert';

import 'package:http/http.dart' as http;

/// A payment's settlement status, mirrors the backend's `payment_status`
/// Postgres enum.
enum PaymentStatus { pending, success, failed }

PaymentStatus _statusFromApi(String value) {
  switch (value) {
    case 'success':
      return PaymentStatus.success;
    case 'failed':
      return PaymentStatus.failed;
    default:
      return PaymentStatus.pending;
  }
}

/// Result of starting a checkout — `checkoutUrl` is Chapa's hosted payment
/// page; open it in the system browser and poll [PaymentService.verify]
/// with `txRef` until it settles.
class ChapaCheckout {
  final String txRef;
  final String checkoutUrl;
  const ChapaCheckout({required this.txRef, required this.checkoutUrl});
}

class PaymentException implements Exception {
  final String message;
  const PaymentException(this.message);
  @override
  String toString() => message;
}

/// Talks to the real backend's `/api/payments/chapa/*` routes.
class PaymentService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mlmpropertyebn.vercel.app',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// POST /api/payments/chapa/initialize — starts a checkout for [amount]
  /// ETB. [purpose] is a short machine tag (e.g. `sell_request_fee`) kept
  /// for bookkeeping; [email] is required by Chapa.
  Future<ChapaCheckout> initialize({
    required String purpose,
    required double amount,
    required String email,
    String? ownerUserId,
    String? firstName,
    String? lastName,
    String? description,
    String currency = 'ETB',
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/api/payments/chapa/initialize'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'purpose': purpose,
              'amount': amount,
              'currency': currency,
              'email': email,
              if (ownerUserId != null) 'ownerUserId': ownerUserId,
              if (firstName != null) 'firstName': firstName,
              if (lastName != null) 'lastName': lastName,
              if (description != null) 'description': description,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const PaymentException("Couldn't reach the payment server. Check your connection and try again.");
    }
    final json = _decode(res);
    return ChapaCheckout(txRef: json['txRef'] as String, checkoutUrl: json['checkoutUrl'] as String);
  }

  /// GET /api/payments/chapa/:txRef/verify — the authoritative check; the
  /// backend re-verifies with Chapa directly rather than trusting the
  /// client. Safe to call repeatedly while polling.
  Future<PaymentStatus> verify(String txRef) async {
    http.Response res;
    try {
      res = await http.get(_uri('/api/payments/chapa/$txRef/verify')).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const PaymentException("Couldn't reach the payment server. Check your connection and try again.");
    }
    final json = _decode(res);
    return _statusFromApi(json['status'] as String? ?? 'pending');
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const PaymentException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw PaymentException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }
}
