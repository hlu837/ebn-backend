/// "Order Us" — the reverse of Sell/Rent: a Visitor describes what they
/// want to buy/rent instead of listing something themselves. Mirrors the
/// [SellRequest] pattern (submit → land in a queue → get matched) but the
/// payload here is a *requirement*, not a listing.
library;

import 'asset.dart';
import 'machinery_requirement.dart';
import 'vehicle_requirement.dart';

/// Categories that go through the detailed property-buyer questionnaire.
/// Every other category uses [GeneralRequirement] instead.
const kPropertyRequirementCategories = {
  AssetCategorySlug.house,
  AssetCategorySlug.apartments,
  AssetCategorySlug.condominium,
  AssetCategorySlug.building,
  AssetCategorySlug.warehouse,
  AssetCategorySlug.land,
};

/// The Vehicles category goes through its own dedicated buyer/renter
/// questionnaire ([VehicleRequirement]) instead of the generic form.
const kVehicleRequirementCategories = {
  AssetCategorySlug.vehicles,
};

/// The Machinery category goes through its own dedicated buyer/renter
/// questionnaire ([MachineryRequirement]) instead of the generic form.
const kMachineryRequirementCategories = {
  AssetCategorySlug.machinery,
};

enum RequirementPurpose { personalResidence, officeBusiness, investmentRental }

extension RequirementPurposeX on RequirementPurpose {
  String get label => switch (this) {
        RequirementPurpose.personalResidence => 'Personal residence',
        RequirementPurpose.officeBusiness => 'Office / business space',
        RequirementPurpose.investmentRental => 'Investment (rental income)',
      };
}

enum RequirementFinishing { fullyFinished, semiFinishedOffPlan, noPreference }

extension RequirementFinishingX on RequirementFinishing {
  String get label => switch (this) {
        RequirementFinishing.fullyFinished => 'Fully finished — ready to move in',
        RequirementFinishing.semiFinishedOffPlan => 'Semi-finished / off-plan (discounted)',
        RequirementFinishing.noPreference => 'No preference',
      };
}

enum RequirementPaymentMethod { fullCash, bankLoan, installmentRentToOwn }

extension RequirementPaymentMethodX on RequirementPaymentMethod {
  String get label => switch (this) {
        RequirementPaymentMethod.fullCash => 'Full cash',
        RequirementPaymentMethod.bankLoan => 'Bank loan / mortgage',
        RequirementPaymentMethod.installmentRentToOwn => 'Phased / installment (rent-to-own)',
      };
}

enum RequirementUrgency { urgent, browsing }

extension RequirementUrgencyX on RequirementUrgency {
  String get label => switch (this) {
        RequirementUrgency.urgent => 'Urgent — within this week/month',
        RequirementUrgency.browsing => 'Just browsing — deciding over time',
      };
}

enum RequirementDecisionMaker { self, consultingOthers }

extension RequirementDecisionMakerX on RequirementDecisionMaker {
  String get label => switch (this) {
        RequirementDecisionMaker.self => 'I\'ll decide directly',
        RequirementDecisionMaker.consultingOthers => 'Consulting family / other stakeholders',
      };
}

/// The detailed property-buyer questionnaire — one section per step of the
/// checklist: Property Type & Purpose, Location & Accessibility,
/// Specifications & Layout, Budget & Financial Terms, Urgency & Decision.
class PropertyRequirement {
  // ── 1. Property Type & Purpose ──────────────────────────────────────
  AssetCategorySlug propertyType;
  RequirementPurpose purpose;
  RequirementFinishing finishing;

  // ── 2. Location & Accessibility ─────────────────────────────────────
  String preferredAreas; // e.g. "Bole, Saris"
  String accessibilityNotes; // main road / workplace / school proximity

  // ── 3. Specifications & Layout ──────────────────────────────────────
  int minBedrooms;
  int minBathrooms;
  double minAreaSqm;
  double? maxAreaSqm;
  bool needsSpaciousLaundry;
  int parkingCarsNeeded;
  bool needsGuardhouse;
  bool needsSharedAmenities; // relevant for apartments/condos

  // ── 4. Budget & Financial Terms ─────────────────────────────────────
  double budgetMinEtb;
  double budgetMaxEtb;
  RequirementPaymentMethod paymentMethod;
  String? bankLoanDetails; // which bank, approved vs. processing

