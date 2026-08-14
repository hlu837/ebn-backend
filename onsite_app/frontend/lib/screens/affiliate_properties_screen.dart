import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../services/asset_service.dart';
import '../services/mock_asset_data.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

const _kAccentRed = AppColors.primaryYellow;

/// Full, searchable/filterable catalog of shareable listings for the
/// Affiliater role — the "View All" / "Assets" destination the dashboard's
/// Top Properties rail only shows a preview of.
///
/// Commission % is derived per-asset the same simple way the dashboard
/// preview does (alternating 2.0 / 2.5) since there's no real commission
/// schedule from the backend yet — see the TODO on [AffiliaterHomeScreen].
class AffiliatePropertiesScreen extends StatefulWidget {
  const AffiliatePropertiesScreen({super.key});

  @override
  State<AffiliatePropertiesScreen> createState() =>
      _AffiliatePropertiesScreenState();
}

class _AffiliatePropertiesScreenState extends State<AffiliatePropertiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  AssetCategorySlug? _category;

  final AssetService _assetService = AssetService();

  // Painted instantly from the bundled mock list so this page is never
  // empty on first frame, then swapped for the real `GET /api/assets`
  // response the moment it lands.
  List<Asset> _allAssets = List.of(kMockCompanyAssets);

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      final assets = await _assetService.fetchAssets(limit: 200);
      if (!mounted) return;
      setState(() => _allAssets = assets);
    } on AssetException catch (_) {
      // Backend down / unreachable — keep showing the bundled mock listings.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _commissionFor(int index) => index.isEven ? 2.0 : 2.5;

  List<Asset> get _filtered {
    var list = _allAssets.where((a) => a.status == AssetStatus.active);
    if (_category != null) {
      list = list.where((a) => a.category == _category);
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list.where((a) =>
          a.title.toLowerCase().contains(q) ||
          (a.city ?? '').toLowerCase().contains(q));
    }
    return list.toList();
  }

  void _generateLink(Asset asset) {
    AppToast.showSuccess(
        context, 'Referral link generated for "${asset.title}".');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final categories = _allAssets.map((a) => a.category).toSet().toList();

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Properties',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search homes, vehicles, machinery...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slate),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  borderSide: const BorderSide(
                      color: AppColors.primaryYellow, width: 2),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              children: [
                _CategoryChip(
                    label: 'All',
                    active: _category == null,
                    onTap: () => setState(() => _category = null)),
                const SizedBox(width: AppSpacing.sm),
                ...categories.map((c) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _CategoryChip(
                        label: c.label,
                        active: _category == c,
                        onTap: () => setState(() => _category = c),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: filtered.isEmpty
                ? const _EmptyProperties()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _PropertyGridCard(
                      asset: filtered[i],
                      commissionPercent: _commissionFor(i),
                      onGenerateLink: () => _generateLink(filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(
      {required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? _kAccentRed : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: active ? _kAccentRed : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.slate),
        ),
      ),
    );
  }
}

class _PropertyGridCard extends StatelessWidget {
  const _PropertyGridCard(
      {required this.asset,
      required this.commissionPercent,
      required this.onGenerateLink});

  final Asset asset;
  final double commissionPercent;
  final VoidCallback onGenerateLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 11,
                child: asset.imageUrl != null
                    ? Image.network(asset.imageUrl!,
                        fit: BoxFit.cover, width: double.infinity)
                    : Container(color: AppColors.border),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: Text(
                    'Earn ${commissionPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(asset.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(asset.city ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate)),
                const SizedBox(height: 4),
                Text(asset.formattedPrice,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _kAccentRed)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: onGenerateLink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccentRed.withOpacity(0.1),
                      foregroundColor: _kAccentRed,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Generate Link'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProperties extends StatelessWidget {
  const _EmptyProperties();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.holiday_village_outlined,
                size: 40, color: AppColors.slate),
            SizedBox(height: AppSpacing.md),
            Text('No properties match your search.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
