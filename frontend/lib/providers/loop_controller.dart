import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/asset.dart';

/// Stages of the core transactional loop. Shared, single source of truth —
/// the Customer, Admin, and Agent sides are separate full-screen flows in
/// this app, but they all watch the same [LoopController] instance, so
/// actions taken on one side are reflected live on the others.
///
/// Backed by the real `/api/tour-requests/*` endpoints (Postgres-persisted)
/// as of this wiring — `searching` is the only stage with no server-side
/// equivalent; it's a brief, purely cosmetic pause shown right after the
/// Visitor taps "Request Tour", before the real `pending_approval` row
/// comes back from the POST.
enum LoopStage {
  idle,
  searching,
  pendingApproval,
  dispatched,
  broadcasting,
  accepted,
  declined,
  expired,
}

/// Thrown for any tour-request call the backend rejects or that fails to
/// reach the server. [message] is safe to show directly in a SnackBar.
class TourRequestException implements Exception {
  final String message;
  const TourRequestException(this.message);

  @override
  String toString() => message;
}

LoopStage _stageFromApi(String status) {
  switch (status) {
    case 'pending_approval':
      return LoopStage.pendingApproval;
    case 'dispatched':
      return LoopStage.dispatched;
    case 'broadcasting':
      return LoopStage.broadcasting;
    case 'accepted':
      return LoopStage.accepted;
    case 'declined':
      return LoopStage.declined;
    case 'expired':
      return LoopStage.expired;
    default:
      return LoopStage.idle;
  }
}

bool _isQueueStatus(String status) =>
    status == 'pending_approval' ||
    status == 'broadcasting' ||
    status == 'declined' ||
    status == 'expired';

/// Builds a minimal [Asset] from just the id/title stored on the
/// `tour_requests` row itself — used when a polled request originated on
/// a *different* device, so this session never had the full Asset object
/// to begin with. Good enough for the title/price-free UI that reads
/// [LoopController.requestedAsset] (Admin/Agent only ever show the title
/// and, where present, address/city).
Asset _placeholderAsset(String id, String title) => Asset(
      id: id,
      title: title,
      priceAmount: 0,
      category: AssetCategorySlug.others,
      status: AssetStatus.active,
    );

/// Single source of truth for the live tour-request loop. Provided once at
/// the app root so every side (Customer / Admin / Agent) reads and mutates
/// the same state, now backed by real HTTP calls to `/api/tour-requests/*`
/// instead of local timers.
class LoopController extends ChangeNotifier {
  static const dispatchWindowSeconds = 30;

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // ── Server-backed state for the current request ─────────────────────
  String? _id;
  String _status = 'idle';
  String? _agentName;
  int _dispatchWindow = dispatchWindowSeconds;

  /// True for the brief cosmetic pause between tapping "Request Tour" and
  /// the real `pending_approval` row coming back from the server.
  bool _searching = false;

  bool agentOnline = true;
  int secondsLeft = dispatchWindowSeconds;
  Asset? requestedAsset;

  /// Requests currently broadcasting to nearby agents (the credited/
  /// dispatched agent fell through) that *this* agent could claim —
  /// refreshed by [refreshAgentBroadcasting]. Raw rows: `id`, `asset_title`,
  /// `customer_name`, etc, straight off the `tour_requests` table.
  List<Map<String, dynamic>> broadcastingRequests = [];

  /// Set when the most recent server call failed — cleared on the next
  /// successful call. Screens aren't required to read this, but can.
  String? lastError;

  Timer? _countdown;

  LoopStage get stage {
    if (_searching) return LoopStage.searching;
    if (_id == null) return LoopStage.idle;
    return _stageFromApi(_status);
  }

  String? get agentName => _agentName;

  bool get isRinging => stage == LoopStage.dispatched && agentOnline;