  // ── 5. Urgency & Decision Making ────────────────────────────────────
  RequirementUrgency urgency;
  RequirementDecisionMaker decisionMaker;

  PropertyRequirement({
    this.propertyType = AssetCategorySlug.house,
    this.purpose = RequirementPurpose.personalResidence,
    this.finishing = RequirementFinishing.fullyFinished,
    this.preferredAreas = '',
    this.accessibilityNotes = '',
    this.minBedrooms = 0,
    this.minBathrooms = 0,
    this.minAreaSqm = 0,
    this.maxAreaSqm,
    this.needsSpaciousLaundry = false,
    this.parkingCarsNeeded = 0,
    this.needsGuardhouse = false,
    this.needsSharedAmenities = false,
    this.budgetMinEtb = 0,
    this.budgetMaxEtb = 0,
    this.paymentMethod = RequirementPaymentMethod.fullCash,
    this.bankLoanDetails,
    this.urgency = RequirementUrgency.browsing,
    this.decisionMaker = RequirementDecisionMaker.self,
  });

  /// Renders every answer into a readable block, same idea as
  /// `HousePropertyDetails.toDescriptionText()` — keeps plain-text-only
  /// screens (Admin queues, etc.) useful without needing bespoke UI.
  String toDescriptionText() {
    final buffer = StringBuffer();
    buffer.writeln('Property Type & Purpose');
    buffer.writeln('• Looking for: ${propertyType.label}');
    buffer.writeln('• Purpose: ${purpose.label}');
    buffer.writeln('• Finishing: ${finishing.label}');
    buffer.writeln();
    buffer.writeln('Location & Accessibility');
    buffer.writeln('• Preferred areas: ${preferredAreas.trim().isNotEmpty ? preferredAreas : 'No preference'}');
    if (accessibilityNotes.trim().isNotEmpty) buffer.writeln('• Accessibility notes: $accessibilityNotes');
    buffer.writeln();
    buffer.writeln('Specifications & Layout');
    buffer.writeln('• Min $minBedrooms bedroom(s), $minBathrooms bathroom(s)');
    buffer.writeln('• Area: ${minAreaSqm.toStringAsFixed(0)} m²${maxAreaSqm != null ? ' – ${maxAreaSqm!.toStringAsFixed(0)} m²' : '+'}');
    final extras = <String>[
      if (needsSpaciousLaundry) 'spacious laundry/utility area',
      if (parkingCarsNeeded > 0) 'parking for $parkingCarsNeeded car(s)',
      if (needsGuardhouse) 'guardhouse',
      if (needsSharedAmenities) 'shared amenities',
    ];
    if (extras.isNotEmpty) buffer.writeln('• Needs: ${extras.join(', ')}');
    buffer.writeln();
    buffer.writeln('Budget & Financial Terms');
    buffer.writeln('• Budget: ETB ${_fmt(budgetMinEtb)} – ETB ${_fmt(budgetMaxEtb)}');
    buffer.writeln('• Payment method: ${paymentMethod.label}'
        '${paymentMethod == RequirementPaymentMethod.bankLoan && bankLoanDetails?.trim().isNotEmpty == true ? ' — $bankLoanDetails' : ''}');
    buffer.writeln();
    buffer.writeln('Urgency & Decision Making');
    buffer.writeln('• ${urgency.label}');
    buffer.writeln('• ${decisionMaker.label}');
    return buffer.toString().trim();
  }

  static String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }
}

/// Lighter requirement form for categories without a dedicated wizard
/// (construction materials, others) — same spirit, fewer fields.
class GeneralRequirement {
  String description; // free text: exactly what they're looking for
  double budgetMinEtb;
  double budgetMaxEtb;
  String preferredLocation;
  RequirementPaymentMethod paymentMethod;
  RequirementUrgency urgency;

  GeneralRequirement({
    this.description = '',
    this.budgetMinEtb = 0,
    this.budgetMaxEtb = 0,
    this.preferredLocation = '',
    this.paymentMethod = RequirementPaymentMethod.fullCash,
    this.urgency = RequirementUrgency.browsing,
  });

  String toDescriptionText() {
    final buffer = StringBuffer();
    buffer.writeln('What they\'re looking for');
    buffer.writeln('• $description');
    buffer.writeln();
    buffer.writeln('Budget & Location');
    buffer.writeln('• Budget: ETB ${PropertyRequirement._fmt(budgetMinEtb)} – ETB ${PropertyRequirement._fmt(budgetMaxEtb)}');
    if (preferredLocation.trim().isNotEmpty) buffer.writeln('• Preferred location: $preferredLocation');
    buffer.writeln('• Payment method: ${paymentMethod.label}');
    buffer.writeln();
    buffer.writeln('Urgency');
    buffer.writeln('• ${urgency.label}');
    return buffer.toString().trim();
  }
}

