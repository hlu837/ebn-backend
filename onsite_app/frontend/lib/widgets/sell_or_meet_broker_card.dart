import 'package:flutter/material.dart';
import '../theme/landing_colors.dart';

/// The gold "Sell it here / Meet a broker" prompt card.
/// Shared between the category listing page and the Visitor dashboard so
/// both stay visually in sync — pass in whatever title/subtitle fits the
/// context it's shown in.
class SellOrMeetBrokerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSell;
  final VoidCallback onMeetBroker;

  const SellOrMeetBrokerCard({
    super.key,
    required this.title,
    this.subtitle = 'List it in minutes, or talk to a broker who can guide you through it.',
    required this.onSell,
    required this.onMeetBroker,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: LandingColors.card,
        border: Border.all(color: LandingColors.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: LandingColors.foreground),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: LandingColors.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onSell,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: LandingColors.gold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sell_outlined, size: 16, color: LandingColors.goldFg),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Sell it here',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LandingColors.goldFg),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onMeetBroker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: LandingColors.foreground, width: 1.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.groups_rounded, size: 16, color: LandingColors.foreground),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Meet a broker',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: LandingColors.foreground),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
