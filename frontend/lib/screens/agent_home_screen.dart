import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/order_request.dart';
import '../providers/favorites_controller.dart';
import '../providers/loop_controller.dart';
import '../providers/order_request_controller.dart';
import '../services/asset_service.dart';
import '../services/agent_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/order_request_service.dart';
import '../theme/app_theme.dart';
import '../widgets/agent_bottom_nav.dart';
import '../widgets/agent_drawer.dart' show AgentTier;
import '../widgets/app_buttons.dart';
import '../widgets/asset_list_card.dart';
import '../widgets/listing_intent_sheet.dart';
import '../widgets/loop_progress.dart';
import 'agent_broker_network_screen.dart';
import 'agent_network_screen.dart';
import 'agent_customers_screen.dart';
import 'agent_dashboard_screen.dart';
import 'agent_membership_screen.dart';
import 'agent_menu_screen.dart';
import 'agent_referrals_screen.dart';
import 'agent_schedule_screen.dart';
import 'agent_settings_screen.dart';
import 'agent_support_screen.dart';
import 'agent_visibility_profile_screen.dart';
import 'agent_wallet_screen.dart';
import 'chat_inbox_screen.dart';
import 'favorites_screen.dart';
import 'my_tour_requests_screen.dart';
import 'agent_sell_requests_screen.dart';
import 'notifications_screen.dart';
import 'rent_property_form_screen.dart';
import 'role_gate_screen.dart';
import 'sell_property_form_screen.dart';

enum _SortOption { newest, priceLow, priceHigh }

extension on _SortOption {
  String get label => switch (this) {
        _SortOption.newest => 'Newest',
        _SortOption.priceLow => 'Price: Low to High',
        _SortOption.priceHigh => 'Price: High to Low',
      };
}

