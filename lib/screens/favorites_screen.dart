import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../providers/favorites_controller.dart';
import '../services/asset_service.dart';
import '../theme/app_theme.dart';
import 'asset_detail_screen.dart';

const _kAccentRed = Color(0xFFFF2686);
const _kRoiGreen = Color(0xFF1FAA59);
const _kRoiGreenBg = Color(0xFFE6F6EC);

/// "Saved Listings / Favorites" — every asset the current account has
/// hearted, rendered with the rating-badge / ROI-pill card style from the
/// reference mock (star + review count over the photo, bold title, green
/// ROI pill, pin + location line underneath). Shared across Visitor and
/// Agent — both sides feed the same [FavoritesController].
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final AssetService _assetService = AssetService();

  // Populated from the real `GET /api/assets` response once it lands.
  List<Asset> _allAssets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAssets();
    // Belt-and-suspenders: the home shell already calls this on load, but
    // attachUser is a no-op once loaded for the same account, so it's
    // cheap to re-assert here too (e.g. if this screen is ever reached
    // before the shell finishes hydrating).
    context.read<FavoritesController>().attachUser(widget.user);
  }

  Future<void> _loadAssets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final assets = await _assetService.fetchAssets(limit: 200);
      if (!mounted) return;
      setState(() {
        _allAssets = assets;
        _loading = false;
      });
    } on AssetException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesController>();
    final saved = _allAssets.where((a) => favorites.isFavorite(a.id)).toList();

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = _ErrorState(message: _error!, onRetry: _loadAssets);
    } else if (saved.isEmpty) {
      body = const _EmptyFavorites();
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: saved.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) => _FavoriteAssetCard(asset: saved[i], user: widget.user),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Saved Listings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(child: body),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.slate, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: _kAccentRed.withOpacity(0.1), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.favorite_border_rounded, size: 30, color: _kAccentRed),
            ),
            const SizedBox(height: 16),
            const Text(
              'No saved listings yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the heart on any listing in the Explore Feed to save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.slate, fontWeight: FontWeight.w500, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteAssetCard extends StatelessWidget {
  const _FavoriteAssetCard({required this.asset, required this.user});

  final Asset asset;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AssetDetailScreen(
          asset: asset,
          user: user,
        ),
      )),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (asset.imageUrl != null)
                    Image.network(
                      asset.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          Container(color: AppColors.primaryYellow.withOpacity(0.18)),
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : Container(color: AppColors.primaryYellow.withOpacity(0.18)),
                    )
                  else
                    Container(color: AppColors.primaryYellow.withOpacity(0.18)),
                  if (asset.rating != null)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _RatingBadge(rating: asset.rating!, reviewCount: asset.reviewCount),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _UnsaveButton(assetId: asset.id),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          asset.title,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink, height: 1.25),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (asset.roiPercent != null) ...[
                        const SizedBox(width: 8),
                        _RoiPill(roiPercent: asset.roiPercent!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 13, color: AppColors.slate),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          asset.addressLine ?? asset.city ?? '',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.slate, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White/cream pill over the photo: gold star + rating + "(120+)".
class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating, this.reviewCount});

  final double rating;
  final int? reviewCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 15, color: AppColors.primaryYellow),
          const SizedBox(width: 3),
          Text(
            reviewCount != null ? '${rating.toStringAsFixed(1)} ($reviewCount+)' : rating.toStringAsFixed(1),
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

/// Green "12.0% ROI" pill next to the title.
class _RoiPill extends StatelessWidget {
  const _RoiPill({required this.roiPercent});

  final double roiPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _kRoiGreenBg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '${roiPercent.toStringAsFixed(1)}% ROI',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kRoiGreen),
      ),
    );
  }
}

/// Filled heart button over the photo — tapping it removes the listing
/// from Favorites right from this page.
class _UnsaveButton extends StatelessWidget {
  const _UnsaveButton({required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<FavoritesController>().toggle(assetId),
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Icon(Icons.favorite_rounded, size: 16, color: _kAccentRed),
      ),
    );
  }
}
