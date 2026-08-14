/// One row from `GET /api/transactions` — a real Chapa payment record
/// (see backend/src/models/payments.js), as seen by an admin. Replaces the
/// old page-local `TransactionSummary` scaffolding model.
class AdminTransaction {
  final String id;
  final String txRef;
  final String purpose;
  final String? ownerUserId;
  final String? ownerName;
  final double amount;
  final String currency;
  final String email;
  final String status; // 'pending' | 'success' | 'failed'
  final DateTime createdAt;

  const AdminTransaction({
    required this.id,
    required this.txRef,
    required this.purpose,
    required this.ownerUserId,
    required this.ownerName,
    required this.amount,
    required this.currency,
    required this.email,
    required this.status,
    required this.createdAt,
  });

  /// Best available label for who this payment belongs to — a matched
  /// account name, falling back to the checkout email since `ownerUserId`
  /// isn't a guaranteed foreign key (see payments.js listAll()).
  String get payerLabel => ownerName ?? email;

  factory AdminTransaction.fromJson(Map<String, dynamic> json) {
    return AdminTransaction(
      id: json['id'] as String,
      txRef: json['txRef'] as String? ?? '',
      purpose: json['purpose'] as String? ?? '',
      ownerUserId: json['ownerUserId'] as String?,
      ownerName: json['ownerName'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'ETB',
      email: json['email'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
