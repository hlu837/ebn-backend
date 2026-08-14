import 'package:flutter/material.dart';
import '../data/landing_content.dart';
import '../theme/landing_colors.dart';
import '../widgets/landing_shared.dart';
import '../widgets/marketing_page_shell.dart';
import 'role_select_screen.dart';

/// Key platform features + the "get started" CTA. Reached from the landing
/// page nav ("Platform") or from search.
class PlatformFeaturesScreen extends StatelessWidget {
  const PlatformFeaturesScreen({super.key});

  void _goToRoleSelect(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RoleSelectScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return MarketingPageShell(
      title: 'Platform',
      child: Column(
        children: [
          const SectionHeading(eyebrow: 'Platform', title: 'Key Platform Features'),
          const SizedBox(height: 40),
          ResponsiveGrid(
            itemCount: kFeatures.length,
            gap: 16,
            breakpoints: const {0: 2, 640: 4},
            itemBuilder: (i) => _FeatureTile(kFeatures[i]),
          ),
          const SizedBox(height: 48),
          _CtaCard(onGetStarted: () => _goToRoleSelect(context)),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final FeatureItem f;
  const _FeatureTile(this.f);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: LandingColors.card,
            border: Border.all(color: LandingColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(f.icon, size: 20, color: LandingColors.gold),
        ),
        const SizedBox(height: 10),
        Text(f.title,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: LandingColors.foreground, height: 1.3)),
      ],
    );
  }
}

class _CtaCard extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _CtaCard({required this.onGetStarted});
  @override
  Widget build(BuildContext context) {
    final wide = LandingBreakpoints.isDesktop(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ready to verify with confidence?',
            style: TextStyle(fontSize: wide ? 28 : 22, fontWeight: FontWeight.w600, color: LandingColors.foreground)),
        const SizedBox(height: 6),
        const Text('Join EBN and start requesting on-site verification in minutes.',
            style: TextStyle(fontSize: 14, color: LandingColors.muted)),
      ],
    );
    final btn = GoldButton(label: 'Get Started / Sign Up', trailing: Icons.arrow_forward, fontSize: 14, onTap: onGetStarted);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: LandingColors.card,
        border: Border.all(color: LandingColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: wide
          ? Row(children: [Expanded(child: text), const SizedBox(width: 24), btn])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 20), btn]),
    );
  }
}
