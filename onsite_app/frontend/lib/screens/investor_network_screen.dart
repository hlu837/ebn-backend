import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_response.dart';
import '../models/investor_network.dart';
import '../services/investor_wallet_service.dart';
import '../theme/app_theme.dart';

String _formatMoney(double value) {
  final s = value.abs().toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final posFromEnd = s.length - i;
    buffer.write(s[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(',');
  }
  return '${value < 0 ? '-' : ''}${buffer.toString()}';
}

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// The investor's own referral program: their "INV-" referral link, every
/// investor who signed up under it, and the one-time rewards that's
/// generated so far. Backed by `GET /api/investors/:investorId/network`.
///
/// Separate from the agent-to-agent network and the Affiliater program's
/// referral link — this is specifically "other investors I referred".
/// Unlike the agent network, there's no ongoing commission to override:
/// a sponsor is credited a one-time reward the moment a downline
/// investor's *first* commitment is confirmed by an admin.
class InvestorNetworkScreen extends StatefulWidget {
  const InvestorNetworkScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<InvestorNetworkScreen> createState() => _InvestorNetworkScreenState();
}

class _InvestorNetworkScreenState extends State<InvestorNetworkScreen> {
  final _service = InvestorWalletService();
  late Future<InvestorNetworkData> _future = _load();

  Future<InvestorNetworkData> _load() {
    return _service.getNetwork(investorId: widget.user.id, token: widget.user.token ?? '');
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  String _linkFor(String code) {
    final origin = Uri.base.origin.isNotEmpty ? Uri.base.origin : 'http://localhost:8080';
    return '$origin/signup/investor?ref=$code';
  }

  Future<void> _copyLink(String code) async {
    await Clipboard.setData(ClipboardData(text: _linkFor(code)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral link copied.')));
  }

  Future<void> _shareLink(String code) async {
    // No native share-sheet package in this project (matches the rest of
    // the app, which sticks to url_launcher's tel/sms intents) — SMS with
    // the link pre-filled is the closest equivalent.
    final uri = Uri(
      scheme: 'sms',
      queryParameters: {
        'body': "Join me as an investor on Onsite — sign up with my link: ${_linkFor(code)}",
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await _copyLink(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Referral Program', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: FutureBuilder<InvestorNetworkData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error is InvestorWalletException
                  ? (snapshot.error as InvestorWalletException).message
                  : 'Something went wrong.',
              onRetry: _refresh,
            );
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _ReferralCard(
                  code: data.referralCode,
                  rewardPercent: data.rewardPercent,
                  onCopy: () => _copyLink(data.referralCode),
                  onShare: () => _shareLink(data.referralCode),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Earned from referrals',
                        value: 'ETB ${_formatMoney(data.rewardEarningsCleared)}',
                        icon: Icons.trending_up_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        label: 'Pending clearance',
                        value: 'ETB ${_formatMoney(data.rewardEarningsPending)}',
                        icon: Icons.hourglass_top_rounded,
                        color: AppColors.primaryYellow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Investors you referred (${data.downline.length})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: AppSpacing.sm),
                if (data.downline.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        const Icon(Icons.groups_outlined, size: 36, color: AppColors.slate),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          "No investors have joined through your link yet.\nShare it — you'll earn ${data.rewardPercent}% of their first confirmed investment.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4),
                        ),
                      ],
                    ),
                  )
                else
                  for (final entry in data.downline) ...[
                    _DownlineTile(entry: entry),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.code, required this.rewardPercent, required this.onCopy, required this.onShare});
  final String code;
  final int rewardPercent;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR REFERRAL CODE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryYellow, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(code, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(
            'Invite other investors to join Onsite. The moment their first commitment is confirmed, you automatically earn $rewardPercent% of it as a one-time reward.',
            style: const TextStyle(fontSize: 12, color: Colors.white60, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy link'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryYellow, foregroundColor: Colors.white),
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded, size: 16),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DownlineTile extends StatelessWidget {
  const _DownlineTile({required this.entry});
  final InvestorNetworkDownlineEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.border,
            child: Text(
              entry.fullName.isNotEmpty ? entry.fullName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.fullName,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Joined ${_formatDate(entry.joinedAt)}', style: const TextStyle(fontSize: 11.5, color: AppColors.slate)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: entry.rewardCredited ? AppColors.success.withOpacity(0.12) : AppColors.border.withOpacity(0.5),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              entry.rewardCredited ? 'Reward earned' : 'Awaiting first investment',
              style: TextStyle(
                color: entry.rewardCredited ? AppColors.success : AppColors.slate,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.slate)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
