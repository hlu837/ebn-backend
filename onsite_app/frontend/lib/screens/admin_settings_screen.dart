import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'admin_accounts_screen.dart';
import 'admin_app_content_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_cities_screen.dart';
import 'admin_general_settings_screen.dart';
import 'admin_membership_pricing_screen.dart';

/// Sectioned settings list. Each row pushes to its real, backend-backed
/// sub-screen — see /api/admin-settings/* on the backend.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen(
      {super.key, required this.token, required this.currentAdminId});

  final String token;
  final String currentAdminId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _SettingsSection(
              title: 'Marketplace',
              items: [
                _SettingsItem(
                  icon: Icons.category_outlined,
                  label: 'Categories & Pricing',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminCategoriesScreen(token: token),
                  )),
                ),
                _SettingsItem(
                  icon: Icons.location_city_outlined,
                  label: 'Cities',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminCitiesScreen(token: token),
                  )),
                ),
                _SettingsItem(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Membership Pricing',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminMembershipPricingScreen(token: token),
                  )),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsSection(
              title: 'Content',
              items: [
                _SettingsItem(
                  icon: Icons.article_outlined,
                  label: 'App Content (FAQ, About Us, Features)',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminAppContentScreen(token: token),
                  )),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsSection(
              title: 'Account',
              items: [
                _SettingsItem(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Admin Accounts',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminAccountsScreen(
                        token: token, currentAdminId: currentAdminId),
                  )),
                ),
                _SettingsItem(
                  icon: Icons.tune_rounded,
                  label: 'General',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AdminGeneralSettingsScreen(token: token),
                  )),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.items});

  final String title;
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate,
                  letterSpacing: 0.4)),
        ),
        Container(
          decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.border)),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                items[i],
                if (i != items.length - 1)
                  const Divider(
                      height: 1,
                      color: AppColors.border,
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.ink),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink))),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}
