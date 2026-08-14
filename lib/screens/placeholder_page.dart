import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Generic stand-in for any sidebar destination that doesn't have a full
/// screen built yet. Keeps every nav item genuinely tappable and on-brand
/// instead of leaving dead links, while making it obvious to a client
/// which pieces are wireframed vs. fully built.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    this.bullets = const [],
  });

  final String title;
  final IconData icon;
  final String description;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: Color(0xFFF0F0EE), shape: BoxShape.circle),
                child: Icon(icon, color: const Color(0xFF4A4A45), size: 28),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: AppColors.primaryYellow.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
                child: const Text('IN PROGRESS', style: TextStyle(color: AppColors.primaryYellow, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text(description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.slate)),
              if (bullets.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("What this screen will do", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: AppSpacing.md),
                      for (final b in bullets) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.circle, size: 6, color: AppColors.slate),
                            const SizedBox(width: 10),
                            Expanded(child: Text(b, style: const TextStyle(fontSize: 13.5, color: AppColors.ink, height: 1.4))),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
