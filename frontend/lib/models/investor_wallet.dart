/// A single ledger entry in an investor's wallet — a payout credited by
/// an admin against a confirmed investment commitment, or a withdrawal
/// the investor requested.
class InvestorWalletTransaction {
  final String id;
  final String investorId;
  final String type; // 'payout' | 'withdrawal'
  final double amount;
  final String label;
  final String status; // 'pending' | 'cleared'
  final String? commitmentId;
  final String? bankAccountLast4;
  final DateTime createdAt;

  const InvestorWalletTransaction({
    required this.id,
    required this.investorId,
    required this.type,
    required this.amount,
    required this.label,
    required this.status,
    required this.commitmentId,
    required this.bankAccountLast4,
    required this.createdAt,
  });

  factory InvestorWalletTransaction.fromJson(Map<String, dynamic> json) {
    return InvestorWalletTransaction(
      id: json['id'] as String,
      investorId: json['investorId'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      label: json['label'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      commitmentId: json['commitmentId'] as String?,
      bankAccountLast4: json['bankAccountLast4'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// The balance summary + full ledger returned by GET
/// `/api/investors/:id/wallet`.
class InvestorWalletSummary {
  final double balance;
  final double pendingClearance;
  final List<InvestorWalletTransaction> transactions;

  const InvestorWalletSummary({
    required this.balance,
    required this.pendingClearance,
    required this.transactions,
  });

  factory InvestorWalletSummary.fromJson(Map<String, dynamic> json) {
    return InvestorWalletSummary(
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
      pendingClearance: (json['pendingClearance'] as num?)?.toDouble() ?? 0,
      transactions: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => InvestorWalletTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
