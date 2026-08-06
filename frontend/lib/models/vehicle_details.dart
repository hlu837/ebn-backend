/// Structured answers captured by the Vehicle-specific "Sell it here"
/// wizard. Only populated when the Visitor is listing a car under the
/// Vehicles category — other categories keep using the simple generic form.
library;

enum VehicleCondition { brandNew, used }

extension VehicleConditionX on VehicleCondition {
  String get label => switch (this) {
        VehicleCondition.brandNew => 'Brand New / 0 KM',
        VehicleCondition.used => 'Used / Locally Driven',
      };
}

enum VehicleOrigin { fullyImported, locallyAssembled }

extension VehicleOriginX on VehicleOrigin {
  String get label => switch (this) {
        VehicleOrigin.fullyImported => 'Fully Imported (CBU)',
        VehicleOrigin.locallyAssembled => 'Locally Assembled in Ethiopia (SKD/CKD)',
      };
}

enum VehicleFuelType { petrol, diesel, electric }

extension VehicleFuelTypeX on VehicleFuelType {
  String get label => switch (this) {
        VehicleFuelType.petrol => 'Petrol / Benzine',
        VehicleFuelType.diesel => 'Diesel',
        VehicleFuelType.electric => 'Electric (EV)',
      };
}

enum VehicleTransmission { automatic, manual }

extension VehicleTransmissionX on VehicleTransmission {
  String get label => switch (this) {
        VehicleTransmission.automatic => 'Automatic',
        VehicleTransmission.manual => 'Manual',
      };
}

enum UpholsteryType { creamLeather, blackLeather, cloth }

extension UpholsteryTypeX on UpholsteryType {
  String get label => switch (this) {
        UpholsteryType.creamLeather => 'Cream Leather',
        UpholsteryType.blackLeather => 'Black Leather',
        UpholsteryType.cloth => 'Cloth',
      };
}

enum VehiclePaymentTerms { cashOnly, bankLoanFriendly }

extension VehiclePaymentTermsX on VehiclePaymentTerms {
  String get label => switch (this) {
        VehiclePaymentTerms.cashOnly => 'Cash Only',
        VehiclePaymentTerms.bankLoanFriendly => 'Bank Loan Friendly',
      };
}

enum PlateStatus { plated, unplated }

extension PlateStatusX on PlateStatus {
  String get label => switch (this) {
        PlateStatus.plated => 'Registered / Plated',
        PlateStatus.unplated => 'Unplated (Fresh Duty / Customs item)',
      };
}

enum CustomsDutyStatus { dutyPaid, dutyFree }

extension CustomsDutyStatusX on CustomsDutyStatus {
  String get label => switch (this) {
        CustomsDutyStatus.dutyPaid => 'Fully Duty Paid',
        CustomsDutyStatus.dutyFree => 'Duty Free',
      };
}

/// The five-section "Vehicle Listing Form" (የመኪና ሽያጭ ምዝገባ ቅፅ) questionnaire.
class VehicleDetails {
  // ── 1. Vehicle Overview ─────────────────────────────────────────────
  String makeModel;
  int yearOfManufacture;
  VehicleCondition condition;
  VehicleOrigin origin;

  // ── 2. Technical Specifications ─────────────────────────────────────
  int mileageKm;
  String engineCapacity; // free text, e.g. "1.6L"
  VehicleFuelType fuelType;
  VehicleTransmission transmission;
  String rimTyreSize; // e.g. "R16"

  // ── 3. Interior & Exterior Features ─────────────────────────────────
  UpholsteryType upholstery;
  bool hasAndroidScreenAndCamera;
  String exteriorColor;

  // ── 4. Pricing & Payment Options ────────────────────────────────────
  double askingPriceMillionEtb;
  VehiclePaymentTerms paymentTerms;
  String? bankLoanPriceAdjustment;

  // ── 5. Documentation & Customs ──────────────────────────────────────
  PlateStatus plateStatus;
  String? plateCode; // e.g. "Code 2 – Axxxxx AA"
  CustomsDutyStatus customsDutyStatus;

