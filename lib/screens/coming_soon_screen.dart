import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../theme/app_theme.dart';
import '../widgets/affiliater_drawer.dart';
import '../widgets/app_buttons.dart';
import '../widgets/investor_drawer.dart';
import 'placeholder_page.dart';
import 'role_gate_screen.dart';

/// Shown for paths that are pitched on the landing page but don't have a
/// full dashboard built yet (Affiliater, Investor). Captures interest with
/// a simple waitlist form so the pitch still feels complete end-to-end.
class ComingSoonScreen extends StatefulWidget {
  const ComingSoonScreen({super.key, required this.role, required this.highlights, required this.userName});

  final UserRole role;
  final List<String> highlights;
  final String userName;

  @override
  State<ComingSoonScreen> createState() => _ComingSoonScreenState();
}

class _ComingSoonScreenState extends State<ComingSoonScreen> {
  final _emailCtrl = TextEditingController();
  bool _joined = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleGateScreen()),
      (route) => false,
    );
  }

  Widget? _buildDrawer() {
    if (widget.role == UserRole.affiliater) {
      return AffiliaterDrawer(
        affiliaterName: widget.userName,
        tokenBalance: 0,
        actions: AffiliaterDrawerActions(
          onDashboard: () {}, // already here — closing the drawer is enough
          onProperties: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Properties',
              icon: Icons.holiday_village_outlined,
              description: 'Browse the listing catalogue you can share and earn on.',
            ),
          )),
          onMyReferrals: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'My Referrals',
              icon: Icons.groups_2_outlined,
              description: 'Everyone you\'ve referred and where they are in the funnel.',
            ),
          )),
          onEarnings: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Earnings',
              icon: Icons.payments_outlined,
              description: 'Commission balance, payout history, and pending earnings.',
            ),
          )),
          onReports: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Reports',
              icon: Icons.bar_chart_rounded,
              description: 'Performance breakdowns across clicks, referrals, and conversions.',
            ),
          )),
          onCampaigns: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Campaigns',
              icon: Icons.campaign_outlined,
              description: 'Active and past promotions you can join to boost earnings.',
            ),
          )),
          onMembership: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Membership',
              icon: Icons.workspace_premium_outlined,
              description: 'Your plan, perks, and billing history.',
            ),
          )),
          onNotifications: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Notifications',
              icon: Icons.notifications_outlined,
              description: 'Updates on your referrals, earnings, and campaign activity.',
            ),
          )),
          onAccountSettings: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Account Settings',
              icon: Icons.settings_outlined,
              description: 'Manage your profile, payout details, and preferences.',
            ),
          )),
          onSupport: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Support',
              icon: Icons.support_agent_outlined,
              description: 'Get help from the EBN team or browse FAQs.',
            ),
          )),
          onLogout: _logout,
        ),
      );
    }
    if (widget.role == UserRole.investor) {
      return InvestorDrawer(
        investorName: widget.userName,
        actions: InvestorDrawerActions(
          onDashboard: () {}, // already here — closing the drawer is enough
          onMyInvestments: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'My Investments',
              icon: Icons.pie_chart_outline_rounded,
              description: 'A snapshot of every deal you\'ve put capital into.',
            ),
          )),
          onInvestmentOpportunities: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Investment Opportunities',
              icon: Icons.explore_outlined,
              description: 'Exclusive, high-yield, or fractional investment opportunities.',
            ),
          )),
          onReinvest: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Reinvest',
              icon: Icons.autorenew_rounded,
              description: 'Roll your profits and payouts into new opportunities.',
            ),
          )),
          onWallet: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Wallet',
              icon: Icons.account_balance_wallet_outlined,
              description: 'Your balance, deposits, withdrawal methods, and profit payout history.',
            ),
          )),
          onReferralProgram: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Referral Program',
              icon: Icons.groups_2_outlined,
              description: 'Invite other investors and earn rewards for referrals.',
            ),
          )),
          onNewsAnnouncements: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'News & Announcements',
              icon: Icons.campaign_outlined,
              description: 'The latest updates from the EBN team.',
            ),
          )),
          onSupport: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Support',
              icon: Icons.support_agent_outlined,
              description: 'Get help from the EBN team or browse FAQs.',
            ),
          )),
          onProfileSettings: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PlaceholderPage(
              title: 'Profile & Settings',
              icon: Icons.settings_outlined,
              description: 'Manage your profile, payout details, and preferences.',
            ),
          )),
          onLogout: _logout,
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.cloud,
      drawer: _buildDrawer(),
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppColors.primaryYellow, shape: BoxShape.circle),
                child: Icon(widget.role.pitchIcon, color: AppColors.ink, size: 30),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.pill)),
                child: const Text('COMING SOON', style: TextStyle(color: AppColors.primaryYellow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('${widget.role.label} portal', style: textTheme.displayLarge?.copyWith(fontSize: 28)),
              const SizedBox(height: 6),
              Text(widget.role.pitchLine, style: textTheme.bodyLarge?.copyWith(color: AppColors.slate)),

              const SizedBox(height: AppSpacing.xl),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("What you'll get", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: AppSpacing.md),
                    for (final h in widget.highlights) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                          const SizedBox(width: 10),
                          Expanded(child: Text(h, style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.4))),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              if (_joined)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadii.lg)),
                  child: const Row(
                    children: [
                      Icon(Icons.celebration_rounded, color: AppColors.success),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text("You're on the list — we'll email you the moment this opens.", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ),
                    ],
                  ),
                )
              else ...[
                Text('Get early access', style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', hintText: 'you@example.com'),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(label: 'Notify Me', onPressed: () => setState(() => _joined = true)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
