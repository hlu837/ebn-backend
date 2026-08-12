import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_response.dart';
import '../providers/favorites_controller.dart';
import '../services/visitor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import 'role_gate_screen.dart';

enum AppLanguage { english, amharic }

extension _AppLanguageX on AppLanguage {
  String get label => this == AppLanguage.english ? 'English' : 'አማርኛ (Amharic)';
  String get apiValue => this == AppLanguage.english ? 'english' : 'amharic';
}

AppLanguage _languageFromString(String value) => value == 'amharic' ? AppLanguage.amharic : AppLanguage.english;

/// Account details, notification preferences, and app preferences for the
/// signed-in Visitor. Opened from `VisitorAccountScreen`'s "Account &
/// Settings" row.
///
/// Notifications + app language are backed by
/// `GET/PATCH /api/auth/me/settings` (mirrors the agent settings screen's
/// `/api/agents/:agentId/settings`, just self-scoped via the token).
/// Account name/phone and password change use the existing
/// `PATCH /api/auth/me` and `POST /api/auth/me/change-password` routes.
class VisitorAccountSettingsScreen extends StatefulWidget {
  const VisitorAccountSettingsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<VisitorAccountSettingsScreen> createState() => _VisitorAccountSettingsScreenState();
}

class _VisitorAccountSettingsScreenState extends State<VisitorAccountSettingsScreen> {
  final _service = VisitorService();

  late final TextEditingController _nameController = TextEditingController(text: widget.user.fullName);
  late final TextEditingController _emailController = TextEditingController(text: widget.user.email);
  late final TextEditingController _phoneController = TextEditingController(text: widget.user.phone ?? '');

  bool _loading = true;
  String? _loadError;
  bool _savingAccount = false;