/// The Agent side — its own full flow, now organized as a bottom-nav shell
/// (Home / Chat / Leads / Menu, plus a raised "+" for quick-create) instead
/// of a side drawer. Home is the dashboard; everything the drawer used to
/// hold (Property Management, Wallet, Membership, Schedule, Settings,
/// Support, etc.) now lives one tap away under Menu. A live ringing overlay
/// still appears the instant Admin dispatches the shared [LoopController]
/// to this agent, over whichever tab is open. Accept/Decline here is
/// instantly reflected on the Customer and Admin sides.
class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  AssetCategorySlug? _categoryFilter;
  _SortOption _sort = _SortOption.newest;
  double? _minPrice;
  double? _maxPrice;
  LoopController? _loop;

  /// 0 = Home, 1 = Chat, 2 = Leads, 3 = Menu.
  int _tabIndex = 0;
  int _unreadChatCount = 0;

  late AppUser _currentUser = widget.user;
  bool _settingLocation = false;
  String? _locationError;

  final AssetService _assetService = AssetService();
  final AgentService _agentService = AgentService();
  final NotificationService _notificationService = NotificationService();

  // Polled independently of chat's unread count — new-dispatch and
  // payout alerts land here too, not just messages. No socket client
  // wired up yet (see notification_service.dart), so this is a poll
  // like the rest of the agent side's "live-ish" state.
  int _unreadNotificationsCount = 0;
  Timer? _notificationsPollTimer;

  // Real `GET /api/assets` company-inventory feed for the Leads tab —
  // starts empty and shows a proper loading/error state rather than a
  // bundled mock fallback.
  List<Asset> _assets = const [];
  bool _assetsLoading = true;
  String? _assetsError;

  // The agent's own listings, for the Dashboard's "Property Management"
  // section — previously this reused the full company-inventory list
  // above, which mislabeled every listing on the platform as "your
  // properties". Fetched separately via `GET /api/assets/broker/:id`.
  List<Asset> _myProperties = const [];

  double _walletBalance = 0;

  @override
  void initState() {
    super.initState();
    // Discovers dispatches created by an Admin on a different device/session.
    _loop = context.read<LoopController>()..startAgentPolling(widget.user.id);
    _loop!.setOnlineStatus(_hasLocation);
    // Same shared cache the visitor side uses — a listing an agent hearts
    // while browsing Leads shows up on their own Saved Listings page too.
    context.read<FavoritesController>().attachUser(widget.user);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        context.read<OrderRequestController>().fetchForAgent(widget.user.id);
    });
    _loadAssets();
    _loadMyProperties();
    _loadWallet();
    _refreshUnreadNotifications();
    _notificationsPollTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _refreshUnreadNotifications());
  }

  Future<void> _refreshUnreadNotifications() async {
    final token = widget.user.token;
    if (token == null) return;
    try {
      final notifications = await _notificationService.getNotifications(token);
      if (!mounted) return;
      final unread = notifications.where((n) => !n.isRead).length;
      if (unread != _unreadNotificationsCount)
        setState(() => _unreadNotificationsCount = unread);
    } on NotificationException {
      // Transient hiccup — next poll tick retries.
    }
  }

  Future<void> _loadAssets() async {
    setState(() {
      _assetsLoading = true;
      _assetsError = null;
    });
    try {
      final assets = await _assetService.fetchAssets(limit: 200);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _assetsLoading = false;
      });
    } on AssetException catch (e) {
      if (!mounted) return;
      setState(() {
        _assetsLoading = false;
        _assetsError = e.message;
      });
    }
  }

  Future<void> _loadMyProperties() async {
    try {
      final rows = await _assetService.fetchByBroker(widget.user.id);
      if (!mounted) return;
      setState(() => _myProperties = rows);
    } on AssetException catch (_) {
      // Leave the dashboard's empty state showing rather than blocking
      // the rest of the screen on this one section.
    }
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await _agentService.getWallet(widget.user.id,
          token: widget.user.token ?? '');
      if (!mounted) return;
      setState(() => _walletBalance = wallet.balance);
    } on AgentServiceException catch (_) {
      // Leave it at 0 rather than showing a fabricated balance.
    }
  }

  bool get _hasLocation =>
      _currentUser.agentLatitude != null && _currentUser.agentLongitude != null;

  bool _togglingOnline = false;

  /// Handler for the dashboard's online/offline switch. Being "online" here
  /// literally means "has a location on file" — that's the only thing
  /// findNearbyAgents checks server-side before broadcasting a request to
  /// this agent, so the switch now drives that directly instead of a
  /// local-only flag that never reached the backend.
  Future<void> _setOnline(bool value) async {
    if (value) {
      // Turning on: capture GPS and save it, same as the "Update" link.
      await _setMyLocation();
      return;
    }
    // Turning off: clear the saved location so this agent stops being
    // matched by findNearbyAgents until they turn it back on.
    setState(() => _togglingOnline = true);
    try {
      final token = _currentUser.token;
      if (token == null)
        throw 'Your session is missing a token — please sign in again.';
      final updated = await AuthService().clearAgentLocation(token: token);
      if (!mounted) return;
      setState(() => _currentUser = updated);
      _loop?.setOnlineStatus(false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationError = '$e');
    } finally {
      if (mounted) setState(() => _togglingOnline = false);
    }
  }

  /// Captures the agent's current GPS position and saves it to their
  /// profile — needed before any order requests can be broadcast to them.
  Future<void> _setMyLocation() async {
    setState(() {
      _settingLocation = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Location services are turned off on this device.';
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw 'Location access was denied.';
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final token = _currentUser.token;
      if (token == null)
        throw 'Your session is missing a token — please sign in again.';
      final updated = await AuthService().updateAgentLocation(
        token: token,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() => _currentUser = updated);
      _loop?.setOnlineStatus(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationError = '$e');
    } finally {
      if (mounted) setState(() => _settingLocation = false);
    }
  }

  Future<void> _claim(OrderRequest request) async {
    try {
      await context.read<OrderRequestController>().agentClaim(
            request.id,
            agentId: widget.user.id,
            agentName: widget.user.fullName,
            agentPhone: widget.user.phone ?? '',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Claimed — reach out to the visitor directly.')));
    } on OrderRequestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  bool get _hasActiveFilters => _minPrice != null || _maxPrice != null;

  List<Asset> get _visibleAssets {
    final query = _searchController.text.trim().toLowerCase();
    var list = _assets.where((asset) {
      final matchesCategory =
          _categoryFilter == null || asset.category == _categoryFilter;
      final matchesQuery = query.isEmpty ||
          (asset.city?.toLowerCase().contains(query) ?? false) ||
          (asset.addressLine?.toLowerCase().contains(query) ?? false) ||
          asset.title.toLowerCase().contains(query);
      final matchesMin = _minPrice == null || asset.priceAmount >= _minPrice!;
      final matchesMax = _maxPrice == null || asset.priceAmount <= _maxPrice!;
      return matchesCategory && matchesQuery && matchesMin && matchesMax;
    }).toList();

    switch (_sort) {
      case _SortOption.priceLow:
        list.sort((a, b) => a.priceAmount.compareTo(b.priceAmount));
        break;
      case _SortOption.priceHigh:
        list.sort((a, b) => b.priceAmount.compareTo(a.priceAmount));
        break;
      case _SortOption.newest:
        break;
    }
    return list;
  }

  Future<void> _openFilters(BuildContext context) async {
    _minPriceController.text =
        _minPrice == null ? '' : _minPrice!.toStringAsFixed(0);
    _maxPriceController.text =
        _maxPrice == null ? '' : _maxPrice!.toStringAsFixed(0);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cloud,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Filters',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink)),
                  ),
                  TextButton(
                    onPressed: () {
                      _minPriceController.clear();
                      _maxPriceController.clear();
                    },
                    child: const Text('Reset',
                        style: TextStyle(
                            color: AppColors.slate,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Price range',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Min',
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('–', style: TextStyle(color: AppColors.slate)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Max',
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _minPrice =
                        double.tryParse(_minPriceController.text.trim());
                    _maxPrice =
                        double.tryParse(_maxPriceController.text.trim());
                  });
                  Navigator.of(sheetContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Apply filters',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _loop?.stopAgentPolling();
    _notificationsPollTimer?.cancel();
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _logout(LoopController loop) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleGateScreen()),
      (route) => false,
    );
  }

  /// Same flow as the Visitor side's raised "+" (see
  /// `_openListingIntent`/`showListingIntentSheet` in
  /// `customer_home_screen.dart`): ask Sell vs Rent, then go straight into
  /// the real listing wizard — no more fake "Quick Create" placeholder
  /// sheet in between.
  Future<void> _openListingIntent(BuildContext context) async {
    final intent = await showListingIntentSheet(context);
    if (intent == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => intent == ListingIntent.sell
          ? SellPropertyFormScreen(user: _currentUser, isAgentListing: true)
          : RentPropertyFormScreen(user: _currentUser),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loop = context.watch<LoopController>();
    final orderRequests = context.watch<OrderRequestController>();
    final availableOrderRequests =
        orderRequests.availableForAgent(widget.user.id);
    final assignedOrderRequests = orderRequests.assignedToAgent(widget.user.id);

    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: Stack(
        children: [
          Column(
            children: [
              LoopProgress(stage: loop.stage),
              if (loop.broadcastingRequests.isNotEmpty)
                _BroadcastingToursBanner(
                    loop: loop,
                    agentId: widget.user.id,
                    agentName: widget.user.fullName),
              Expanded(
                child: IndexedStack(
                  index: _tabIndex,
                  children: [
                    AgentDashboardScreen(
                      user: _currentUser,
                      tier: AgentTier.gold,
                      isOnline: _hasLocation,
                      onOnlineChanged: _setOnline,
                      hasLocation: _hasLocation,
                      settingLocation: _settingLocation || _togglingOnline,
                      onSetLocation: _setMyLocation,
                      walletBalance: _walletBalance,
                      properties: _myProperties,
                      activeLeads: assignedOrderRequests,
                      availableLeadsCount: availableOrderRequests.length,
                      onSwitchToLeadsTab: () => setState(() => _tabIndex = 2),
                      unreadNotifications: _unreadNotificationsCount,
                      onNotificationsTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => NotificationsScreen(
                                    token: widget.user.token ?? '',
                                    onUnreadCountChanged: (count) {
                                      if (mounted)
                                        setState(() =>
                                            _unreadNotificationsCount = count);
                                    },
                                  ))),
                    ),
                    ChatInboxScreen(
                      user: _currentUser,
                      showBackButton: false,
                      onUnreadChanged: (count) {
                        if (mounted && count != _unreadChatCount)
                          setState(() => _unreadChatCount = count);
                      },
                    ),
                    _buildLeadsTab(
                        availableOrderRequests, assignedOrderRequests),
                    AgentMenuScreen(
                      user: _currentUser,
                      tier: AgentTier.gold,
                      isOnline: _hasLocation,
                      onOnlineChanged: _setOnline,
                      onPropertyManagement: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  AgentSellRequestsScreen(user: widget.user))),
                      onCustomers: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  AgentCustomersScreen(user: widget.user))),
                      onReferrals: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  AgentReferralsScreen(user: widget.user))),
                      onBrokerNetwork: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  AgentBrokerNetworkScreen(user: widget.user))),
                      onNetwork: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  AgentNetworkScreen(user: widget.user))),
                      onVisibilityProfile: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => AgentVisibilityProfileScreen(
                                  user: widget.user, tier: AgentTier.gold))),
                      onSavedListings: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  FavoritesScreen(user: widget.user))),
                      onWallet: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  AgentWalletScreen(user: widget.user))),
                      onMembership: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => AgentMembershipScreen(
                                  user: widget.user,
                                  initialTier: AgentTier.gold))),
                      onCommunication: () => setState(() => _tabIndex = 1),
                      onSchedule: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  AgentScheduleScreen(user: widget.user))),
                      onTourHistory: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => MyTourRequestsScreen(
                                  user: widget.user, forAgent: true))),
                      onSettings: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  AgentSettingsScreen(user: widget.user))),
                      onSupport: () =>
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => AgentSupportScreen(
                                  user: widget.user,
                                  onStartLiveChat: () {
                                    Navigator.of(context).pop();
                                    setState(() => _tabIndex = 1);
                                  }))),
                      onResetDemo: loop.reset,
                      onLogout: () => _logout(loop),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (loop.isRinging)
            _RingingOverlay(loop: loop, agentId: widget.user.id),
        ],
      ),
      bottomNavigationBar: AgentBottomNav(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        onAddTap: () => _openListingIntent(context),
        unreadChatCount: _unreadChatCount,
      ),
    );
  }

  /// The old full-screen browsing feed (search + category filters + sort +
  /// nearby Order Us requests + company inventory grid), now living under
  /// the "Leads" tab instead of behind the drawer's "Dashboard" link.
  Widget _buildLeadsTab(List<OrderRequest> availableOrderRequests,
      List<OrderRequest> assignedOrderRequests) {
    final assets = _visibleAssets;
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Leads',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  const Text('Nearby requests plus your company\'s inventory',
                      style: TextStyle(fontSize: 12.5, color: AppColors.slate)),
                  const SizedBox(height: AppSpacing.md),
                  _SearchRow(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    onFilterTap: () => _openFilters(context),
                    hasActiveFilters: _hasActiveFilters,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _CategoryFilterRow(
                    selected: _categoryFilter,
                    onSelected: (v) => setState(() => _categoryFilter = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ResultsSortRow(
                      count: assets.length,
                      sort: _sort,
                      onSortChanged: (v) => setState(() => _sort = v)),
                  const SizedBox(height: AppSpacing.sm),
                  if (_assetsError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: AppColors.border)),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(_assetsError!,
                                  style: const TextStyle(
                                      fontSize: 12.5, color: AppColors.slate))),
                          TextButton(
                              onPressed: _loadAssets,
                              child: const Text('Retry')),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_assetsLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
              child: _OrderRequestsSection(
                hasLocation: _hasLocation,
                settingLocation: _settingLocation,
                locationError: _locationError,
                onSetLocation: _setMyLocation,
                available: availableOrderRequests,
                assigned: assignedOrderRequests,
                onClaim: _claim,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final asset = assets[index];
                  final favorites = context.watch<FavoritesController>();
                  return AssetListCard(
                    asset: asset,
                    compact: true,
                    isSaved: favorites.isFavorite(asset.id),
                    onSaveToggle: (_) =>
                        context.read<FavoritesController>().toggle(asset.id),
                    actionLabel: 'View',
                    onActionPressed: () {},
                  );
                },
                childCount: assets.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Order Us requests near this agent — a "set my location" prompt if
/// they haven't registered one yet, a claimable list of nearby broadcasts,
/// and a short list of what they've already claimed.
class _OrderRequestsSection extends StatelessWidget {
  const _OrderRequestsSection({
    required this.hasLocation,
    required this.settingLocation,
    required this.locationError,
    required this.onSetLocation,
    required this.available,
    required this.assigned,
    required this.onClaim,
  });

  final bool hasLocation;
  final bool settingLocation;
  final String? locationError;
  final VoidCallback onSetLocation;
  final List<OrderRequest> available;
  final List<OrderRequest> assigned;
  final ValueChanged<OrderRequest> onClaim;

  @override
  Widget build(BuildContext context) {
    if (!hasLocation) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryYellow.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.primaryYellow.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Set your location',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text(
              "Order requests from visitors nearby only reach you once you've set your location.",
              style: TextStyle(fontSize: 12.5, color: AppColors.slate),
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: settingLocation
                  ? 'Getting your location…'
                  : 'Use my current location',
              borderColor: AppColors.primaryYellow,
              textColor: AppColors.primaryYellowDark,
              onPressed: settingLocation ? null : onSetLocation,
            ),
            if (locationError != null) ...[
              const SizedBox(height: 6),
              Text(locationError!,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.danger)),
            ],
          ],
        ),
      );
    }

    if (available.isEmpty && assigned.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (available.isNotEmpty) ...[
          Text('Order requests near you (${available.length})',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm),
          for (final r in available) ...[
            _OrderRequestCard(
                request: r, primaryLabel: 'Claim', onPrimary: () => onClaim(r)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        if (assigned.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Your claimed requests (${assigned.length})',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm),
          for (final r in assigned) ...[
            _OrderRequestCard(request: r),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _OrderRequestCard extends StatelessWidget {
  const _OrderRequestCard(
      {required this.request, this.primaryLabel, this.onPrimary});

  final OrderRequest request;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(request.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppColors.slate.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadii.pill)),
                child: Text(request.status.agentLabel,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('${request.budgetSummary} · ${request.locationSummary}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate)),
          const SizedBox(height: 6),
          Text(
            request.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12, color: AppColors.slate, height: 1.4),
          ),
          if (primaryLabel != null && onPrimary != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                  label: primaryLabel!,
                  backgroundColor: AppColors.primaryYellow,
                  foregroundColor: Colors.white,
                  onPressed: onPrimary),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
                'Requester: ${request.requesterName} · ${request.requesterPhone}',
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.slate,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

/// Shown right under [LoopProgress] whenever [LoopController.broadcastingRequests]
/// isn't empty — nearby tour requests whose credited/dispatched agent fell
/// through (declined or timed out), now broadcasting for any nearby agent
/// to claim, first-come-first-served (`POST /:id/claim`).
class _BroadcastingToursBanner extends StatefulWidget {
  const _BroadcastingToursBanner(
      {required this.loop, required this.agentId, required this.agentName});

  final LoopController loop;
  final String agentId;
  final String agentName;

  @override
  State<_BroadcastingToursBanner> createState() =>
      _BroadcastingToursBannerState();
}

class _BroadcastingToursBannerState extends State<_BroadcastingToursBanner> {
  String? _claimingId;

  Future<void> _claim(Map<String, dynamic> row) async {
    setState(() => _claimingId = row['id'] as String);
    final ok = await widget.loop.agentClaim(
      row['id'] as String,
      agentId: widget.agentId,
      agentName: widget.agentName,
    );
    if (!mounted) return;
    setState(() => _claimingId = null);
    if (!ok && widget.loop.lastError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.loop.lastError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.loop.broadcastingRequests;
    return Container(
      color: AppColors.primaryYellow.withOpacity(0.12),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${rows.length} nearby tour${rows.length == 1 ? '' : 's'} up for grabs',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          ...rows.map((row) {
            final id = row['id'] as String;
            final busy = _claimingId == id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row['asset_title'] as String? ?? 'Tour request',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    height: 30,
                    child: PrimaryButton(
                      label: busy ? '…' : 'Claim',
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      onPressed: busy ? null : () => _claim(row),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Full-screen overlay that appears the instant Admin dispatches this agent
/// while they're online — matches the platform's ink/yellow language even
/// though it's a dark "focus" moment layered over the light feed below.
class _RingingOverlay extends StatelessWidget {
  const _RingingOverlay({required this.loop, required this.agentId});

  final LoopController loop;
  final String agentId;

  @override
  Widget build(BuildContext context) {
    final asset = loop.requestedAsset;
    return Positioned.fill(
      child: Container(
        color: AppColors.ink.withOpacity(0.94),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryYellow.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                      color: AppColors.primaryYellow.withOpacity(0.4)),
                ),
                child: const Text(
                  'NEW DISPATCH',
                  style: TextStyle(
                      color: AppColors.primaryYellow,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 1),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _CountdownRing(
                  seconds: loop.secondsLeft,
                  total: LoopController.dispatchWindowSeconds,
                  size: 140),
              const SizedBox(height: AppSpacing.lg),
              Text(
                asset?.title ?? 'New tour request',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              if (asset != null)
                Text(
                  [
                    if (asset.addressLine != null) asset.addressLine!,
                    if (asset.city != null) asset.city!
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0xFFB9B8AE), fontSize: 13.5),
                ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Decline',
                      borderColor: AppColors.danger,
                      textColor: AppColors.danger,
                      onPressed: () => loop.agentDecline(agentId),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Accept',
                      backgroundColor: AppColors.primaryYellow,
                      foregroundColor: Colors.white,
                      onPressed: () => loop.agentAccept(agentId),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing(
      {required this.seconds, required this.total, required this.size});
  final int seconds;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = seconds > total * .5
        ? AppColors.success
        : seconds > total * .25
            ? AppColors.primaryYellow
            : AppColors.danger;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(
            value: total == 0 ? 0 : seconds / total,
            strokeWidth: 6,
            color: color,
            backgroundColor: Colors.white.withOpacity(.12),
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$seconds',
              style: TextStyle(
                  color: color, fontSize: 28, fontWeight: FontWeight.w900)),
          const Text('sec',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ]),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow(
      {required this.controller,
      required this.onChanged,
      this.onFilterTap,
      this.hasActiveFilters = false});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search city or address',
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.slate),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color:
              hasActiveFilters ? AppColors.primaryYellow : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
                color: hasActiveFilters
                    ? AppColors.primaryYellow
                    : AppColors.border),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onFilterTap,
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Icon(Icons.tune_rounded, size: 20, color: AppColors.ink),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryFilterRow extends StatelessWidget {
  const _CategoryFilterRow({required this.selected, required this.onSelected});
  final AssetCategorySlug? selected;
  final ValueChanged<AssetCategorySlug?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
              label: 'All',
              isSelected: selected == null,
              onTap: () => onSelected(null)),
          const SizedBox(width: 8),
          for (final category in AssetCategorySlug.values) ...[
            _FilterChip(
                label: category.label,
                isSelected: selected == category,
                onTap: () => onSelected(category)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.ink : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                  color: isSelected ? AppColors.ink : AppColors.border)),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.primaryYellow : AppColors.ink)),
        ),
      ),
    );
  }
}

class _ResultsSortRow extends StatelessWidget {
  const _ResultsSortRow(
      {required this.count, required this.sort, required this.onSortChanged});
  final int count;
  final _SortOption sort;
  final ValueChanged<_SortOption> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$count result${count == 1 ? '' : 's'}',
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.slate)),
        const Spacer(),
        PopupMenuButton<_SortOption>(
          initialValue: sort,
          onSelected: onSortChanged,
          color: AppColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md)),
          itemBuilder: (context) => _SortOption.values
              .map((o) => PopupMenuItem(value: o, child: Text(o.label)))
              .toList(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(sort.label,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const Icon(Icons.expand_more_rounded,
                  size: 18, color: AppColors.ink),
            ],
          ),
        ),
      ],
    );
  }
}
