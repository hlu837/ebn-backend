/// An investor's request to commit capital to a specific
/// [InvestmentOpportunity]. Pending until an admin approves or rejects it
/// — see InvestmentCommitmentService.
class InvestmentCommitment {
  final String id;
  final String userId;
  final String opportunityId;
  final double amount;
  final String status;
  final String? adminNote;
  final DateTime? decidedAt;
  final DateTime createdAt;
  final String? opportunityTitle;
  final String? opportunityStatus;
  final String? userFullName;
  final String? userEmail;
  // Payout schedule — see backend's investmentPayoutScheduler.js. Only
  // meaningful once status is Confirmed; termMonths comes from the
  // joined opportunity so it's null on rows that don't join it.
  final int? termMonths;
  final int payoutsMade;
  final DateTime? maturedAt;

  const InvestmentCommitment({
    required this.id,
    required this.userId,
    required this.opportunityId,
    required this.amount,
    required this.status,
    required this.adminNote,
    required this.decidedAt,
    required this.createdAt,
    required this.opportunityTitle,
    required this.opportunityStatus,
    required this.userFullName,
    required this.userEmail,
    this.termMonths,
    this.payoutsMade = 0,
    this.maturedAt,
  });

  factory InvestmentCommitment.fromJson(Map<String, dynamic> json) {
    return InvestmentCommitment(
      id: json['id'] as String,
      userId: json['userId'] as String,
      opportunityId: json['opportunityId'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? 'Pending',
      adminNote: json['adminNote'] as String?,
      decidedAt: json['decidedAt'] != null ? DateTime.tryParse(json['decidedAt'] as String) : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      opportunityTitle: json['opportunityTitle'] as String?,
      opportunityStatus: json['opportunityStatus'] as String?,
      userFullName: json['userFullName'] as String?,
      userEmail: json['userEmail'] as String?,
      termMonths: (json['termMonths'] as num?)?.toInt(),
      payoutsMade: (json['payoutsMade'] as num?)?.toInt() ?? 0,
      maturedAt: json['maturedAt'] != null ? DateTime.tryParse(json['maturedAt'] as String) : null,
    );
  }

  /// Next payout due date, derived the same way the backend scheduler
  /// derives it — decidedAt + (payoutsMade + 1) months. Null if this
  /// commitment isn't on a schedule yet (not Confirmed, no term, or
  /// already matured).
  DateTime? get nextPayoutDueAt {
    if (status != 'Confirmed' || decidedAt == null || termMonths == null || maturedAt != null) return null;
    if (payoutsMade >= termMonths!) return null;
    final base = decidedAt!;
    final monthsAhead = payoutsMade + 1;
    return DateTime.utc(base.year, base.month + monthsAhead, base.day, base.hour, base.minute, base.second);
  }
}
