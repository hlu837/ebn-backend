/// Structured answers captured by the Construction Machinery-specific
/// "Sell it here" wizard. Only populated when the Visitor is listing under
/// the Machinery category — other categories keep using their own forms.
library;

enum MachineryCategory {
  excavator,
  dozerGrader,
  loaderRoller,
  crane,
  concreteMixerPump,
  forkliftGenerator,
  other,
}

extension MachineryCategoryX on MachineryCategory {
  String get label => switch (this) {
        MachineryCategory.excavator => 'Excavator (ቁፋሮ ማሽን)',
        MachineryCategory.dozerGrader => 'Dozer / Grader',
        MachineryCategory.loaderRoller => 'Loader / Roller (ማውደሚያ)',
        MachineryCategory.crane => 'Crane (Tower / Mobile)',
        MachineryCategory.concreteMixerPump => 'Concrete Mixer / Pump',
        MachineryCategory.forkliftGenerator => 'Forklift / High Capacity Generator',
        MachineryCategory.other => 'Other',
      };
}

enum MachineryCondition { brandNew, used }

extension MachineryConditionX on MachineryCondition {
  String get label => switch (this) {
        MachineryCondition.brandNew => 'Brand New (00 Hours) – Direct from factory',
        MachineryCondition.used => 'Used / Second-hand – Previously operated machine',
      };
}

enum MachineryFuelType { diesel, electric, petrol }

extension MachineryFuelTypeX on MachineryFuelType {
  String get label => switch (this) {
        MachineryFuelType.diesel => 'Diesel',
        MachineryFuelType.electric => 'Electric',
        MachineryFuelType.petrol => 'Petrol / Benzine',
      };
}

enum MachineryPlateStatus { registered, unplated }

extension MachineryPlateStatusX on MachineryPlateStatus {
  String get label => switch (this) {
        MachineryPlateStatus.registered => 'Registered / Plated',
        MachineryPlateStatus.unplated => 'Unplated (Customs Item / Freshly offloaded)',
      };
}

enum MachineryCustomsStatus { dutyPaid, dutyFreeImport }

extension MachineryCustomsStatusX on MachineryCustomsStatus {
  String get label => switch (this) {
        MachineryCustomsStatus.dutyPaid => 'Duty Paid',
        MachineryCustomsStatus.dutyFreeImport => 'Duty Free Import',
      };
}

enum MachineryFinancingOption { bankLoanAllowed, preApprovedBankLoan, cashOnly }

extension MachineryFinancingOptionX on MachineryFinancingOption {
  String get label => switch (this) {
        MachineryFinancingOption.bankLoanAllowed => 'Bank Loan Allowed',
        MachineryFinancingOption.preApprovedBankLoan => 'Pre-Approved Bank Loan',
        MachineryFinancingOption.cashOnly => 'Cash Only',
      };
}

/// The five-section "Construction Machinery Listing Form"
/// (የኮንስትራክሽን ማሽነሪዎች ሽያጭ ምዝገባ ቅፅ) questionnaire.
class MachineryDetails {
  // ── 1. Machinery Type & Brand ───────────────────────────────────────
  MachineryCategory category;
  String otherCategoryDescription;
  String makeBrand;
  String modelAndYear;

  // ── 2. Operational & Technical Status ───────────────────────────────
  MachineryCondition condition;
  int operatingHours;
  int? mileageKm; // optional, for vehicle-based machinery
  MachineryFuelType fuelType;

  // ── 3. Capacity & Specifications ────────────────────────────────────
  String weightLoadCapacity; // e.g. "20 Tons", "50 KVA"
  MachineryPlateStatus plateStatus;
  MachineryCustomsStatus customsStatus;

  // ── 4. Pricing & Financial Options ──────────────────────────────────
  double askingPriceEtb;
  Set<MachineryFinancingOption> financingOptions;
  String? preApprovedPercentage; // e.g. "70%"

  // ── 5. Media Upload & Verification ──────────────────────────────────
  int photoCount;
  int videoCount;
  String videoLink;

