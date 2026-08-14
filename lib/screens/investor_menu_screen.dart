import 'package:flutter/material.dart';
import '../models/auth_response.dart';
import '../theme/app_theme.dart';

/// Everything that used to live in the side [InvestorDrawer], now surfaced
/// as the "Menu" tab in the bottom nav: Reinvest, Wallet, Referral
/// Program, News & Announcements, Support, and Profile & Settings.
/// Mirrors [AgentMenuScreen] so both sides feel like the same app.
class InvestorMenuScreen extends StatelessWidget {
  const InvestorMenuScreen({
    super.key,
    required this.user,
    required this.onReinvest,
    required this.onWallet,
    required this.onReferralProgram,
    required this.onNewsAnnouncements,
    required this.onSupport,
    required this.onProfileSettings,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback onReinvest;
  final VoidCallback onWallet;
  final VoidCallback onReferralProgram;
  final VoidCallback onNewsAnnouncements;
  final VoidCallback onSupport;
  final VoidCallback onProfileSettings;
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
                    const _InvestorChip(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _MenuSection(title: 'Portfolio', items: [
            _MenuEntry(Icons.autorenew_rounded, 'Reinvest', onReinvest),
            _MenuEntry(Icons.account_balance_wallet_outlined, 'Wallet', onWallet),
          ]),
          const SizedBox(height: AppSpacing.lg),
          _MenuSection(title: 'Account', items: [
            _MenuEntry(Icons.groups_2_outlined, 'Referral Program', onReferralProgram),
            _MenuEntry(Icons.campaign_outlined, 'News & Announcements', onNewsAnnouncements),
            _MenuEntry(Icons.settings_outlined, 'Profile & Settings', onProfileSettings),
          ]),
          const SizedBox(height: AppSpacing.lg),
          _MenuSection(title: 'General', items: [
            _MenuEntry(Icons.support_agent_outlined, 'Support', onSupport),
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

class _InvestorChip extends StatelessWidget {
  const _InvestorChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.primaryYellow.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, size: 13, color: AppColors.primaryYellowDark),
          SizedBox(width: 4),
          Text('Investor', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryYellowDark)),
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
