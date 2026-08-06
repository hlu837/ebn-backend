import 'asset.dart';
import 'house_property_details.dart';
import 'vehicle_details.dart';
import 'machinery_details.dart';

/// Stages of the "Sell my property" pipeline — separate from [LoopStage]
/// (the tour-request loop). A Visitor submits a property + pays a listing
/// fee, Admin screens it, any online Agent/Broker can claim it and go
/// inspect it in person, then Admin reviews the Agent's inspection report
/// before the property goes live under that Agent's name.
enum SellRequestStatus {
  /// Submitted + paid, waiting for Admin to screen it.
  pendingAdminApproval,

  /// Admin rejected the submission outright — never opened to brokers.
  submissionRejected,

  /// Admin approved it — sent to nearby Agents/Brokers first, first to
  /// claim wins. Falls back to [openToBrokers] if there's no usable
  /// location on file or no agent nearby.
  broadcasting,

  /// Admin approved it (fallback) — visible to every Agent/Broker to claim.
  openToBrokers,

  /// An Agent claimed it and is expected to go inspect it in person.
  claimed,

  /// Agent submitted their inspection report — waiting for Admin's final
  /// sign-off before it becomes a real listing.
  reportPendingApproval,

  /// Admin sent the report back — Agent can revise and resubmit.
  reportRejected,

  /// Admin approved the report — now a real, live [Asset] listed under the
  /// claiming Agent's name.
  listed,
}

extension SellRequestStatusX on SellRequestStatus {
  /// The backend's `sell_request_status` Postgres enum uses snake_case.
  static SellRequestStatus fromApi(String value) {
    switch (value) {
      case 'submission_rejected':
        return SellRequestStatus.submissionRejected;
      case 'broadcasting':
        return SellRequestStatus.broadcasting;
      case 'open_to_brokers':
        return SellRequestStatus.openToBrokers;
      case 'claimed':
        return SellRequestStatus.claimed;
      case 'report_pending_approval':
        return SellRequestStatus.reportPendingApproval;
      case 'report_rejected':
        return SellRequestStatus.reportRejected;
      case 'listed':
        return SellRequestStatus.listed;
      case 'pending_admin_approval':
      default:
        return SellRequestStatus.pendingAdminApproval;
    }
  }

  String get label => switch (this) {
        SellRequestStatus.pendingAdminApproval => 'Pending review',
        SellRequestStatus.submissionRejected => 'Rejected',
        SellRequestStatus.broadcasting => 'Alerting nearby agents',
        SellRequestStatus.openToBrokers => 'Open to brokers',
        SellRequestStatus.claimed => 'Broker assigned',
        SellRequestStatus.reportPendingApproval => 'Report under review',
        SellRequestStatus.reportRejected => 'Report needs changes',
        SellRequestStatus.listed => 'Listed',
      };

  /// Visitor-facing copy — a little more explanatory than the admin/agent
  /// facing [label].
  String get visitorDescription => switch (this) {
        SellRequestStatus.pendingAdminApproval =>
          'We received your submission and the 100 ETB fee. Our team is reviewing it now.',
        SellRequestStatus.submissionRejected => 'This submission wasn\'t approved. See the note below.',
        SellRequestStatus.broadcasting => 'Approved! We\'ve alerted brokers near you — waiting for one to pick it up.',
        SellRequestStatus.openToBrokers => 'Approved! Waiting for a broker to pick it up for inspection.',
        SellRequestStatus.claimed => 'A broker has been assigned and will visit to inspect the property.',
        SellRequestStatus.reportPendingApproval => 'The broker submitted their inspection report — pending final approval.',
        SellRequestStatus.reportRejected => 'The inspection report needs changes before it can go live.',
        SellRequestStatus.listed => 'Your property is live on the marketplace!',
      };
}

/// A photo/video attached to an inspection report. In this frontend-only
/// demo there's no real file picker or upload — each entry is just a mock
/// placeholder the Agent "adds" from the report form.
class ReportMediaItem {
  final String id;
  final bool isVideo;
  const ReportMediaItem({required this.id, this.isVideo = false});

  factory ReportMediaItem.fromJson(Map<String, dynamic> json) =>
      ReportMediaItem(id: json['id'] as String, isVideo: json['isVideo'] as bool? ?? false);

  Map<String, dynamic> toJson() => {'id': id, 'isVideo': isVideo};
}

/// One end-to-end "sell my property" submission.
class SellRequest {
  final String id;
  final DateTime submittedAt;

  // ── Visitor submission ────────────────────────────────────────────────
  final String ownerUserId;
  final String ownerName;
  final String ownerPhone;
  final AssetCategorySlug category;
  final String title;
  final String description;
  final double askingPrice;
  final String city;
  final String addressLine;

  /// Geocoded server-side from [addressLine]/[city] at submission — null if
  /// geocoding wasn't available/failed, in which case approval falls back
  /// to opening the request to every agent instead of just nearby ones.
  final double? latitude;
  final double? longitude;

  final double feeAmount;
  final bool feePaid;

  /// Populated only when this submission went through the House-specific
  /// wizard (Property Type is house/villa/apartment/condominium). `null`
  /// for submissions made through the generic short form.
  final HousePropertyDetails? houseDetails;

