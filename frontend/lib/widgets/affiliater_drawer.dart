import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum AffiliateTier { bronze, silver, gold, diamond }

extension AffiliateTierX on AffiliateTier {
  String get label {
    switch (this) {
      case AffiliateTier.bronze:
        return 'Bronze Member';
      case AffiliateTier.silver:
        return 'Silver Member';
      case AffiliateTier.gold:
        return 'Gold Member';
      case AffiliateTier.diamond:
        return 'Diamond Member';
    }
  }

  /// Accent color used for the badge background, icon, and text.
  Color get color {
    switch (this) {
      case AffiliateTier.bronze:
        return const Color(0xFFB2703C);
      case AffiliateTier.silver:
        return const Color(0xFF8A8D93);
      case AffiliateTier.gold:
        return const Color(0xFFC79A2E);
      case AffiliateTier.diamond:
        return const Color(0xFF2E8FDE);
    }
  }

  IconData get icon => this == AffiliateTier.diamond ? Icons.diamond_rounded : Icons.workspace_premium_rounded;
}

class AffiliaterDrawerActions {
  final VoidCallback? onDashboard;
  final VoidCallback? onProperties;
  final VoidCallback? onMyReferrals;
  final VoidCallback? onEarnings;
  final VoidCallback? onReports;
  final VoidCallback? onCampaigns;
  final VoidCallback? onMembership;
  final VoidCallback? onNotifications;
  final VoidCallback? onAccountSettings;
  final VoidCallback? onSupport;
  final VoidCallback? onLogout;

  const AffiliaterDrawerActions({
    this.onDashboard,
    this.onProperties,
    this.onMyReferrals,
    this.onEarnings,
    this.onReports,
    this.onCampaigns,
    this.onMembership,
    this.onNotifications,
    this.onAccountSettings,
    this.onSupport,
    this.onLogout,
  });
}

/// Sidebar for the Affiliater side:
/// Dashboard · Properties · My Referrals · Earnings · Reports ·
/// Campaigns · Notifications · Account Settings · Support.
class AffiliaterDrawer extends StatelessWidget {
  const AffiliaterDrawer({
    super.key,
    required this.affiliaterName,
    required this.tokenBalance,
    this.actions = const AffiliaterDrawerActions(),
  });

  final String affiliaterName;
  final int tokenBalance;
  final AffiliaterDrawerActions actions;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cloud,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(affiliaterName: affiliaterName, tokenBalance: tokenBalance),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  _DrawerItem(icon: Icons.home_rounded, label: 'Dashboard', onTap: () => _tap(context, actions.onDashboard)),
                  _DrawerItem(icon: Icons.holiday_village_outlined, label: 'Properties', onTap: () => _tap(context, actions.onProperties)),
                  _DrawerItem(icon: Icons.groups_2_outlined, label: 'My Referrals', onTap: () => _tap(context, actions.onMyReferrals)),
                  _DrawerItem(icon: Icons.payments_outlined, label: 'Earnings', onTap: () => _tap(context, actions.onEarnings)),
                  _DrawerItem(icon: Icons.bar_chart_rounded, label: 'Reports', onTap: () => _tap(context, actions.onReports)),
                  _DrawerItem(icon: Icons.campaign_outlined, label: 'Campaigns', onTap: () => _tap(context, actions.onCampaigns)),
                  _DrawerItem(icon: Icons.workspace_premium_outlined, label: 'Membership', onTap: () => _tap(context, actions.onMembership)),
                  _DrawerItem(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () => _tap(context, actions.onNotifications)),
                  _DrawerItem(icon: Icons.settings_outlined, label: 'Account Settings', onTap: () => _tap(context, actions.onAccountSettings)),
                  _DrawerItem(icon: Icons.support_agent_outlined, label: 'Support', onTap: () => _tap(context, actions.onSupport)),
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
  const _DrawerHeader({required this.affiliaterName, required this.tokenBalance});

  final String affiliaterName;
  final int tokenBalance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.border,
                child: const Icon(Icons.share_rounded, color: AppColors.slate, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(affiliaterName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.25), borderRadius: BorderRadius.circular(AppRadii.pill)),
                      child: const Text('Affiliater', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                const Icon(Icons.toll_rounded, size: 16, color: AppColors.primaryYellowDark),
                const SizedBox(width: 8),
                Text('$tokenBalance tokens', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
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
                Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink))),
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
                Text('Log Out', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
