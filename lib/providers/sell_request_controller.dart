import 'package:flutter/foundation.dart';
import '../models/asset.dart';
import '../models/house_property_details.dart';
import '../models/vehicle_details.dart';
import '../models/machinery_details.dart';
import '../models/sell_request.dart';
import '../services/asset_service.dart';
import '../services/sell_request_service.dart';

/// Single source of truth for every "sell my property" submission — backed
/// by the real `/api/sell-requests/*` backend. Keeps a local cache so every
/// side (Visitor / Admin / Agent) watching this one instance still reads
/// plain synchronous getters exactly as before; screens are responsible for
/// triggering the `fetch*`/`refresh*` call that keeps their slice current
/// (typically once in `initState`).
class SellRequestController extends ChangeNotifier {
  SellRequestController({SellRequestService? service, AssetService? assetService})
      : _service = service ?? SellRequestService(),
        _assetService = assetService ?? AssetService();

  final SellRequestService _service;
  final AssetService _assetService;

  final List<SellRequest> _requests = [];

  List<SellRequest> get all => List.unmodifiable(_requests);

  bool isLoading = false;

  void _upsert(SellRequest request) {
    final index = _requests.indexWhere((r) => r.id == request.id);
    if (index == -1) {
      _requests.insert(0, request);
    } else {
      _requests[index] = request;
    }
  }

  void _upsertAll(List<SellRequest> requests) {
    for (final r in requests) {
      _upsert(r);
    }
  }

  // ── Visitor ──────────────────────────────────────────────────────────
  /// Submits a new property for sale. Payment is mocked — in this demo the
  /// 100 ETB fee is treated as paid the moment this is called (the UI
  /// shows a mock "processing payment" step before calling this) — but the
  /// submission itself is now persisted for real via the backend.
  Future<SellRequest> submit({
    required String ownerUserId,
    required String ownerName,
    required String ownerPhone,
    required AssetCategorySlug category,
    required String title,
    required String description,
    required double askingPrice,
    required String city,
    required String addressLine,
    HousePropertyDetails? houseDetails,
    VehicleDetails? vehicleDetails,
    MachineryDetails? machineryDetails,
  }) async {
    final request = await _service.submit(
      ownerUserId: ownerUserId,
      ownerName: ownerName,
      ownerPhone: ownerPhone,
      category: category.slug,
      title: title,
      description: description,
      askingPrice: askingPrice,
      city: city,
      addressLine: addressLine,
      houseDetails: houseDetails,
      vehicleDetails: vehicleDetails,
      machineryDetails: machineryDetails,
    );
    _upsert(request);
    notifyListeners();
    return request;
  }

  // ── Agent: self-listing ─────────────────────────────────────────────
  /// An Agent submits a property they own themselves — carries its own
  /// photos/video + written notes up front, so Admin can publish it
  /// directly under this Agent's name without a separate claim/inspection
  /// hand-off. Same 100 ETB fee as [submit].
  Future<SellRequest> submitAsAgent({
    required String ownerUserId,
    required String ownerName,
    required String ownerPhone,
    required AssetCategorySlug category,
    required String title,
    required String description,
    required double askingPrice,
    required String city,
    required String addressLine,
    required String agentId,
    required String agentName,
    required List<ReportMediaItem> media,
    required String notes,
    HousePropertyDetails? houseDetails,
    VehicleDetails? vehicleDetails,
    MachineryDetails? machineryDetails,
  }) async {
    final request = await _service.submitAgentListing(
      ownerUserId: ownerUserId,
      ownerName: ownerName,
      ownerPhone: ownerPhone,
      category: category.slug,
      title: title,
      description: description,
      askingPrice: askingPrice,
      city: city,
      addressLine: addressLine,
      agentId: agentId,
      agentName: agentName,
      media: media,
      notes: notes,
      houseDetails: houseDetails,
      vehicleDetails: vehicleDetails,
      machineryDetails: machineryDetails,
    );
    _upsert(request);
    notifyListeners();
    return request;
  }

  /// Local getter — filters whatever's already in the cache.
  List<SellRequest> byOwner(String ownerUserId) =>
      _requests.where((r) => r.ownerUserId == ownerUserId).toList();

