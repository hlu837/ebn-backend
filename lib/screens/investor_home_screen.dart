import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_response.dart';
import '../models/investment_commitment.dart';
import '../models/investor_wallet.dart';
import '../providers/sell_request_controller.dart';
import '../services/investment_commitment_service.dart';
import '../services/investor_wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/investor_bottom_nav.dart';
import 'investor_account_screen.dart';
import 'investor_announcements_screen.dart';
import 'investor_investment_opportunities_screen.dart';
import 'investor_menu_screen.dart';
import 'investor_my_investments_screen.dart';
import 'investor_network_screen.dart';
import 'investor_reinvest_screen.dart';
import 'investor_wallet_screen.dart';
import 'my_sell_requests_screen.dart';
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
/// InvestorMyInvestmentsScreen). Reinvest is also real now — see
/// InvestorReinvestScreen — rolling wallet balance into a new commitment
/// via POST /api/investors/:id/wallet/reinvest. Investors are Visitors too: they can submit a
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
            onReinvest: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => InvestorReinvestScreen(user: widget.user)),
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
/// and a live portfolio snapshot pulled from the real wallet and
/// investment-commitment backends.
class _InvestorDashboardTab extends StatefulWidget {
  const _InvestorDashboardTab({required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  State<_InvestorDashboardTab> createState() => _InvestorDashboardTabState();
}

class _InvestorDashboardTabState extends State<_InvestorDashboardTab> {
  final InvestorWalletService _walletService = InvestorWalletService();
  final InvestmentCommitmentService _commitmentService = InvestmentCommitmentService();

  bool _loading = true;
  String? _error;
  InvestorWalletSummary? _wallet;
  List<InvestmentCommitment> _commitments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.user.token ?? '';
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _walletService.getWallet(token: token, investorId: widget.user.id),
        _commitmentService.listMine(token: token),
      ]);
      if (!mounted) return;
      setState(() {
        _wallet = results[0] as InvestorWalletSummary;
        _commitments = results[1] as List<InvestmentCommitment>;
        _loading = false;
      });
    } on InvestorWalletException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } on InvestmentCommitmentException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final user = widget.user;
    final onLogout = widget.onLogout;
    final mySellRequests = context.watch<SellRequestController>().byOwner(user.id);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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

              // ── Portfolio snapshot — real data from the wallet and
              // investment-commitment backends ──────────────────────────────
              _PortfolioSnapshotCard(
                loading: _loading,
                error: _error,
                wallet: _wallet,
                commitments: _commitments,
                onRetry: _load,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live portfolio numbers pulled from `/api/investors/:id/wallet` and
/// `/api/investment-commitments/me` — replaces the old static
/// "Portfolio tools — COMING SOON" card.
class _PortfolioSnapshotCard extends StatelessWidget {
  const _PortfolioSnapshotCard({
    required this.loading,
    required this.error,
    required this.wallet,
    required this.commitments,
    required this.onRetry,
  });

  final bool loading;
  final String? error;
  final InvestorWalletSummary? wallet;
  final List<InvestmentCommitment> commitments;
  final VoidCallback onRetry;

  static String _fmtAmount(double value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text('Portfolio snapshot', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: AppSpacing.md),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.slate),
                    const SizedBox(width: 8),
                    Expanded(child: Text(error!, style: const TextStyle(fontSize: 12.5, color: AppColors.slate))),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            )
          else
            Builder(builder: (context) {
              final confirmed = commitments.where((c) => c.status == 'Confirmed').toList();
              final pending = commitments.where((c) => c.status == 'Pending').toList();
              final totalInvested = confirmed.fold<double>(0, (sum, c) => sum + c.amount);
              final balance = wallet?.balance ?? 0;
              final pendingClearance = wallet?.pendingClearance ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SnapshotStat(
                          label: 'Wallet balance',
                          value: '${_fmtAmount(balance)} ETB',
                        ),
                      ),
                      Expanded(
                        child: _SnapshotStat(
                          label: 'Total invested',
                          value: '${_fmtAmount(totalInvested)} ETB',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _SnapshotStat(
                          label: 'Active investments',
                          value: '${confirmed.length}',
                        ),
                      ),
                      Expanded(
                        child: _SnapshotStat(
                          label: 'Pending review',
                          value: '${pending.length}',
                        ),
                      ),
                    ],
                  ),
                  if (pendingClearance > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.cloud,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Text(
                        '${_fmtAmount(pendingClearance)} ETB pending clearance',
                        style: const TextStyle(fontSize: 12, color: AppColors.slate),
                      ),
                    ),
                  ],
                  if (commitments.isEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'You haven\'t committed to any opportunities yet — check Opportunities to get started.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4),
                    ),
                  ],
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _SnapshotStat extends StatelessWidget {
  const _SnapshotStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.slate, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
      ],
    );
  }
}
