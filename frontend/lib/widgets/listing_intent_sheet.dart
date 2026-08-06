import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// What a Visitor wants to do with their asset — chosen before they land
/// on the actual listing wizard, so the right form (Sell vs Rent) opens.
enum ListingIntent { sell, rent }

/// Shows a small bottom sheet letting the Visitor pick "Sell" or "Rent"
/// before continuing into the listing flow. Returns `null` if dismissed.
Future<ListingIntent?> showListingIntentSheet(BuildContext context) {
  return showModalBottomSheet<ListingIntent>(
    context: context,
    backgroundColor: AppColors.cloud,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => const _ListingIntentSheet(),
  );
}

class _ListingIntentSheet extends StatelessWidget {
  const _ListingIntentSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('What would you like to do?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Pick the option that matches your listing — the form after this adjusts to fit.",
              style: TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            _IntentOption(
              icon: Icons.sell_outlined,
              title: 'Sell',
              subtitle: 'List an asset for sale — property, vehicle, machinery, and more.',
              onTap: () => Navigator.of(context).pop(ListingIntent.sell),
            ),
            const SizedBox(height: AppSpacing.sm),
            _IntentOption(
              icon: Icons.key_outlined,
              title: 'Rent',
              subtitle: 'List an asset for rent instead of selling it outright.',
              onTap: () => Navigator.of(context).pop(ListingIntent.rent),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentOption extends StatelessWidget {
  const _IntentOption({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Color(0xFFF0F0EE), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, color: const Color(0xFF4A4A45), size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.35)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}
