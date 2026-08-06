import 'package:flutter/material.dart';

import '../models/agent_account.dart';
import '../models/auth_response.dart';
import '../services/agent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/agent_drawer.dart' show AgentTier, AgentTierX;

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

AgentTier _tierFromString(String tier) => AgentTier.values.firstWhere((t) => t.name == tier, orElse: () => AgentTier.bronze);

/// The agent's current membership tier, the perks each tier unlocks, an
/// upgrade flow, and a billing history — backed by
/// `GET/POST /api/agents/:id/membership*`.
class AgentMembershipScreen extends StatefulWidget {
  const AgentMembershipScreen({super.key, required this.user, this.initialTier = AgentTier.gold});

  final AppUser user;
  final AgentTier initialTier;

  @override
  State<AgentMembershipScreen> createState() => _AgentMembershipScreenState();
}

class _AgentMembershipScreenState extends State<AgentMembershipScreen> {
  final _service = AgentService();
  late Future<AgentMembershipData> _future = _load();

  Future<AgentMembershipData> _load() => _service.getMembership(widget.user.id, token: widget.user.token ?? '');

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  void _openTierSheet(AgentMembershipData membership) {
    final currentTier = _tierFromString(membership.tier);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cloud,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _TierPickerSheet(
        currentTier: currentTier,
        onSelect: (tier) async {
          Navigator.of(context).pop();
          if (tier == currentTier) return;
          final upgrading = tier.index > currentTier.index;
          try {
            final updated = await _service.upgradeMembership(widget.user.id, tier: tier.name, token: widget.user.token ?? '');
            if (!mounted) return;
            await _refresh();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(upgrading ? 'Upgraded to ${tier.label}. Charged ETB ${_formatMoney(updated.monthlyFeeEtb)} today.' : 'Switched to ${tier.label}.')),
            );
          } on AgentServiceException catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Membership', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: FutureBuilder<AgentMembershipData>(
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
          final membership = snapshot.data!;
          final tier = _tierFromString(membership.tier);
          final perks = membership.perks;
          final fee = membership.monthlyFeeEtb;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.lg)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(tier.icon, color: tier.color, size: 22),
                          const SizedBox(width: 8),
                          Text(tier.label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: tier.color)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        fee == 0 ? 'Free plan' : 'ETB ${_formatMoney(fee)} / month',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        membership.renewalDate != null ? 'Renews ${_formatDate(membership.renewalDate!)}' : 'No active renewal',
                        style: const TextStyle(fontSize: 12.5, color: Colors.white60, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (tier != AgentTier.diamond) _TierProgressBar(tier: tier),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryYellow, foregroundColor: Colors.white),
                          onPressed: () => _openTierSheet(membership),
                          icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                          label: Text(tier == AgentTier.diamond ? 'Manage plan' : 'Upgrade plan'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('Perks on your plan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: [
                      for (int i = 0; i < perks.length; i++) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, size: 18, color: tier.color),
                            const SizedBox(width: 10),
                            Expanded(child: Text(perks[i], style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.3))),
                          ],
                        ),
                        if (i != perks.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('Billing history', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: AppSpacing.sm),
                if (membership.billingHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(child: Text('No billing history yet.', style: TextStyle(fontSize: 13, color: AppColors.slate))),
                  ),
                for (final b in membership.billingHistory) ...[
                  _BillingTile(entry: b),
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

class _TierProgressBar extends StatelessWidget {
  const _TierProgressBar({required this.tier});
  final AgentTier tier;

  @override
  Widget build(BuildContext context) {
    final tiers = AgentTier.values;
    final idx = tiers.indexOf(tier);
    final next = tiers[idx + 1];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Next tier: ${next.label}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: LinearProgressIndicator(
            value: (idx + 1) / tiers.length,
            minHeight: 6,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(tier.color),
          ),
        ),
      ],
    );
  }
}

class _BillingTile extends StatelessWidget {
  const _BillingTile({required this.entry});
  final AgentBillingEntry entry;

  @override
  Widget build(BuildContext context) {
    final upcoming = entry.status == 'upcoming';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: (upcoming ? AppColors.primaryYellow : AppColors.success).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(upcoming ? Icons.schedule_rounded : Icons.check_rounded, size: 17, color: upcoming ? AppColors.primaryYellow : AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_formatDate(entry.billedOn), style: const TextStyle(fontSize: 11.5, color: AppColors.slate)),
              ],
            ),
          ),
          Text(
            entry.amount == 0 ? 'Free' : 'ETB ${_formatMoney(entry.amount)}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _TierPickerSheet extends StatelessWidget {
  const _TierPickerSheet({required this.currentTier, required this.onSelect});
  final AgentTier currentTier;
  final ValueChanged<AgentTier> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const Text('Choose a plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: AppSpacing.md),
          for (final tier in AgentTier.values) ...[
            _TierOptionRow(tier: tier, selected: tier == currentTier, onTap: () => onSelect(tier)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

const Map<AgentTier, double> _kTierMonthlyFeeEtb = {
  AgentTier.bronze: 0,
  AgentTier.silver: 800,
  AgentTier.gold: 2200,
  AgentTier.diamond: 5000,
};

class _TierOptionRow extends StatelessWidget {
  const _TierOptionRow({required this.tier, required this.selected, required this.onTap});
  final AgentTier tier;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fee = _kTierMonthlyFeeEtb[tier] ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: selected ? tier.color : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(tier.icon, color: tier.color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tier.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    Text(fee == 0 ? 'Free' : 'ETB ${_formatMoney(fee)} / month', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: tier.color, size: 20) else const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}