  VehicleDetails({
    this.makeModel = '',
    this.yearOfManufacture = 0,
    this.condition = VehicleCondition.used,
    this.origin = VehicleOrigin.fullyImported,
    this.mileageKm = 0,
    this.engineCapacity = '',
    this.fuelType = VehicleFuelType.petrol,
    this.transmission = VehicleTransmission.automatic,
    this.rimTyreSize = '',
    this.upholstery = UpholsteryType.cloth,
    this.hasAndroidScreenAndCamera = false,
    this.exteriorColor = '',
    this.askingPriceMillionEtb = 0,
    this.paymentTerms = VehiclePaymentTerms.cashOnly,
    this.bankLoanPriceAdjustment,
    this.plateStatus = PlateStatus.plated,
    this.plateCode,
    this.customsDutyStatus = CustomsDutyStatus.dutyPaid,
  });

  /// JSON sent to the backend (`vehicle_details` jsonb column on
  /// `sell_requests`). Nothing currently reads this back on the client —
  /// [toDescriptionText] is what screens display — so this only needs to
  /// be a faithful one-way encode.
  Map<String, dynamic> toJson() => {
        'makeModel': makeModel,
        'yearOfManufacture': yearOfManufacture,
        'condition': condition.name,
        'origin': origin.name,
        'mileageKm': mileageKm,
        'engineCapacity': engineCapacity,
        'fuelType': fuelType.name,
        'transmission': transmission.name,
        'rimTyreSize': rimTyreSize,
        'upholstery': upholstery.name,
        'hasAndroidScreenAndCamera': hasAndroidScreenAndCamera,
        'exteriorColor': exteriorColor,
        'askingPriceMillionEtb': askingPriceMillionEtb,
        'paymentTerms': paymentTerms.name,
        'bankLoanPriceAdjustment': bankLoanPriceAdjustment,
        'plateStatus': plateStatus.name,
        'plateCode': plateCode,
        'customsDutyStatus': customsDutyStatus.name,
      };

  /// Renders every answer into a readable block — this is what backs the
  /// generic [SellRequest.description] field so Admin/Agent screens that
  /// only know how to display plain text still show the full picture.
  String toDescriptionText() {
    final buffer = StringBuffer();
    buffer.writeln('Vehicle Overview');
    buffer.writeln('• Make & Model: $makeModel');
    buffer.writeln('• Year of Manufacture: $yearOfManufacture');
    buffer.writeln('• Condition: ${condition.label}');
    buffer.writeln('• Origin / Assembly: ${origin.label}');
    buffer.writeln();
    buffer.writeln('Technical Specifications');
    buffer.writeln('• Mileage: ${mileageKm}km');
    buffer.writeln('• Engine Capacity: $engineCapacity');
    buffer.writeln('• Fuel Type: ${fuelType.label}');
    buffer.writeln('• Transmission: ${transmission.label}');
    buffer.writeln('• Rim/Tyre Size: $rimTyreSize');
    buffer.writeln();
    buffer.writeln('Interior & Exterior Features');
    buffer.writeln('• Upholstery / Seat Material: ${upholstery.label}');
    buffer.writeln('• Android Screen & Rearview Camera: ${hasAndroidScreenAndCamera ? 'Yes' : 'No'}');
    buffer.writeln('• Exterior Color: $exteriorColor');
    buffer.writeln();
    buffer.writeln('Pricing & Payment Options');
    buffer.writeln('• Asking Price: ${askingPriceMillionEtb.toStringAsFixed(2)} million ETB');
    buffer.writeln('• Payment Terms: ${paymentTerms.label}'
        '${paymentTerms == VehiclePaymentTerms.bankLoanFriendly && bankLoanPriceAdjustment?.trim().isNotEmpty == true ? ' — $bankLoanPriceAdjustment' : ''}');
    buffer.writeln();
    buffer.writeln('Documentation & Customs');
    buffer.writeln('• License Plate Status: ${plateStatus.label}'
        '${plateStatus == PlateStatus.plated && plateCode?.trim().isNotEmpty == true ? ' — $plateCode' : ''}');
    buffer.writeln('• Customs Duty & Taxes: ${customsDutyStatus.label}');
    return buffer.toString().trim();
  }
}
