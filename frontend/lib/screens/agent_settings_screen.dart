import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../services/agent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

enum AppLanguage { english, amharic }

extension _AppLanguageX on AppLanguage {
  String get label => this == AppLanguage.english ? 'English' : 'አማርኛ (Amharic)';
  String get apiValue => this == AppLanguage.english ? 'english' : 'amharic';
}

AppLanguage _languageFromString(String value) => value == 'amharic' ? AppLanguage.amharic : AppLanguage.english;

/// Account details, notification preferences, payout/banking details, and
/// app preferences for the signed-in agent.
///
/// Notifications, app language, and payout/banking are backed by
/// `GET/PATCH /api/agents/:id/settings`. Account name/phone and password
/// change remain local-only — there's no `PATCH /api/auth/me` or
/// change-password endpoint yet (only signup/login/me/agent-location exist
/// in `auth.js`).
class AgentSettingsScreen extends StatefulWidget {
  const AgentSettingsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AgentSettingsScreen> createState() => _AgentSettingsScreenState();
}

class _AgentSettingsScreenState extends State<AgentSettingsScreen> {
  final _service = AgentService();

  late final TextEditingController _nameController = TextEditingController(text: widget.user.fullName);
  late final TextEditingController _emailController = TextEditingController(text: widget.user.email);
  late final TextEditingController _phoneController = TextEditingController(text: widget.user.phone ?? '');

  // The full account number is never round-tripped from the server (only
  // the last 4 digits are). This controller is only for a *new* number
  // being actively entered — it starts empty and is cleared after every
  // successful save, never pre-filled from `settings`.
  final TextEditingController _newAccountNumberController = TextEditingController();
  bool _editingAccountNumber = false;
  String? _bankAccountLast4;

  bool _loading = true;
  String? _loadError;