  MachineryDetails({
    this.category = MachineryCategory.excavator,
    this.otherCategoryDescription = '',
    this.makeBrand = '',
    this.modelAndYear = '',
    this.condition = MachineryCondition.used,
    this.operatingHours = 0,
    this.mileageKm,
    this.fuelType = MachineryFuelType.diesel,
    this.weightLoadCapacity = '',
    this.plateStatus = MachineryPlateStatus.registered,
    this.customsStatus = MachineryCustomsStatus.dutyPaid,
    this.askingPriceEtb = 0,
    Set<MachineryFinancingOption>? financingOptions,
    this.preApprovedPercentage,
    this.photoCount = 0,
    this.videoCount = 0,
    this.videoLink = '',
  }) : financingOptions = financingOptions ?? {};

  /// JSON sent to the backend (`machinery_details` jsonb column on
  /// `sell_requests`). Nothing currently reads this back on the client —
  /// [toDescriptionText] is what screens display — so this only needs to
  /// be a faithful one-way encode.
  Map<String, dynamic> toJson() => {
        'category': category.name,
        'otherCategoryDescription': otherCategoryDescription,
        'makeBrand': makeBrand,
        'modelAndYear': modelAndYear,
        'condition': condition.name,
        'operatingHours': operatingHours,
        'mileageKm': mileageKm,
        'fuelType': fuelType.name,
        'weightLoadCapacity': weightLoadCapacity,
        'plateStatus': plateStatus.name,
        'customsStatus': customsStatus.name,
        'askingPriceEtb': askingPriceEtb,
        'financingOptions': financingOptions.map((f) => f.name).toList(),
        'preApprovedPercentage': preApprovedPercentage,
        'photoCount': photoCount,
        'videoCount': videoCount,
        'videoLink': videoLink,
      };

  /// Renders every answer into a readable block — this is what backs the
  /// generic [SellRequest.description] field so Admin/Agent screens that
  /// only know how to display plain text still show the full picture.
  String toDescriptionText() {
    final buffer = StringBuffer();
    buffer.writeln('Machinery Type & Brand');
    buffer.writeln('• Category: ${category.label}'
        '${category == MachineryCategory.other && otherCategoryDescription.trim().isNotEmpty ? ' — $otherCategoryDescription' : ''}');
    buffer.writeln('• Make / Brand: $makeBrand');
    buffer.writeln('• Model & Year of Manufacture: $modelAndYear');
    buffer.writeln();
    buffer.writeln('Operational & Technical Status');
    buffer.writeln('• Condition: ${condition.label}');
    buffer.writeln('• Operating Hours: ${operatingHours}hrs'
        '${mileageKm != null && mileageKm! > 0 ? ' · ${mileageKm}km' : ''}');
    buffer.writeln('• Power / Fuel Type: ${fuelType.label}');
    buffer.writeln();
    buffer.writeln('Capacity & Specifications');
    buffer.writeln('• Weight / Load Capacity: $weightLoadCapacity');
    buffer.writeln('• Plate & Document Status: ${plateStatus.label}');
    buffer.writeln('• Customs / Tax Status: ${customsStatus.label}');
    buffer.writeln();
    buffer.writeln('Pricing & Financial Options');
    buffer.writeln('• Asking Price: ${askingPriceEtb.toStringAsFixed(0)} ETB');
    final financing = financingOptions.map((f) => f.label).toList();
    buffer.writeln('• Financing: ${financing.isEmpty ? 'Not specified' : financing.join(', ')}'
        '${financingOptions.contains(MachineryFinancingOption.preApprovedBankLoan) && preApprovedPercentage?.trim().isNotEmpty == true ? ' ($preApprovedPercentage)' : ''}');
    buffer.writeln();
    buffer.writeln('Media Upload & Verification');
    buffer.writeln('• Photos attached: $photoCount');
    buffer.writeln('• Videos attached: $videoCount');
    if (videoLink.trim().isNotEmpty) buffer.writeln('• Video link: $videoLink');
    return buffer.toString().trim();
  }
}