  bool _notifyRequestUpdates = true;
  bool _notifyChatMessages = true;
  bool _notifyPriceDrops = true;
  bool _notifyPromotions = false;
  AppLanguage _language = AppLanguage.english;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final settings = await _service.getSettings(widget.user.id, token: widget.user.token ?? '');
      if (!mounted) return;
      setState(() {
        _notifyRequestUpdates = settings.notifyRequestUpdates;
        _notifyChatMessages = settings.notifyChatMessages;
        _notifyPriceDrops = settings.notifyPriceDrops;
        _notifyPromotions = settings.notifyPromotions;
        _language = _languageFromString(settings.language);
        _loading = false;
      });
    } on VisitorServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    FocusScope.of(context).unfocus();
    setState(() => _savingAccount = true);
    try {
      await _service.updateProfile(
        widget.user.id,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        token: widget.user.token ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account details saved.')));
    } on VisitorServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _savingAccount = false);
    }
  }

  Future<void> _updateNotification(String field, bool value) async {
    setState(() {
      switch (field) {
        case 'notifyRequestUpdates':
          _notifyRequestUpdates = value;
        case 'notifyChatMessages':
          _notifyChatMessages = value;
        case 'notifyPriceDrops':
          _notifyPriceDrops = value;
        case 'notifyPromotions':
          _notifyPromotions = value;
      }
    });
    try {
      await _service.updateSettings(
        widget.user.id,
        notifyRequestUpdates: field == 'notifyRequestUpdates' ? value : null,
        notifyChatMessages: field == 'notifyChatMessages' ? value : null,
        notifyPriceDrops: field == 'notifyPriceDrops' ? value : null,
        notifyPromotions: field == 'notifyPromotions' ? value : null,
        token: widget.user.token ?? '',
      );
    } on VisitorServiceException catch (e) {
      if (!mounted) return;
      // Revert on failure.
      setState(() {
        switch (field) {
          case 'notifyRequestUpdates':
            _notifyRequestUpdates = !value;
          case 'notifyChatMessages':
            _notifyChatMessages = !value;
          case 'notifyPriceDrops':
            _notifyPriceDrops = !value;
          case 'notifyPromotions':
            _notifyPromotions = !value;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openChangePassword() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cloud,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ChangePasswordSheet(
        onSubmit: (current, next) async {
          await _service.changePassword(
            widget.user.id,
            currentPassword: current,
            newPassword: next,
            token: widget.user.token ?? '',
          );
        },
      ),
    );
  }

  void _openLanguagePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cloud,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const Text('App language', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: AppSpacing.md),
            for (final lang in AppLanguage.values)
              RadioListTile<AppLanguage>(
                contentPadding: EdgeInsets.zero,
                value: lang,
                groupValue: _language,
                activeColor: AppColors.primaryYellow,
                title: Text(lang.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                onChanged: (v) async {
                  Navigator.of(context).pop();
                  if (v == null || v == _language) return;
                  final previous = _language;
                  setState(() => _language = v);
                  try {
                    await _service.updateSettings(widget.user.id, language: v.apiValue, token: widget.user.token ?? '');
                  } on VisitorServiceException catch (e) {
                    if (!mounted) return;
                    setState(() => _language = previous);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogoutAllDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out everywhere?'),
        content: const Text('This will sign you out on all devices where you\'re currently logged in.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Log out everywhere', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out on all other devices.')));
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('This permanently removes your profile, saved listings, and request history. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete account', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account deletion is coming soon — contact support to delete your account now.')));
    }
  }

  void _logout() {
    context.read<FavoritesController>().clearUser();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleGateScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Account & Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorState(message: _loadError!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _SectionCard(
                      title: 'Account',
                      children: [
                        _LabeledField(label: 'Full name', controller: _nameController),
                        const SizedBox(height: AppSpacing.md),
                        _LabeledField(label: 'Email', controller: _emailController, enabled: false),
                        const SizedBox(height: AppSpacing.md),
                        _LabeledField(label: 'Phone', controller: _phoneController, keyboardType: TextInputType.phone),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(label: 'Save changes', isLoading: _savingAccount, onPressed: _savingAccount ? null : _saveAccount),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(width: double.infinity, child: SecondaryButton(label: 'Change password', onPressed: _openChangePassword)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionCard(
                      title: 'Notifications',
                      children: [
                        _SwitchRow(
                          label: 'Sell & order request updates',
                          subtitle: 'Status changes on things you\'ve submitted',
                          value: _notifyRequestUpdates,
                          onChanged: (v) => _updateNotification('notifyRequestUpdates', v),
                        ),
                        _SwitchRow(
                          label: 'Chat messages',
                          subtitle: 'New messages from brokers & agents',
                          value: _notifyChatMessages,
                          onChanged: (v) => _updateNotification('notifyChatMessages', v),
                        ),
                        _SwitchRow(
                          label: 'Price drops & saved listings',
                          subtitle: 'Updates on the properties you\'ve favorited',
                          value: _notifyPriceDrops,
                          onChanged: (v) => _updateNotification('notifyPriceDrops', v),
                        ),
                        _SwitchRow(
                          label: 'Promotions & tips',
                          subtitle: 'Occasional product updates',
                          value: _notifyPromotions,
                          onChanged: (v) => _updateNotification('notifyPromotions', v),
                          isLast: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionCard(
                      title: 'Preferences',
                      children: [
                        _NavRow(icon: Icons.language_rounded, label: 'App language', value: _language.label, onTap: _openLanguagePicker),
                        _NavRow(
                          icon: Icons.light_mode_outlined,
                          label: 'App theme',
                          value: 'Light',
                          isLast: true,
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dark mode is coming soon.'))),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionCard(
                      title: 'Danger zone',
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                            onPressed: _confirmLogoutAllDevices,
                            child: const Text('Log out of all devices'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            onPressed: _confirmDeleteAccount,
                            child: const Text('Delete my account', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.border, width: 1.4),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.button)),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.slate)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.slate, letterSpacing: 0.6))),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.controller, this.enabled = true, this.keyboardType});
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.subtitle, required this.value, required this.onChanged, this.isLast = false});
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.slate)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppColors.primaryYellow),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.value, required this.onTap, this.isLast = false});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md, top: 2),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.ink),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink))),
              Text(value, style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.onSubmit});

  /// Throws [VisitorServiceException] on failure.
  final Future<void> Function(String currentPassword, String newPassword) onSubmit;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _serverError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? get _error {
    if (_newController.text.isEmpty) return null;
    if (_newController.text.length < 8) return 'New password must be at least 8 characters';
    if (_confirmController.text.isNotEmpty && _confirmController.text != _newController.text) return 'Passwords do not match';
    return null;
  }

  bool get _canSubmit =>
      !_submitting && _currentController.text.isNotEmpty && _newController.text.length >= 8 && _newController.text == _confirmController.text;

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _serverError = null;
    });
    try {
      await widget.onSubmit(_currentController.text, _newController.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.')));
    } on VisitorServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _serverError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const Text('Change password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: _currentController, obscureText: true, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Current password')),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: _newController, obscureText: true, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'New password')),
          const SizedBox(height: AppSpacing.md),
          TextField(controller: _confirmController, obscureText: true, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Confirm new password', errorText: _error)),
          if (_serverError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_serverError!, style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Update password',
              isLoading: _submitting,
              onPressed: _canSubmit ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }
}
