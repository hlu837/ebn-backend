import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/admin_user.dart';
import '../models/order_request.dart';
import '../models/sell_request.dart';
import '../models/user_role.dart';
import '../providers/loop_controller.dart';
import '../services/admin_service.dart';
import '../services/order_request_service.dart';
import '../services/sell_request_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_list_widgets.dart';
import '../widgets/app_buttons.dart';

/// Admin's detail page for a single user — profile info plus their real
/// request history, with a working suspend/reactivate control.
///
/// History pulls from three separate real sources rather than one unified
/// endpoint, since that's how the app already tracks these three request
/// types: tour requests (`LoopController.fetchCustomerHistory`), sell
/// submissions (`SellRequestService.byOwner`), and Order Us requests
/// (`OrderRequestService.byRequester`).
class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({super.key, required this.user, required this.token});

  final AdminUser user;
  final String token;

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  final AdminService _adminService = AdminService();
  final SellRequestService _sellRequestService = SellRequestService();
  final OrderRequestService _orderRequestService = OrderRequestService();

  late AdminUser _user;
  bool _suspending = false;

  bool _loadingHistory = true;
  String? _historyError;
  List<Map<String, dynamic>> _tourRequests = const [];
  List<SellRequest> _sellRequests = const [];
  List<OrderRequest> _orderRequests = const [];

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final loop = context.read<LoopController>();
      final results = await Future.wait([
        loop.fetchCustomerHistory(_user.id),
        _sellRequestService.byOwner(_user.id),
        _orderRequestService.byRequester(_user.id),
      ]);
      if (!mounted) return;
      setState(() {
        _tourRequests = results[0] as List<Map<String, dynamic>>;
        _sellRequests = results[1] as List<SellRequest>;
        _orderRequests = results[2] as List<OrderRequest>;
        _loadingHistory = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        _historyError = e.toString();
      });
    }
  }

  Future<void> _toggleSuspend() async {
    setState(() => _suspending = true);
    try {
      final updated = await _adminService.setUserSuspended(_user.id, !_user.isSuspended, token: widget.token);
      if (!mounted) return;
      setState(() {
        _user = updated;
        _suspending = false;
      });
      AppToast.showSuccess(context, _user.isSuspended ? 'User suspended.' : 'User reactivated.');
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() => _suspending = false);
      AppToast.showError(context, e.message);
    }
  }

  int get _totalRequests => _tourRequests.length + _sellRequests.length + _orderRequests.length;

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final isAdmin = user.role.apiValue == 'admin';
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('User', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHistory,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.ink,
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primaryYellow, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
                        const SizedBox(height: 2),
                        Text(user.email, style: const TextStyle(fontSize: 13, color: AppColors.slate)),
                        if (user.phone != null) ...[
                          const SizedBox(height: 2),
                          Text(user.phone!, style: const TextStyle(fontSize: 13, color: AppColors.slate)),
                        ],
                        const SizedBox(height: 2),
                        Text('Joined ${_monthYear(user.createdAt)}', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  AdminStatCard(value: _loadingHistory ? '—' : '$_totalRequests', label: 'Total Requests'),
                  const SizedBox(width: AppSpacing.sm),
                  AdminStatCard(value: user.role.label, label: 'Role'),
                  const SizedBox(width: AppSpacing.sm),
                  AdminStatCard(value: user.isSuspended ? 'Suspended' : 'Active', label: 'Account Status'),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),
              if (_loadingHistory)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_historyError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Column(
                    children: [
                      const Text("Couldn't load this user's request history.", style: TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton(onPressed: _loadHistory, child: const Text('Retry')),
                    ],
                  ),
                )
              else ...[
                const Text('Tour requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: AppSpacing.sm),
                if (_tourRequests.isEmpty)
                  const AdminEmptyState(message: 'No tour requests yet.', icon: Icons.tour_outlined)
                else
                  ..._tourRequests.map((row) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AdminEntityRow(
                          leadingIcon: Icons.tour_outlined,
                          title: row['asset_title'] as String? ?? 'Listing',
                          subtitle: '${_tourStatusLabel(row['status'] as String?)} · ${_relative(DateTime.tryParse(row['created_at'] as String? ?? ''))}',
                        ),
                      )),

                const SizedBox(height: AppSpacing.lg),
                const Text('Sell submissions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: AppSpacing.sm),
                if (_sellRequests.isEmpty)
                  const AdminEmptyState(message: 'No sell submissions yet.', icon: Icons.sell_outlined)
                else
                  ..._sellRequests.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AdminEntityRow(
                          leadingIcon: Icons.sell_outlined,
                          title: r.title,
                          subtitle: '${r.statusDescription} · ${_relative(r.submittedAt)}',
                        ),
                      )),

                const SizedBox(height: AppSpacing.lg),
                const Text('Order Us requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: AppSpacing.sm),
                if (_orderRequests.isEmpty)
                  const AdminEmptyState(message: 'No Order Us requests yet.', icon: Icons.request_page_outlined)
                else
                  ..._orderRequests.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AdminEntityRow(
                          leadingIcon: Icons.request_page_outlined,
                          title: r.title,
                          subtitle: '${r.status.name} · ${_relative(r.submittedAt)}',
                        ),
                      )),
              ],

              const SizedBox(height: AppSpacing.xl),
              if (isAdmin)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    "Admin accounts can't be suspended from here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                )
              else
                SecondaryButton(
                  label: _suspending
                      ? 'Please wait…'
                      : (user.isSuspended ? 'Reactivate user' : 'Suspend user'),
                  borderColor: user.isSuspended ? AppColors.success : AppColors.danger,
                  textColor: user.isSuspended ? AppColors.success : AppColors.danger,
                  onPressed: _suspending ? null : _toggleSuspend,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _monthYear(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.year}';
}

String _tourStatusLabel(String? status) {
  switch (status) {
    case 'pending_approval':
      return 'Pending';
    case 'broadcasting':
      return 'Broadcasting';
    case 'dispatched':
      return 'Dispatched';
    case 'accepted':
      return 'Accepted';
    case 'declined':
      return 'Declined';
    case 'expired':
      return 'Expired';
    default:
      return 'Unknown';
  }
}

String _relative(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  if (diff.inDays >= 1) return '${diff.inDays} day(s) ago';
  if (diff.inHours >= 1) return '${diff.inHours} hour(s) ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes} minute(s) ago';
  return 'Just now';
}
