/// Structured answers captured by the "Rent it here" wizard — the rental
/// counterpart to [HousePropertyDetails]. Covers the full Rental Property
/// Detail Form (የኪራይ ንብረት ምዝገባ ቅፅ): Basic Information, Size & Interior
/// Layout, Location & Neighborhood, Amenities & Utilities, and Pricing &
/// Lease Terms.
library;

enum RentalPropertyType { apartment, villa, condominium, studio, commercialShop, officeSpace, warehouse }

extension RentalPropertyTypeX on RentalPropertyType {
  String get label => switch (this) {
        RentalPropertyType.apartment => 'Apartment',
        RentalPropertyType.villa => 'Villa',
        RentalPropertyType.condominium => 'Condominium',
        RentalPropertyType.studio => 'Studio',
        RentalPropertyType.commercialShop => 'Commercial Shop',
        RentalPropertyType.officeSpace => 'Office Space',
        RentalPropertyType.warehouse => 'Warehouse',
      };
}

enum RentalCategory { residential, commercial }

extension RentalCategoryX on RentalCategory {
  String get label => switch (this) {
        RentalCategory.residential => 'Residential',
        RentalCategory.commercial => 'Commercial',
      };
}

enum FurnishingCondition { fullyFurnished, unfurnished }

extension FurnishingConditionX on FurnishingCondition {
  String get label => switch (this) {
        FurnishingCondition.fullyFurnished => 'Fully Furnished',
        FurnishingCondition.unfurnished => 'Unfurnished',
      };
}

enum SubMeterType { dedicated, shared }

extension SubMeterTypeX on SubMeterType {
  String get label => switch (this) {
        SubMeterType.dedicated => 'Dedicated sub-meter',
        SubMeterType.shared => 'Shared meter',
      };
}

enum RentPriceTerms { negotiable, fixed }

extension RentPriceTermsX on RentPriceTerms {
  String get label => switch (this) {
        RentPriceTerms.negotiable => 'Negotiable',
        RentPriceTerms.fixed => 'Fixed',
      };
}

enum AdvancePaymentTerm { threeMonths, sixMonths, oneYear }

extension AdvancePaymentTermX on AdvancePaymentTerm {
  String get label => switch (this) {
        AdvancePaymentTerm.threeMonths => '3 months',
        AdvancePaymentTerm.sixMonths => '6 months',
        AdvancePaymentTerm.oneYear => '1 year',
      };
}

/// The five-section "Rental Property Detail Form" questionnaire.
class RentalPropertyDetails {
  // ── 1. Basic Information ────────────────────────────────────────────
  RentalPropertyType propertyType;
  RentalCategory rentalCategory;
  FurnishingCondition furnishing;

  // ── 2. Size & Interior Layout ───────────────────────────────────────
  double areaSqm;
  String floorLevel;
  int bedrooms;
  int bathrooms;
  bool hasLivingRoomAndKitchen;
  bool hasMaidsOrLaundryRoom;

  // ── 3. Location & Neighborhood ──────────────────────────────────────
  String zoneSubCity;
  String landmark;
  String roadAccessibility;

  // ── 4. Amenities & Utilities ────────────────────────────────────────
  bool hasOwnWaterTank;
  bool hasWaterPump;
  bool isThreePhase;
  SubMeterType meterType;
  bool hasElevator;
  bool hasGeneratorBackup;
  bool hasWasteDisposalAndSecurity;
  int parkingSpaces;

  // ── 5. Pricing & Lease Terms ────────────────────────────────────────
  double monthlyRentEtb;
  RentPriceTerms priceTerms;
  AdvancePaymentTerm advancePayment;
  bool isVacantNow;
  String? availableFromDate;
  String? restrictions;

