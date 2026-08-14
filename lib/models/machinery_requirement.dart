/// Structured answers captured by the Machinery-specific "Order Us" wizard —
/// the buyer-side counterpart to [MachineryDetails] (which captures a
/// seller's listing). Reuses the same category/condition/fuel/customs enums
/// so the two sides speak the same vocabulary when Admin cross-references a
/// request against live listings.
library;

import 'machinery_details.dart';

enum MachineryOrigin { directNewImportChina, usedRefurbishedImportChina, europeanUsOrigin, locallyAvailable }

extension MachineryOriginX on MachineryOrigin {
  String get label => switch (this) {
        MachineryOrigin.directNewImportChina => 'Direct Brand New Import from China',
        MachineryOrigin.usedRefurbishedImportChina => 'Used / Refurbished Import from China',
        MachineryOrigin.europeanUsOrigin => 'European / US Origin',
        MachineryOrigin.locallyAvailable => 'Locally Available (Already in Ethiopia)',
      };
}

enum MachineryFinancingPreference { preApprovedFinancing, selfProcessingBankLoan, fullCashPurchase }

extension MachineryFinancingPreferenceX on MachineryFinancingPreference {
  String get label => switch (this) {
        MachineryFinancingPreference.preApprovedFinancing =>
          'Looking for Pre-Approved Financing — only interested in machines with pre-arranged bank/leasing financing from the seller',
        MachineryFinancingPreference.selfProcessingBankLoan =>
          'Self-Processing Bank Loan — just need a proforma invoice & documentation to process my own loan',
        MachineryFinancingPreference.fullCashPurchase => 'Full Cash Purchase — funds ready for immediate payment and takeover',
      };
}

enum MachineryRequirementUrgency { urgentThisWeek, withinOneMonth, overseasOrder }

extension MachineryRequirementUrgencyX on MachineryRequirementUrgency {
  String get label => switch (this) {
        MachineryRequirementUrgency.urgentThisWeek => 'Urgent (Within this week)',
        MachineryRequirementUrgency.withinOneMonth => 'Within 1 month',
        MachineryRequirementUrgency.overseasOrder => 'Willing to wait for an overseas order/shipment (1 to 3 months)',
      };
}

/// The five-section "Construction Machinery Buyer Requirement Form"
/// (የኮንስትራክሽን ማሽነሪ ፈላጊ/ገዢ ፍላጎት መመዝገቢያ ቅፅ) questionnaire.
class MachineryRequirement {
  // ── 1. Machinery Type & Brand Preference ────────────────────────────
  MachineryCategory category;
  String otherCategoryDescription;
  bool anyReliableBrand;
  String specificBrand; // filled when anyReliableBrand is false

  // ── 2. Condition & Origin ────────────────────────────────────────────
  MachineryCondition condition;
  MachineryOrigin origin;

  // ── 3. Technical Specifications & Power Requirements ────────────────
  String workCapacity; // e.g. "20 Tons", "3 m³ Bucket Size"
  MachineryFuelType fuelType;
  MachineryCustomsStatus customsStatus;

  // ── 4. Budget & Financing Options ────────────────────────────────────
  double maxBudgetEtb;
  MachineryFinancingPreference financingPreference;

  // ── 5. Urgency & Timeline ─────────────────────────────────────────────
  MachineryRequirementUrgency urgency;

  MachineryRequirement({
    this.category = MachineryCategory.excavator,
    this.otherCategoryDescription = '',
    this.anyReliableBrand = true,
    this.specificBrand = '',
    this.condition = MachineryCondition.used,
    this.origin = MachineryOrigin.locallyAvailable,
    this.workCapacity = '',
    this.fuelType = MachineryFuelType.diesel,
    this.customsStatus = MachineryCustomsStatus.dutyPaid,
    this.maxBudgetEtb = 0,
    this.financingPreference = MachineryFinancingPreference.fullCashPurchase,
    this.urgency = MachineryRequirementUrgency.withinOneMonth,
  });

  /// Renders every answer into a readable block, same idea as
  /// `MachineryDetails.toDescriptionText()` — keeps plain-text-only screens
  /// (Admin queues, etc.) useful without needing bespoke UI.
  String toDescriptionText() {
    final buffer = StringBuffer();
    buffer.writeln('Machinery Type & Brand Preference');
    buffer.writeln('• Category required: ${category.label}'
        '${category == MachineryCategory.other && otherCategoryDescription.trim().isNotEmpty ? ' — $otherCategoryDescription' : ''}');
    buffer.writeln('• Brand preference: ${anyReliableBrand ? 'Any reliable brand' : 'Specific brand only — $specificBrand'}');
    buffer.writeln();
    buffer.writeln('Condition & Origin');
    buffer.writeln('• Machine condition: ${condition.label}');
    buffer.writeln('• Origin / import category: ${origin.label}');
    buffer.writeln();
    buffer.writeln('Technical Specifications & Power Requirements');
    buffer.writeln('• Required work capacity / operating weight: ${workCapacity.trim().isNotEmpty ? workCapacity : 'Not specified'}');
    buffer.writeln('• Power / fuel type: ${fuelType.label}');
    buffer.writeln('• Customs status: ${customsStatus.label}');
    buffer.writeln();
    buffer.writeln('Budget & Financing Options');
    buffer.writeln('• Maximum budget: ${maxBudgetEtb.toStringAsFixed(0)} ETB');
    buffer.writeln('• Financing: ${financingPreference.label}');
    buffer.writeln();
    buffer.writeln('Urgency & Timeline');
    buffer.writeln('• ${urgency.label}');
    return buffer.toString().trim();
  }
}
