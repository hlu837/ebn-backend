/// Category an [Asset] belongs to. Mirrors the `categories` table
/// (slug column) so JSON from the API maps straight across.
enum AssetCategorySlug {
  vehicles,
  apartments,
  condominium,
  machinery,
  house,
  warehouse,
  building,
  constructionMaterials,
  land,
  others,
  realEstate, // legacy slug, kept so old mock/API data still resolves
}

extension AssetCategorySlugX on AssetCategorySlug {
  static AssetCategorySlug fromSlug(String slug) {
    switch (slug) {
      case 'vehicles':
        return AssetCategorySlug.vehicles;
      case 'machinery':
        return AssetCategorySlug.machinery;
      case 'condominium':
        return AssetCategorySlug.condominium;
      case 'house':
        return AssetCategorySlug.house;
      case 'warehouse':
        return AssetCategorySlug.warehouse;
      case 'building':
        return AssetCategorySlug.building;
      case 'construction-materials':
        return AssetCategorySlug.constructionMaterials;
      case 'land':
        return AssetCategorySlug.land;
      case 'others':
        return AssetCategorySlug.others;
      case 'real-estate':
        return AssetCategorySlug.realEstate;
      case 'apartments':
      default:
        return AssetCategorySlug.apartments;
    }
  }

  String get label {
    switch (this) {
      case AssetCategorySlug.apartments:
        return 'Apartments';
      case AssetCategorySlug.vehicles:
        return 'Vehicles';
      case AssetCategorySlug.machinery:
        return 'Machinery';
      case AssetCategorySlug.realEstate:
        return 'Real Estate';
      case AssetCategorySlug.condominium:
        return 'Condominium';
      case AssetCategorySlug.house:
        return 'House';
      case AssetCategorySlug.warehouse:
        return 'Warehouse';
      case AssetCategorySlug.building:
        return 'Building';
      case AssetCategorySlug.constructionMaterials:
        return 'Construction Materials';
      case AssetCategorySlug.land:
        return 'Land';
      case AssetCategorySlug.others:
        return 'Others';
    }
  }

  /// Reverse of [fromSlug] — the wire-format string sent to/stored by the
  /// backend (free-text `category` column on `sell_requests`, etc.).
  String get slug {
    switch (this) {
      case AssetCategorySlug.vehicles:
        return 'vehicles';
      case AssetCategorySlug.apartments:
        return 'apartments';
      case AssetCategorySlug.condominium:
        return 'condominium';
      case AssetCategorySlug.machinery:
        return 'machinery';
      case AssetCategorySlug.house:
        return 'house';
      case AssetCategorySlug.warehouse:
        return 'warehouse';
      case AssetCategorySlug.building:
        return 'building';
      case AssetCategorySlug.constructionMaterials:
        return 'construction-materials';
      case AssetCategorySlug.others:
        return 'others';
      case AssetCategorySlug.land:
        return 'land';
      case AssetCategorySlug.realEstate:
        return 'real-estate';
    }
  }
}

/// Mirrors the `asset_status` enum in the DB.
enum AssetStatus { draft, active, underInspection, sold, archived }

extension AssetStatusX on AssetStatus {
  static AssetStatus fromApi(String value) {
    switch (value) {
      case 'under_inspection':
        return AssetStatus.underInspection;
      case 'sold':
        return AssetStatus.sold;
      case 'archived':
        return AssetStatus.archived;
      case 'draft':
        return AssetStatus.draft;
      case 'active':
      default:
        return AssetStatus.active;
    }
  }

  String get label {
    switch (this) {
      case AssetStatus.draft:
        return 'Draft';
      case AssetStatus.active:
        return 'Active';
      case AssetStatus.underInspection:
        return 'Under Inspection';
      case AssetStatus.sold:
        return 'Sold';
      case AssetStatus.archived:
        return 'Archived';
    }
  }
}

