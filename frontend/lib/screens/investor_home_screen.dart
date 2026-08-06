import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_response.dart';
import '../providers/sell_request_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/investor_bottom_nav.dart';
import 'investor_account_screen.dart';
import 'investor_announcements_screen.dart';
import 'investor_investment_opportunities_screen.dart';
import 'investor_menu_screen.dart';
import 'investor_my_investments_screen.dart';
import 'investor_network_screen.dart';
import 'investor_wallet_screen.dart';
import 'my_sell_requests_screen.dart';
import 'placeholder_page.dart';
import 'role_gate_screen.dart';
import 'sell_property_form_screen.dart';
import 'support_screen.dart';

/// The Investor side — now organized as a bottom-nav shell (Home /
/// Opportunities / Portfolio / Menu, plus a raised "+" for the primary
/// quick action) instead of a side drawer, matching the Agent side's
/// navigation. Home is the dashboard; everything the drawer used to hold
/// (Reinvest, Wallet, Referral Program, News & Announcements, Support,
/// Profile & Settings) now lives one tap away under Menu. Investment
/// Opportunities and My Investments are real tabs, wired to the real
/// backend (see InvestorInvestmentOpportunitiesScreen and
/// InvestorMyInvestmentsScreen). Reinvest is still a placeholder with no
/// backend behind it yet. Investors are Visitors too: they can submit a
/// property to sell exactly like the Customer side does, backed by the
/// same real `/api/sell-requests/*` pipeline, and track their own
/// submissions here.
class InvestorHomeScreen extends StatefulWidget {
  const InvestorHomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<InvestorHomeScreen> createState() => _InvestorHomeScreenState();
}

class _InvestorHomeScreenState extends State<InvestorHomeScreen> {
  /// 0 = Home, 1 = Opportunities, 2 = Portfolio, 3 = Menu.
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SellRequestController>().fetchByOwner(widget.user.id);
    });
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleGateScreen()),
      (route) => false,
    );
  }

  void _openPlaceholder(String title, IconData icon, String description) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaceholderPage(title: title, icon: icon, description: description),
    ));
  }

  /// Raised "+" quick action — same destination as the Home tab's
  /// "Sell it here" card, just one tap away from anywhere in the shell.
  void _openSellProperty(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SellPropertyFormScreen(user: widget.user),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _InvestorDashboardTab(user: widget.user, onLogout: _logout),
          InvestorInvestmentOpportunitiesScreen(user: widget.user, showBackButton: false),
          InvestorMyInvestmentsScreen(user: widget.user, showBackButton: false),
          InvestorMenuScreen(
            user: widget.user,
            onReinvest: () => _openPlaceholder(
              'Reinvest',
              Icons.autorenew_rounded,
              'Roll your profits and payouts into new opportunities.',
            ),
            onWallet: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => InvestorWalletScreen(user: widget.user)),
            ),
            onReferralProgram: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => InvestorNetworkScreen(user: widget.user)),
            ),
            onNewsAnnouncements: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InvestorAnnouncementsScreen()),
            ),
            onSupport: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SupportScreen(user: widget.user)),
            ),
            onProfileSettings: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => InvestorAccountScreen(user: widget.user)),
            ),
            onLogout: _logout,
          ),
        ],
      ),
      bottomNavigationBar: InvestorBottomNav(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        onAddTap: () => _openSellProperty(context),
      ),
    );
  }
}

/// The Investor workspace "Home" tab — same content the old drawer-based
/// screen showed at its root: a header, the "Sell a property" entry point,
/// and a preview of portfolio tools still being built out.
class _InvestorDashboardTab extends StatelessWidget {
  const _InvestorDashboardTab({required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final mySellRequests = context.watch<SellRequestController>().byOwner(user.id);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Welcome back', style: textTheme.displayLarge?.copyWith(fontSize: 24)),
                ),
                IconButton(tooltip: 'Log out', onPressed: onLogout, icon: const Icon(Icons.logout_rounded, color: AppColors.ink)),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Manage what you own and put new opportunities in front of the right buyers.',
              style: TextStyle(fontSize: 13, color: AppColors.slate, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Working entry point: Sell a property ────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sell_rounded, color: AppColors.primaryYellow, size: 28),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Sell a property',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 6),
                  const Text(
                    'Submit any asset in your portfolio for our team to screen, have a broker inspect it, and list it on the marketplace.',
                    style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryYellow,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SellPropertyFormScreen(user: user)),
                        ),
                        child: const Text('Sell it here', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => MySellRequestsScreen(user: user)),
                        ),
                        child: Text(
                          mySellRequests.isEmpty ? 'My sell requests' : 'My sell requests (${mySellRequests.length})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Portfolio / investment tools — not backed by a real API yet ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Portfolio tools', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.pill)),
                        child: const Text('COMING SOON',
                            style: TextStyle(color: AppColors.primaryYellow, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final h in const [
                    'A single dashboard for every asset in your portfolio',
                    'Curated, high-yield opportunities before they go public',
                    'Live valuation and performance tracking',
                    'Direct line to the agent handling each of your assets',
                  ]) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                        const SizedBox(width: 10),
                        Expanded(child: Text(h, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4))),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
