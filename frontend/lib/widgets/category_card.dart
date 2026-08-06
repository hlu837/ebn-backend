import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AssetCategory {
  final String label;
  final IconData icon;
  const AssetCategory(this.label, this.icon);
}

const List<AssetCategory> kAssetCategories = [
  AssetCategory('Vehicles', Icons.directions_car_filled_rounded),
  AssetCategory('Apartments', Icons.apartment_rounded),
  AssetCategory('Condominium', Icons.location_city_rounded),
  AssetCategory('Machinery', Icons.precision_manufacturing_rounded),
  AssetCategory('House', Icons.house_rounded),
  AssetCategory('Warehouse', Icons.warehouse_rounded),
  AssetCategory('Land', Icons.terrain_rounded),
  AssetCategory('Building', Icons.business_rounded),
  AssetCategory('Construction Materials', Icons.construction_rounded),
  AssetCategory('Others', Icons.category_rounded),
];

/// A premium, tap-able category tile used on the landing grid.
class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category, this.onTap});

  final AssetCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F0EE),
                  shape: BoxShape.circle,
                ),
                child: Icon(category.icon, color: const Color(0xFF4A4A45), size: 26),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                category.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
