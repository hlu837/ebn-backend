import 'package:flutter/material.dart';
import '../theme/landing_colors.dart';
import '../widgets/marketing_page_shell.dart';
import '../data/faq_data.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MarketingPageShell(
      title: 'FAQ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Frequently asked questions',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: LandingColors.foreground)),
          const SizedBox(height: 12),
          const Text(
            'Can\u2019t find what you\u2019re looking for? Reach out on the Contact Us page.',
            style: TextStyle(fontSize: 15, color: LandingColors.muted, height: 1.6),
          ),
          const SizedBox(height: 32),
          for (final f in faqItems) _FaqTile(f),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final FaqItem item;
  const _FaqTile(this.item);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: LandingColors.card,
        border: Border.all(color: LandingColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          expandedAlignment: Alignment.topLeft,
          iconColor: LandingColors.gold,
          collapsedIconColor: LandingColors.muted,
          title: Text(item.question,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: LandingColors.foreground)),
          children: [
            Text(item.answer, style: const TextStyle(fontSize: 14, color: LandingColors.muted, height: 1.6)),
          ],
        ),
      ),
    );
  }
}
