import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_response.dart';
import '../providers/sell_request_controller.dart';
import '../theme/app_theme.dart';
import 'my_sell_requests_screen.dart';
import 'role_gate_screen.dart';
import 'support_screen.dart';
import 'visitor_account_settings_screen.dart';

/// Investor-flavored "Profile & Settings" screen — mirrors
/// [VisitorAccountScreen]'s structure/polish, minus the Customer-only rows
/// (Favorites, Order Requests, Role Upgrade) that don't apply here, plus an
/// "Investor" badge instead of "Visitor".
///
/// "Account & Settings" reuses [VisitorAccountSettingsScreen] as-is — it
/// talks to `/api/auth/me/settings`, which is self-scoped by Bearer token
/// and not role-gated, so it already works correctly for an Investor.
class InvestorAccountScreen extends StatelessWidget {
  const InvestorAccountScreen({super.key, required this.user});

  final AppUser user;

  void _logout(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleGateScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mySellRequests = context.watch<SellRequestController>().byOwner(user.id);

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileHeader(user: user),
              const SizedBox(height: 22),
              const _SectionLabel('Activity'),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.sell_outlined,
                label: 'My Sell Requests',
                subtitle: mySellRequests.isEmpty
                    ? 'Track every property you\'ve submitted to sell'
                    : '${mySellRequests.length} submitted so far',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MySellRequestsScreen(user: user),
                )),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Support'),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.support_agent_outlined,
                label: 'Contact Support',
                subtitle: 'FAQs, submit a ticket, or reach the team directly',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SupportScreen(user: user),
                )),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Account'),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.settings_outlined,
                label: 'Account & Settings',
                subtitle: 'Profile, password, notifications, language',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VisitorAccountSettingsScreen(user: user),
                )),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger, width: 1.4),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.border,
            child: Icon(Icons.person_rounded, color: AppColors.slate, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Text(
                    'Investor',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryYellow),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.slate, letterSpacing: 0.8),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.1), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: AppColors.primaryYellow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.slate, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
