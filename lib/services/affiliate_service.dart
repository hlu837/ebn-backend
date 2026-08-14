import 'dart:convert';
import 'package:http/http.dart' as http;

class AffiliateException implements Exception {
  final String message;
  const AffiliateException(this.message);

  @override
  String toString() => message;
}

class ReferralItem {
  final String id;
  final String customerName;
  final String assetTitle;
  final double commissionAmount;
  final String commissionCurrency;
  final String status;
  final DateTime createdAt;

  const ReferralItem({
    required this.id,
    required this.customerName,
    required this.assetTitle,
    required this.commissionAmount,
    required this.commissionCurrency,
    required this.status,
    required this.createdAt,
  });

  factory ReferralItem.fromJson(Map<String, dynamic> json) {
    return ReferralItem(
      id: json['id'] as String,
      customerName: json['customerName'] as String? ?? 'Customer',
      assetTitle: json['assetTitle'] as String? ?? 'Property Sale',
      commissionAmount: (json['commissionAmount'] as num?)?.toDouble() ?? 0.0,
      commissionCurrency: json['commissionCurrency'] as String? ?? 'ETB',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isPending => status == 'pending';
}

class EarningsSummary {
  final double totalEarned;
  final double pending;
  final double paidOut;
  final double processing;
  final double availableForPayout;

  const EarningsSummary({
    required this.totalEarned,
    required this.pending,
    required this.paidOut,
    required this.processing,
    required this.availableForPayout,
  });

  factory EarningsSummary.fromJson(Map<String, dynamic> json) {
    return EarningsSummary(
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0.0,
      pending: (json['pending'] as num?)?.toDouble() ?? 0.0,
      paidOut: (json['paidOut'] as num?)?.toDouble() ?? 0.0,
      processing: (json['processing'] as num?)?.toDouble() ?? 0.0,
      availableForPayout: (json['availableForPayout'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PayoutItem {
  final String id;
  final double amount;
  final String currency;
  final String status; // 'processing' | 'paid'
  final String source; // 'commission' | 'token_redemption'
  final DateTime requestedAt;
  final DateTime? paidAt;

  const PayoutItem({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    this.source = 'commission',
    required this.requestedAt,
    this.paidAt,
  });

  bool get isTokenRedemption => source == 'token_redemption';

  factory PayoutItem.fromJson(Map<String, dynamic> json) {
    return PayoutItem(
      id: json['id'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'ETB',
      status: json['status'] as String? ?? 'processing',
      source: json['source'] as String? ?? 'commission',
      requestedAt: json['requestedAt'] != null
          ? DateTime.tryParse(json['requestedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      paidAt: json['paidAt'] != null ? DateTime.tryParse(json['paidAt'] as String) : null,
    );
  }
}

class TokenSummary {
  final int balance;
  final int totalEarned;
  final int totalRedeemed;
  final double cashValue;
  final double etbPerToken;
  final int minRedeemableTokens;

  const TokenSummary({
    required this.balance,
    required this.totalEarned,
    required this.totalRedeemed,
    required this.cashValue,
    required this.etbPerToken,
    required this.minRedeemableTokens,
  });

  bool get canRedeem => balance >= minRedeemableTokens;

  factory TokenSummary.fromJson(Map<String, dynamic> json) {
    return TokenSummary(
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      totalEarned: (json['totalEarned'] as num?)?.toInt() ?? 0,
      totalRedeemed: (json['totalRedeemed'] as num?)?.toInt() ?? 0,
      cashValue: (json['cashValue'] as num?)?.toDouble() ?? 0.0,
      etbPerToken: (json['etbPerToken'] as num?)?.toDouble() ?? 1.0,
      minRedeemableTokens: (json['minRedeemableTokens'] as num?)?.toInt() ?? 0,
    );
  }
}

enum TokenEntryType { earned, redeemed }

class TokenLedgerEntry {
  final String id;
  final TokenEntryType type;
  final int amount; // signed: positive for earned, negative for redeemed
  final String reason;
  final String? referredUserName;
  final DateTime createdAt;

  const TokenLedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    this.referredUserName,
    required this.createdAt,
  });

  factory TokenLedgerEntry.fromJson(Map<String, dynamic> json) {
    return TokenLedgerEntry(
      id: json['id'] as String,
      type: (json['type'] as String?) == 'redeemed' ? TokenEntryType.redeemed : TokenEntryType.earned,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String? ?? '',
      referredUserName: json['referredUserName'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

enum AffiliateNotificationKind { commission, referral, campaign, payout, token, system }

class AffiliateNotification {
  final String id;
  final AffiliateNotificationKind kind;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const AffiliateNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  AffiliateNotification copyWith({bool? isRead}) {
    return AffiliateNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory AffiliateNotification.fromJson(Map<String, dynamic> json) {
    return AffiliateNotification(
      id: json['id'] as String,
      kind: AffiliateNotificationKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => AffiliateNotificationKind.system,
      ),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Payout/banking details + notification prefs from the Affiliater
/// "Account Settings" screen. Name/phone live on [AppUser] instead — see
/// AuthService.updateProfile for those.
class AffiliateSettings {
  final bool notifyNewReferrals;
  final bool notifyPayouts;
  final String? bankName;
  final String? bankAccountLast4;

  const AffiliateSettings({
    required this.notifyNewReferrals,
    required this.notifyPayouts,
    this.bankName,
    this.bankAccountLast4,
  });

  factory AffiliateSettings.fromJson(Map<String, dynamic> json) {
    return AffiliateSettings(
      notifyNewReferrals: json['notifyNewReferrals'] as bool? ?? true,
      notifyPayouts: json['notifyPayouts'] as bool? ?? true,
      bankName: json['bankName'] as String?,
      // The API only ever returns the last 4 digits — the full number is
      // never sent back down from the server.
      bankAccountLast4: json['bankAccountLast4'] as String?,
    );
  }
}

// ── Membership ─────────────────────────────────────────────────────────

class AffiliateBillingEntry {
  final String id;
  final String label;
  final double amount;
  final String status; // 'paid' | 'upcoming'
  final DateTime billedOn;

  const AffiliateBillingEntry({
    required this.id,
    required this.label,
    required this.amount,
    required this.status,
    required this.billedOn,
  });

  factory AffiliateBillingEntry.fromJson(Map<String, dynamic> json) => AffiliateBillingEntry(
        id: json['id'] as String,
        label: json['label'] as String,
        amount: (json['amount'] as num).toDouble(),
        status: json['status'] as String,
        billedOn: DateTime.parse(json['billedOn'] as String),
      );
}

class AffiliateMembershipData {
  final String tier; // 'bronze' | 'silver' | 'gold' | 'diamond'
  final DateTime? renewalDate;
  final double monthlyFeeEtb;
  final List<String> perks;
  final List<AffiliateBillingEntry> billingHistory;

  const AffiliateMembershipData({
    required this.tier,
    this.renewalDate,
    required this.monthlyFeeEtb,
    required this.perks,
    required this.billingHistory,
  });

  factory AffiliateMembershipData.fromJson(Map<String, dynamic> json) => AffiliateMembershipData(
        tier: json['tier'] as String? ?? 'bronze',
        renewalDate: json['renewalDate'] != null ? DateTime.parse(json['renewalDate'] as String) : null,
        monthlyFeeEtb: (json['monthlyFeeEtb'] as num?)?.toDouble() ?? 0,
        perks: (json['perks'] as List<dynamic>? ?? []).cast<String>(),
        billingHistory: (json['billingHistory'] as List<dynamic>? ?? [])
            .map((b) => AffiliateBillingEntry.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
}

/// One month's rolled-up performance from `GET /api/affiliates/me/reports`.
class MonthlyReport {
  final String month; // 'YYYY-MM'
  final int clicks;
  final int referrals;
  final double commission;

  const MonthlyReport({
    required this.month,
    required this.clicks,
    required this.referrals,
    required this.commission,
  });

  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    return MonthlyReport(
      month: json['month'] as String? ?? '',
      clicks: (json['clicks'] as num?)?.toInt() ?? 0,
      referrals: (json['referrals'] as num?)?.toInt() ?? 0,
      commission: (json['commission'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Performance overview for the Affiliater "Reports" screen — totals plus
/// a month-by-month breakdown, from `GET /api/affiliates/me/reports`.
class ReportsSummary {
  final int totalClicks;
  final int totalReferrals;
  final double totalCommission;
  final double conversionRate;
  final List<MonthlyReport> monthly;

  const ReportsSummary({
    required this.totalClicks,
    required this.totalReferrals,
    required this.totalCommission,
    required this.conversionRate,
    required this.monthly,
  });

  factory ReportsSummary.fromJson(Map<String, dynamic> json) {
    return ReportsSummary(
      totalClicks: (json['totalClicks'] as num?)?.toInt() ?? 0,
      totalReferrals: (json['totalReferrals'] as num?)?.toInt() ?? 0,
      totalCommission: (json['totalCommission'] as num?)?.toDouble() ?? 0.0,
      conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0.0,
      monthly: (json['monthly'] as List<dynamic>? ?? [])
          .map((m) => MonthlyReport.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AffiliateService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mlmpropertyebn.vercel.app',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// GET /api/affiliates/me/code — fetches or generates the caller's affiliate code.
  Future<String> getCode(String token) async {
    final json = await _get('/api/affiliates/me/code', token: token);
    return json['code'] as String;
  }

  /// POST /api/affiliates/me/links — mints a shareable affiliate link and records a click.
  Future<Map<String, String>> generateLink(String token, {String? assetId}) async {
    final res = await _post(
      '/api/affiliates/me/links',
      {if (assetId != null) 'assetId': assetId},
      token: token,
    );
    return {
      'code': res['code'] as String,
      'url': res['url'] as String,
    };
  }

  /// GET /api/affiliates/me/referrals — fetches referrals for the logged in affiliater.
  Future<List<ReferralItem>> getReferrals(String token, {String? status}) async {
    final path = status != null ? '/api/affiliates/me/referrals?status=$status' : '/api/affiliates/me/referrals';
    final res = await _getRaw(path, token: token);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((item) => ReferralItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// GET /api/affiliates/me/earnings — fetches earnings summary.
  Future<EarningsSummary> getEarnings(String token) async {
    final json = await _get('/api/affiliates/me/earnings', token: token);
    return EarningsSummary.fromJson(json);
  }

  /// POST /api/affiliates/me/payouts — requests a payout for available earnings.
  Future<PayoutItem> requestPayout(String token, {double? amount}) async {
    final json = await _post(
      '/api/affiliates/me/payouts',
      {if (amount != null) 'amount': amount},
      token: token,
    );
    return PayoutItem.fromJson(json);
  }

  /// GET /api/affiliates/me/payouts — lists all payout requests.
  Future<List<PayoutItem>> listPayouts(String token) async {
    final res = await _getRaw('/api/affiliates/me/payouts', token: token);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((item) => PayoutItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// GET /api/affiliates/me/notifications — fetches the affiliate's notification feed.
  Future<List<AffiliateNotification>> getNotifications(String token) async {
    final res = await _getRaw('/api/affiliates/me/notifications', token: token);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((item) => AffiliateNotification.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// POST /api/affiliates/me/notifications/:id/read — marks a single notification read.
  Future<AffiliateNotification> markNotificationRead(String token, String id) async {
    final json = await _post('/api/affiliates/me/notifications/$id/read', {}, token: token);
    return AffiliateNotification.fromJson(json);
  }

  /// POST /api/affiliates/me/notifications/read-all — marks every notification read.
  Future<int> markAllNotificationsRead(String token) async {
    final json = await _post('/api/affiliates/me/notifications/read-all', {}, token: token);
    return (json['markedRead'] as num?)?.toInt() ?? 0;
  }

  /// GET /api/affiliates/me/tokens — balance, lifetime totals, and the
  /// current cash-conversion rate.
  Future<TokenSummary> getTokenSummary(String token) async {
    final json = await _get('/api/affiliates/me/tokens', token: token);
    return TokenSummary.fromJson(json);
  }

  /// GET /api/affiliates/me/tokens/ledger — full history of token events
  /// (earned from referral signups, redeemed for cash).
  Future<List<TokenLedgerEntry>> getTokenLedger(String token) async {
    final res = await _getRaw('/api/affiliates/me/tokens/ledger', token: token);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((item) => TokenLedgerEntry.fromJson(item as Map<String, dynamic>)).toList();
  }

  /// POST /api/affiliates/me/tokens/redeem — converts `tokens` (or the full
  /// balance, if omitted) into a cash payout at the current rate.
  Future<PayoutItem> redeemTokens(String token, {int? tokens}) async {
    final json = await _post(
      '/api/affiliates/me/tokens/redeem',
      {if (tokens != null) 'tokens': tokens},
      token: token,
    );
    return PayoutItem.fromJson(json);
  }

  /// GET /api/affiliates/me/settings — bank/payout details + notification prefs.
  Future<AffiliateSettings> getSettings(String token) async {
    final json = await _get('/api/affiliates/me/settings', token: token);
    return AffiliateSettings.fromJson(json);
  }

  /// PATCH /api/affiliates/me/settings — any subset of the fields.
  Future<AffiliateSettings> updateSettings(
    String token, {
    bool? notifyNewReferrals,
    bool? notifyPayouts,
    String? bankName,
    String? bankAccountNumber,
  }) async {
    final json = await _patch('/api/affiliates/me/settings', {
      if (notifyNewReferrals != null) 'notifyNewReferrals': notifyNewReferrals,
      if (notifyPayouts != null) 'notifyPayouts': notifyPayouts,
      if (bankName != null) 'bankName': bankName,
      if (bankAccountNumber != null) 'bankAccountNumber': bankAccountNumber,
    }, token: token);
    return AffiliateSettings.fromJson(json);
  }

  /// GET /api/affiliates/me/reports — totals + monthly breakdown for the Reports screen.
  Future<ReportsSummary> getReports(String token) async {
    final json = await _get('/api/affiliates/me/reports', token: token);
    return ReportsSummary.fromJson(json);
  }

  /// GET /api/affiliates/me/membership — current tier, perks, fee, and billing history.
  Future<AffiliateMembershipData> getMembership(String token) async {
    final json = await _get('/api/affiliates/me/membership', token: token);
    return AffiliateMembershipData.fromJson(json);
  }

  /// POST /api/affiliates/me/membership/upgrade — Body: { tier }.
  Future<AffiliateMembershipData> upgradeMembership(String token, {required String tier}) async {
    final json = await _post('/api/affiliates/me/membership/upgrade', {'tier': tier}, token: token);
    return AffiliateMembershipData.fromJson(json);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _get(String path, {required String token}) async {
    final res = await _getRaw(path, token: token);
    return _decode(res);
  }

  Future<http.Response> _getRaw(String path, {required String token}) async {
    try {
      return await http.get(
        _uri(path),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AffiliateException("Couldn't reach the server. Check connection.");
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {required String token}) async {
    http.Response res;
    try {
      res = await http.post(
        _uri(path),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AffiliateException("Couldn't reach the server. Check connection.");
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body, {required String token}) async {
    http.Response res;
    try {
      res = await http.patch(
        _uri(path),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AffiliateException("Couldn't reach the server. Check connection.");
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AffiliateException('Unexpected server response.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw AffiliateException(json['error'] as String? ?? 'Error (${res.statusCode})');
    }
    return json;
  }
}
