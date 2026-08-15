import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_response.dart';
import '../providers/loop_controller.dart';
import '../providers/order_request_controller.dart';
import '../providers/sell_request_controller.dart';
import '../models/asset.dart';
import '../services/agent_service.dart';
import '../services/asset_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_drawer.dart';
import '../widgets/app_buttons.dart';
import '../widgets/asset_list_card.dart';
import '../widgets/loop_progress.dart';
import 'admin_activity_log_screen.dart';
import 'admin_announcements_screen.dart';
import 'admin_agents_screen.dart';
import 'admin_investment_opportunities_screen.dart';
import 'admin_investment_commitments_screen.dart';
import 'admin_confirmed_investments_screen.dart';
import 'admin_listing_detail_screen.dart';
import 'admin_order_requests_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_role_upgrade_requests_screen.dart';
import 'admin_sell_requests_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_support_inbox_screen.dart';
import 'admin_transactions_screen.dart';
import 'admin_users_screen.dart';
import 'notifications_screen.dart';
import 'role_gate_screen.dart';

/// The Admin side — its own full flow: sidebar navigation, live approvals
/// queue, and a snapshot of the asset catalogue. Watches the shared
/// [LoopController] so requests placed on the Customer side show up here
/// the moment they're submitted.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  LoopController? _loop;
  final AssetService _assetService = AssetService();
  final NotificationService _notificationService = NotificationService();

  // Loaded from the real `GET /api/assets` response (all statuses, so
  // Admin can see drafts/sold/etc too).
  List<Asset> _assets = [];
  bool _loadingAssets = true;

  // Same poll-based approach as the agent/customer home screens (see
  // notification_service.dart — no socket client wired up yet).
  int _unreadNotificationsCount = 0;
  Timer? _notificationsPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SellRequestController>().fetchAdminQueues();
      if (mounted) context.read<OrderRequestController>().fetchAdminQueues();
    });
    // Discovers tour requests submitted from *any* device, not just ones
    // created within this same running app instance.
    _loop = context.read<LoopController>()..startAdminPolling();
    _loadAssets();
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
      // Transient hiccup — next poll tick retries.
    }
  }

  Future<void> _loadAssets() async {
    try {
      // Every status — Admin needs to see drafts/under-inspection/sold too,
      // not just what's currently active for visitors.
      final assets = await _assetService.fetchAssets(limit: 200, status: 'all');
      if (!mounted) return;
      setState(() {
        _assets = assets;
        _loadingAssets = false;
      });
    } on AssetException catch (_) {
      if (!mounted) return;
      setState(() => _loadingAssets = false);
    }
  }

  @override
  void dispose() {
    _loop?.stopAdminPolling();
    _notificationsPollTimer?.cancel();
    super.dispose();
  }

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleGateScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loop = context.watch<LoopController>();
    final sellRequests = context.watch<SellRequestController>();
    final orderRequests = context.watch<OrderRequestController>();

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('EBN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text('Admin · ${widget.user.fullName}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        actions: [
          _NotificationBellAction(
            unreadCount: _unreadNotificationsCount,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => NotificationsScreen(
                token: widget.user.token ?? '',
                onUnreadCountChanged: (count) {
                  if (mounted) setState(() => _unreadNotificationsCount = count);
                },
              ),
            )),
          ),
          IconButton(tooltip: 'Reset demo', onPressed: loop.reset, icon: const Icon(Icons.restart_alt_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      drawer: AdminDrawer(
        adminName: widget.user.fullName,
        actions: AdminDrawerActions(
          onApprovalsQueue: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AdminSellRequestsScreen(),
          )),
          onOrderRequests: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AdminOrderRequestsScreen(),
          )),
          onAssets: () {
            // "Assets & Listings" from the drawer scrolls to the catalogue
            // already on this screen — the grid below doubles as that page
            // for now. Swap this for a dedicated full-catalogue screen
            // (with search/filter) once the list grows past a page.
          },
          onAgents: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AdminAgentsScreen(),
          )),
          onUsers: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminUsersScreen(token: widget.user.token ?? ''),
          )),
          onRoleUpgradeRequests: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminRoleUpgradeRequestsScreen(user: widget.user),
          )),
          onReports: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminReportsScreen(token: widget.user.token ?? ''),
          )),
          onTransactions: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminTransactionsScreen(token: widget.user.token ?? ''),
          )),
          onSupportInbox: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminSupportInboxScreen(user: widget.user),
          )),
          onActivityLog: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminActivityLogScreen(token: widget.user.token ?? ''),
          )),
          onAnnouncements: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminAnnouncementsScreen(token: widget.user.token ?? ''),
          )),
          onInvestmentOpportunities: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminInvestmentOpportunitiesScreen(token: widget.user.token ?? ''),
          )),
          onInvestmentCommitments: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminInvestmentCommitmentsScreen(token: widget.user.token ?? ''),
          )),
          onConfirmedInvestments: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminConfirmedInvestmentsScreen(token: widget.user.token ?? ''),
          )),
          onSettings: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AdminSettingsScreen(token: widget.user.token ?? '', currentAdminId: widget.user.id),
          )),
          onLogout: () => _logout(context),
        ),
      ),
      body: Column(
        children: [
          LoopProgress(stage: loop.stage),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Row(
                  children: [
                    _StatCard(value: '${_assets.length}', label: 'Total Listings'),
                    const SizedBox(width: AppSpacing.sm),
                    _StatCard(value: _pendingCount(loop), label: 'Pending Approvals'),
                    const SizedBox(width: AppSpacing.sm),
                    const _StatCard(value: '12', label: 'Active Agents'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Approvals Queue', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _ApprovalCard(loop: loop),
                const SizedBox(height: AppSpacing.xl),
                Text('Property Sell Requests', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _SellRequestsSummaryCard(
                  pendingSubmissions: sellRequests.pendingSubmissions.length,
                  pendingReports: sellRequests.pendingReports.length,
                  onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AdminSellRequestsScreen(),
                  )),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Order Requests ("Order Us")', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                _OrderRequestsSummaryCard(
                  broadcasting: orderRequests.broadcasting.length,
                  disputed: orderRequests.disputed.length,
                  onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AdminOrderRequestsScreen(),
                  )),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Asset Catalogue', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                if (_loadingAssets)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_assets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: Text('No listings yet.')),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _assets.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.60,
                    ),
                    itemBuilder: (context, index) => AssetListCard(
                      asset: _assets[index],
                      compact: true,
                      actionLabel: 'Manage',
                      onActionPressed: () async {
                        final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
                          builder: (_) => AdminListingDetailScreen(asset: _assets[index]),
                        ));
                        // The detail screen returns true if it saved/deleted —
                        // refresh so the catalogue reflects the real change.
                        if (result == true) _loadAssets();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pendingCount(LoopController loop) {
    final active = loop.stage == LoopStage.pendingApproval ||
        loop.stage == LoopStage.broadcasting ||
        loop.stage == LoopStage.declined ||
        loop.stage == LoopStage.expired;
    return active ? '1' : '0';
  }
}

class _SellRequestsSummaryCard extends StatelessWidget {
  const _SellRequestsSummaryCard({required this.pendingSubmissions, required this.pendingReports, required this.onOpen});

  final int pendingSubmissions;
  final int pendingReports;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final total = pendingSubmissions + pendingReports;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.18), borderRadius: BorderRadius.circular(AppRadii.md)),
                alignment: Alignment.center,
                child: const Icon(Icons.sell_outlined, color: AppColors.ink),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total == 0 ? 'Nothing waiting' : '$total item${total == 1 ? '' : 's'} need review',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$pendingSubmissions new submission${pendingSubmissions == 1 ? '' : 's'} · $pendingReports inspection report${pendingReports == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderRequestsSummaryCard extends StatelessWidget {
  const _OrderRequestsSummaryCard({required this.broadcasting, required this.disputed, required this.onOpen});

  final int broadcasting;
  final int disputed;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final total = broadcasting + disputed;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.18), borderRadius: BorderRadius.circular(AppRadii.md)),
                alignment: Alignment.center,
                child: const Icon(Icons.search_rounded, color: AppColors.ink),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      total == 0 ? 'Nothing needs attention' : '$total item${total == 1 ? '' : 's'} need attention',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$broadcasting awaiting an agent · $disputed disputed',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBellAction extends StatelessWidget {
  const _NotificationBellAction({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (unreadCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
                decoration: const BoxDecoration(color: AppColors.primaryYellow, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: AppColors.slate)),
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatefulWidget {
  const _ApprovalCard({required this.loop});

  final LoopController loop;

  @override
  State<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<_ApprovalCard> {
  bool _dispatching = false;

  Future<void> _pickAgentAndApprove() async {
    List<Map<String, dynamic>> agents;
    try {
      agents = await AgentService().fetchDirectory();
    } on AgentServiceException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
      return;
    }
    if (!mounted) return;
    if (agents.isEmpty) {
      AppToast.showError(context, 'No agents in the Broker Network yet — add one first.');
      return;
    }
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Dispatch to which agent?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            ...agents.map((a) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(a['name'] as String? ?? 'Agent', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text((a['city'] as String?)?.isNotEmpty == true ? a['city'] as String : 'No city on file'),
                  onTap: () => Navigator.of(sheetContext).pop(a),
                )),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _dispatching = true);
    await widget.loop.adminApprove(
      agentId: picked['userId'] as String,
      agentName: picked['name'] as String? ?? 'Agent',
    );
    if (!mounted) return;
    setState(() => _dispatching = false);
    if (widget.loop.lastError != null) AppToast.showError(context, widget.loop.lastError!);
  }

  @override
  Widget build(BuildContext context) {
    final loop = widget.loop;
    final showQueueItem = loop.stage == LoopStage.pendingApproval ||
        loop.stage == LoopStage.broadcasting ||
        loop.stage == LoopStage.declined ||
        loop.stage == LoopStage.expired;

    if (!showQueueItem) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.inbox_rounded, color: AppColors.slate, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                loop.stage == LoopStage.idle
                    ? 'Nothing waiting — queue is empty.'
                    : 'Request is with an agent right now, awaiting their response.',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate),
              ),
            ),
          ],
        ),
      );
    }

    final asset = loop.requestedAsset;
    final isRetry = loop.stage != LoopStage.pendingApproval;
    final isBroadcasting = loop.stage == LoopStage.broadcasting;

    final String headline;
    final String? subtitle;
    final String buttonLabel;
    if (isBroadcasting) {
      headline = 'Broadcasting to nearby agents';
      subtitle = 'Original agent didn\'t respond in time — the system is currently offering '
          'this to nearby agents. You can still assign someone directly instead of waiting.';
      buttonLabel = 'Assign an Agent Directly';
    } else if (isRetry) {
      headline = 'Needs re-dispatch';
      subtitle = loop.stage == LoopStage.declined
          ? 'Previous agent declined the dispatch.'
          : 'Previous dispatch window expired with no response.';
      buttonLabel = 'Re-dispatch to Agent';
    } else {
      headline = 'New tour request';
      subtitle = null;
      buttonLabel = 'Approve & Publish';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: AppColors.primaryYellow, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(
                  isBroadcasting
                      ? Icons.podcasts_rounded
                      : (isRetry ? Icons.replay_rounded : Icons.request_page_rounded),
                  color: AppColors.ink,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    if (asset != null)
                      Text(
                        asset.title,
                        style: const TextStyle(color: Color(0xFFB9B8AE), fontSize: 12.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFFB9B8AE), fontSize: 12, height: 1.4),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: _dispatching ? 'Dispatching…' : buttonLabel,
            backgroundColor: AppColors.primaryYellow,
            foregroundColor: Colors.white,
            onPressed: _dispatching ? null : _pickAgentAndApprove,
          ),
        ],
      ),
    );
  }
}
