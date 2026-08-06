import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bundles the navigation callbacks the admin drawer needs.
class AdminDrawerActions {
  final VoidCallback? onApprovalsQueue;
  final VoidCallback? onOrderRequests;
  final VoidCallback? onAssets;
  final VoidCallback? onAgents;
  final VoidCallback? onUsers;
  final VoidCallback? onRoleUpgradeRequests;
  final VoidCallback? onReports;
  final VoidCallback? onTransactions;
  final VoidCallback? onSupportInbox;
  final VoidCallback? onActivityLog;
  final VoidCallback? onAnnouncements;
  final VoidCallback? onInvestmentOpportunities;
  final VoidCallback? onInvestmentCommitments;
  final VoidCallback? onConfirmedInvestments;
  final VoidCallback? onSettings;
  final VoidCallback? onLogout;

  const AdminDrawerActions({
    this.onApprovalsQueue,
    this.onOrderRequests,
    this.onAssets,
    this.onAgents,
    this.onUsers,
    this.onRoleUpgradeRequests,
    this.onReports,
    this.onTransactions,
    this.onSupportInbox,
    this.onActivityLog,
    this.onAnnouncements,
    this.onInvestmentOpportunities,
    this.onInvestmentCommitments,
    this.onConfirmedInvestments,
    this.onSettings,
    this.onLogout,
  });
}

/// The primary navigation drawer for the Admin side. Visually mirrors
/// [AgentDrawer] so the ink/yellow language stays consistent across sides.
class AdminDrawer extends StatelessWidget {
  const AdminDrawer({
    super.key,
    required this.adminName,
    this.actions = const AdminDrawerActions(),
  });

  final String adminName;
  final AdminDrawerActions actions;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cloud,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(adminName: adminName),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  _DrawerItem(
                    icon: Icons.fact_check_outlined,
                    label: 'Approvals Queue',
                    onTap: () => _tap(context, actions.onApprovalsQueue),
                  ),
                  _DrawerItem(
                    icon: Icons.search_rounded,
                    label: 'Order Requests',
                    onTap: () => _tap(context, actions.onOrderRequests),
                  ),
                  _DrawerItem(
                    icon: Icons.inventory_2_outlined,
                    label: 'Assets & Listings',
                    onTap: () => _tap(context, actions.onAssets),
                  ),
                  _DrawerItem(
                    icon: Icons.groups_outlined,
                    label: 'Agents & Team',
                    onTap: () => _tap(context, actions.onAgents),
                  ),
                  _DrawerItem(
                    icon: Icons.people_outline_rounded,
                    label: 'Users',
                    onTap: () => _tap(context, actions.onUsers),
                  ),
                  _DrawerItem(
                    icon: Icons.upgrade_rounded,
                    label: 'Role Upgrade Requests',
                    onTap: () => _tap(context, actions.onRoleUpgradeRequests),
                  ),
                  _DrawerItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'Reports',
                    onTap: () => _tap(context, actions.onReports),
                  ),
                  _DrawerItem(
                    icon: Icons.receipt_long_outlined,
                    label: 'Transactions',
                    onTap: () => _tap(context, actions.onTransactions),
                  ),
                  _DrawerItem(
                    icon: Icons.mail_outline_rounded,
                    label: 'Support Inbox',
                    onTap: () => _tap(context, actions.onSupportInbox),
                  ),
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    label: 'Activity Log',
                    onTap: () => _tap(context, actions.onActivityLog),
                  ),
                  _DrawerItem(
                    icon: Icons.campaign_outlined,
                    label: 'News & Announcements',
                    onTap: () => _tap(context, actions.onAnnouncements),
                  ),
                  _DrawerItem(
                    icon: Icons.trending_up_rounded,
                    label: 'Investment Opportunities',
                    onTap: () => _tap(context, actions.onInvestmentOpportunities),
                  ),
                  _DrawerItem(
                    icon: Icons.fact_check_outlined,
                    label: 'Investment Commitments',
                    onTap: () => _tap(context, actions.onInvestmentCommitments),
                  ),
                  _DrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Confirmed Investments',
                    onTap: () => _tap(context, actions.onConfirmedInvestments),
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () => _tap(context, actions.onSettings),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            _LogoutTile(onTap: () => _tap(context, actions.onLogout)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _tap(BuildContext context, VoidCallback? callback) {
    Navigator.of(context).pop();
    callback?.call();
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.adminName});

  final String adminName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      color: AppColors.card,
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.ink,
            child: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primaryYellow, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adminName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryYellow.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Text(
                    'Administrator',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          hoverColor: AppColors.border.withOpacity(0.4),
          splashColor: AppColors.primaryYellow.withOpacity(0.25),
          highlightColor: AppColors.primaryYellow.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppColors.ink),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          hoverColor: AppColors.danger.withOpacity(0.08),
          splashColor: AppColors.danger.withOpacity(0.15),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 13),
            child: Row(
              children: [
                Icon(Icons.logout_rounded, size: 22, color: AppColors.danger),
                SizedBox(width: AppSpacing.md),
                Text(
                  'Log Out',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.danger),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
