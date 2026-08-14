import 'package:flutter/material.dart';
import 'asset.dart';

/// Mirrors the platform's membership tiers (see `landing_content.dart`
/// `kTiers`) as they apply to a broker's posting rights.
///
/// Business rule (mock, matches membership plan copy):
///  - Diamond / Gold  -> can post listings in ANY category.
///  - Silver / Bronze -> can only post listings in ONE category
///    (their `lockedCategory`), e.g. a Silver broker who only does
///    vehicles can't also post apartments.
enum BrokerTier { diamond, gold, silver, bronze }

extension BrokerTierX on BrokerTier {
  /// Mirrors the `agent_tier` / `affiliate_tier` Postgres enums (see
  /// migrations 017 and 035) — 'bronze' is both the DB default and the
  /// fallback here for a null/unrecognized value.
  static BrokerTier fromApi(String? value) {
    switch (value) {
      case 'diamond':
        return BrokerTier.diamond;
      case 'gold':
        return BrokerTier.gold;
      case 'silver':
        return BrokerTier.silver;
      case 'bronze':
      default:
        return BrokerTier.bronze;
    }
  }

  String get label {
    switch (this) {
      case BrokerTier.diamond:
        return 'Diamond';
      case BrokerTier.gold:
        return 'Gold';
      case BrokerTier.silver:
        return 'Silver';
      case BrokerTier.bronze:
        return 'Bronze';
    }
  }

  /// Whether this tier is allowed to post across every category, or is
  /// restricted to a single locked category.
  bool get canPostAnyCategory =>
      this == BrokerTier.diamond || this == BrokerTier.gold;

  IconData get icon {
    switch (this) {
      case BrokerTier.diamond:
        return Icons.diamond;
      case BrokerTier.gold:
        return Icons.emoji_events;
      case BrokerTier.silver:
        return Icons.military_tech;
      case BrokerTier.bronze:
        return Icons.shield_outlined;
    }
  }

  Color get color {
    switch (this) {
      case BrokerTier.diamond:
        return const Color(0xFF7FD8E8);
      case BrokerTier.gold:
        return const Color(0xFFE8B23A);
      case BrokerTier.silver:
        return const Color(0xFFB8BEC7);
      case BrokerTier.bronze:
        return const Color(0xFFB0763F);
    }
  }

  String get description {
    switch (this) {
      case BrokerTier.diamond:
        return 'Top priority leads and full posting rights across every listing category.';
      case BrokerTier.gold:
        return 'Premium visibility and full posting rights across every listing category.';
      case BrokerTier.silver:
        return 'Standard visibility. Can only post listings in one category.';
      case BrokerTier.bronze:
        return 'Overflow / starter tier. Can only post listings in one category.';
    }
  }
}

/// UI model for an entry in the Broker Network directory — powers the
/// "Find brokers" list on category detail pages, the broker map, and
/// broker profile/chat screens.
///
/// Populated from the real `GET /api/agents` endpoint via
/// [Broker.fromDirectoryJson]; see [AgentService] for the fetch call.
class Broker {
  final String id;
  final String name;
  final String company;
  final String city;
  final String? addressLine;
  final String? phone;
  final String? bio;
  final double rating;
  final List<AssetCategorySlug> specialties;
  final BrokerTier tier;

  /// Only meaningful when `tier.canPostAnyCategory` is false — the single
  /// category this broker is allowed to post listings in.
  final AssetCategorySlug? lockedCategory;
  final double latitude;
  final double longitude;

  /// False when [latitude]/[longitude] are a city-center fallback rather
  /// than a real pin the agent set (see [fromDirectoryJson]) — the map
  /// screen should skip these rather than stack fake pins on one spot.
  final bool hasPreciseLocation;

  const Broker({
    required this.id,
    required this.name,
    required this.company,
    required this.city,
    required this.rating,
    required this.specialties,
    required this.tier,
    required this.latitude,
    required this.longitude,
    this.addressLine,
    this.phone,
    this.bio,
    this.lockedCategory,
    this.hasPreciseLocation = true,
  });

  /// Maps a row from `GET /api/agents` (the real Broker Network
  /// directory) into this UI model. Agents without a `specialties`
  /// entry fall back to every category so they aren't invisible in
  /// category-filtered views; agents without a saved location default to
  /// Addis Ababa's center with [hasPreciseLocation] = false so the map
  /// screen can skip plotting them.
  factory Broker.fromDirectoryJson(Map<String, dynamic> json) {
    final specialtiesRaw =
        (json['specialties'] as List?)?.cast<String>() ?? const <String>[];
    final specialties = specialtiesRaw.isEmpty
        ? AssetCategorySlug.values
        : specialtiesRaw.map(AssetCategorySlugX.fromSlug).toList();
    final lat = json['latitude'] as num?;
    final lng = json['longitude'] as num?;
    return Broker(
      id: json['userId'] as String,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Agent',
      company: (json['company'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      addressLine: json['addressLine'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      specialties: specialties,
      tier: BrokerTierX.fromApi(json['tier'] as String?),
      lockedCategory: specialties.length == 1 ? specialties.first : null,
      latitude: lat?.toDouble() ?? 9.03, // Addis Ababa center fallback
      longitude: lng?.toDouble() ?? 38.74,
      hasPreciseLocation: lat != null && lng != null,
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Categories this broker is actually allowed to post listings in right
  /// now, given their membership tier.
  List<AssetCategorySlug> get postableCategories {
    if (tier.canPostAnyCategory) return specialties;
    return [lockedCategory ?? specialties.first];
  }
}
