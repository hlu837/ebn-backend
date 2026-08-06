import 'package:flutter/material.dart';
import '../theme/landing_colors.dart';

/// Common chrome for standalone marketing pages that live outside the main
/// landing-page scroll (About Us, Contact Us, FAQ, ...). Gives every one of
/// these pages the same cream background, back button, and content width so
/// new pages can be dropped in with minimal boilerplate.
class MarketingPageShell extends StatelessWidget {
  final String title;
  final Widget child;
  const MarketingPageShell({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LandingColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(title: title),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: LandingColors.foreground,
      padding: const EdgeInsets.fromLTRB(8, 16, 24, 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: LandingColors.gold, borderRadius: BorderRadius.circular(7)),
            alignment: Alignment.center,
            child: const Text('EBN', style: TextStyle(color: LandingColors.goldFg, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
