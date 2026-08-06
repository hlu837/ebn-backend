import 'package:flutter/material.dart';
import '../theme/landing_colors.dart';
import '../widgets/marketing_page_shell.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MarketingPageShell(
      title: 'About Us',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About EBN',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: LandingColors.foreground)),
          const SizedBox(height: 16),
          const Text(
            'EBN is a real-time, crowd-sourced verification network. Instead of trusting listing '
            'photos and paperwork, customers get a real person to physically visit a property, '
            'vehicle, or piece of machinery, and report back with photos, video, and an honest '
            'on-the-ground assessment.',
            style: TextStyle(fontSize: 15, color: LandingColors.muted, height: 1.6),
          ),
          const SizedBox(height: 16),
          const Text(
            'We started in Addis Ababa with a simple goal: make it possible to trust an asset '
            'before you commit to it, without having to go see it yourself.',
            style: TextStyle(fontSize: 15, color: LandingColors.muted, height: 1.6),
          ),
          const SizedBox(height: 40),
          const Text('How we work',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: LandingColors.foreground)),
          const SizedBox(height: 16),
          _Bullet('A tiered network of verified field agents (Diamond, Gold, Silver, Bronze) '
              'covering property, vehicles, machinery, and real estate.'),
          _Bullet('Every request is dispatched in real time and matched to the nearest available, '
              'qualified agent.'),
          _Bullet('Every report includes on-site photos and video, so you see exactly what our '
              'agent saw.'),
          const SizedBox(height: 40),
          const Text('Where we operate',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: LandingColors.foreground)),
          const SizedBox(height: 12),
          const Text(
            'EBN is live in Addis Ababa today, with more cities planned as our agent network '
            'grows.',
            style: TextStyle(fontSize: 15, color: LandingColors.muted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: LandingColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, color: LandingColors.muted, height: 1.5)),
          ),
        ],
      ),
    );
  }
}
