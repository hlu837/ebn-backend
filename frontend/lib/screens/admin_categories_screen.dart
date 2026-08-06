import 'package:flutter/material.dart';

import '../models/admin_settings_models.dart';
import '../services/admin_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Admin > Settings > Categories & Pricing. Add/rename/archive listing
/// categories, set the fee charged per submission, and reorder them.
class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final AdminSettingsService _service = AdminSettingsService();

  List<AdminCategory> _categories = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _service.fetchCategories(token: widget.token);
      if (!mounted) return;
      setState(() {
        _categories = rows;
        _loading = false;
      });
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _openEditor({AdminCategory? existing}) async {
    final labelController = TextEditingController(text: existing?.label ?? '');
    final feeController = TextEditingController(
      text: existing != null ? existing.listingFeeBirr.toStringAsFixed(2) : '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(existing == null ? 'Add Category' : 'Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Category name', border: OutlineInputBorder()),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: feeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Listing fee (Birr)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true) return;

    final label = labelController.text.trim();
    if (label.isEmpty) {
      if (!mounted) return;
      AppToast.showError(context, 'Category name is required.');
      return;
    }
    final feeBirr = double.tryParse(feeController.text.trim()) ?? 0;
    final feeCents = (feeBirr * 100).round();

    try {
      if (existing == null) {
        await _service.createCategory(label: label, listingFeeCents: feeCents, token: widget.token);
      } else {
        await _service.updateCategory(existing.id, label: label, listingFeeCents: feeCents, token: widget.token);
      }
      await _load();
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _toggleActive(AdminCategory category) async {
    try {
      await _service.updateCategory(category.id, isActive: !category.isActive, token: widget.token);
      await _load();
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final items = List<AdminCategory>.from(_categories);
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    setState(() => _categories = items);
    try {
      final rows = await _service.reorderCategories(items.map((c) => c.id).toList(), token: widget.token);
      if (!mounted) return;
      setState(() => _categories = rows);
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        title: const Text('Categories & Pricing'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _categories.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                            child: Center(child: Text('No categories yet.', style: TextStyle(color: AppColors.slate))),
                          ),
                        ],
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
                        itemCount: _categories.length,
                        onReorder: _reorder,
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return Container(
                            key: ValueKey(category.id),
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(AppRadii.lg),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ListTile(
                              leading: const Icon(Icons.drag_indicator_rounded, color: AppColors.slate),
                              title: Text(
                                category.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: category.isActive ? AppColors.ink : AppColors.slate,
                                  decoration: category.isActive ? null : TextDecoration.lineThrough,
                                ),
                              ),
                              subtitle: Text(
                                'Fee: ${category.listingFeeBirr.toStringAsFixed(2)} Birr · ${category.slug}',
                                style: const TextStyle(fontSize: 12, color: AppColors.slate),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _openEditor(existing: category),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      category.isActive ? Icons.archive_outlined : Icons.unarchive_outlined,
                                      size: 20,
                                      color: category.isActive ? AppColors.danger : AppColors.primaryYellow,
                                    ),
                                    onPressed: () => _toggleActive(category),
                                    tooltip: category.isActive ? 'Archive' : 'Restore',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
    );
  }
}