/// Location a request was submitted with — either read straight from the
/// device's GPS, or a manually typed address that the backend geocodes.
enum OrderLocationSource { gps, manual }

extension OrderLocationSourceX on OrderLocationSource {
  static OrderLocationSource fromApi(String value) => value == 'gps' ? OrderLocationSource.gps : OrderLocationSource.manual;
  String get toApi => this == OrderLocationSource.gps ? 'gps' : 'manual';
}

/// Stages of an "Order Us" request. The Visitor's location (GPS or a
/// geocoded manual address) is used to broadcast the request to nearby
/// agents; whichever agent confirms first is assigned. If it doesn't work
/// out, the Visitor reports it and Admin re-broadcasts the same request.
enum OrderRequestStatus { broadcasting, agentConfirmed, disputed, closed }

extension OrderRequestStatusX on OrderRequestStatus {
  /// The backend's `order_request_status` Postgres enum uses snake_case.
  static OrderRequestStatus fromApi(String value) {
    switch (value) {
      case 'agent_confirmed':
        return OrderRequestStatus.agentConfirmed;
      case 'disputed':
        return OrderRequestStatus.disputed;
      case 'closed':
        return OrderRequestStatus.closed;
      case 'broadcasting':
      default:
        return OrderRequestStatus.broadcasting;
    }
  }

  String get label => switch (this) {
        OrderRequestStatus.broadcasting => 'Finding an agent',
        OrderRequestStatus.agentConfirmed => 'Agent confirmed',
        OrderRequestStatus.disputed => 'Reported',
        OrderRequestStatus.closed => 'Closed',
      };

  /// Same states, worded for the agent's own dashboard instead of the
  /// visitor's — an agent looking at their own assigned request doesn't
  /// need to be told "Agent confirmed", they need to know it's still
  /// open work vs. wrapped up.
  String get agentLabel => switch (this) {
        OrderRequestStatus.broadcasting => 'Awaiting confirmation',
        OrderRequestStatus.agentConfirmed => 'In progress',
        OrderRequestStatus.disputed => 'Reported — under review',
        OrderRequestStatus.closed => 'Completed',
      };

  String get visitorDescription => switch (this) {
        OrderRequestStatus.broadcasting => "We've sent your request to agents near you — waiting for one to confirm.",
        OrderRequestStatus.agentConfirmed => 'An agent has confirmed your request and will reach out directly.',
        OrderRequestStatus.disputed => "We've flagged this and are finding you another agent — no need to resubmit.",
        OrderRequestStatus.closed => 'This request has been closed.',
      };
}

/// Renders the category label into the same title shown across every
/// requirement variant — computed once at submit time and sent to the
/// backend as plain text (mirrors [SellRequest]'s title/description not
/// needing to be reconstructed from JSON).
String composeOrderRequestTitle(AssetCategorySlug category) => 'Looking for ${category.label}';

/// Renders whichever requirement variant is populated into the same
/// free-text description Admin/matching screens read — exactly one of the
/// four should be non-null, matching the category.
String composeOrderRequestDescription({
  PropertyRequirement? propertyRequirement,
  VehicleRequirement? vehicleRequirement,
  MachineryRequirement? machineryRequirement,
  GeneralRequirement? generalRequirement,
}) =>
    propertyRequirement?.toDescriptionText() ??
    vehicleRequirement?.toDescriptionText() ??
    machineryRequirement?.toDescriptionText() ??
    generalRequirement?.toDescriptionText() ??
    '';

/// Budget line for compact display (list rows, cards), regardless of which
/// requirement variant was submitted — computed once at submit time.
String composeOrderRequestBudgetSummary({
  PropertyRequirement? propertyRequirement,
  VehicleRequirement? vehicleRequirement,
  MachineryRequirement? machineryRequirement,
  GeneralRequirement? generalRequirement,
}) {
  if (vehicleRequirement != null) {
    return 'Up to ETB ${vehicleRequirement.maxBudgetMillionEtb.toStringAsFixed(2)}M';
  }
  if (machineryRequirement != null) {
    return 'Up to ETB ${PropertyRequirement._fmt(machineryRequirement.maxBudgetEtb)}';
  }
  final min = propertyRequirement?.budgetMinEtb ?? generalRequirement?.budgetMinEtb ?? 0;
  final max = propertyRequirement?.budgetMaxEtb ?? generalRequirement?.budgetMaxEtb ?? 0;
  return 'ETB ${PropertyRequirement._fmt(min)} – ${PropertyRequirement._fmt(max)}';
}

