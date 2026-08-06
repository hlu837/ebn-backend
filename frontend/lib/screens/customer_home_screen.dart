import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/user_role.dart';
import '../providers/favorites_controller.dart';
import '../providers/loop_controller.dart';
import '../services/asset_service.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/listing_intent_sheet.dart';
import '../widgets/loop_progress.dart';
import '../widgets/order_category_sheet.dart';
import 'asset_detail_screen.dart';
import 'broker_directory_screen.dart';
import 'chat_inbox_screen.dart';
import 'notifications_screen.dart';
import 'order_request_form_screen.dart';
import 'rent_property_form_screen.dart';
import 'role_gate_screen.dart';
import 'sell_property_form_screen.dart';
import 'visitor_account_screen.dart';

const _kAccentRed = Color(0xFFFF2636);

/// Visual & interactive redesign of the Visitor home screen: matching the
/// "EBN Visitor Dashboard" reference mock: search bar with quick-scan
/// icons, a category tab strip, an inspection promo banner, a "Find your
/// desire" order card, and a Top picks grid on a bottom-tabbed feed —
/// closed off with a 5-tab bottom navigation bar.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _categoryTabIndex = 0;
  int _picksTabIndex = 0;
  int _navIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final AssetService _assetService = AssetService();
  final ChatService _chatService = ChatService();
  final NotificationService _notificationService = NotificationService();

  // Loaded from the real `GET /api/assets` response.
  List<Asset> _assets = [];
  bool _loadingAssets = true;
  String? _assetsError;

  // Total unread messages across all threads, for the Chat tab's badge.
  // The inbox itself isn't kept mounted (it's pushed as its own route,
  // unlike the agent side's persistent tab), so this polls independently
  // just for the count.
  int _unreadChatCount = 0;
  Timer? _unreadPollTimer;

  // Same idea for the generic notifications feed (order updates, etc)
  // behind the bell icon — polled independently since there's no socket
  // client wired up yet (see notification_service.dart).
  int _unreadNotificationsCount = 0;
  Timer? _notificationsPollTimer;

  static const _categoryTabs = ['For You', 'Real Estate', 'Vehicles', 'Machinery', 'Broker List'];
  static const _picksTabs = ['Top picks', 'Nearby', 'Certified', 'Free Items'];

  @override
  void initState() {
    super.initState();
    _loadAssets();
    // Keeps the "waiting on an agent" screen honest — without this, the
    // customer only ever sees a local countdown guess, never the real
    // accept/decline/broadcasting status the server actually has.
    context.read<LoopController>().startCustomerPolling(widget.user.id);
    context.read<FavoritesController>().attachUser(widget.user);
    _refreshUnreadCount();
    _unreadPollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshUnreadCount());
    _refreshUnreadNotifications();
    _notificationsPollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshUnreadNotifications());
  }

  Future<void> _refreshUnreadNotifications() async {
    final token = widget.user.token;
    if (token == null) return;
    try {
      final notifications = await _notificationService.getNotifications(token);
      if (!mounted) return;
      final unread = notifications.where((n) => !n.isRead).length;
      if (unread != _unreadNotificationsCount) setState(() => _unreadNotificationsCount = unread);
    } on NotificationException {
      // Same as chat's unread poll — transient hiccup, next tick retries.
    }
  }

  Future<void> _refreshUnreadCount() async {
    final token = widget.user.token;
    if (token == null) return;
    try {
      final threads = await _chatService.listThreads(token: token);
      if (!mounted) return;
      final total = threads.fold<int>(0, (sum, t) => sum + t.unreadCount);
      if (total != _unreadChatCount) setState(() => _unreadChatCount = total);
    } on ChatException {
      // Transient network hiccup — the next poll tick will retry; not
      // worth surfacing a badge-count fetch failure to the user.
    }
  }

  Future<void> _loadAssets() async {
    setState(() {
      _loadingAssets = true;
      _assetsError = null;
    });
    try {
      final assets = await _assetService.fetchAssets(limit: 100);
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _loadingAssets = false;
      });
    } on AssetException catch (e) {
      if (!mounted) return;
      setState(() {
        _assetsError = e.message;
        _loadingAssets = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _unreadPollTimer?.cancel();
    _notificationsPollTimer?.cancel();
    context.read<LoopController>().stopCustomerPolling();
    super.dispose();
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleGateScreen()),
      (route) => false,
    );
  }

  Future<void> _openOrderUs(BuildContext context) async {
    final category = await showOrderCategorySheet(context);
    if (category == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OrderRequestFormScreen(user: widget.user, category: category),
    ));
  }

  Future<void> _openListingIntent(BuildContext context) async {
    final intent = await showListingIntentSheet(context);
    if (intent == null || !context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => intent == ListingIntent.sell
          ? SellPropertyFormScreen(user: widget.user)
          : RentPropertyFormScreen(user: widget.user),
    ));
  }

  void _handleCategoryTabChange(int index) {
    if (index == 4) {
      // Broker List tapped
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BrokerDirectoryScreen(
          category: AssetCategorySlug.others,
          categoryLabel: 'All',
          showAllBrokers: true,
          currentUser: widget.user,
        ),
      ));
      return;
    }
    setState(() => _categoryTabIndex = index);
  }

  List<Asset> get _filteredAssets {
    final query = _searchController.text.trim().toLowerCase();
    var list = _assets.where((asset) {
      final matchesQuery = query.isEmpty ||
          (asset.city?.toLowerCase().contains(query) ?? false) ||
          (asset.addressLine?.toLowerCase().contains(query) ?? false) ||
          asset.title.toLowerCase().contains(query);

      bool matchesCategory = true;
      if (_categoryTabIndex == 1) {
        // Real Estate
        matchesCategory = asset.category == AssetCategorySlug.house ||
            asset.category == AssetCategorySlug.apartments ||
            asset.category == AssetCategorySlug.condominium ||
            asset.category == AssetCategorySlug.building ||
            asset.category == AssetCategorySlug.land;
      } else if (_categoryTabIndex == 2) {
        // Vehicles
        matchesCategory = asset.category == AssetCategorySlug.vehicles;
      } else if (_categoryTabIndex == 3) {
        // Machinery
        matchesCategory = asset.category == AssetCategorySlug.machinery;
      }

      return matchesQuery && matchesCategory;
    }).toList();

    if (_picksTabIndex == 1) {
      // Nearby (filter Addis Ababa)
      list = list.where((a) => a.city == 'Addis Ababa').toList();
    } else if (_picksTabIndex == 2) {
      // Certified (active listings)
      list = list.where((a) => a.status == AssetStatus.active).toList();
    }

    return list;
  }

  void _handleBottomNavChange(int index) {
    if (index == 2) {
      // Raised center '+' Sell button
      _openListingIntent(context);
      return;
    }
    if (index == 1) {
      // Chat / Messages — "Interests" used to live here, but Saved
      // Listings is already reachable from the "Me" tab, so this slot
      // now opens the real chat inbox instead.
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatInboxScreen(user: widget.user),
      )).then((_) {
        if (mounted) _refreshUnreadCount();
      });
      return;
    }
    if (index == 3) {
      // Agents
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BrokerDirectoryScreen(
          category: AssetCategorySlug.others,
          categoryLabel: 'All',
          showAllBrokers: true,
          currentUser: widget.user,
        ),
      ));
      return;
    }
    if (index == 4) {
      // Me / Account hub (includes My Sell Requests as a section)
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VisitorAccountScreen(user: widget.user),
      ));
      return;
    }
    setState(() => _navIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final loop = context.watch<LoopController>();
    final assets = _filteredAssets;

    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: SafeArea(
        child: Builder(
          builder: (scaffoldContext) {
            return Column(
              children: [
                _TopBar(
                  searchController: _searchController,
                  onSearchChanged: (_) => setState(() {}),
                  unreadNotifications: _unreadNotificationsCount,
                  onNotificationsTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => NotificationsScreen(
                            token: widget.user.token ?? '',
                            onUnreadCountChanged: (count) {
                              if (mounted) setState(() => _unreadNotificationsCount = count);
                            },
                          ))),
                ),
                _CategoryTabStrip(
                  tabs: _categoryTabs,
                  activeIndex: _categoryTabIndex,
                  onChanged: _handleCategoryTabChange,
                ),
                if (loop.stage != LoopStage.idle)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: LoopProgress(stage: loop.stage),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: _InspectionBanner(onTap: () => _openOrderUs(context)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: _FindYourDesireCard(onOrderUs: () => _openOrderUs(context)),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                          child: _PicksTabStrip(
                            tabs: _picksTabs,
                            activeIndex: _picksTabIndex,
                            onChanged: (i) => setState(() => _picksTabIndex = i),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: _loadingAssets
                              ? const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : _assetsError != null
                                  ? Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.cloud_off_rounded, size: 34, color: AppColors.slate),
                                          const SizedBox(height: 12),
                                          Text(
                                            _assetsError!,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 14),
                                          OutlinedButton(onPressed: _loadAssets, child: const Text('Try again')),
                                        ],
                                      ),
                                    )
                                  : assets.isEmpty
                                      ? const Padding(
                                          padding: EdgeInsets.all(32),
                                          child: Center(
                                            child: Text('No listings found',
                                                style: TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600)),
                                          ),
                                        )
                                      : _PicksGrid(assets: assets, user: widget.user),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: _BottomNavBar(
        activeIndex: _navIndex,
        onChanged: _handleBottomNavChange,
        unreadChatCount: _unreadChatCount,
      ),
    );
  }
}

