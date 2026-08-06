/// Structured answers captured by the House-specific "Sell it here" wizard.
/// Only populated when the Visitor is listing a house/villa/apartment/
/// condominium — other categories keep using the simple generic form.
library;

enum HousePropertyType { apartment, villa, condominium }

extension HousePropertyTypeX on HousePropertyType {
  String get label => switch (this) {
        HousePropertyType.apartment => 'Apartment',
        HousePropertyType.villa => 'Villa',
        HousePropertyType.condominium => 'Condominium',
      };
}

enum FinishingStatus { fullyFinished, semiFinished }

extension FinishingStatusX on FinishingStatus {
  String get label => switch (this) {
        FinishingStatus.fullyFinished => 'Fully finished',
        FinishingStatus.semiFinished => 'Semi-finished',
      };
}

enum PaymentOption { fullCash, bankLoan, either }

extension PaymentOptionX on PaymentOption {
  String get label => switch (this) {
        PaymentOption.fullCash => 'Full cash only',
        PaymentOption.bankLoan => 'Bank loan',
        PaymentOption.either => 'Full cash or bank loan',
      };
}

enum BankLiabilityStatus { clear, hasLien }

extension BankLiabilityStatusX on BankLiabilityStatus {
  String get label => switch (this) {
        BankLiabilityStatus.clear => 'Clear — no loan or restriction',
        BankLiabilityStatus.hasLien => 'Existing bank loan / lien',
      };
}

enum LeaseStatus { freehold, lease }

extension LeaseStatusX on LeaseStatus {
  String get label => switch (this) {
        LeaseStatus.freehold => 'Freehold',
        LeaseStatus.lease => 'Leasehold',
      };
}

/// The four-section "A House for Sale" questionnaire.
class HousePropertyDetails {
  // ── 1. Property Details ─────────────────────────────────────────────
  HousePropertyType propertyType;

  /// How close the property is to the main road (free text, e.g. "5 min walk").
  String roadProximity;
  double areaSqm;
  int bedrooms;
  int bathrooms;
  bool hasLivingRoom;
  bool hasKitchen;
  FinishingStatus finishingStatus;

  // ── 2. Pricing & Payment Terms ──────────────────────────────────────
  bool priceNegotiable;
  PaymentOption paymentOption;
  BankLiabilityStatus bankLiability;
  String? bankLiabilityDetails;

  // ── 3. Legal & Documentation ────────────────────────────────────────
  bool hasDigitalTitleDeed; // "Carta"
  bool titleDeedUnderSellerName;
  LeaseStatus leaseStatus;
  double? leaseAmountPaid;
  double? leaseAmountRemaining;
  bool isDirectOwner;
  String? representativeDetails; // filled when acting as power of attorney

  // ── 4. Amenities & Infrastructure ───────────────────────────────────
  bool waterConnected;
  bool hasWaterTank;
  bool electricityConnected;
  bool isThreePhase;
  bool drainageConnected;
  int parkingCapacity;
  bool hasGuardhouse;
  bool hasElevator;
  bool hasGeneratorBackup;

  HousePropertyDetails({
    this.propertyType = HousePropertyType.apartment,
    this.roadProximity = '',
    this.areaSqm = 0,
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.hasLivingRoom = true,
    this.hasKitchen = true,
    this.finishingStatus = FinishingStatus.fullyFinished,
    this.priceNegotiable = false,
    this.paymentOption = PaymentOption.either,
    this.bankLiability = BankLiabilityStatus.clear,
    this.bankLiabilityDetails,
    this.hasDigitalTitleDeed = false,
    this.titleDeedUnderSellerName = true,
    this.leaseStatus = LeaseStatus.freehold,
    this.leaseAmountPaid,
    this.leaseAmountRemaining,
    this.isDirectOwner = true,
    this.representativeDetails,
    this.waterConnected = true,
    this.hasWaterTank = false,
    this.electricityConnected = true,
    this.isThreePhase = false,
    this.drainageConnected = true,
    this.parkingCapacity = 0,
    this.hasGuardhouse = false,
    this.hasElevator = false,
    this.hasGeneratorBackup = false,
  });