  /// Populated only when this submission went through the Vehicle-specific
  /// wizard (category is Vehicles). `null` for every other submission.
  final VehicleDetails? vehicleDetails;

  /// Populated only when this submission went through the Machinery-specific
  /// wizard (category is Machinery). `null` for every other submission.
  final MachineryDetails? machineryDetails;

  /// True when an Agent submitted this for a property they own themselves
  /// (see `SellPropertyFormScreen(isAgentListing: true)`) — already carries
  /// its own [reportMedia]/[reportNotes] at submission time, and Admin's
  /// approval publishes it directly under [agentName] instead of opening it
  /// to the claim pool.
  final bool isAgentListing;

  // ── Admin (submission stage) ────────────────────────────────────────────
  String? submissionRejectionReason;

  /// Agent ids this request is currently broadcasting to while
  /// [status] is [SellRequestStatus.broadcasting] — empty otherwise.
  final List<String> broadcastAgentIds;

  // ── Agent claim ──────────────────────────────────────────────────────
  String? agentId;
  String? agentName;
  DateTime? claimedAt;

  // ── Agent inspection report ─────────────────────────────────────────────
  List<ReportMediaItem> reportMedia;
  String? reportNotes;
  DateTime? reportSubmittedAt;
  String? reportRejectionReason;

  // ── Final listing ────────────────────────────────────────────────────
  String? listedAssetId;

  SellRequestStatus status;

  SellRequest({
    required this.id,
    required this.submittedAt,
    required this.ownerUserId,
    required this.ownerName,
    required this.ownerPhone,
    required this.category,
    required this.title,
    required this.description,
    required this.askingPrice,
    required this.city,
    required this.addressLine,
    this.latitude,
    this.longitude,
    this.feeAmount = 100,
    this.feePaid = true,
    this.houseDetails,
    this.vehicleDetails,
    this.machineryDetails,
    this.isAgentListing = false,
    this.status = SellRequestStatus.pendingAdminApproval,
    this.submissionRejectionReason,
    List<String>? broadcastAgentIds,
    this.agentId,
    this.agentName,
    this.claimedAt,
    List<ReportMediaItem>? reportMedia,
    this.reportNotes,
    this.reportSubmittedAt,
    this.reportRejectionReason,
    this.listedAssetId,
  })  : reportMedia = reportMedia ?? [],
        broadcastAgentIds = broadcastAgentIds ?? [];

  /// Builds a [SellRequest] from the backend's camelCase JSON shape (see
  /// `toPublic` in `backend/src/models/sellRequests.js`).
  ///
  /// Note: [houseDetails] / [vehicleDetails] / [machineryDetails] are not
  /// reconstructed from JSON — nothing on the client reads them back off a
  /// fetched request ([toDescriptionText] is baked into [description] at
  /// submit time), so round-tripping them isn't needed.
  factory SellRequest.fromJson(Map<String, dynamic> json) {
    return SellRequest(
      id: json['id'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      ownerUserId: json['ownerUserId'] as String,
      ownerName: json['ownerName'] as String,
      ownerPhone: json['ownerPhone'] as String,
      category: AssetCategorySlugX.fromSlug(json['category'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
      askingPrice: (json['askingPrice'] as num).toDouble(),
      city: json['city'] as String,
      addressLine: json['addressLine'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      feeAmount: (json['feeAmount'] as num?)?.toDouble() ?? 100,
      feePaid: json['feePaid'] as bool? ?? true,
      isAgentListing: json['isAgentListing'] as bool? ?? false,
      status: SellRequestStatusX.fromApi(json['status'] as String),
      submissionRejectionReason: json['submissionRejectionReason'] as String?,
      broadcastAgentIds: (json['broadcastAgentIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      agentId: json['agentId'] as String?,
      agentName: json['agentName'] as String?,
      claimedAt: json['claimedAt'] != null ? DateTime.parse(json['claimedAt'] as String) : null,
      reportMedia: (json['reportMedia'] as List<dynamic>?)
              ?.map((m) => ReportMediaItem.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      reportNotes: json['reportNotes'] as String?,
      reportSubmittedAt:
          json['reportSubmittedAt'] != null ? DateTime.parse(json['reportSubmittedAt'] as String) : null,
      reportRejectionReason: json['reportRejectionReason'] as String?,
      listedAssetId: json['listedAssetId'] as String?,
    );
  }

  /// Status copy for whoever submitted this, shown in "my submissions".
  /// An Agent's own self-listing ([isAgentListing]) never enters the
  /// broadcasting/claimed/report stages — it goes straight from pending
  /// review to listed — so it gets its own phrasing instead of
  /// [SellRequestStatusX.visitorDescription]'s broker-assignment language.
  String get statusDescription {
    if (!isAgentListing) return status.visitorDescription;
    switch (status) {
      case SellRequestStatus.pendingAdminApproval:
        return 'We received your listing and the 100 ETB fee. Our team is reviewing it now.';
      case SellRequestStatus.submissionRejected:
        return 'This listing wasn\'t approved. See the note below.';
      case SellRequestStatus.listed:
        return 'Your property is live on the marketplace, listed under your name.';
      default:
        return status.visitorDescription;
    }
  }
}
