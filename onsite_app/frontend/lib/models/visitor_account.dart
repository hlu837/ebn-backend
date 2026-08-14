/// Notification + preference settings for a signed-in Visitor.
///
/// Backed by `GET/PATCH /api/auth/me/settings` (mirrors
/// `AgentSettingsData` / `/api/agents/:agentId/settings`, just self-scoped
/// via the Bearer token instead of an `:agentId` param) — see
/// `VisitorService`.
class VisitorSettingsData {
  /// Replies / status changes on the visitor's own sell & order requests.
  final bool notifyRequestUpdates;

  /// New chat messages from a broker/agent.
  final bool notifyChatMessages;

  /// Price drops or status changes on favorited/saved listings.
  final bool notifyPriceDrops;

  /// Occasional product updates & promotions.
  final bool notifyPromotions;

  final String language;

  const VisitorSettingsData({
    required this.notifyRequestUpdates,
    required this.notifyChatMessages,
    required this.notifyPriceDrops,
    required this.notifyPromotions,
    required this.language,
  });

  factory VisitorSettingsData.fromJson(Map<String, dynamic> json) => VisitorSettingsData(
        notifyRequestUpdates: json['notifyRequestUpdates'] as bool? ?? true,
        notifyChatMessages: json['notifyChatMessages'] as bool? ?? true,
        notifyPriceDrops: json['notifyPriceDrops'] as bool? ?? true,
        notifyPromotions: json['notifyPromotions'] as bool? ?? false,
        language: json['language'] as String? ?? 'english',
      );
}
