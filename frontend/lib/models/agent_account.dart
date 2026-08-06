/// Models backing the agent-side Wallet, Schedule, Settings, Membership,
/// Visibility/Profile, and Support screens — mirrors the shapes returned by
/// `/api/agents/:agentId/*` and `/api/support-tickets` in the backend.
library;

// ── Wallet ─────────────────────────────────────────────────────────────

class AgentWalletTransaction {
  final String id;
  final String agentId;
  final String type; // 'commission' | 'withdrawal'
  final double amount;
  final String label;
  final String status; // 'pending' | 'cleared'
  final String? bankAccountLast4;
  final DateTime createdAt;

  const AgentWalletTransaction({
    required this.id,
    required this.agentId,
    required this.type,
    required this.amount,
    required this.label,
    required this.status,
    this.bankAccountLast4,
    required this.createdAt,
  });

  factory AgentWalletTransaction.fromJson(Map<String, dynamic> json) => AgentWalletTransaction(
        id: json['id'] as String,
        agentId: json['agentId'] as String,
        type: json['type'] as String,
        amount: (json['amount'] as num).toDouble(),
        label: json['label'] as String,
        status: json['status'] as String,
        bankAccountLast4: json['bankAccountLast4'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AgentWallet {
  final double balance;
  final double pendingClearance;
  final List<AgentWalletTransaction> transactions;

  const AgentWallet({required this.balance, required this.pendingClearance, required this.transactions});

  factory AgentWallet.fromJson(Map<String, dynamic> json) => AgentWallet(
        balance: (json['balance'] as num).toDouble(),
        pendingClearance: (json['pendingClearance'] as num).toDouble(),
        transactions: (json['transactions'] as List<dynamic>)
            .map((t) => AgentWalletTransaction.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}

// ── Schedule ───────────────────────────────────────────────────────────

class AgentBooking {
  final String id;
  final String agentId;
  final String clientName;
  final String propertyTitle;
  final String? address;
  final DateTime startAt;
  final int durationMinutes;
  final String status; // 'pending' | 'confirmed' | 'cancelled'

  const AgentBooking({
    required this.id,
    required this.agentId,
    required this.clientName,
    required this.propertyTitle,
    this.address,
    required this.startAt,
    required this.durationMinutes,
    required this.status,
  });

  factory AgentBooking.fromJson(Map<String, dynamic> json) => AgentBooking(
        id: json['id'] as String,
        agentId: json['agentId'] as String,
        clientName: json['clientName'] as String,
        propertyTitle: json['propertyTitle'] as String,
        address: json['address'] as String?,
        startAt: DateTime.parse(json['startAt'] as String),
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 60,
        status: json['status'] as String,
      );
}

// ── Settings ───────────────────────────────────────────────────────────

class AgentSettingsData {
  final bool notifyNewDispatches;
  final bool notifyChatMessages;
  final bool notifyPromotions;
  final bool notifyPayouts;
  final String language;
  final String? bankName;
  final String? bankAccountHolder;
  final String? bankAccountLast4;

  const AgentSettingsData({
    required this.notifyNewDispatches,
    required this.notifyChatMessages,
    required this.notifyPromotions,
    required this.notifyPayouts,
    required this.language,
    this.bankName,
    this.bankAccountHolder,
    this.bankAccountLast4,
  });

  factory AgentSettingsData.fromJson(Map<String, dynamic> json) => AgentSettingsData(
        notifyNewDispatches: json['notifyNewDispatches'] as bool? ?? true,
        notifyChatMessages: json['notifyChatMessages'] as bool? ?? true,
        notifyPromotions: json['notifyPromotions'] as bool? ?? false,
        notifyPayouts: json['notifyPayouts'] as bool? ?? true,
        language: json['language'] as String? ?? 'english',
        bankName: json['bankName'] as String?,
        bankAccountHolder: json['bankAccountHolder'] as String?,
        bankAccountLast4: json['bankAccountLast4'] as String?,
      );
}

// ── Membership ─────────────────────────────────────────────────────────

class AgentBillingEntry {
  final String id;
  final String label;
  final double amount;
  final String status; // 'paid' | 'upcoming'
  final DateTime billedOn;

  const AgentBillingEntry({required this.id, required this.label, required this.amount, required this.status, required this.billedOn});

  factory AgentBillingEntry.fromJson(Map<String, dynamic> json) => AgentBillingEntry(
        id: json['id'] as String,
        label: json['label'] as String,
        amount: (json['amount'] as num).toDouble(),
        status: json['status'] as String,
        billedOn: DateTime.parse(json['billedOn'] as String),
      );
}

class AgentMembershipData {
  final String tier; // 'bronze' | 'silver' | 'gold' | 'diamond'
  final DateTime? renewalDate;
  final double monthlyFeeEtb;
  final List<String> perks;
  final List<AgentBillingEntry> billingHistory;

  const AgentMembershipData({
    required this.tier,
    this.renewalDate,
    required this.monthlyFeeEtb,
    required this.perks,
    required this.billingHistory,
  });

  factory AgentMembershipData.fromJson(Map<String, dynamic> json) => AgentMembershipData(
        tier: json['tier'] as String? ?? 'bronze',
        renewalDate: json['renewalDate'] != null ? DateTime.parse(json['renewalDate'] as String) : null,
        monthlyFeeEtb: (json['monthlyFeeEtb'] as num?)?.toDouble() ?? 0,
        perks: (json['perks'] as List<dynamic>? ?? []).cast<String>(),
        billingHistory: (json['billingHistory'] as List<dynamic>? ?? [])
            .map((b) => AgentBillingEntry.fromJson(b as Map<String, dynamic>))
            .toList(),
      );
}

// ── Profile (Visibility) ──────────────────────────────────────────────

class AgentReview {
  final String id;
  final String reviewerName;
  final int stars;
  final String quote;
  final DateTime createdAt;

  const AgentReview({required this.id, required this.reviewerName, required this.stars, required this.quote, required this.createdAt});

  factory AgentReview.fromJson(Map<String, dynamic> json) => AgentReview(
        id: json['id'] as String,
        reviewerName: json['reviewerName'] as String,
        stars: (json['stars'] as num).toInt(),
        quote: json['quote'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AgentProfileData {
  final String userId;
  final String bio;
  final String city;
  final List<String> specialties;
  final bool boosted;
  final DateTime? boostedUntil;
  final int reviewCount;
  final double avgRating;
  final List<AgentReview> reviews;

  const AgentProfileData({
    required this.userId,
    required this.bio,
    required this.city,
    required this.specialties,
    required this.boosted,
    this.boostedUntil,
    required this.reviewCount,
    required this.avgRating,
    required this.reviews,
  });

  factory AgentProfileData.fromJson(Map<String, dynamic> json) => AgentProfileData(
        userId: json['userId'] as String,
        bio: json['bio'] as String? ?? '',
        city: json['city'] as String? ?? '',
        specialties: (json['specialties'] as List<dynamic>? ?? []).cast<String>(),
        boosted: json['boosted'] as bool? ?? false,
        boostedUntil: json['boostedUntil'] != null ? DateTime.parse(json['boostedUntil'] as String) : null,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
        reviews: (json['reviews'] as List<dynamic>? ?? []).map((r) => AgentReview.fromJson(r as Map<String, dynamic>)).toList(),
      );
}

// ── Support tickets ────────────────────────────────────────────────────

class SupportTicket {
  final String id;
  final String category;
  final String subject;
  final String body;
  final String status;
  final DateTime createdAt;

  /// Present on the admin inbox/detail payloads (`GET /api/support-tickets`,
  /// `GET /api/support-tickets/:id`) — omitted from a user's own ticket
  /// history (`GET /api/support-tickets/me`) since there it's always just
  /// themselves.
  final String? senderName;
  final String? senderContact;
  final DateTime? updatedAt;

  /// The admin's answer, if one has been sent yet (`POST
  /// /api/support-tickets/:id/reply`). Also delivered to the sender as a
  /// notification — this field is what backs re-displaying it here after
  /// the fact.
  final String? adminResponse;
  final DateTime? adminResponseAt;

  const SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.body,
    required this.status,
    required this.createdAt,
    this.senderName,
    this.senderContact,
    this.updatedAt,
    this.adminResponse,
    this.adminResponseAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String,
        category: json['category'] as String,
        subject: json['subject'] as String,
        body: json['body'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        senderName: json['senderName'] as String?,
        senderContact: json['senderContact'] as String?,
        updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
        adminResponse: json['adminResponse'] as String?,
        adminResponseAt: json['adminResponseAt'] != null ? DateTime.parse(json['adminResponseAt'] as String) : null,
      );
}

// ── Network (agent-to-agent referral program) ──────────────────────────
// Separate from the Affiliater program: an agent's own "AGT-" code/link
// for recruiting other agents, who then work as this agent's downline.
// No fee-share client referrals here — this is purely "who's in my
// network" plus the automatic override commission it generates.

class AgentNetworkDownlineEntry {
  final String id;
  final String fullName;
  final String email;
  final DateTime joinedAt;
  final double totalEarned;

  const AgentNetworkDownlineEntry({
    required this.id,
    required this.fullName,
    required this.email,
    required this.joinedAt,
    required this.totalEarned,
  });

  factory AgentNetworkDownlineEntry.fromJson(Map<String, dynamic> json) => AgentNetworkDownlineEntry(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        joinedAt: DateTime.parse(json['joinedAt'] as String),
        totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0,
      );
}

class AgentNetworkData {
  final String referralCode;
  final int overridePercent;
  final List<AgentNetworkDownlineEntry> downline;
  final double overrideEarningsCleared;
  final double overrideEarningsPending;

  const AgentNetworkData({
    required this.referralCode,
    required this.overridePercent,
    required this.downline,
    required this.overrideEarningsCleared,
    required this.overrideEarningsPending,
  });

  factory AgentNetworkData.fromJson(Map<String, dynamic> json) {
    final earnings = json['overrideEarnings'] as Map<String, dynamic>? ?? const {};
    return AgentNetworkData(
      referralCode: json['referralCode'] as String? ?? '',
      overridePercent: (json['overridePercent'] as num?)?.toInt() ?? 6,
      downline: (json['downline'] as List<dynamic>? ?? [])
          .map((d) => AgentNetworkDownlineEntry.fromJson(d as Map<String, dynamic>))
          .toList(),
      overrideEarningsCleared: (earnings['cleared'] as num?)?.toDouble() ?? 0,
      overrideEarningsPending: (earnings['pending'] as num?)?.toDouble() ?? 0,
    );
  }
}
