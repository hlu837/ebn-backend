/// Structured answers captured by the "Rent it here" wizard when the
/// Visitor is listing a vehicle instead of a property — the car-rental
/// counterpart to [RentalPropertyDetails]. Covers the full Car Rental
/// Listing Form (የመኪና ኪራይ ምዝገባ ቅፅ): Vehicle Specifications, Driver &
/// Lease Terms, Rental Rates & Pricing Structure, Insurance & Security
/// Terms, and Media Upload & Verification.
library;

enum CarRentalCategory { sedanCompact, suvPickup4x4, luxuryEvent, commercialHeavyFreight }

extension CarRentalCategoryX on CarRentalCategory {
  String get label => switch (this) {
        CarRentalCategory.sedanCompact => 'Sedan / Compact',
        CarRentalCategory.suvPickup4x4 => 'SUV / 4x4 / Pickup',
        CarRentalCategory.luxuryEvent => 'Luxury / Event',
        CarRentalCategory.commercialHeavyFreight => 'Commercial / Heavy Freight',
      };

  String get hint => switch (this) {
        CarRentalCategory.sedanCompact => 'For city commuting (Vitz, Dzire, Corolla)',
        CarRentalCategory.suvPickup4x4 => 'For long-distance trips and field projects (Hilux, Land Cruiser, RAV4)',
        CarRentalCategory.luxuryEvent => 'For weddings and VIP guests (Limousine, Mercedes, Prado)',
        CarRentalCategory.commercialHeavyFreight => 'For cargo and transport (Isuzu, Sino Truck)',
      };
}

enum CarRentalFuelType { electric, petrol, diesel }

extension CarRentalFuelTypeX on CarRentalFuelType {
  String get label => switch (this) {
        CarRentalFuelType.electric => 'Electric (EV)',
        CarRentalFuelType.petrol => 'Petrol / Benzine',
        CarRentalFuelType.diesel => 'Diesel',
      };
}

enum DriverOption { withDriverOnly, selfDriveAllowed }

extension DriverOptionX on DriverOption {
  String get label => switch (this) {
        DriverOption.withDriverOnly => 'With Driver Only',
        DriverOption.selfDriveAllowed => 'Self-Drive Allowed',
      };

  String get hint => switch (this) {
        DriverOption.withDriverOnly => 'Provided exclusively with a dedicated driver.',
        DriverOption.selfDriveAllowed => 'The renter is permitted to drive the vehicle.',
      };
}

enum OperationalTerritory { cityLimitsOnly, regionalTravelAllowed }

extension OperationalTerritoryX on OperationalTerritory {
  String get label => switch (this) {
        OperationalTerritory.cityLimitsOnly => 'City Limits Only',
        OperationalTerritory.regionalTravelAllowed => 'Field Trips / Regional Travel Allowed',
      };

  String get hint => switch (this) {
        OperationalTerritory.cityLimitsOnly => 'Addis Ababa only',
        OperationalTerritory.regionalTravelAllowed => 'Cross-country travel allowed',
      };
}

enum FuelCoverage { includedInPrice, coveredByRenter }

extension FuelCoverageX on FuelCoverage {
  String get label => switch (this) {
        FuelCoverage.includedInPrice => 'Fuel included in the rental price',
        FuelCoverage.coveredByRenter => 'Fuel covered by the renter',
      };
}

enum InsuranceCoverageType { thirdPartyOnly, comprehensive }

extension InsuranceCoverageTypeX on InsuranceCoverageType {
  String get label => switch (this) {
        InsuranceCoverageType.thirdPartyOnly => 'Third-Party Only',
        InsuranceCoverageType.comprehensive => 'Comprehensive Insurance',
      };

  String get hint => switch (this) {
        InsuranceCoverageType.thirdPartyOnly => '',
        InsuranceCoverageType.comprehensive => 'Full accidental and liability coverage',
      };
}

/// The five-section "Car Rental Listing Form" questionnaire.
class VehicleRentalDetails {
  // ── 1. Vehicle Specifications ───────────────────────────────────────
  String makeModel;
  CarRentalCategory vehicleCategory;
  CarRentalFuelType fuelType;
  bool hasAirConditioning;

