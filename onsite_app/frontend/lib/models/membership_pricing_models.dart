/// Models for admin membership pricing configuration.
library;

class MembershipTierPrice {
  final String role;
  final String tier;
  final double monthlyFeeEtb;

  const MembershipTierPrice({
    required this.role,
    required this.tier,
    required this.monthlyFeeEtb,
  });

  factory MembershipTierPrice.fromJson(Map<String, dynamic> json) {
    return MembershipTierPrice(
      role: json['role'] as String? ?? '',
      tier: json['tier'] as String? ?? '',
      monthlyFeeEtb: (json['monthlyFeeEtb'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MembershipPricing {
  final Map<String, double> agent;
  final Map<String, double> affiliate;

  const MembershipPricing({required this.agent, required this.affiliate});

  factory MembershipPricing.fromJson(Map<String, dynamic> json) {
    final agent = <String, double>{};
    final affiliate = <String, double>{};

    if (json['agent'] is Map) {
      for (final entry in (json['agent'] as Map).entries) {
        agent[entry.key] = (entry.value as num).toDouble();
      }
    }

    if (json['affiliate'] is Map) {
      for (final entry in (json['affiliate'] as Map).entries) {
        affiliate[entry.key] = (entry.value as num).toDouble();
      }
    }

    return MembershipPricing(agent: agent, affiliate: affiliate);
  }

  double getPrice(String role, String tier) {
    final prices = role == 'agent' ? agent : affiliate;
    return prices[tier] ?? 0.0;
  }
}
