import 'package:flutter/foundation.dart';
import '../models/asset.dart';
import '../models/machinery_requirement.dart';
import '../models/order_request.dart';
import '../models/vehicle_requirement.dart';
import '../services/order_request_service.dart';

/// Single source of truth for every "Order Us" submission — backed by the
/// real `/api/order-requests/*` backend. Keeps a local cache so every side
/// (Visitor / Agent / Admin) watching this one instance still reads plain
/// synchronous getters as before; screens are responsible for triggering
/// the `fetch*` call that keeps their slice current (typically once in
/// `initState`), same convention as [SellRequestController].
class OrderRequestController extends ChangeNotifier {
  OrderRequestController({OrderRequestService? service}) : _service = service ?? OrderRequestService();

  final OrderRequestService _service;

  final List<OrderRequest> _requests = [];

  List<OrderRequest> get all => List.unmodifiable(_requests);

  bool isLoading = false;

  void _upsert(OrderRequest request) {
    final index = _requests.indexWhere((r) => r.id == request.id);
    if (index == -1) {
      _requests.insert(0, request);
    } else {
      _requests[index] = request;
    }
  }

  void _upsertAll(List<OrderRequest> requests) {
    for (final r in requests) {
      _upsert(r);
    }
  }

  // ── Visitor ────────────────────────────────────────────────────────────

  /// Submits a new "Order Us" request with a location — either GPS
  /// coordinates or a manually typed address (geocoded server-side). The
  /// backend broadcasts it to nearby agents as part of creating it.
  /// Exactly one of [propertyRequirement] / [vehicleRequirement] /
  /// [machineryRequirement] / [generalRequirement] should be provided,
  /// matching the category.
  Future<OrderRequest> submit({
    required String requesterUserId,
    required String requesterName,
    required String requesterPhone,
    required AssetCategorySlug category,
    required OrderLocationSource locationSource,
    double? latitude,
    double? longitude,
    String? addressText,
    PropertyRequirement? propertyRequirement,
    VehicleRequirement? vehicleRequirement,
    MachineryRequirement? machineryRequirement,
    GeneralRequirement? generalRequirement,
  }) async {
    final request = await _service.submit(
      requesterUserId: requesterUserId,
      requesterName: requesterName,
      requesterPhone: requesterPhone,
      category: category.slug,
      title: composeOrderRequestTitle(category),
      description: composeOrderRequestDescription(
        propertyRequirement: propertyRequirement,
        vehicleRequirement: vehicleRequirement,
        machineryRequirement: machineryRequirement,
        generalRequirement: generalRequirement,
      ),
      budgetSummary: composeOrderRequestBudgetSummary(
        propertyRequirement: propertyRequirement,
        vehicleRequirement: vehicleRequirement,
        machineryRequirement: machineryRequirement,
        generalRequirement: generalRequirement,
      ),
      locationSource: locationSource,
      latitude: latitude,
      longitude: longitude,
      addressText: addressText,
    );
    _upsert(request);
    notifyListeners();
    return request;
  }

  /// Local getter — filters whatever's already in the cache.
  List<OrderRequest> byRequester(String requesterUserId) =>
      _requests.where((r) => r.requesterUserId == requesterUserId).toList();

  /// Refreshes [byRequester] from the backend — call from `initState` on
  /// any screen that reads a Visitor's own submissions (e.g. My Order
  /// Requests).
  Future<void> fetchByRequester(String requesterUserId) async {
    isLoading = true;
    notifyListeners();
    try {
      _upsertAll(await _service.byRequester(requesterUserId));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// The Visitor reports that they and the assigned agent couldn't work it
  /// out — Admin will see it under "Disputed" and can repost it.
  Future<void> report(String id, {required String requesterUserId, String? reason}) async {
    _upsert(await _service.report(id, requesterUserId: requesterUserId, reason: reason));
    notifyListeners();
  }

  // ── Agent ──────────────────────────────────────────────────────────────

  List<OrderRequest> availableForAgent(String agentId) =>
      _requests.where((r) => r.status == OrderRequestStatus.broadcasting && r.broadcastAgentIds.contains(agentId)).toList();

  List<OrderRequest> assignedToAgent(String agentId) => _requests.where((r) => r.assignedAgentId == agentId).toList();

  /// Refreshes both agent-facing slices — call from `initState` on the
  /// Agent home screen.
  Future<void> fetchForAgent(String agentId) async {
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.availableForAgent(agentId),
        _service.assignedToAgent(agentId),
      ]);
      _upsertAll(results[0]);
      _upsertAll(results[1]);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// First agent to call this wins — throws [OrderRequestException] with a
  /// friendly message if someone else already claimed it.
  Future<void> agentClaim(String id, {required String agentId, required String agentName, required String agentPhone}) async {
    _upsert(await _service.claim(id, agentId: agentId, agentName: agentName, agentPhone: agentPhone));
    notifyListeners();
  }

  /// The assigned agent closes the request out themselves once the work is
  /// done — throws [OrderRequestException] if it's no longer confirmed to
  /// them.
  Future<void> agentComplete(String id, {required String agentId}) async {
    _upsert(await _service.complete(id, agentId: agentId));
    notifyListeners();
  }

  /// The assigned agent flags that a confirmed request couldn't be worked
  /// out on their end — throws [OrderRequestException] if it's no longer
  /// confirmed to them. Puts it back in front of Admin for a repost.
  Future<void> agentReport(String id, {required String agentId, String? reason}) async {
    _upsert(await _service.agentReport(id, agentId: agentId, reason: reason));
    notifyListeners();
  }

  // ── Admin ────────────────────────────────────────────────────────────
  List<OrderRequest> get broadcasting => _requests.where((r) => r.status == OrderRequestStatus.broadcasting).toList();
  List<OrderRequest> get confirmed => _requests.where((r) => r.status == OrderRequestStatus.agentConfirmed).toList();
  List<OrderRequest> get disputed => _requests.where((r) => r.status == OrderRequestStatus.disputed).toList();

  /// Refreshes all three Admin queues — call from `initState` on the Admin
  /// order-requests screen.
  Future<void> fetchAdminQueues() async {
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.adminBroadcasting(),
        _service.adminConfirmed(),
        _service.adminDisputed(),
      ]);
      _upsertAll(results[0]);
      _upsertAll(results[1]);
      _upsertAll(results[2]);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Re-broadcasts a disputed request to nearby agents again (excluding
  /// whoever it was assigned to before) — same data, no re-filled form.
  Future<void> adminRepost(String id) async {
    _upsert(await _service.repost(id));
    notifyListeners();
  }

  Future<void> adminClose(String id) async {
    _upsert(await _service.close(id));
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
