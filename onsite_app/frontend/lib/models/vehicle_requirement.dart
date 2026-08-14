/// Structured answers captured by the Vehicle-specific "Order Us" wizard —
/// the buyer/renter-side counterpart to [VehicleDetails] (which captures a
/// seller's listing). Reuses the same condition/origin/fuel/transmission/
/// upholstery/plate enums so the two sides speak the same vocabulary when
/// Admin cross-references a request against live listings.
library;

import 'vehicle_details.dart';
import 'order_request.dart' show RequirementPaymentMethod, RequirementPaymentMethodX;

enum VehicleRequirementClass { light, suvOrPickup, heavyDutyCommercial, motorhomeCampervan }

extension VehicleRequirementClassX on VehicleRequirementClass {
  String get label => switch (this) {
        VehicleRequirementClass.light => 'Light Vehicle (e.g. Corolla, Dzire, Atos)',
        VehicleRequirementClass.suvOrPickup => 'SUV / 4WD / Pickup (e.g. RAV4, Land Cruiser, Hilux)',
        VehicleRequirementClass.heavyDutyCommercial => 'Heavy Duty / Commercial (e.g. Sinotruk, Isuzu, Forward)',
        VehicleRequirementClass.motorhomeCampervan => 'Motorhome / Campervan',
      };
}

enum VehicleRequirementUsage { personalFamily, commercialRental, cargoTransport }

extension VehicleRequirementUsageX on VehicleRequirementUsage {
  String get label => switch (this) {
        VehicleRequirementUsage.personalFamily => 'Personal / Family transport',
        VehicleRequirementUsage.commercialRental => 'Commercial / Rental business',
        VehicleRequirementUsage.cargoTransport => 'Cargo transport',
      };
}

enum EngineCapacityPreference { small, medium, high, noPreference }

extension EngineCapacityPreferenceX on EngineCapacityPreference {
  String get label => switch (this) {
        EngineCapacityPreference.small => 'Small (1.0L – 1.6L)',
        EngineCapacityPreference.medium => 'Medium (2.0L)',
        EngineCapacityPreference.high => 'High capacity (2.0L+)',
        EngineCapacityPreference.noPreference => 'No preference',
      };
}

/// The five-section "Vehicle Buyer/Renter Requirement Form"
/// (የኪራይ/የግዢ መኪና ፈላጊ ፍላጎት መመዝገቢያ ቅፅ) questionnaire.
class VehicleRequirement {
  // ── 1. Category & Usage ─────────────────────────────────────────────
  VehicleRequirementClass vehicleClass;
  VehicleRequirementUsage usage;

  // ── 2. Vehicle Condition & Origin ───────────────────────────────────
  VehicleCondition condition;
  PlateStatus plateStatus;
  VehicleOrigin origin;

  // ── 3. Engine & Power Options ────────────────────────────────────────
  VehicleFuelType fuelType;
  EngineCapacityPreference engineCapacity;
  VehicleTransmission transmission;

  // ── 4. Interior, Tech & Color Preferences ───────────────────────────
  UpholsteryType upholstery;
  int seatingCapacity;
  bool needsAutoAC;
  bool needsInfotainmentPackage; // Android screen + rearview camera + digital dashboard
  String preferredColor;

  // ── 5. Budget & Payment Terms ───────────────────────────────────────
  double maxBudgetMillionEtb;
  RequirementPaymentMethod paymentMethod; // only fullCash / bankLoan used here
  String? downPaymentCapacity; // filled when financing via bank

  VehicleRequirement({
    this.vehicleClass = VehicleRequirementClass.light,
    this.usage = VehicleRequirementUsage.personalFamily,
    this.condition = VehicleCondition.used,
    this.plateStatus = PlateStatus.plated,
    this.origin = VehicleOrigin.fullyImported,
    this.fuelType = VehicleFuelType.petrol,
    this.engineCapacity = EngineCapacityPreference.noPreference,
    this.transmission = VehicleTransmission.automatic,
    this.upholstery = UpholsteryType.cloth,
    this.seatingCapacity = 5,
    this.needsAutoAC = false,
    this.needsInfotainmentPackage = false,
    this.preferredColor = '',
    this.maxBudgetMillionEtb = 0,
    this.paymentMethod = RequirementPaymentMethod.fullCash,
    this.downPaymentCapacity,
  });

  /// Renders every answer into a readable block, same idea as
  /// `VehicleDetails.toDescriptionText()` — keeps plain-text-only screens
  /// (Admin queues, etc.) useful without needing bespoke UI.
  String toDescriptionText() {
    final buffer = StringBuffer();
    buffer.writeln('Category & Usage');
    buffer.writeln('• Vehicle class: ${vehicleClass.label}');
    buffer.writeln('• Intended usage: ${usage.label}');
    buffer.writeln();
    buffer.writeln('Vehicle Condition & Origin');
    buffer.writeln('• Condition: ${condition.label}');
    buffer.writeln('• Plate status: ${plateStatus.label}');
    buffer.writeln('• Origin / assembly: ${origin.label}');
    buffer.writeln();
    buffer.writeln('Engine & Power Options');
    buffer.writeln('• Fuel / power type: ${fuelType.label}');
    buffer.writeln('• Engine capacity: ${engineCapacity.label}');
    buffer.writeln('• Transmission: ${transmission.label}');
    buffer.writeln();
    buffer.writeln('Interior, Tech & Color Preferences');
    buffer.writeln('• Upholstery: ${upholstery.label}');
    buffer.writeln('• Seating capacity: $seatingCapacity-seater');
    buffer.writeln('• Automatic climate control / digital A/C: ${needsAutoAC ? 'Required' : 'Optional / not required'}');
    buffer.writeln('• Android screen, rearview camera & digital dashboard: ${needsInfotainmentPackage ? 'Required' : 'Not required'}');
    if (preferredColor.trim().isNotEmpty) buffer.writeln('• Preferred exterior color: $preferredColor');
    buffer.writeln();
    buffer.writeln('Budget & Payment Terms');
    buffer.writeln('• Maximum budget: ${maxBudgetMillionEtb.toStringAsFixed(2)} million ETB');
    buffer.writeln('• Payment method: ${paymentMethod.label}'
        '${paymentMethod == RequirementPaymentMethod.bankLoan && downPaymentCapacity?.trim().isNotEmpty == true ? ' — down payment capacity: $downPaymentCapacity' : ''}');
    return buffer.toString().trim();
  }
}