  RentalPropertyDetails({
    this.propertyType = RentalPropertyType.apartment,
    this.rentalCategory = RentalCategory.residential,
    this.furnishing = FurnishingCondition.unfurnished,
    this.areaSqm = 0,
    this.floorLevel = '',
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.hasLivingRoomAndKitchen = true,
    this.hasMaidsOrLaundryRoom = false,
    this.zoneSubCity = '',
    this.landmark = '',
    this.roadAccessibility = '',
    this.hasOwnWaterTank = false,
    this.hasWaterPump = false,
    this.isThreePhase = false,
    this.meterType = SubMeterType.shared,
    this.hasElevator = false,
    this.hasGeneratorBackup = false,
    this.hasWasteDisposalAndSecurity = false,
    this.parkingSpaces = 0,
    this.monthlyRentEtb = 0,
    this.priceTerms = RentPriceTerms.negotiable,
    this.advancePayment = AdvancePaymentTerm.threeMonths,
    this.isVacantNow = true,
    this.availableFromDate,
    this.restrictions,
  });

  /// Renders every answer into a readable block, the same way
  /// [HousePropertyDetails.toDescriptionText] backs the Sell flow's
  /// generic description field.
  String toDescriptionText() {
    final buffer = StringBuffer();
    buffer.writeln('Basic Information');
    buffer.writeln('• Property type: ${propertyType.label}');
    buffer.writeln('• Rental category: ${rentalCategory.label}');
    buffer.writeln('• Furnishing: ${furnishing.label}');
    buffer.writeln();
    buffer.writeln('Size & Interior Layout');
    buffer.writeln('• Total area: ${areaSqm.toStringAsFixed(0)} m²');
    if (floorLevel.trim().isNotEmpty) buffer.writeln('• Floor level: $floorLevel');
    buffer.writeln('• $bedrooms bedroom(s), $bathrooms bathroom(s)');
    buffer.writeln('• Living room & modern kitchen: ${hasLivingRoomAndKitchen ? 'Yes' : 'No'}');
    buffer.writeln('• Maid\'s / laundry room: ${hasMaidsOrLaundryRoom ? 'Yes' : 'No'}');
    buffer.writeln();
    buffer.writeln('Location & Neighborhood');
    if (zoneSubCity.trim().isNotEmpty) buffer.writeln('• Zone / Sub-City: $zoneSubCity');
    if (landmark.trim().isNotEmpty) buffer.writeln('• Nearby landmark: $landmark');
    if (roadAccessibility.trim().isNotEmpty) buffer.writeln('• Proximity to main asphalt road: $roadAccessibility');
    buffer.writeln();
    buffer.writeln('Amenities & Utilities');
    buffer.writeln('• Water: ${hasOwnWaterTank ? 'Own water tank' : 'No dedicated water tank'}'
        '${hasWaterPump ? ', water pump/motor available' : ''}');
    buffer.writeln('• Electricity: ${isThreePhase ? '3-Phase line' : 'Single-phase line'}, ${meterType.label}');
    final buildingExtras = <String>[
      if (hasElevator) 'elevator/lift',
      if (hasGeneratorBackup) 'backup generator',
      if (hasWasteDisposalAndSecurity) 'waste disposal & 24/7 security',
    ];
    buffer.writeln('• Building features: ${buildingExtras.isEmpty ? 'None' : buildingExtras.join(', ')}');
    buffer.writeln('• Parking: $parkingSpaces secure space(s)');
    buffer.writeln();
    buffer.writeln('Pricing & Lease Terms');
    buffer.writeln('• Monthly rent: ETB ${monthlyRentEtb.toStringAsFixed(0)} (${priceTerms.label})');
    buffer.writeln('• Advance payment required: ${advancePayment.label}');
    buffer.writeln('• Availability: ${isVacantNow ? 'Vacant now' : 'Available from ${availableFromDate ?? 'a specific date'}'}');
    if (restrictions?.trim().isNotEmpty == true) buffer.writeln('• Restrictions: $restrictions');
    return buffer.toString().trim();
  }
}
