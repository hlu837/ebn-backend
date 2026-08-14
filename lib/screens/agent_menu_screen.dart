import 'package:flutter/material.dart';
import '../models/auth_response.dart';
import '../theme/app_theme.dart';
import '../widgets/agent_drawer.dart' show AgentTier, AgentTierX;

/// Everything that used to live in the side [AgentDrawer], now surfaced as
/// the "Menu" tab in the bottom nav: Property Management, Membership,
/// Wallet, Schedule, Settings, Support, and the rest.
class AgentMenuScreen extends StatelessWidget {
  const AgentMenuScreen({
    super.key,
    required this.user,
    required this.tier,
    required this.isOnline,
    required this.onOnlineChanged,
    required this.onPropertyManagement,
    required this.onCustomers,
    required this.onReferrals,
    required this.onBrokerNetwork,
    required this.onNetwork,
    required this.onVisibilityProfile,
    required this.onSavedListings,
    required this.onWallet,
    required this.onMembership,
    required this.onCommunication,
    required this.onSchedule,
    required this.onTourHistory,
    required this.onSettings,
    required this.onSupport,
    required this.onResetDemo,
    required this.onLogout,
  });

  final AppUser user;
  final AgentTier tier;
  final bool isOnline;
  final ValueChanged<bool> onOnlineChanged;
  final VoidCallback onPropertyManagement;
  final VoidCallback onCustomers;
  final VoidCallback onReferrals;
  final VoidCallback onBrokerNetwork;
  final VoidCallback onNetwork;
  final VoidCallback onVisibilityProfile;
  final VoidCallback onSavedListings;
  final VoidCallback onWallet;
  final VoidCallback onMembership;
  final VoidCallback onCommunication;
  final VoidCallback onSchedule;
  final VoidCallback onTourHistory;
  final VoidCallback onSettings;
  final VoidCallback onSupport;
  final VoidCallback onResetDemo;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.border,
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 4),
                    _TierChip(tier: tier),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cloud,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: isOnline ? AppColors.success : AppColors.slate),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'Online — receiving dispatches' : 'Offline',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isOnline ? AppColors.success : AppColors.slate),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: isOnline,
                  onChanged: onOnlineChanged,
                  activeColor: AppColors.success,
                  inactiveThumbColor: AppColors.slate,
                  inactiveTrackColor: AppColors.border,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _MenuSection(title: 'Business', items: [
            _MenuEntry(Icons.apartment_outlined, 'Property Management', onPropertyManagement),
            _MenuEntry(Icons.people_outline, 'Customers', onCustomers),
            _MenuEntry(Icons.handshake_outlined, 'Referrals', onReferrals),
            _MenuEntry(Icons.public, 'Broker Network', onBrokerNetwork),
            _MenuEntry(Icons.groups_2_outlined, 'My Network', onNetwork),
            _MenuEntry(Icons.star_outline, 'Visibility & Profile', onVisibilityProfile),
            _MenuEntry(Icons.favorite_border_rounded, 'Saved Listings', onSavedListings),
          ]),
          const SizedBox(height: AppSpacing.lg),
          _MenuSection(title: 'Account', items: [
            _MenuEntry(Icons.account_balance_wallet_outlined, 'Wallet', onWallet),
            _MenuEntry(Icons.workspace_premium_outlined, 'Membership', onMembership),
            _MenuEntry(Icons.chat_bubble_outline, 'Communication', onCommunication),
            _MenuEntry(Icons.calendar_month_outlined, 'Schedule', onSchedule),
            _MenuEntry(Icons.tour_outlined, 'Tour History', onTourHistory),
          ]),
          const SizedBox(height: AppSpacing.lg),
          _MenuSection(title: 'General', items: [
            _MenuEntry(Icons.settings_outlined, 'Settings', onSettings),
            _MenuEntry(Icons.support_agent_outlined, 'Support', onSupport),
            _MenuEntry(Icons.restart_alt_rounded, 'Reset demo', onResetDemo),
          ]),
          const SizedBox(height: AppSpacing.lg),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: onLogout,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 20, color: AppColors.danger),
                    SizedBox(width: 10),
                    Text('Log Out', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.danger)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});
  final AgentTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: tier.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: 13, color: tier.color),
          const SizedBox(width: 4),
          Text(tier.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tier.color)),
        ],
      ),
    );
  }
}

class _MenuEntry {
  const _MenuEntry(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});
  final String title;
  final List<_MenuEntry> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.slate, letterSpacing: 0.6)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _MenuRow(entry: items[i]),
                if (i != items.length - 1) const Divider(height: 1, color: AppColors.border, indent: AppSpacing.md, endIndent: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.entry});
  final _MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: entry.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 13),
          child: Row(
            children: [
              Icon(entry.icon, size: 21, color: AppColors.ink),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(entry.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink))),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}
