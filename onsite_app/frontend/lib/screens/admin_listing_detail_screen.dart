import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../services/asset_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Admin's detail/edit page for a single listing — opened from the
/// "Manage" action on the Asset Catalogue grid. Status changes, edited
/// fields, and deletion are all persisted for real via `PATCH`/`DELETE
/// /api/assets/:id`. Pops with `true` on save/delete so the caller
/// (Admin's catalogue grid) knows to refetch.
class AdminListingDetailScreen extends StatefulWidget {
  const AdminListingDetailScreen({super.key, required this.asset});

  final Asset asset;

  @override
  State<AdminListingDetailScreen> createState() => _AdminListingDetailScreenState();
}

class _AdminListingDetailScreenState extends State<AdminListingDetailScreen> {
  final AssetService _assetService = AssetService();

  late AssetStatus _status = widget.asset.status;
  late final _titleCtrl = TextEditingController(text: widget.asset.title);
  late final _priceCtrl = TextEditingController(text: widget.asset.priceAmount.toStringAsFixed(0));
  late final _addressCtrl = TextEditingController(text: widget.asset.addressLine ?? '');

  bool _saving = false;
  bool _deleting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: const Text('Delete this listing?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        content: const Text(
          'This removes it from the catalogue everywhere it\'s shown. This can\'t be undone.',
          style: TextStyle(fontSize: 13.5, color: AppColors.slate),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteListing();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteListing() async {
    setState(() => _deleting = true);
    try {
      await _assetService.deleteAsset(widget.asset.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AssetException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _saveChanges() async {
    final price = double.tryParse(_priceCtrl.text.trim());
    if (_titleCtrl.text.trim().isEmpty) {
      AppToast.showError(context, 'Title can\'t be empty.');
      return;
    }
    if (price == null || price <= 0) {
      AppToast.showError(context, 'Enter a valid price.');
      return;
    }
    setState(() => _saving = true);
    try {
      await _assetService.updateAsset(
        widget.asset.id,
        title: _titleCtrl.text.trim(),
        priceAmount: price,
        addressLine: _addressCtrl.text.trim(),
        status: _status,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.showSuccess(context, 'Changes saved.');
      Navigator.of(context).pop(true);
    } on AssetException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Listing', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ── Photo header ─────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: asset.imageUrl != null
                    ? Image.network(asset.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.border,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_outlined, size: 40, color: AppColors.slate),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Title + status badge ────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(asset.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.ink)),
                ),
                const SizedBox(width: AppSpacing.sm),
                _StatusBadge(status: _status),
              ],
            ),
            const SizedBox(height: 4),
            Text(asset.formattedPrice, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
            if (asset.specLine.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(asset.specLine, style: const TextStyle(fontSize: 13, color: AppColors.slate)),
            ],
            const SizedBox(height: 4),
            Text(
              [asset.category.label, asset.city].where((s) => s != null && s.isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 13, color: AppColors.slate),
            ),

            const SizedBox(height: AppSpacing.lg),
            if (asset.brokerId != null) _InfoRow(icon: Icons.badge_outlined, label: 'Listed by agent', value: asset.brokerId!),
            if (asset.postedLabel != null) _InfoRow(icon: Icons.schedule_rounded, label: 'Posted', value: asset.postedLabel!),

            // ── Attributes ───────────────────────────────────────────────
            if (asset.attributes.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const Text('Attributes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
                child: Column(
                  children: [
                    for (final entry in asset.attributes.entries) ...[
                      Row(
                        children: [
                          Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 13, color: AppColors.slate))),
                          Text('${entry.value}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        ],
                      ),
                      if (entry.key != asset.attributes.entries.last.key) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],

            // ── Status control ──────────────────────────────────────────
            const SizedBox(height: AppSpacing.xl),
            const Text('Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final s in AssetStatus.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: _status == s,
                    selectedColor: AppColors.primaryYellow,
                    backgroundColor: AppColors.card,
                    side: const BorderSide(color: AppColors.border),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _status == s ? AppColors.ink : AppColors.slate,
                    ),
                    onSelected: (_) => setState(() => _status = s), // persisted on "Save changes"
                  ),
              ],
            ),

            // ── Edit fields ──────────────────────────────────────────────
            const SizedBox(height: AppSpacing.xl),
            const Text('Edit details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (ETB)'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: _saving ? 'Saving…' : 'Save changes',
              onPressed: (_saving || _deleting) ? null : _saveChanges,
            ),

            // ── Danger zone ──────────────────────────────────────────────
            const SizedBox(height: AppSpacing.xl),
            const Text('Danger zone', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.danger)),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: _deleting ? 'Deleting…' : 'Delete listing',
              borderColor: AppColors.danger,
              textColor: AppColors.danger,
              onPressed: (_saving || _deleting) ? null : _confirmDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final AssetStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AssetStatus.active => AppColors.success,
      AssetStatus.underInspection => AppColors.primaryYellowDark,
      AssetStatus.sold => AppColors.slate,
      AssetStatus.archived => AppColors.slate,
      AssetStatus.draft => AppColors.slate,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.slate),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink))),
        ],
      ),
    );
  }
}
