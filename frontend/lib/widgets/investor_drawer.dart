import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InvestorDrawerActions {
  final VoidCallback? onDashboard;
  final VoidCallback? onMyInvestments;
  final VoidCallback? onInvestmentOpportunities;
  final VoidCallback? onReinvest;
  final VoidCallback? onWallet;
  final VoidCallback? onReferralProgram;
  final VoidCallback? onNewsAnnouncements;
  final VoidCallback? onSupport;
  final VoidCallback? onProfileSettings;
  final VoidCallback? onLogout;

  const InvestorDrawerActions({
    this.onDashboard,
    this.onMyInvestments,
    this.onInvestmentOpportunities,
    this.onReinvest,
    this.onWallet,
    this.onReferralProgram,
    this.onNewsAnnouncements,
    this.onSupport,
    this.onProfileSettings,
    this.onLogout,
  });
}

/// Sidebar for the Investor side:
/// Dashboard · My Investments · Investment Opportunities ·
/// Reinvest · Wallet · Referral Program ·
/// News & Announcements · Support · Profile & Settings · Logout.
class InvestorDrawer extends StatelessWidget {
  const InvestorDrawer({
    super.key,
    required this.investorName,
    this.actions = const InvestorDrawerActions(),
  });

  final String investorName;
  final InvestorDrawerActions actions;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cloud,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(investorName: investorName),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  _DrawerItem(icon: Icons.dashboard_outlined, label: 'Dashboard', onTap: () => _tap(context, actions.onDashboard)),
                  _DrawerItem(icon: Icons.pie_chart_outline_rounded, label: 'My Investments', onTap: () => _tap(context, actions.onMyInvestments)),
                  _DrawerItem(icon: Icons.explore_outlined, label: 'Investment Opportunities', onTap: () => _tap(context, actions.onInvestmentOpportunities)),
                  _DrawerItem(icon: Icons.autorenew_rounded, label: 'Reinvest', onTap: () => _tap(context, actions.onReinvest)),
                  _DrawerItem(icon: Icons.account_balance_wallet_outlined, label: 'Wallet', onTap: () => _tap(context, actions.onWallet)),
                  _DrawerItem(icon: Icons.groups_2_outlined, label: 'Referral Program', onTap: () => _tap(context, actions.onReferralProgram)),
                  _DrawerItem(icon: Icons.campaign_outlined, label: 'News & Announcements', onTap: () => _tap(context, actions.onNewsAnnouncements)),
                  _DrawerItem(icon: Icons.support_agent_outlined, label: 'Support', onTap: () => _tap(context, actions.onSupport)),
                  _DrawerItem(icon: Icons.settings_outlined, label: 'Profile & Settings', onTap: () => _tap(context, actions.onProfileSettings)),
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
  const _DrawerHeader({required this.investorName});

  final String investorName;

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
            backgroundColor: AppColors.border,
            child: const Icon(Icons.trending_up_rounded, color: AppColors.slate, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(investorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.25), borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: const Text('Investor', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
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