/// Search bar row + notification bell + globe icon.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchController,
    required this.onSearchChanged,
    this.unreadNotifications = 0,
    this.onNotificationsTap,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final int unreadNotifications;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F1),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: AppColors.slate),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.ink, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        hintText: 'Search homes, vehicles...',
                        hintStyle: TextStyle(fontSize: 13.5, color: AppColors.slate, fontWeight: FontWeight.w500),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _IconCircleButton(
            icon: Icons.notifications_outlined,
            onTap: onNotificationsTap,
            badgeCount: unreadNotifications,
          ),
          const SizedBox(width: 8),
          const _IconCircleButton(icon: Icons.language_rounded),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({required this.icon, this.onTap, this.badgeCount = 0});

  final IconData icon;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 17, color: AppColors.ink),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                decoration: const BoxDecoration(color: _kAccentRed, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "For You / Real Estate / Vehicles / Machinery / Broker List" tabs with a
/// red underline on the active tab, horizontally scrollable.
class _CategoryTabStrip extends StatelessWidget {
  const _CategoryTabStrip({required this.tabs, required this.activeIndex, required this.onChanged});

  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        itemBuilder: (context, i) {
          final active = i == activeIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () => onChanged(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tabs[i],
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? _kAccentRed : AppColors.slate,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 2.5,
                    width: 26,
                    color: active ? _kAccentRed : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Order Verified Inspection" promo card.
class _InspectionBanner extends StatelessWidget {
  const _InspectionBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E8),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.primaryYellow.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: Color(0xFFF0F0EE), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.verified_rounded, size: 20, color: Color(0xFF4A4A45)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Verified Inspection',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Get an on-site asset report before making any transaction',
                    style: TextStyle(fontSize: 11.5, color: AppColors.slate, fontWeight: FontWeight.w500, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
          ],
        ),
      ),
    );
  }
}

