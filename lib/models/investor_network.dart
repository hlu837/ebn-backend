// ── Network (investor-to-investor referral program) ────────────────────
// Separate from the agent network and the Affiliater program: an
// investor's own "INV-" code/link for recruiting other investors, who
// then work as this investor's downline. There's no ongoing commission
// to override here (investors don't earn commissions) — instead the
// sponsor earns a one-time reward the moment a downline investor's first
// commitment is confirmed by an admin.

class InvestorNetworkDownlineEntry {
  final String id;
  final String fullName;
  final String email;
  final DateTime joinedAt;
  final bool rewardCredited;

  const InvestorNetworkDownlineEntry({
    required this.id,
    required this.fullName,
    required this.email,
    required this.joinedAt,
    required this.rewardCredited,
  });

  factory InvestorNetworkDownlineEntry.fromJson(Map<String, dynamic> json) => InvestorNetworkDownlineEntry(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        rewardCredited: json['rewardCredited'] as bool? ?? false,
      );
}

class InvestorNetworkData {
  final String referralCode;
  final int rewardPercent;
  final List<InvestorNetworkDownlineEntry> downline;
  final double rewardEarningsCleared;
  final double rewardEarningsPending;

  const InvestorNetworkData({
    required this.referralCode,
    required this.rewardPercent,
    required this.downline,
    required this.rewardEarningsCleared,
    required this.rewardEarningsPending,
  });

  factory InvestorNetworkData.fromJson(Map<String, dynamic> json) {
    final earnings = json['rewardEarnings'] as Map<String, dynamic>? ?? const {};
    return InvestorNetworkData(
      referralCode: json['referralCode'] as String? ?? '',
      rewardPercent: (json['rewardPercent'] as num?)?.toInt() ?? 2,
      downline: (json['downline'] as List<dynamic>? ?? [])
          .map((d) => InvestorNetworkDownlineEntry.fromJson(d as Map<String, dynamic>))
          .toList(),
      rewardEarningsCleared: (earnings['cleared'] as num?)?.toDouble() ?? 0,
      rewardEarningsPending: (earnings['pending'] as num?)?.toDouble() ?? 0,
    );
  }
}
