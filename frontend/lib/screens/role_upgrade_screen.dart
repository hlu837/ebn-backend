import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../models/role_upgrade_request.dart';
import '../models/user_role.dart';
import '../services/role_upgrade_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

const _selectableRoles = [UserRole.affiliater, UserRole.agent, UserRole.investor];

/// Lets a signed-in Visitor request to switch to Affiliater, Agent /
/// Broker, or Investor, and shows the status of any request already in
/// flight. Opened from `VisitorAccountScreen`'s "Upgrade your role" row.
///
/// Submissions land in an Admin review queue (`role_upgrade_requests`
/// table) — approval flips `users.role` on the backend, so the person
/// needs to sign in again afterwards to land in their new workspace.
class RoleUpgradeScreen extends StatefulWidget {
  const RoleUpgradeScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<RoleUpgradeScreen> createState() => _RoleUpgradeScreenState();
}

class _RoleUpgradeScreenState extends State<RoleUpgradeScreen> {
  final _service = RoleUpgradeService();

  bool _loading = true;
  String? _loadError;
  List<RoleUpgradeRequest> _history = const [];

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
      final history = await _service.myRequests(token: widget.user.token ?? '');
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    } on RoleUpgradeServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    }
  }

  RoleUpgradeRequest? get _pendingRequest {
    for (final r in _history) {
      if (r.status == RoleUpgradeStatus.pending) return r;
    }
    return null;
  }

  Future<void> _openRequestSheet(UserRole role) async {
    final pending = _pendingRequest;
    if (pending != null) {
      AppToast.showError(
        context,
        "You already have a request to become ${pending.requestedRole.label} in review.",
      );
      return;
    }
    if (widget.user.role == role) {
      AppToast.showError(context, "You're already a${role == UserRole.agent ? 'n' : ''} ${role.label}.");
      return;
    }

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cloud,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RequestRoleSheet(
        role: role,
        onSubmit: (message, agencyOrLicense, fractionalInterest) async {
          await _service.submitRequest(
            requestedRole: role,
            message: message,
            agencyOrLicense: agencyOrLicense,
            interestedInFractionalInvesting: fractionalInterest,
            token: widget.user.token ?? '',
          );
        },
      ),
    );

    if (submitted == true) {
      if (!mounted) return;
      AppToast.showSuccess(context, 'Request sent — we\'ll notify you once it\'s reviewed.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pendingRequest;
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Upgrade Your Role', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorState(message: _loadError!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Text(
                        "You're currently a Visitor. Pick a path below to request a switch — an admin reviews every request before it takes effect.",
                        style: TextStyle(fontSize: 13, color: AppColors.slate, height: 1.4),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (pending != null) ...[
                        _PendingBanner(request: pending),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      for (final role in _selectableRoles) ...[
                        _RolePathCard(
                          role: role,
                          disabled: pending != null || widget.user.role == role,
                          isCurrentRole: widget.user.role == role,
                          onTap: () => _openRequestSheet(role),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, left: 4),
                          child: Text(
                            'REQUEST HISTORY',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.slate, letterSpacing: 0.6),
                          ),
                        ),
                        for (final r in _history) _HistoryRow(request: r),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.request});
  final RoleUpgradeRequest request;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryYellow.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.primaryYellow.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.ink, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your request to become ${request.requestedRole.label} is in review.',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePathCard extends StatelessWidget {
  const _RolePathCard({
    required this.role,
    required this.disabled,
    required this.isCurrentRole,
    required this.onTap,
  });

  final UserRole role;
  final bool disabled;
  final bool isCurrentRole;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: disabled ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: Color(0xFFF0F0EE), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(role.pitchIcon, color: const Color(0xFF4A4A45), size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(role.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(
                        isCurrentRole ? "That's your current role." : role.pitchLine,
                        style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.request});
  final RoleUpgradeRequest request;

  Color get _statusColor => switch (request.status) {
        RoleUpgradeStatus.approved => AppColors.success,
        RoleUpgradeStatus.rejected => AppColors.danger,
        RoleUpgradeStatus.pending => AppColors.primaryYellow,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Requested ${request.requestedRole.label}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  '${request.createdAt.month}/${request.createdAt.day}/${request.createdAt.year}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
                ),
                if (request.status == RoleUpgradeStatus.rejected && request.adminNote != null) ...[
                  const SizedBox(height: 4),
                  Text(request.adminNote!, style: const TextStyle(fontSize: 11.5, color: AppColors.slate, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _statusColor.withOpacity(0.14), borderRadius: BorderRadius.circular(AppRadii.pill)),
            child: Text(request.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor)),
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

/// Bottom sheet form for a single role's request — collects the
/// role-specific field (agency/license for Agent, fractional-investing
/// interest for Investor) plus an optional free-text message, mirroring
/// the role-specific fields on [SignUpScreen].
class _RequestRoleSheet extends StatefulWidget {
  const _RequestRoleSheet({required this.role, required this.onSubmit});

  final UserRole role;

  /// Throws [RoleUpgradeServiceException] on failure.
  final Future<void> Function(String? message, String? agencyOrLicense, bool interestedInFractionalInvesting) onSubmit;

  @override
  State<_RequestRoleSheet> createState() => _RequestRoleSheetState();
}

class _RequestRoleSheetState extends State<_RequestRoleSheet> {
  final _messageController = TextEditingController();
  final _agencyController = TextEditingController();
  bool _fractionalInterest = false;
  bool _submitting = false;
  String? _serverError;

  @override
  void dispose() {
    _messageController.dispose();
    _agencyController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_submitting) return false;
    if (widget.role == UserRole.agent) return _agencyController.text.trim().isNotEmpty;
    return true;
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _serverError = null;
    });
    try {
      await widget.onSubmit(
        _messageController.text,
        widget.role == UserRole.agent ? _agencyController.text : null,
        widget.role == UserRole.investor ? _fractionalInterest : false,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on RoleUpgradeServiceException catch (e) {
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Row(
              children: [
                Icon(widget.role.pitchIcon, size: 18, color: AppColors.ink),
                const SizedBox(width: 8),
                Expanded(child: Text('Request to become ${widget.role.label}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink))),
              ],
            ),
            const SizedBox(height: 6),
            Text(widget.role.pitchLine, style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4)),
            const SizedBox(height: AppSpacing.lg),
            if (widget.role == UserRole.agent) ...[
              TextField(
                controller: _agencyController,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Agency Name / License-ID Number',
                  hintText: 'e.g. Meridian Realty · LIC-88213',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "We'll verify this before approving — it's how we keep the marketplace trustworthy.",
                style: TextStyle(fontSize: 11.5, color: AppColors.slate, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (widget.role == UserRole.investor) ...[
              Material(
                color: AppColors.cloud,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: () => setState(() => _fractionalInterest = !_fractionalInterest),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _fractionalInterest,
                          onChanged: (v) => setState(() => _fractionalInterest = v ?? false),
                          activeColor: AppColors.ink,
                          checkColor: AppColors.primaryYellow,
                        ),
                        const Expanded(
                          child: Text('I am interested in fractional property investments.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.3)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Anything else you\'d like the reviewer to know? (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_serverError!, style: const TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Submit request',
                isLoading: _submitting,
                onPressed: _canSubmit ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