/// A single listing, unified across every category. Category-specific
/// details (bedrooms, mileage, etc.) live in [attributes], same as the
/// JSONB column on the backend.
class Asset {
  final String id;
  final String title;
  final double priceAmount;
  final String priceCurrency;
  final String? addressLine;
  final String? city;
  final double latitude;
  final double longitude;
  final AssetCategorySlug category;
  final AssetStatus status;
  final Map<String, dynamic> attributes;
  final String? imageUrl;
  final String? postedLabel; // e.g. "New · 1 hour ago"
  final String? brokerId; // links to Broker.id in models/broker.dart
  final double? rating; // e.g. 4.9 — shown as a star badge on the card image
  final int? reviewCount; // e.g. 120 — shown alongside rating as "(120+)"
  final double? roiPercent; // e.g. 12.0 — shown as a green "12.0% ROI" pill

  const Asset({
    required this.id,
    required this.title,
    required this.priceAmount,
    required this.category,
    required this.status,
    this.priceCurrency = 'ETB',
    this.addressLine,
    this.city,
    this.latitude = 0,
    this.longitude = 0,
    this.attributes = const {},
    this.imageUrl,
    this.postedLabel,
    this.brokerId,
    this.rating,
    this.reviewCount,
    this.roiPercent,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      title: json['title'] as String,
      priceAmount: double.tryParse('${json['price_amount']}') ?? 0,
      priceCurrency: json['price_currency'] as String? ?? 'ETB',
      addressLine: json['address_line'] as String?,
      city: json['city'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      category: AssetCategorySlugX.fromSlug(
          json['category_slug'] as String? ?? 'apartments'),
      status: AssetStatusX.fromApi(json['status'] as String? ?? 'active'),
      attributes:
          (json['attributes'] as Map?)?.cast<String, dynamic>() ?? const {},
      imageUrl: json['image_url'] as String?,
      postedLabel: json['posted_label'] as String?,
      brokerId: json['broker_id'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: (json['review_count'] as num?)?.toInt(),
      roiPercent: (json['roi_percent'] as num?)?.toDouble(),
    );
  }

  /// Short spec line under the price, tailored per category — mirrors
  /// "4 bd · 3 ba · 2,766 sqft" style summaries from listing marketplaces.
  String get specLine {
    switch (category) {
      case AssetCategorySlug.apartments:
      case AssetCategorySlug.realEstate:
      case AssetCategorySlug.condominium:
      case AssetCategorySlug.house:
      case AssetCategorySlug.warehouse:
      case AssetCategorySlug.building:
        final beds = attributes['bedrooms'];
        final baths = attributes['bathrooms'];
        final sqft = attributes['sqft'];
        final parts = <String>[
          if (beds != null) '$beds bd',
          if (baths != null) '$baths ba',
          if (sqft != null) '${_formatThousands(sqft)} sqft',
        ];
        return parts.join(' · ');
      case AssetCategorySlug.vehicles:
        final year = attributes['year'];
        final make = attributes['make'];
        final model = attributes['model'];
        final mileage = attributes['mileage'];
        final parts = <String>[
          if (year != null) '$year',
          if (make != null) '$make',
          if (model != null) '$model',
          if (mileage != null) '${_formatThousands(mileage)} mi',
        ];
        return parts.join(' · ');
      case AssetCategorySlug.machinery:
        final type = attributes['type'];
        final year = attributes['year'];
        final hours = attributes['hours'];
        final parts = <String>[
          if (type != null) '$type',
          if (year != null) '$year',
          if (hours != null) '${_formatThousands(hours)} hrs',
        ];
        return parts.join(' · ');
      case AssetCategorySlug.constructionMaterials:
      case AssetCategorySlug.others:
        final condition = attributes['condition'];
        final quantity = attributes['quantity'];
        final parts = <String>[
          if (condition != null) '$condition',
          if (quantity != null) '$quantity',
        ];
        return parts.join(' · ');
    }
  }

  String get formattedPrice {
    final symbol = switch (priceCurrency) {
      'USD' => '\$',
      'ETB' => 'ETB ',
      _ => '$priceCurrency ',
    };
    return '$symbol${_formatThousands(priceAmount.round())}';
  }

  static String _formatThousands(Object value) {
    final n = value is num ? value : num.tryParse('$value') ?? 0;
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}
