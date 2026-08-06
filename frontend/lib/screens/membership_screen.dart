import 'package:flutter/material.dart';
import '../data/landing_content.dart';
import '../theme/landing_colors.dart';
import '../widgets/landing_shared.dart';
import '../widgets/marketing_page_shell.dart';

/// Membership tiers (Diamond/Gold/Silver/Bronze) and how orders are
/// distributed across them. Reached from the landing page nav ("Membership")
/// or from search.
class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final twoCol = LandingBreakpoints.isDesktop(context);
    return MarketingPageShell(
      title: 'Membership',
      child: Column(
        children: [
          const SectionHeading(eyebrow: 'Membership', title: 'Levels, priority & order distribution'),
          const SizedBox(height: 40),
          twoCol
              ? const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _TierTable()),
                    SizedBox(width: 24),
                    Expanded(child: _OrderDistribution()),
                  ],
                )
              : const Column(children: [_TierTable(), SizedBox(height: 24), _OrderDistribution()]),
        ],
      ),
    );
  }
}

class _TierTable extends StatelessWidget {
  const _TierTable();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LandingColors.card,
        border: Border.all(color: LandingColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('MEMBERSHIP',
              style: TextStyle(fontSize: 10, letterSpacing: 2.5, color: LandingColors.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('Levels & Priority', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: LandingColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (int i = 0; i < kTiers.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: LandingColors.border),
                  _TierRow(t: kTiers[i], top: i == 0),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final TierItem t;
  final bool top;
  const _TierRow({required this.t, required this.top});
  @override
  Widget build(BuildContext context) {
    final bg = top ? LandingColors.primary : LandingColors.gold;
    final fg = top ? LandingColors.primaryFg : LandingColors.goldFg;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(t.icon, size: 20, color: LandingColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                child: Text(t.priority.toUpperCase(),
                    style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: fg)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final b in t.benefits) Text('\u2022 $b', style: const TextStyle(fontSize: 12, color: LandingColors.muted, height: 1.6))],
          ),
        ],
      ),
    );
  }
}

class _OrderDistribution extends StatelessWidget {
  const _OrderDistribution();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LandingColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('ALERT SYSTEM',
              style: TextStyle(fontSize: 10, letterSpacing: 2.5, color: LandingColors.gold, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('Order Distribution', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: LandingColors.primaryFg)),
          const SizedBox(height: 24),
          for (final r in kRingTiers) ...[
            _RingRow(r: r),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
          Text(
            'Routed by level, location, online status & performance.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}

class _RingRow extends StatelessWidget {
  final RingTier r;
  const _RingRow({required this.r});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LandingColors.gold)),
                    const SizedBox(height: 2),
                    Text(r.window, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                  ],
                ),
              ),
              Icon(Icons.notifications_active, size: 16, color: Colors.white.withOpacity(0.6)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: r.pct,
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(LandingColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}
