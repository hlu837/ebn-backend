import 'package:flutter/material.dart';
import '../models/admin_user.dart';
import '../models/user_role.dart';
import '../services/admin_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_list_widgets.dart';
import 'admin_user_detail_screen.dart';

/// Admin's "Users" directory — a real read of `GET /api/users`. Was
/// page-local mock data (`_sampleUsers`) until the backend route existed.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService _adminService = AdminService();

  String _filter = 'All';
  String _query = '';

  List<AdminUser> _users = const [];
  bool _loading = true;
  String? _error;

  static const _filterOptions = ['All', 'Visitor', 'Agent / Broker', 'Affiliater', 'Investor'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _adminService.fetchUsers(token: widget.token);
      if (!mounted) return;
      setState(() {
        _users = rows;
        _loading = false;
      });
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  List<AdminUser> get _filtered {
    return _users.where((u) {
      final matchesFilter = _filter == 'All' || u.role.label == _filter;
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty || u.fullName.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  Future<void> _openDetail(AdminUser user) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminUserDetailScreen(user: user, token: widget.token)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final users = _filtered;
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Users', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Column(
                children: [
                  AdminSearchField(hintText: 'Search users by name or email', onChanged: (v) => setState(() => _query = v)),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AdminFilterChips(
                      options: _filterOptions,
                      selected: _filter,
                      onSelected: (v) => setState(() => _filter = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _load)
                      : users.isEmpty
                          ? const AdminEmptyState(message: 'No users match this filter.', icon: Icons.people_outline_rounded)
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                                itemCount: users.length,
                                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final user = users[index];
                                  return AdminEntityRow(
                                    leadingIcon: Icons.person_outline_rounded,
                                    title: user.fullName,
                                    subtitle: '${user.email}${user.phone != null ? ' · ${user.phone}' : ''} · Joined ${_monthYear(user.createdAt)}',
                                    trailingText: user.isSuspended ? 'SUSPENDED' : user.role.label.toUpperCase(),
                                    trailingColor: user.isSuspended
                                        ? AppColors.danger
                                        : (user.role == UserRole.user ? AppColors.primaryYellowDark : AppColors.slate),
                                    onTap: () => _openDetail(user),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

String _monthYear(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.year}';
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.slate),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