  /// Refreshes [byOwner] from the backend — call from `initState` on any
  /// screen that reads a Visitor's own submissions.
  Future<void> fetchByOwner(String ownerUserId) async {
    isLoading = true;
    notifyListeners();
    try {
      _upsertAll(await _service.byOwner(ownerUserId));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Admin: submission screening ─────────────────────────────────────────
  List<SellRequest> get pendingSubmissions =>
      _requests.where((r) => r.status == SellRequestStatus.pendingAdminApproval).toList();

  List<SellRequest> get pendingReports =>
      _requests.where((r) => r.status == SellRequestStatus.reportPendingApproval).toList();

  /// Refreshes both Admin queues — call from `initState` on the Admin
  /// sell-requests screen.
  Future<void> fetchAdminQueues() async {
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.pendingSubmissions(),
        _service.pendingReports(),
      ]);
      _upsertAll(results[0]);
      _upsertAll(results[1]);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Approves a pending submission. An Agent self-listing already carries
  /// its own report (media + notes), so this creates the live [Asset]
  /// immediately — same as [adminApproveReport] — and publishes it under
  /// the submitting Agent's name in one step, instead of opening it to the
  /// claim pool first.
  Future<void> adminApproveSubmission(String id) async {
    final r = _requests.firstWhere(
      (r) => r.id == id,
      orElse: () => throw StateError('Sell request $id is not loaded'),
    );

    if (r.isAgentListing) {
      final asset = await _assetService.createAsset(
        title: r.title,
        priceAmount: r.askingPrice,
        priceCurrency: 'ETB',
        category: r.category,
        status: AssetStatus.active,
        addressLine: r.addressLine,
        city: r.city,
        attributes: const {},
        imageUrl: r.reportMedia.isNotEmpty
            ? 'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800&q=80'
            : null,
        postedLabel: 'New · listed by ${r.agentName ?? 'agent'}',
        brokerId: r.agentId,
      );
      _upsert(await _service.approveSubmission(id, listedAssetId: asset.id));
      notifyListeners();
      return;
    }

    _upsert(await _service.approveSubmission(id));
    notifyListeners();
  }

  Future<void> adminRejectSubmission(String id, {String? reason}) async {
    _upsert(await _service.rejectSubmission(id, reason: reason));
    notifyListeners();
  }

  // ── Agent/Broker: claim ──────────────────────────────────────────────
  List<SellRequest> get openToBrokers =>
      _requests.where((r) => r.status == SellRequestStatus.openToBrokers).toList();

  /// Nearby requests currently broadcasting to this agent specifically —
  /// separate from [openToBrokers] (the global fallback pool), so the UI
  /// can surface "near you" ahead of "open to everyone".
  List<SellRequest> broadcastingFor(String agentId) => _requests
      .where((r) =>
          r.status == SellRequestStatus.broadcasting && r.broadcastAgentIds.contains(agentId))
      .toList();

  List<SellRequest> claimedBy(String agentId) => _requests
      .where((r) =>
          r.agentId == agentId &&
          (r.status == SellRequestStatus.claimed || r.status == SellRequestStatus.reportRejected))
      .toList();

  List<SellRequest> reportsPendingBy(String agentId) =>
      _requests.where((r) => r.agentId == agentId && r.status == SellRequestStatus.reportPendingApproval).toList();

  List<SellRequest> listedBy(String agentId) =>
      _requests.where((r) => r.agentId == agentId && r.status == SellRequestStatus.listed).toList();

  /// Refreshes everything an Agent/Broker screen needs — open pool, plus
  /// this agent's claimed/pending/listed requests. Call from `initState`.
  Future<void> fetchAgentView(String agentId) async {
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.openToBrokers(),
        _service.broadcastingForAgent(agentId),
        _service.claimedByAgent(agentId),
        _service.pendingReportsByAgent(agentId),
        _service.listedByAgent(agentId),
      ]);
      for (final list in results) {
        _upsertAll(list);
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// First-come-first-served: succeeds while the request is still
  /// `broadcasting` (and this agent was one it was sent to) or
  /// `openToBrokers` on the server. Returns false if someone else already
  /// claimed it (a 409 from the backend), rethrows any other error.
  Future<bool> agentClaim(String id, {required String agentId, required String agentName}) async {
    try {
      final request = await _service.claim(id, agentId: agentId, agentName: agentName);
      _upsert(request);
      notifyListeners();
      return true;
    } on SellRequestConflictException {
      return false;
    }
  }

  // ── Agent/Broker: inspection report ─────────────────────────────────────
  Future<void> agentSubmitReport(
    String id, {
    required String agentId,
    required List<ReportMediaItem> media,
    required String notes,
  }) async {
    _upsert(await _service.submitReport(id, agentId: agentId, media: media, notes: notes));
    notifyListeners();
  }

  // ── Admin: report screening → publish ───────────────────────────────────
  /// Approves the inspection report and turns it into a real, persisted
  /// [Asset] — `POST /api/assets` first (so it's a real Postgres row every
  /// visitor/agent/admin session can see), then tells the backend the
  /// sell-request is `listed` with that asset's real id, crediting it to
  /// the claiming Agent.
  Future<Asset> adminApproveReport(String id) async {
    final r = _requests.firstWhere(
      (r) => r.id == id,
      orElse: () => throw StateError('Sell request $id is not loaded'),
    );
    final asset = await _assetService.createAsset(
      title: r.title,
      priceAmount: r.askingPrice,
      priceCurrency: 'ETB',
      category: r.category,
      status: AssetStatus.active,
      addressLine: r.addressLine,
      city: r.city,
      attributes: const {},
      imageUrl: r.reportMedia.isNotEmpty
          ? 'https://images.unsplash.com/photo-1560518883-ce09059eeffa?w=800&q=80'
          : null,
      postedLabel: 'New · listed by ${r.agentName ?? 'agent'}',
      brokerId: r.agentId,
    );
    final updated = await _service.approveReport(id, listedAssetId: asset.id);
    _upsert(updated);
    notifyListeners();
    return asset;
  }

  Future<void> adminRejectReport(String id, {String? reason}) async {
    _upsert(await _service.rejectReport(id, reason: reason));
    notifyListeners();
  }

  /// Clears the local cache only — the backend is the real source of truth
  /// now, so this no longer wipes any data, just what's currently loaded on
  /// screen. Kept for the demo's existing "reset" controls.
  void reset() {
    _requests.clear();
    notifyListeners();
  }
}
