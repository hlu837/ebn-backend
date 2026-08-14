import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_response.dart';
import '../providers/favorites_controller.dart';
import '../theme/app_theme.dart';
import 'favorites_screen.dart';
import 'my_order_requests_screen.dart';
import 'my_sell_requests_screen.dart';
import 'my_tour_requests_screen.dart';
import 'placeholder_page.dart';
import 'role_gate_screen.dart';
import 'role_upgrade_screen.dart';
import 'support_screen.dart';
import 'visitor_account_settings_screen.dart';

const _kAccentRed = Color(0xFFFF2686);

/// The "Me" tab for a Visitor: profile header + quick links, including
/// "My Sell Requests" as a first-class row (not the whole tab anymore).
class VisitorAccountScreen extends StatelessWidget {
  const VisitorAccountScreen({super.key, required this.user});

  final AppUser user;

  void _logout(BuildContext context) {
    context.read<FavoritesController>().clearUser();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleGateScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                subtitle: 'Track every property you\'ve submitted to sell',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MySellRequestsScreen(user: user),
                )),
              ),
              _MenuTile(
                icon: Icons.playlist_add_check_circle_outlined,
                label: 'My Order Requests',
                subtitle: 'Track everything you\'ve asked us to find',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MyOrderRequestsScreen(user: user),
                )),
              ),
              _MenuTile(
                icon: Icons.favorite_border_rounded,
                label: 'Saved Listings / Favorites',
                subtitle: 'Everything you\'ve favorited from the feed',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FavoritesScreen(user: user),
                )),
              ),
              _MenuTile(
                icon: Icons.tour_outlined,
                label: 'My Tour Requests',
                subtitle: 'Every visit you\'ve booked and its status',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MyTourRequestsScreen(user: user),
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
              const _SectionLabel('Grow With EBN'),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.upgrade_rounded,
                label: 'Upgrade Your Role',
                subtitle: 'Become an Affiliater, Agent / Broker, or Investor',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RoleUpgradeScreen(user: user),
                )),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('Account'),
              const SizedBox(height: 8),
              _MenuTile(
                icon: Icons.settings_outlined,
                label: 'Account & Settings',
                subtitle: 'Profile, password, notifications',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VisitorAccountSettingsScreen(user: user),
                )),
              ),
              _MenuTile(
                icon: Icons.help_outline_rounded,
                label: 'About Us / FAQ',
                subtitle: 'Who we are & how verification works',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const PlaceholderPage(
                    title: 'About Us / FAQ',
                    icon: Icons.help_outline_rounded,
                    description: 'Who EBN is, how verification works, and answers to common questions.',
                  ),
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
                    color: _kAccentRed.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Text(
                    'Visitor',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kAccentRed),
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
                decoration: BoxDecoration(color: _kAccentRed.withOpacity(0.1), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: _kAccentRed),
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