/// "Find your desire" card with the red "Order Us" button.
class _FindYourDesireCard extends StatelessWidget {
  const _FindYourDesireCard({required this.onOrderUs});

  final VoidCallback onOrderUs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Find your desire',
            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Request an on-site inspection',
            style: TextStyle(fontSize: 12.5, color: AppColors.slate, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onOrderUs,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentRed,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                elevation: 0,
              ),
              child: const Text('Order Us', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Top picks / Nearby / Certified / Free Items" tab row above the grid.
class _PicksTabStrip extends StatelessWidget {
  const _PicksTabStrip({required this.tabs, required this.activeIndex, required this.onChanged});

  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(tabs.length, (i) {
        final active = i == activeIndex;
        return Padding(
          padding: const EdgeInsets.only(right: 18),
          child: InkWell(
            onTap: () => onChanged(i),
            child: Text(
              tabs[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? _kAccentRed : AppColors.slate,
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// 2-column grid of listing cards, styled to match the reference mock:
/// photo with heart icon, ETB price, title, location line, verified badge.
class _PicksGrid extends StatelessWidget {
  const _PicksGrid({required this.assets, required this.user});

  final List<Asset> assets;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: assets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, i) => _PickCard(asset: assets[i], user: user),
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({required this.asset, required this.user});

  final Asset asset;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.select<FavoritesController, bool>((f) => f.isFavorite(asset.id));

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AssetDetailScreen(asset: asset, user: user),
        ));
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (asset.imageUrl != null)
                    Image.network(
                      asset.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          Container(color: AppColors.primaryYellow.withValues(alpha: 0.18)),
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : Container(color: AppColors.primaryYellow.withValues(alpha: 0.18)),
                    )
                  else
                    Container(color: AppColors.primaryYellow.withValues(alpha: 0.18)),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => context.read<FavoritesController>().toggle(asset.id),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(
                          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 14,
                          color: isFavorite ? _kAccentRed : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.formattedPrice,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    asset.title,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 11, color: AppColors.slate),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          asset.city ?? '',
                          style: const TextStyle(fontSize: 10.5, color: AppColors.slate, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: const [
                      Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
                      SizedBox(width: 3),
                      Text(
                        'Verified Listing',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom nav bar: Explore / Chat / Sell (raised red "+") / Agents / Me.
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.activeIndex, required this.onChanged, this.unreadChatCount = 0});

  final int activeIndex;
  final ValueChanged<int> onChanged;
  final int unreadChatCount;

  static const _items = [
    (Icons.explore_outlined, Icons.explore_rounded, 'Explore'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chat'),
    (Icons.add_rounded, Icons.add_rounded, 'Sell'),
    (Icons.groups_outlined, Icons.groups_rounded, 'Agents'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final (outline, filled, label) = _items[i];
            final active = i == activeIndex;

            if (i == 2) {
              // Center "Sell" tab: raised red circular button, no label.
              return InkWell(
                onTap: () => onChanged(i),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: const BoxDecoration(
                    color: _kAccentRed,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x33E84C3D), blurRadius: 10, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Icon(filled, color: Colors.white, size: 26),
                ),
              );
            }

            return InkWell(
              onTap: () => onChanged(i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(active ? filled : outline, size: 22, color: active ? _kAccentRed : AppColors.slate),
                      if (i == 1 && unreadChatCount > 0)
                        Positioned(
                          right: -7,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            constraints: const BoxConstraints(minWidth: 15),
                            decoration: BoxDecoration(
                              color: _kAccentRed,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              unreadChatCount > 9 ? '9+' : '$unreadChatCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? _kAccentRed : AppColors.slate,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
