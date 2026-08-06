import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../models/role_upgrade_request.dart';
import '../models/user_role.dart';
import '../services/role_upgrade_service.dart';
import '../theme/app_theme.dart';

/// Admin's queue for role-upgrade requests — Visitors asking to become an
/// Affiliater, Agent / Broker, or Investor. Approving flips the
/// requester's `users.role`; they'll see their new workspace next time
/// they sign in (see the note in `role_upgrade_requests.js`'s `/approve`
/// route).
class AdminRoleUpgradeRequestsScreen extends StatefulWidget {
  const AdminRoleUpgradeRequestsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminRoleUpgradeRequestsScreen> createState() => _AdminRoleUpgradeRequestsScreenState();
}

class _AdminRoleUpgradeRequestsScreenState extends State<AdminRoleUpgradeRequestsScreen> {
  final _service = RoleUpgradeService();

  bool _loading = true;
  String? _loadError;
  List<RoleUpgradeRequest> _pending = const [];
  final Set<String> _busyIds = {};

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
      final rows = await _service.fetchPending(token: widget.user.token ?? '');
      if (!mounted) return;
      setState(() {
        _pending = rows;
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

  Future<String?> _promptNote(String title, String hint, {required bool isReject}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.cloud,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isReject ? AppColors.danger : AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(isReject ? 'Reject' : 'Approve'),
          ),
        ],
      ),
    );
  }

  Future<void> _approve(RoleUpgradeRequest request) async {
    final note = await _promptNote(
      'Approve ${request.userFullName ?? 'this request'}?',
      'Optional note (visible to the requester)',
      isReject: false,
    );
    if (note == null) return;
    setState(() => _busyIds.add(request.id));
    try {
      await _service.approve(request.id, adminNote: note, token: widget.user.token ?? '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${request.userFullName} is now ${request.requestedRole.label}.')));
      setState(() => _pending = _pending.where((r) => r.id != request.id).toList());
    } on RoleUpgradeServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  Future<void> _reject(RoleUpgradeRequest request) async {
    final reason = await _promptNote(
      'Reject this request?',
      'Why is this being declined? (sent to the requester)',
      isReject: true,
    );
    if (reason == null) return;
    setState(() => _busyIds.add(request.id));
    try {
      await _service.reject(request.id, adminNote: reason, token: widget.user.token ?? '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request declined.')));
      setState(() => _pending = _pending.where((r) => r.id != request.id).toList());
    } on RoleUpgradeServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyIds.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: Text('Role Upgrade Requests${_pending.isEmpty ? '' : ' (${_pending.length})'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorState(message: _loadError!, onRetry: _load)
              : _pending.isEmpty
                  ? const _EmptyQueue()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: _pending.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final r = _pending[i];
                          final busy = _busyIds.contains(r.id);
                          return _RequestCard(
                            request: r,
                            busy: busy,
                            onApprove: () => _approve(r),
                            onReject: () => _reject(r),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.busy, required this.onApprove, required this.onReject});

  final RoleUpgradeRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Color(0xFFF0F0EE), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(request.requestedRole.pitchIcon, size: 19, color: const Color(0xFF4A4A45)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.userFullName ?? 'Unknown', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    Text(request.userEmail ?? '', style: const TextStyle(fontSize: 11.5, color: AppColors.slate)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.14), borderRadius: BorderRadius.circular(AppRadii.pill)),
                child: Text('\u2192 ${request.requestedRole.label}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (request.currentRole != null)
            Text(
              'Currently: ${UserRole.values.firstWhere((r) => r.apiValue == request.currentRole, orElse: () => UserRole.user).label}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate),
            ),
          if (request.agencyOrLicense != null && request.agencyOrLicense!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Agency / License: ${request.agencyOrLicense}', style: const TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w600)),
          ],
          if (request.interestedInFractionalInvesting) ...[
            const SizedBox(height: 4),
            const Text('Interested in fractional investing', style: TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w600)),
          ],
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.cloud, borderRadius: BorderRadius.circular(AppRadii.sm)),
              child: Text('"${request.message}"', style: const TextStyle(fontSize: 12.5, color: AppColors.slate, fontStyle: FontStyle.italic)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: busy ? null : onApprove,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                  child: busy
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            const Text('No role upgrade requests waiting on review.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: AppColors.slate)),
          ],
        ),
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
