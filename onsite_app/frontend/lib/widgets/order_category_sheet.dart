import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../theme/app_theme.dart';

/// Shows a bottom sheet letting the Visitor pick which category they want
/// to place a custom order/request for, before continuing into the
/// category-specific order form. Returns `null` if dismissed.
///
/// Mirrors [showListingIntentSheet]'s pattern (Sell/Rent chooser) — pick
/// first, then the next screen adjusts to fit the choice.
Future<AssetCategorySlug?> showOrderCategorySheet(BuildContext context) {
  return showModalBottomSheet<AssetCategorySlug>(
    context: context,
    backgroundColor: AppColors.cloud,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) => const _OrderCategorySheet(),
  );
}

const _kOrderCategories = [
  AssetCategorySlug.house,
  AssetCategorySlug.apartments,
  AssetCategorySlug.condominium,
  AssetCategorySlug.building,
  AssetCategorySlug.warehouse,
  AssetCategorySlug.vehicles,
  AssetCategorySlug.machinery,
  AssetCategorySlug.constructionMaterials,
  AssetCategorySlug.others,
];

IconData _iconFor(AssetCategorySlug category) {
  switch (category) {
    case AssetCategorySlug.house:
      return Icons.house_rounded;
    case AssetCategorySlug.apartments:
      return Icons.apartment_rounded;
    case AssetCategorySlug.condominium:
      return Icons.location_city_rounded;
    case AssetCategorySlug.building:
      return Icons.domain_rounded;
    case AssetCategorySlug.warehouse:
      return Icons.warehouse_rounded;
    case AssetCategorySlug.vehicles:
      return Icons.directions_car_filled_rounded;
    case AssetCategorySlug.machinery:
      return Icons.precision_manufacturing_rounded;
    case AssetCategorySlug.constructionMaterials:
      return Icons.construction_rounded;
    case AssetCategorySlug.others:
    case AssetCategorySlug.realEstate:
      return Icons.category_rounded;
  }
}

class _OrderCategorySheet extends StatelessWidget {
  const _OrderCategorySheet();

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
                  child: Text('What would you like to order?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Pick a category and we'll take you to the request form for it.",
              style: TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.lg),
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final category in _kOrderCategories)
                  _OrderCategoryTile(
                    icon: _iconFor(category),
                    label: category.label,
                    onTap: () => Navigator.of(context).pop(category),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCategoryTile extends StatelessWidget {
  const _OrderCategoryTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
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
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: Color(0xFFF0F0EE), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, color: const Color(0xFF4A4A45), size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