  /// JSON sent to the backend (`house_details` jsonb column on
  /// `sell_requests`). Nothing currently reads this back on the client —
  /// [toDescriptionText] is what screens display — so this only needs to
  /// be a faithful one-way encode.
  Map<String, dynamic> toJson() => {
        'propertyType': propertyType.name,
        'roadProximity': roadProximity,
        'areaSqm': areaSqm,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'hasLivingRoom': hasLivingRoom,
        'hasKitchen': hasKitchen,
        'finishingStatus': finishingStatus.name,
        'priceNegotiable': priceNegotiable,
        'paymentOption': paymentOption.name,
        'bankLiability': bankLiability.name,
        'bankLiabilityDetails': bankLiabilityDetails,
        'hasDigitalTitleDeed': hasDigitalTitleDeed,
        'titleDeedUnderSellerName': titleDeedUnderSellerName,
        'leaseStatus': leaseStatus.name,
        'leaseAmountPaid': leaseAmountPaid,
        'leaseAmountRemaining': leaseAmountRemaining,
        'isDirectOwner': isDirectOwner,
        'representativeDetails': representativeDetails,
        'waterConnected': waterConnected,
        'hasWaterTank': hasWaterTank,
        'electricityConnected': electricityConnected,
        'isThreePhase': isThreePhase,
        'drainageConnected': drainageConnected,
        'parkingCapacity': parkingCapacity,
        'hasGuardhouse': hasGuardhouse,
        'hasElevator': hasElevator,
        'hasGeneratorBackup': hasGeneratorBackup,
      };

  /// Renders every answer into a readable block — this is what backs the
  /// generic [SellRequest.description] field so Admin/Agent screens that
  /// only know how to display plain text still show the full picture.
  String toDescriptionText() {
    final buffer = StringBuffer();
    buffer.writeln('Property Details');
    buffer.writeln('• Type: ${propertyType.label}');
    if (roadProximity.trim().isNotEmpty) buffer.writeln('• Proximity to main road: $roadProximity');
    buffer.writeln('• Area: ${areaSqm.toStringAsFixed(0)} m²');
    buffer.writeln('• $bedrooms bedroom(s), $bathrooms bathroom(s)'
        '${hasLivingRoom ? ', living room' : ''}${hasKitchen ? ', kitchen' : ''}');
    buffer.writeln('• Finishing: ${finishingStatus.label}');
    buffer.writeln();
    buffer.writeln('Pricing & Payment Terms');
    buffer.writeln('• Price is ${priceNegotiable ? 'negotiable' : 'fixed'}');
    buffer.writeln('• Payment: ${paymentOption.label}');
    buffer.writeln('• Bank liability: ${bankLiability.label}'
        '${bankLiabilityDetails?.trim().isNotEmpty == true ? ' — $bankLiabilityDetails' : ''}');
    buffer.writeln();
    buffer.writeln('Legal & Documentation');
    buffer.writeln('• Digital title deed (Carta): ${hasDigitalTitleDeed ? 'Yes' : 'No'}');
    buffer.writeln('• Title deed under seller\'s name: ${titleDeedUnderSellerName ? 'Yes' : 'No'}');
    buffer.writeln('• ${leaseStatus.label}'
        '${leaseStatus == LeaseStatus.lease ? ' — paid ${leaseAmountPaid ?? 0}, remaining ${leaseAmountRemaining ?? 0}' : ''}');
    buffer.writeln('• Submitted by: ${isDirectOwner ? 'Direct owner' : 'Legal representative (power of attorney)'}'
        '${!isDirectOwner && representativeDetails?.trim().isNotEmpty == true ? ' — $representativeDetails' : ''}');
    buffer.writeln();
    buffer.writeln('Amenities & Infrastructure');
    buffer.writeln('• Water: ${waterConnected ? 'Connected' : 'Not connected'}${hasWaterTank ? ' (has water tank)' : ''}');
    buffer.writeln('• Electricity: ${electricityConnected ? 'Connected' : 'Not connected'}${isThreePhase ? ' (3-phase)' : ''}');
    buffer.writeln('• Drainage: ${drainageConnected ? 'Connected' : 'Not connected'}');
    buffer.writeln('• Parking: $parkingCapacity car(s)');
    final extras = <String>[
      if (hasGuardhouse) 'guardhouse',
      if (hasElevator) 'elevator service',
      if (hasGeneratorBackup) 'generator backup',
    ];
    buffer.writeln('• Extras: ${extras.isEmpty ? 'None' : extras.join(', ')}');
    return buffer.toString().trim();
  }
}
