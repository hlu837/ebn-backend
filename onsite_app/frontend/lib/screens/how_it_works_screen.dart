import 'package:flutter/material.dart';
import '../data/landing_content.dart';
import '../theme/landing_colors.dart';
import '../widgets/landing_shared.dart';
import '../widgets/marketing_page_shell.dart';

/// The customer-facing request flow, plus the field agent's own inspection
/// flow. Reached from the landing page nav ("How it works") or from search.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = LandingBreakpoints.isDesktop(context);
    return MarketingPageShell(
      title: 'How It Works',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SectionHeading(eyebrow: 'Workflow', title: 'From request to verified report'),
          const SizedBox(height: 40),
          ResponsiveGrid(
            itemCount: kSteps.length,
            gap: 20,
            breakpoints: const {0: 1, 640: 3},
            itemBuilder: (i) => _StepTile(index: i, step: kSteps[i]),
          ),
          const SizedBox(height: 56),
          const SectionHeading(eyebrow: 'For field agents', title: 'Live status & the inspection report'),
          const SizedBox(height: 40),
          wide
              ? const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _LiveStatusCard()),
                  SizedBox(width: 24),
                  Expanded(child: _FieldInspectionCard()),
                ])
              : const Column(children: [_LiveStatusCard(), SizedBox(height: 24), _FieldInspectionCard()]),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final StepItem step;
  const _StepTile({required this.index, required this.step});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: LandingColors.card,
                border: Border.all(color: LandingColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(step.icon, size: 28, color: LandingColors.primary),
            ),
            Positioned(
              top: -8,
              left: -8,
              child: Container(
                height: 24,
                width: 24,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: LandingColors.gold, shape: BoxShape.circle),
                child: Text('${index + 1}',
                    style: const TextStyle(color: LandingColors.goldFg, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(step.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: LandingColors.foreground)),
        const SizedBox(height: 6),
        Text(step.desc,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: LandingColors.muted, height: 1.5)),
      ],
    );
  }
}

class _LiveStatusCard extends StatelessWidget {
  const _LiveStatusCard();
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
          const Text('LIVE STATUS',
              style: TextStyle(fontSize: 10, letterSpacing: 2.5, color: LandingColors.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('Online Status (Live)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          ResponsiveGrid(
            itemCount: kStatuses.length,
            gap: 12,
            breakpoints: const {0: 1, 480: 2},
            itemBuilder: (i) => _StatusTile(kStatuses[i]),
          ),
          const SizedBox(height: 16),
          const Text(
            'Proximity matching keeps inspections fast \u2014 the nearest active agent wins the assignment.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: LandingColors.muted),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final StatusItem s;
  const _StatusTile(this.s);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LandingColors.background,
        border: Border.all(color: LandingColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            height: 10,
            width: 10,
            decoration: BoxDecoration(color: s.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(s.desc, style: const TextStyle(fontSize: 12, color: LandingColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldInspectionCard extends StatelessWidget {
  const _FieldInspectionCard();
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
          const Text('REPORT FLOW',
              style: TextStyle(fontSize: 10, letterSpacing: 2.5, color: LandingColors.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('Field Inspection & Report', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          ResponsiveGrid(
            itemCount: kFieldSteps.length,
            gap: 16,
            breakpoints: const {0: 1, 480: 2},
            itemBuilder: (i) => _FieldStepTile(kFieldSteps[i]),
          ),
        ],
      ),
    );
  }
}

class _FieldStepTile extends StatelessWidget {
  final StepItem s;
  const _FieldStepTile(this.s);
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: LandingColors.background,
            border: Border.all(color: LandingColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(s.icon, size: 20, color: LandingColors.primary),
        ),
        const SizedBox(height: 12),
        Text(s.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(s.desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: LandingColors.muted, height: 1.5)),
      ],
    );
  }
}