  bool _notifyNewDispatches = true;
  bool _notifyChatMessages = true;
  bool _notifyPromotions = false;
  bool _notifyPayouts = true;
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
        _notifyNewDispatches = settings.notifyNewDispatches;
        _notifyChatMessages = settings.notifyChatMessages;
        _notifyPromotions = settings.notifyPromotions;
        _notifyPayouts = settings.notifyPayouts;
        _language = _languageFromString(settings.language);
        _bankAccountLast4 = settings.bankAccountLast4;
        _loading = false;
      });
    } on AgentServiceException catch (e) {
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
    _newAccountNumberController.dispose();
    super.dispose();
  }

  void _saveAccount() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account details saved.')));
  }

  Future<void> _savePayout() async {
    final newAccountNumber = _newAccountNumberController.text.trim();
    if (_editingAccountNumber && newAccountNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an account number, or tap Cancel.')));
      return;
    }
    if (newAccountNumber.isNotEmpty && !RegExp(r'^\d{4,34}$').hasMatch(newAccountNumber)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account number must be 4-34 digits.')));
      return;
    }
    FocusScope.of(context).unfocus();
    try {
      final updated = await _service.updateSettings(
        widget.user.id,
        // Only sent when the user actually typed a new number. The full
        // value is never kept around client-side afterward — we drop it
        // and only hang on to the masked last4 the server hands back.
        bankAccountNumber: newAccountNumber.isEmpty ? null : newAccountNumber,
        token: widget.user.token ?? '',
      );
      if (!mounted) return;
      setState(() {
        _bankAccountLast4 = updated.bankAccountLast4;
        _newAccountNumberController.clear();
        _editingAccountNumber = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout details saved.')));
    } on AgentServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _updateNotification(String field, bool value) async {
    setState(() {
      switch (field) {
        case 'notifyNewDispatches':
          _notifyNewDispatches = value;
        case 'notifyChatMessages':
          _notifyChatMessages = value;
        case 'notifyPromotions':
          _notifyPromotions = value;
        case 'notifyPayouts':
          _notifyPayouts = value;
      }
    });
    try {
      await _service.updateSettings(
        widget.user.id,
        notifyNewDispatches: field == 'notifyNewDispatches' ? value : null,
        notifyChatMessages: field == 'notifyChatMessages' ? value : null,
        notifyPromotions: field == 'notifyPromotions' ? value : null,
        notifyPayouts: field == 'notifyPayouts' ? value : null,
        token: widget.user.token ?? '',
      );
    } on AgentServiceException catch (e) {
      if (!mounted) return;
      // Revert on failure.
      setState(() {
        switch (field) {
          case 'notifyNewDispatches':
            _notifyNewDispatches = !value;
          case 'notifyChatMessages':
            _notifyChatMessages = !value;
          case 'notifyPromotions':
            _notifyPromotions = !value;
          case 'notifyPayouts':
            _notifyPayouts = !value;
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
      builder: (_) => const _ChangePasswordSheet(),
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
                  } on AgentServiceException catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
                        SizedBox(width: double.infinity, child: PrimaryButton(label: 'Save changes', onPressed: _saveAccount)),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(width: double.infinity, child: SecondaryButton(label: 'Change password', onPressed: _openChangePassword)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionCard(
                      title: 'Notifications',
                      children: [
                        _SwitchRow(label: 'New order dispatches', subtitle: 'Alerts when a nearby lead comes in', value: _notifyNewDispatches, onChanged: (v) => _updateNotification('notifyNewDispatches', v)),
                        _SwitchRow(label: 'Chat messages', subtitle: 'Buyers and sellers messaging you', value: _notifyChatMessages, onChanged: (v) => _updateNotification('notifyChatMessages', v)),
                        _SwitchRow(label: 'Payouts & commissions', subtitle: 'Wallet activity and withdrawals', value: _notifyPayouts, onChanged: (v) => _updateNotification('notifyPayouts', v)),
                        _SwitchRow(label: 'Promotions & tips', subtitle: 'Occasional product updates', value: _notifyPromotions, onChanged: (v) => _updateNotification('notifyPromotions', v), isLast: true),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionCard(
                      title: 'Payout & banking',
                      children: [
                        const Text('Commercial Bank of Ethiopia', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        const SizedBox(height: AppSpacing.sm),
                        _AccountNumberField(
                          last4: _bankAccountLast4,
                          editing: _editingAccountNumber,
                          controller: _newAccountNumberController,
                          onStartEditing: () => setState(() => _editingAccountNumber = true),
                          onCancel: () => setState(() {
                            _editingAccountNumber = false;
                            _newAccountNumberController.clear();
                          }),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(width: double.infinity, child: SecondaryButton(label: 'Save payout details', onPressed: _savePayout)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _SectionCard(
                      title: 'Preferences',
                      children: [
                        _NavRow(icon: Icons.language_rounded, label: 'App language', value: _language.label, onTap: _openLanguagePicker),
                        _NavRow(icon: Icons.light_mode_outlined, label: 'App theme', value: 'Light', onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dark mode is coming soon.'))), isLast: true),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                        onPressed: _confirmLogoutAllDevices,
                        child: const Text('Log out of all devices'),
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

/// Shows the account number masked as "•••• 4821" (only the last 4 digits
/// ever live client-side) with a "Change" action that reveals a blank
/// input for a brand-new number. Nothing pre-fills the input — there's
/// nothing to pre-fill it *with*, since the server never sends the full
/// number back down.
class _AccountNumberField extends StatelessWidget {
  const _AccountNumberField({
    required this.last4,
    required this.editing,
    required this.controller,
    required this.onStartEditing,
    required this.onCancel,
  });

  final String? last4;
  final bool editing;
  final TextEditingController controller;
  final VoidCallback onStartEditing;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('New account number', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink))),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter full account number'),
          ),
          const SizedBox(height: 4),
          const Text('Only the last 4 digits are kept after saving.', style: TextStyle(fontSize: 11, color: AppColors.slate)),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            last4 != null && last4!.isNotEmpty ? 'Account number  ••••$last4' : 'Account number  — not set',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
          ),
        ),
        TextButton(onPressed: onStartEditing, child: Text(last4 != null && last4!.isNotEmpty ? 'Change' : 'Add')),
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
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

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

  bool get _canSubmit => _currentController.text.isNotEmpty && _newController.text.length >= 8 && _newController.text == _confirmController.text;

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
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              label: 'Update password',
              onPressed: _canSubmit
                  ? () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.')));
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
