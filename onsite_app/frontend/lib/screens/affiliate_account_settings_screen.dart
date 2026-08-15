import 'package:flutter/material.dart';
import '../models/auth_response.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../services/affiliate_service.dart';
import '../services/auth_service.dart';

const _kAccentRed = AppColors.primaryYellow;

/// Profile + payout settings for the Affiliater role.
///
/// Name/phone are saved via the shared `PATCH /api/auth/me`
/// (AuthService.updateProfile) — same endpoint every other role's account
/// settings screen uses. Bank details + notification prefs are saved via
/// `GET/PATCH /api/affiliates/me/settings` (AffiliateService), backed by
/// the affiliate_settings table.
class AffiliateAccountSettingsScreen extends StatefulWidget {
  const AffiliateAccountSettingsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AffiliateAccountSettingsScreen> createState() => _AffiliateAccountSettingsScreenState();
}

class _AffiliateAccountSettingsScreenState extends State<AffiliateAccountSettingsScreen> {
  final _authService = AuthService();
  final _affiliateService = AffiliateService();

  late final TextEditingController _nameController = TextEditingController(text: widget.user.fullName);
  late final TextEditingController _phoneController = TextEditingController(text: widget.user.phone ?? '');
  final TextEditingController _bankNameController = TextEditingController();

  // The full account number is never round-tripped from the server (only
  // the last 4 digits are). This controller is only for a *new* number the
  // user is actively entering — it starts empty and is cleared after every
  // successful save, it's never pre-filled from `settings`.
  final TextEditingController _newAccountNumberController = TextEditingController();
  bool _editingAccountNumber = false;
  String? _bankAccountLast4;

  bool _emailNotifications = true;
  bool _payoutNotifications = true;

  bool _loading = true;
  String? _loadError;
  bool _saving = false;

  String? _token() => widget.user.token != null && widget.user.token!.isNotEmpty ? widget.user.token : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = _token();
    if (token == null) {
      setState(() { _loadError = 'Not logged in.'; _loading = false; });
      return;
    }
    try {
      final settings = await _affiliateService.getSettings(token);
      if (!mounted) return;
      setState(() {
        _emailNotifications = settings.notifyNewReferrals;
        _payoutNotifications = settings.notifyPayouts;
        _bankNameController.text = settings.bankName ?? '';
        _bankAccountLast4 = settings.bankAccountLast4;
        _loading = false;
      });
    } on AffiliateException catch (e) {
      if (!mounted) return;
      setState(() { _loadError = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loadError = 'Failed to load settings.'; _loading = false; });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bankNameController.dispose();
    _newAccountNumberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = _token();
    if (token == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      AppToast.showError(context, 'Full name cannot be empty.');
      return;
    }

    final newAccountNumber = _newAccountNumberController.text.trim();
    if (_editingAccountNumber && newAccountNumber.isEmpty) {
      AppToast.showError(context, 'Enter an account number, or tap Cancel.');
      return;
    }
    if (newAccountNumber.isNotEmpty && !RegExp(r'^\d{4,34}$').hasMatch(newAccountNumber)) {
      AppToast.showError(context, 'Account number must be 4-34 digits.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      // Two independent real endpoints: profile (name/phone) lives on
      // `users`, everything else lives on `affiliate_settings`.
      final results = await Future.wait([
        _authService.updateProfile(
          token: token,
          fullName: name,
          phone: _phoneController.text.trim(),
        ),
        _affiliateService.updateSettings(
          token,
          notifyNewReferrals: _emailNotifications,
          notifyPayouts: _payoutNotifications,
          bankName: _bankNameController.text.trim(),
          // Only sent when the user actually typed a new number. The full
          // value is never kept around client-side afterward — we drop it
          // and only hang on to the masked last4 the server hands back.
          bankAccountNumber: newAccountNumber.isEmpty ? null : newAccountNumber,
        ),
      ]);
      if (!mounted) return;
      final updatedSettings = results[1] as AffiliateSettings;
      setState(() {
        _bankAccountLast4 = updatedSettings.bankAccountLast4;
        _newAccountNumberController.clear();
        _editingAccountNumber = false;
      });
      AppToast.showSuccess(context, 'Settings saved.');
    } on AuthException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    } on AffiliateException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppToast.showError(context, 'Failed to save settings. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccentRed))
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.slate, size: 40),
                      const SizedBox(height: 12),
                      Text(_loadError!, style: const TextStyle(color: AppColors.slate)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: () { setState(() { _loading = true; _loadError = null; }); _load(); }, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
                          const CircleAvatar(
                            radius: 36,
                            backgroundColor: AppColors.border,
                            child: Icon(Icons.person_rounded, size: 34, color: AppColors.slate),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
                            child: const Text('Affiliater', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kAccentRed)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionLabel('Profile'),
                    const SizedBox(height: AppSpacing.sm),
                    _LabeledField(label: 'Full Name', controller: _nameController),
                    const SizedBox(height: AppSpacing.md),
                    _LabeledField(label: 'Email', initialValue: widget.user.email, enabled: false),
                    const SizedBox(height: AppSpacing.md),
                    _LabeledField(label: 'Phone', controller: _phoneController, keyboardType: TextInputType.phone),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionLabel('Payout Method'),
                    const SizedBox(height: AppSpacing.sm),
                    _LabeledField(label: 'Bank Name', controller: _bankNameController, hint: 'e.g. Commercial Bank of Ethiopia'),
                    const SizedBox(height: AppSpacing.md),
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
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionLabel('Notifications'),
                    const SizedBox(height: AppSpacing.sm),
                    _SwitchTile(
                      label: 'Email me about new referrals',
                      value: _emailNotifications,
                      onChanged: (v) => setState(() => _emailNotifications = v),
                    ),
                    _SwitchTile(
                      label: 'Notify me when a payout is sent',
                      value: _payoutNotifications,
                      onChanged: (v) => setState(() => _payoutNotifications = v),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(label: 'Save Changes', onPressed: _save, isLoading: _saving),
                    ),
                  ],
                ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _kAccentRed,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.slate, letterSpacing: 0.3));
  }
}

/// Shows the account number masked as "•••• 4821" (we only ever have the
/// last 4 digits client-side) with a "Change" action that reveals a blank
/// input for a brand-new number. The full number is never pre-filled —
/// there's nothing to pre-fill it *with*, since the server never sends it
/// back down.
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
              const Expanded(
                child: Text('New Account Number', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter full account number',
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: const BorderSide(color: _kAccentRed)),
            ),
          ),
          const SizedBox(height: 4),
          const Text('Saved as ••••, then only the last 4 digits are kept.', style: TextStyle(fontSize: 11, color: AppColors.slate)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Account Number', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  last4 != null && last4!.isNotEmpty ? '•••• $last4' : 'Not set',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
              TextButton(onPressed: onStartEditing, child: Text(last4 != null && last4!.isNotEmpty ? 'Change' : 'Add')),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.enabled = true,
    this.keyboardType,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
        const SizedBox(height: 6),
        TextField(
          controller: controller ?? (initialValue != null ? TextEditingController(text: initialValue) : null),
          enabled: enabled,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? AppColors.card : AppColors.border.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: const BorderSide(color: AppColors.border)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: const BorderSide(color: _kAccentRed)),
          ),
        ),
      ],
    );
  }
}