  // ── 2. Driver & Lease Terms ──────────────────────────────────────────
  DriverOption driverOption;
  OperationalTerritory territory;

  // ── 3. Rental Rates & Pricing Structure ─────────────────────────────
  double dailyRateEtb;
  double? monthlyRateEtb;
  bool hasLongTermDiscount;
  FuelCoverage fuelCoverage;
  bool hasDailyMileageLimit;
  int? dailyMileageLimitKm;
  double? overageFeePerKmEtb;

  // ── 4. Insurance & Security Terms ───────────────────────────────────
  InsuranceCoverageType insuranceType;
  bool requiresSecurityDeposit;
  String? securityDepositDetails;

  // ── 5. Media Upload & Verification ──────────────────────────────────
  int photoCount;

  VehicleRentalDetails({
    this.makeModel = '',
    this.vehicleCategory = CarRentalCategory.sedanCompact,
    this.fuelType = CarRentalFuelType.petrol,
    this.hasAirConditioning = true,
    this.driverOption = DriverOption.withDriverOnly,
    this.territory = OperationalTerritory.cityLimitsOnly,
    this.dailyRateEtb = 0,
    this.monthlyRateEtb,
    this.hasLongTermDiscount = false,
    this.fuelCoverage = FuelCoverage.coveredByRenter,
    this.hasDailyMileageLimit = false,
    this.dailyMileageLimitKm,
    this.overageFeePerKmEtb,
    this.insuranceType = InsuranceCoverageType.thirdPartyOnly,
    this.requiresSecurityDeposit = false,
    this.securityDepositDetails,
    this.photoCount = 0,
  });

  /// Renders every answer into a readable block, the same way
  /// [RentalPropertyDetails.toDescriptionText] backs the property rental
  /// wizard's review step.
  String toDescriptionText() {
    final buffer = StringBuffer();
    buffer.writeln('Vehicle Specifications');
    buffer.writeln('• Make & Model: ${makeModel.isEmpty ? 'Not specified' : makeModel}');
    buffer.writeln('• Category: ${vehicleCategory.label}');
    buffer.writeln('• Fuel type: ${fuelType.label}');
    buffer.writeln('• A/C available: ${hasAirConditioning ? 'Yes' : 'No'}');
    buffer.writeln();
    buffer.writeln('Driver & Lease Terms');
    buffer.writeln('• ${driverOption.label}');
    buffer.writeln('• ${territory.label}');
    buffer.writeln();
    buffer.writeln('Rental Rates & Pricing Structure');
    buffer.writeln('• Daily rate: ETB ${dailyRateEtb.toStringAsFixed(0)}');
    if (monthlyRateEtb != null && monthlyRateEtb! > 0) {
      buffer.writeln('• Monthly rate: ETB ${monthlyRateEtb!.toStringAsFixed(0)}'
          '${hasLongTermDiscount ? ' (long-term discount available)' : ''}');
    }
    buffer.writeln('• $fuelCoverageLabel');
    if (hasDailyMileageLimit) {
      buffer.writeln('• Daily mileage limit: ${dailyMileageLimitKm ?? 0} KM/day'
          '${overageFeePerKmEtb != null ? ' — extra ETB ${overageFeePerKmEtb!.toStringAsFixed(0)}/km over the limit' : ''}');
    } else {
      buffer.writeln('• No daily mileage limit');
    }
    buffer.writeln();
    buffer.writeln('Insurance & Security Terms');
    buffer.writeln('• Insurance: ${insuranceType.label}');
    buffer.writeln('• Security deposit: ${requiresSecurityDeposit ? 'Required' : 'Not required'}'
        '${requiresSecurityDeposit && securityDepositDetails?.trim().isNotEmpty == true ? ' — $securityDepositDetails' : ''}');
    buffer.writeln();
    buffer.writeln('Media Upload & Verification');
    buffer.writeln('• Photos attached: $photoCount');
    return buffer.toString().trim();
  }

  String get fuelCoverageLabel => fuelCoverage.label;
}
