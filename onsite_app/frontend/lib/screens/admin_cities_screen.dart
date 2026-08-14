import 'package:flutter/material.dart';

import '../models/admin_settings_models.dart';
import '../services/admin_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Admin > Settings > Cities. Add/remove serviceable cities and mark a
/// city as coming soon vs. fully live.
class AdminCitiesScreen extends StatefulWidget {
  const AdminCitiesScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminCitiesScreen> createState() => _AdminCitiesScreenState();
}

class _AdminCitiesScreenState extends State<AdminCitiesScreen> {
  final AdminSettingsService _service = AdminSettingsService();
  final _nameController = TextEditingController();

  List<AdminCity> _cities = const [];
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _service.fetchCities(token: widget.token);
      if (!mounted) return;
      setState(() {
        _cities = rows;
        _loading = false;
      });
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.showError(context, 'City name is required.');
      return;
    }
    setState(() => _adding = true);
    try {
      await _service.createCity(name: name, token: widget.token);
      _nameController.clear();
      if (!mounted) return;
      setState(() => _adding = false);
      await _load();
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      setState(() => _adding = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _toggleLive(AdminCity city) async {
    try {
      await _service.updateCity(city.id, isLive: !city.isLive, token: widget.token);
      await _load();
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _remove(AdminCity city) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove city?'),
        content: Text('"${city.name}" will no longer be offered to customers.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.removeCity(city.id, token: widget.token);
      if (!mounted) return;
      setState(() => _cities.removeWhere((c) => c.id == city.id));
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        title: const Text('Cities'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'New city', border: OutlineInputBorder()),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      onPressed: _adding ? null : _add,
                      icon: _adding
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_cities.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(child: Text('No cities yet.', style: TextStyle(color: AppColors.slate))),
                )
              else
                ..._cities.map(
                  (city) => Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(city.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        city.isLive ? 'Live' : 'Coming soon',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: city.isLive ? AppColors.success : AppColors.primaryYellow,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(value: city.isLive, onChanged: (_) => _toggleLive(city)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                            onPressed: () => _remove(city),
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
