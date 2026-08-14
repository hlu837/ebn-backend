import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/agent_account.dart';
import '../models/auth_response.dart';
import '../services/agent_service.dart';
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

/// The agent's own network program: their "AGT-" referral link, every
/// agent who signed up under it, and the override commissions that's
/// generated so far. Backed by `GET /api/agents/:agentId/network`.
///
/// Separate from [AgentReferralsScreen] (broker-to-broker client
/// referrals) and from the Affiliater program's referral link — this is
/// specifically "other agents working under me".
class AgentNetworkScreen extends StatefulWidget {
  const AgentNetworkScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AgentNetworkScreen> createState() => _AgentNetworkScreenState();
}

class _AgentNetworkScreenState extends State<AgentNetworkScreen> {
  final _service = AgentService();
  late Future<AgentNetworkData> _future = _load();

  Future<AgentNetworkData> _load() {
    return _service.getNetwork(widget.user.id, token: widget.user.token ?? '');
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  String _linkFor(String code) {
    final origin = Uri.base.origin.isNotEmpty ? Uri.base.origin : 'http://localhost:8080';
    return '$origin/signup/agent?ref=$code';
  }

  Future<void> _copyLink(String code) async {
    await Clipboard.setData(ClipboardData(text: _linkFor(code)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral link copied.')));
  }

  Future<void> _shareLink(String code) async {
    // No native share-sheet package in this project (matches the rest of
    // the agent workspace, which sticks to url_launcher's tel/sms
    // intents) — SMS with the link pre-filled is the closest equivalent.
    final uri = Uri(
      scheme: 'sms',
      queryParameters: {
        'body': "Join me as an agent on Onsite — sign up with my link and you'll be part of my network: ${_linkFor(code)}",
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
        title: const Text('My Network', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: FutureBuilder<AgentNetworkData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error is AgentServiceException ? (snapshot.error as AgentServiceException).message : 'Something went wrong.',
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
                  overridePercent: data.overridePercent,
                  onCopy: () => _copyLink(data.referralCode),
                  onShare: () => _shareLink(data.referralCode),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Earned from network',
                        value: 'ETB ${_formatMoney(data.overrideEarningsCleared)}',
                        icon: Icons.trending_up_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatCard(
                        label: 'Pending clearance',
                        value: 'ETB ${_formatMoney(data.overrideEarningsPending)}',
                        icon: Icons.hourglass_top_rounded,
                        color: AppColors.primaryYellow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Agents in your network (${data.downline.length})', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: AppSpacing.sm),
                if (data.downline.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
                    child: const Column(
                      children: [
                        Icon(Icons.groups_outlined, size: 36, color: AppColors.slate),
                        SizedBox(height: AppSpacing.sm),
                        Text(
                          "No agents have joined your network yet.\nShare your link — you'll earn a commission share every time they close a deal.",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4),
                        ),
                      ],
                    ),
                  )
                else
                  for (final entry in data.downline) ...[
                    _DownlineTile(entry: entry, overridePercent: data.overridePercent),
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
  const _ReferralCard({required this.code, required this.overridePercent, required this.onCopy, required this.onShare});
  final String code;
  final int overridePercent;
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
          const Text('YOUR AGENT NETWORK CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryYellow, letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(code, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(
            'Invite other agents to work under you. Whenever they earn a commission, you automatically earn $overridePercent% on top — no fee sharing, no extra work.',
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
  const _DownlineTile({required this.entry, required this.overridePercent});
  final AgentNetworkDownlineEntry entry;
  final int overridePercent;

  @override
  Widget build(BuildContext context) {
    final overrideEarned = entry.totalEarned * overridePercent / 100;
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
                Text(entry.fullName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Joined ${_formatDate(entry.joinedAt)}', style: const TextStyle(fontSize: 11.5, color: AppColors.slate)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('ETB ${_formatMoney(overrideEarned)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success)),
              const SizedBox(height: 2),
              Text('your $overridePercent% share', style: const TextStyle(fontSize: 10.5, color: AppColors.slate)),
            ],
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