  // ── Customer ──────────────────────────────────────────────────────────
  /// POST /api/tour-requests — submits a new tour request for [asset]. If
  /// the listing has a real agent credited to it, the backend dispatches
  /// straight to them; otherwise it lands in Admin's queue for a manual
  /// pick. Shows a brief "searching" state before the real row appears,
  /// exactly like the old cosmetic-only delay did.
  Future<void> customerRequest(
    Asset asset, {
    required String customerId,
    required String customerName,
  }) async {
    if (stage != LoopStage.idle) return;
    requestedAsset = asset;
    _searching = true;
    lastError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _post('/api/tour-requests', {
          'customerId': customerId,
          'customerName': customerName,
          'assetId': asset.id,
          'assetTitle': asset.title,
        }),
        Future.delayed(const Duration(milliseconds: 1400)),
      ]);
      final row = results[0] as Map<String, dynamic>;
      _searching = false;
      _applyRow(row);
    } catch (e) {
      _searching = false;
      _id = null;
      _status = 'idle';
      requestedAsset = null;
      lastError = e.toString();
      notifyListeners();
    }
  }

  /// GET /api/tour-requests?customerId=... — this customer's full history
  /// (every tour they've ever requested, any status). Not cached on the
  /// controller — callers own their own loading state.
  Future<List<Map<String, dynamic>>> fetchCustomerHistory(String customerId) {
    return _getList('/api/tour-requests?customerId=$customerId');
  }

  // ── Admin ───────────────────────────────────────────────────────────────
  /// POST /api/tour-requests/:id/approve — dispatches the current request
  /// to a specific, real agent and arms a fresh countdown. [agentId]/
  /// [agentName] should come from Admin actually picking someone off the
  /// real Broker Network directory (`AgentService.fetchDirectory`), not a
  /// hardcoded identity.
  Future<void> adminApprove({required String agentId, required String agentName}) async {
    final id = _id;
    if (id == null) return;
    final currentStage = _stageFromApi(_status);
    if (currentStage != LoopStage.pendingApproval &&
        currentStage != LoopStage.broadcasting &&
        currentStage != LoopStage.declined &&
        currentStage != LoopStage.expired) {
      return;
    }
    try {
      final row = await _post('/api/tour-requests/$id/approve', {
        'agentId': agentId,
        'agentName': agentName,
      });
      _applyRow(row);
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  // ── Agent ───────────────────────────────────────────────────────────────
  /// POST /api/tour-requests/:id/accept — [agentId] is the *real*,
  /// signed-in agent's own id (e.g. `widget.user.id`), never a shared
  /// placeholder — the backend only accepts this if the request is still
  /// dispatched to that exact agent.
  Future<void> agentAccept(String agentId) async {
    final id = _id;
    if (id == null || _stageFromApi(_status) != LoopStage.dispatched) return;
    _countdown?.cancel();
    try {
      final row = await _post('/api/tour-requests/$id/accept', {'agentId': agentId});
      _applyRow(row);
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  /// POST /api/tour-requests/:id/decline — the backend automatically tries
  /// broadcasting to nearby agents right after, so declining here is what
  /// gets this request into [broadcastingRequests] for someone else.
  Future<void> agentDecline(String agentId) async {
    final id = _id;
    if (id == null || _stageFromApi(_status) != LoopStage.dispatched) return;
    _countdown?.cancel();
    try {
      final row = await _post('/api/tour-requests/$id/decline', {'agentId': agentId});
      _applyRow(row);
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  /// POST /api/tour-requests/:id/claim — first nearby agent to claim a
  /// broadcasting request wins; a 409 (someone beat you to it, or it's no
  /// longer broadcasting) surfaces via [lastError] rather than throwing,
  /// since losing a race here is an expected, non-exceptional outcome.
  Future<bool> agentClaim(String id, {required String agentId, required String agentName}) async {
    try {
      final row = await _post('/api/tour-requests/$id/claim', {
        'agentId': agentId,
        'agentName': agentName,
      });
      broadcastingRequests.removeWhere((r) => r['id'] == id);
      requestedAsset = _placeholderAsset(row['asset_id'] as String, row['asset_title'] as String);
      _applyRow(row);
      return true;
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// GET /api/tour-requests/agent/:agentId — this agent's full history
  /// (every tour ever dispatched/broadcast-claimed to them, any status).
  Future<List<Map<String, dynamic>>> fetchAgentHistory(String agentId) {
    return _getList('/api/tour-requests/agent/$agentId');
  }

  /// Mirrors whether the agent currently has a location on file (i.e. is
  /// actually reachable for new dispatches). Kept in sync by
  /// AgentHomeScreen after every successful set/clear-location call — not
  /// toggled directly from the UI anymore, since "online" has to reflect
  /// real server state, not a local-only flag. Still drives [isRinging] and
  /// the dispatch countdown below, so an agent who goes offline mid-ring
  /// also stops ringing/counting down locally.
  void setOnlineStatus(bool value) {
    agentOnline = value;
    notifyListeners();
  }

  // ── Cross-device polling ────────────────────────────────────────────
  // Everything above only updates local state right after *this session*
  // makes a call. That's enough when Visitor/Admin/Agent are the same
  // running app instance, but on separate devices Admin/Agent otherwise
  // have no way to find out a new request exists. These pollers close
  // that gap by periodically asking the server what's actually waiting.

  Timer? _customerPoll;
  Timer? _adminPoll;
  Timer? _agentPoll;
  Timer? _agentBroadcastPoll;
  String? _agentPollId;

  /// Call from the Visitor/Customer screen (e.g. in `initState`) right
  /// after submitting a tour request. Unlike the Admin/Agent pollers this
  /// doesn't discover new requests — it just keeps re-checking *this*
  /// customer's current request so the waiting screen reflects what the
  /// agent actually did (accepted/declined/still broadcasting) instead of
  /// relying solely on the local client-side countdown, which only ever
  /// guesses "expired" and has no way to learn about a real accept/decline.
  void startCustomerPolling(String customerId) {
    _customerPoll?.cancel();
    _customerPoll = Timer.periodic(
      const Duration(seconds: 4),
      (_) => refreshCustomerRequest(customerId),
    );
  }

  /// Call from the Visitor/Customer screen's `dispose()`.
  void stopCustomerPolling() {
    _customerPoll?.cancel();
    _customerPoll = null;
  }

  /// GET /api/tour-requests?customerId=... — re-checks the current
  /// tracked request ([_id]) against this customer's history and applies
  /// it if the server-side status has moved on. No-op while idle/searching
  /// (nothing submitted yet) so this is safe to poll continuously.
  Future<void> refreshCustomerRequest(String customerId) async {
    final id = _id;
    if (id == null || _searching) return;
    try {
      final rows = await fetchCustomerHistory(customerId);
      final row = rows.cast<Map<String, dynamic>?>().firstWhere(
            (r) => r?['id'] == id,
            orElse: () => null,
          );
      if (row == null) return;
      if (row['status'] == _status) return; // nothing new
      _applyRow(row);
    } catch (_) {
      // Silent — same reasoning as refreshAdminQueue: a failed poll
      // shouldn't spam the waiting screen with error banners.
    }
  }

  /// Call from Admin's screen (e.g. in `initState`). Immediately checks
  /// once, then every few seconds after.
  void startAdminPolling() {
    _adminPoll?.cancel();
    refreshAdminQueue();
    _adminPoll = Timer.periodic(const Duration(seconds: 4), (_) => refreshAdminQueue());
  }

  /// Call from Admin's screen `dispose()`.
  void stopAdminPolling() {
    _adminPoll?.cancel();
    _adminPoll = null;
  }

  /// Call from Agent's screen (e.g. in `initState`) with the real,
  /// signed-in agent's own id — polls both "is anything dispatched
  /// straight to me" and "is anything broadcasting nearby that I could
  /// claim".
  void startAgentPolling(String agentId) {
    _agentPollId = agentId;
    _agentPoll?.cancel();
    _agentBroadcastPoll?.cancel();
    refreshAgentActive(agentId);
    refreshAgentBroadcasting(agentId);
    _agentPoll = Timer.periodic(const Duration(seconds: 4), (_) => refreshAgentActive(agentId));
    _agentBroadcastPoll = Timer.periodic(const Duration(seconds: 5), (_) => refreshAgentBroadcasting(agentId));
  }

  /// Call from Agent's screen `dispose()`.
  void stopAgentPolling() {
    _agentPoll?.cancel();
    _agentPoll = null;
    _agentBroadcastPoll?.cancel();
    _agentBroadcastPoll = null;
    _agentPollId = null;
  }

  /// GET /api/tour-requests/queue — the oldest request still waiting on
  /// Admin, regardless of which device/session originally created it.
  Future<void> refreshAdminQueue() async {
    try {
      final rows = await _getList('/api/tour-requests/queue');
      if (rows.isEmpty) {
        // Only clear local state if we were showing a queue item — never
        // touch a request that's already dispatched/accepted elsewhere.
        if (_id != null && _isQueueStatus(_status)) {
          _id = null;
          _status = 'idle';
          requestedAsset = null;
          notifyListeners();
        }
        return;
      }
      final row = rows.first;
      if (row['id'] == _id && row['status'] == _status) return; // nothing new
      if (requestedAsset == null || requestedAsset!.id != row['asset_id']) {
        requestedAsset = _placeholderAsset(row['asset_id'] as String, row['asset_title'] as String);
      }
      _applyRow(row);
    } catch (_) {
      // Silent — a failed poll shouldn't spam the UI with error banners.
    }
  }

  /// GET /api/tour-requests/agent/:agentId/active — anything currently
  /// dispatched to this specific real agent, regardless of which Admin
  /// session approved it.
  Future<void> refreshAgentActive(String agentId) async {
    try {
      final rows = await _getList('/api/tour-requests/agent/$agentId/active');
      if (rows.isEmpty) {
        if (_id != null && _status == 'dispatched') {
          _id = null;
          _status = 'idle';
          requestedAsset = null;
          notifyListeners();
        }
        return;
      }
      final row = rows.first;
      if (row['id'] == _id && row['status'] == _status) return; // nothing new
      requestedAsset = _placeholderAsset(row['asset_id'] as String, row['asset_title'] as String);
      _applyRow(row);
    } catch (_) {
      // Silent — same reasoning as refreshAdminQueue.
    }
  }

  /// GET /api/tour-requests/agent/:agentId/broadcasting — nearby requests
  /// this agent hasn't claimed (or lost) yet. Populates
  /// [broadcastingRequests] for an Agent-side "nearby tours" list.
  Future<void> refreshAgentBroadcasting(String agentId) async {
    try {
      final rows = await _getList('/api/tour-requests/agent/$agentId/broadcasting');
      broadcastingRequests = rows;
      notifyListeners();
    } catch (_) {
      // Silent — same reasoning as refreshAdminQueue.
    }
  }

  /// Wipes the local view of the loop — used by the demo's "reset"
  /// controls. There's no delete endpoint (and no need for one); this just
  /// stops watching the old request so the Visitor can start a new one.
  void reset() {
    _countdown?.cancel();
    _id = null;
    _status = 'idle';
    _agentName = null;
    _searching = false;
    secondsLeft = dispatchWindowSeconds;
    requestedAsset = null;
    lastError = null;
    notifyListeners();
  }

  // ── internals ────────────────────────────────────────────────────────

  /// Applies a fresh row from the server (camelCase-free — the backend
  /// returns the raw Postgres row) and, if it's `dispatched`, arms the
  /// client-side countdown from its real `expires_at`/`dispatch_window_seconds`.
  void _applyRow(Map<String, dynamic> row) {
    _id = row['id'] as String?;
    _status = row['status'] as String? ?? 'idle';
    _agentName = row['agent_name'] as String?;
    _dispatchWindow = (row['dispatch_window_seconds'] as num?)?.toInt() ?? dispatchWindowSeconds;
    lastError = null;

    _countdown?.cancel();
    if (_stageFromApi(_status) == LoopStage.dispatched) {
      final expiresAt = DateTime.tryParse(row['expires_at'] as String? ?? '');
      secondsLeft = expiresAt == null
          ? _dispatchWindow
          : expiresAt.difference(DateTime.now()).inSeconds.clamp(0, _dispatchWindow);
      _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!agentOnline) return; // countdown pauses while agent is offline
        if (secondsLeft <= 1) {
          secondsLeft = 0;
          _status = 'expired';
          t.cancel();
        } else {
          secondsLeft--;
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    http.Response res;
    try {
      res = await http.get(_uri(path)).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const TourRequestException("Couldn't reach the server. Check your connection and try again.");
    }
    List<dynamic> json;
    try {
      json = jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      throw const TourRequestException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw const TourRequestException('Something went wrong fetching updates.');
    }
    return json.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await http
          .post(_uri(path), headers: const {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const TourRequestException("Couldn't reach the server. Check your connection and try again.");
    }
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const TourRequestException('Unexpected response from the server.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw TourRequestException(json['error'] as String? ?? 'Something went wrong (${res.statusCode}).');
    }
    return json;
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _customerPoll?.cancel();
    _adminPoll?.cancel();
    _agentPoll?.cancel();
    _agentBroadcastPoll?.cancel();
    super.dispose();
  }
}
