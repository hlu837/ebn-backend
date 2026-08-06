import 'package:flutter/material.dart';

import '../models/admin_settings_models.dart';
import '../services/admin_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Admin > Settings > Admin Accounts. Invite a new admin by email, revoke
/// access, and see who else has the dashboard.
class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key, required this.token, required this.currentAdminId});

  final String token;
  final String currentAdminId;

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  final AdminSettingsService _service = AdminSettingsService();

  List<AdminAccountSummary> _admins = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _service.fetchAdmins(token: widget.token);
      if (!mounted) return;
      setState(() {
        _admins = rows;
        _loading = false;
      });
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _invite() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Invite Admin'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Temporary password', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Invite')),
        ],
      ),
    );
    if (saved != true) return;

    try {
      await _service.inviteAdmin(
        fullName: nameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
        token: widget.token,
      );
      await _load();
      if (!mounted) return;
      AppToast.showSuccess(context, 'Admin account created.');
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _revoke(AdminAccountSummary admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke admin access?'),
        content: Text('${admin.fullName} (${admin.email}) will lose access to this dashboard.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Revoke')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.revokeAdmin(admin.id, token: widget.token);
      if (!mounted) return;
      setState(() => _admins.removeWhere((a) => a.id == admin.id));
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
        title: const Text('Admin Accounts'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Invite Admin'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
                  children: [
                    if (_admins.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Center(child: Text('No admin accounts found.', style: TextStyle(color: AppColors.slate))),
                      )
                    else
                      ..._admins.map((admin) {
                        final isSelf = admin.id == widget.currentAdminId;
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFF0F0EE),
                              child: Icon(Icons.admin_panel_settings_outlined, color: AppColors.ink),
                            ),
                            title: Text(
                              admin.fullName.isEmpty ? admin.email : admin.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              [admin.email, if (admin.phone != null) admin.phone!].join(' · '),
                              style: const TextStyle(fontSize: 12, color: AppColors.slate),
                            ),
                            trailing: isSelf
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('You', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger),
                                    onPressed: () => _revoke(admin),
                                    tooltip: 'Revoke',
                                  ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}
