import 'package:flutter/material.dart';

import '../services/admin_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Admin > Settings > General. App-wide basics: name, logo, and the
/// contact details shown to users.
class AdminGeneralSettingsScreen extends StatefulWidget {
  const AdminGeneralSettingsScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminGeneralSettingsScreen> createState() => _AdminGeneralSettingsScreenState();
}

class _AdminGeneralSettingsScreenState extends State<AdminGeneralSettingsScreen> {
  final AdminSettingsService _service = AdminSettingsService();

  final _appNameController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _supportPhoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _logoUrlController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await _service.fetchGeneralSettings(token: widget.token);
      if (!mounted) return;
      setState(() {
        _appNameController.text = settings.appName;
        _logoUrlController.text = settings.logoUrl ?? '';
        _supportEmailController.text = settings.supportEmail ?? '';
        _supportPhoneController.text = settings.supportPhone ?? '';
        _loading = false;
      });
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.updateGeneralSettings(
        appName: _appNameController.text.trim(),
        logoUrl: _logoUrlController.text.trim(),
        supportEmail: _supportEmailController.text.trim(),
        supportPhone: _supportPhoneController.text.trim(),
        token: widget.token,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.showSuccess(context, 'Settings saved.');
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        title: const Text('General'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  TextField(
                    controller: _appNameController,
                    decoration: const InputDecoration(labelText: 'App name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _logoUrlController,
                    decoration: const InputDecoration(labelText: 'Logo URL', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Support Contact', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.slate)),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _supportEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Support email', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _supportPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Support phone', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(label: _saving ? 'Saving…' : 'Save Changes', onPressed: _saving ? null : _save),
                ],
              ),
      ),
    );
  }
}
