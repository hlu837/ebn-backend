/// An admin-curated investment deal — backs the investor-facing
/// "Investment Opportunities" feed (read) and the admin management screen
/// (create/edit/close/delete).
class InvestmentOpportunity {
  final String id;
  final String title;
  final String description;
  final String category;
  final String status;
  final double targetAmount;
  final double minInvestment;
  final double expectedReturnPct;
  final int termMonths;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InvestmentOpportunity({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.targetAmount,
    required this.minInvestment,
    required this.expectedReturnPct,
    required this.termMonths,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvestmentOpportunity.fromJson(Map<String, dynamic> json) {
    return InvestmentOpportunity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Other',
      status: json['status'] as String? ?? 'Open',
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
      minInvestment: (json['minInvestment'] as num?)?.toDouble() ?? 0,
      expectedReturnPct: (json['expectedReturnPct'] as num?)?.toDouble() ?? 0,
      termMonths: (json['termMonths'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
