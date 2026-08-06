import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VisitorDrawerActions {
  final VoidCallback? onExploreFeed;
  final VoidCallback? onSavedListings;
  final VoidCallback? onFindBrokers;
  final VoidCallback? onMySellRequests;
  final VoidCallback? onMyTours;
  final VoidCallback? onUpgradeRole;
  final VoidCallback? onAccountSettings;
  final VoidCallback? onAboutFaq;
  final VoidCallback? onLogout;

  const VisitorDrawerActions({
    this.onExploreFeed,
    this.onSavedListings,
    this.onFindBrokers,
    this.onMySellRequests,
    this.onMyTours,
    this.onUpgradeRole,
    this.onAccountSettings,
    this.onAboutFaq,
    this.onLogout,
  });
}

/// Sidebar for the Visitor side:
/// Explore Feed · Saved Listings · Find Brokers · My Sell Requests ·
/// Account & Settings · About/FAQ
/// (Property Detail View is reached from a listing card, not the sidebar.)
class VisitorDrawer extends StatelessWidget {
  const VisitorDrawer({
    super.key,
    required this.visitorName,
    this.actions = const VisitorDrawerActions(),
  });

  final String visitorName;
  final VisitorDrawerActions actions;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.cloud,
      child: SafeArea(
        child: Column(
          children: [
            _DrawerHeader(visitorName: visitorName),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  _DrawerItem(icon: Icons.explore_outlined, label: 'Explore Feed', onTap: () => _tap(context, actions.onExploreFeed)),
                  _DrawerItem(icon: Icons.favorite_border_rounded, label: 'Saved Listings / Favorites', onTap: () => _tap(context, actions.onSavedListings)),
                  _DrawerItem(icon: Icons.map_outlined, label: 'Find Brokers', onTap: () => _tap(context, actions.onFindBrokers)),
                  _DrawerItem(icon: Icons.sell_outlined, label: 'My Sell Requests', onTap: () => _tap(context, actions.onMySellRequests)),
                  _DrawerItem(icon: Icons.tour_outlined, label: 'My Tour Requests', onTap: () => _tap(context, actions.onMyTours)),
                  _DrawerItem(icon: Icons.upgrade_rounded, label: 'Upgrade Your Role', onTap: () => _tap(context, actions.onUpgradeRole)),
                  _DrawerItem(icon: Icons.settings_outlined, label: 'Account & Settings', onTap: () => _tap(context, actions.onAccountSettings)),
                  _DrawerItem(icon: Icons.help_outline_rounded, label: 'About Us / FAQ', onTap: () => _tap(context, actions.onAboutFaq)),
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
  const _DrawerHeader({required this.visitorName});

  final String visitorName;

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
            child: const Icon(Icons.person_rounded, color: AppColors.slate, size: 30),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(visitorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.25), borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: const Text('Visitor', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
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