/// One end-to-end "Order Us" submission — backed by the real
/// `/api/order-requests/*` backend (see `backend/src/models/orderRequests.js`).
///
/// [title]/[description]/[budgetSummary] are rendered client-side from
/// whichever requirement variant (house/apartments/.../vehicles/machinery/
/// general) was filled in, then sent to the backend as plain text — the
/// structured requirement objects themselves aren't persisted or round-tripped,
/// same approach [SellRequest] takes with its wizard details.
class OrderRequest {
  final String id;
  final DateTime submittedAt;
  final String requesterUserId;
  final String requesterName;
  final String requesterPhone;
  final AssetCategorySlug category;

  final String title;
  final String description;
  final String budgetSummary;

  OrderRequestStatus status;

  /// How [latitude]/[longitude] were obtained.
  final OrderLocationSource locationSource;
  final double? latitude;
  final double? longitude;
  /// Only set for [OrderLocationSource.manual] — the geocoded, formatted
  /// address the backend resolved from what the Visitor typed.
  final String? addressText;

  /// Agent ids this request was broadcast to and hasn't lost to someone
  /// else yet (only meaningful while [status] is [OrderRequestStatus.broadcasting]).
  List<String> broadcastAgentIds;
  /// Agent ids excluded from future broadcasts of this request — e.g. an
  /// agent it was reported against, after Admin reposts.
  List<String> excludedAgentIds;

  String? assignedAgentId;
  String? assignedAgentName;
  String? assignedAgentPhone;
  DateTime? confirmedAt;

  /// Why the Visitor reported the assigned agent — set when [status] is
  /// [OrderRequestStatus.disputed].
  String? disputeReason;

  OrderRequest({
    required this.id,
    required this.submittedAt,
    required this.requesterUserId,
    required this.requesterName,
    required this.requesterPhone,
    required this.category,
    required this.title,
    required this.description,
    required this.budgetSummary,
    required this.locationSource,
    this.latitude,
    this.longitude,
    this.addressText,
    this.status = OrderRequestStatus.broadcasting,
    List<String>? broadcastAgentIds,
    List<String>? excludedAgentIds,
    this.assignedAgentId,
    this.assignedAgentName,
    this.assignedAgentPhone,
    this.confirmedAt,
    this.disputeReason,
  })  : broadcastAgentIds = broadcastAgentIds ?? [],
        excludedAgentIds = excludedAgentIds ?? [];

  /// A short line for wherever the request's location needs to be shown
  /// compactly (Admin queue cards, etc).
  String get locationSummary => locationSource == OrderLocationSource.gps
      ? 'Shared location'
      : (addressText?.trim().isNotEmpty == true ? addressText! : 'Manually entered address');

  /// Builds an [OrderRequest] from the backend's camelCase JSON shape (see
  /// `toPublic` in `backend/src/models/orderRequests.js`).
  factory OrderRequest.fromJson(Map<String, dynamic> json) {
    return OrderRequest(
      id: json['id'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      requesterUserId: json['requesterUserId'] as String,
      requesterName: json['requesterName'] as String,
      requesterPhone: json['requesterPhone'] as String,
      category: AssetCategorySlugX.fromSlug(json['category'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
      budgetSummary: json['budgetSummary'] as String,
      status: OrderRequestStatusX.fromApi(json['status'] as String),
      locationSource: OrderLocationSourceX.fromApi(json['locationSource'] as String? ?? 'manual'),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      addressText: json['addressText'] as String?,
      broadcastAgentIds: (json['broadcastAgentIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      excludedAgentIds: (json['excludedAgentIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      assignedAgentId: json['assignedAgentId'] as String?,
      assignedAgentName: json['assignedAgentName'] as String?,
      assignedAgentPhone: json['assignedAgentPhone'] as String?,
      confirmedAt: json['confirmedAt'] != null ? DateTime.parse(json['confirmedAt'] as String) : null,
      disputeReason: json['disputeReason'] as String?,
    );
  }
}
