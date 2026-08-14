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

  void _showReceiptDialog(BuildContext context, String payer, String amountStr, String ref, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A), // Blue theme for CBE
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 48),
                  const SizedBox(height: 8),
                  const Text(
                    'Transaction Successful',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    amountStr,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _ReceiptField(label: 'Payer Name', value: payer),
                  const _ReceiptField(label: 'Payee Name', value: 'AEBNG Trading PLC'),
                  _ReceiptField(label: 'Reference Number', value: ref),
                  _ReceiptField(label: 'File Attached', value: fileName),
                  _ReceiptField(label: 'Payment Method', value: ref.startsWith('Tele') || ref.startsWith('09') ? 'Telebirr Transfer' : 'CBE Transfer'),
                  _ReceiptField(label: 'Timestamp', value: DateTime.now().toString().split('.').first),
                ],
              ),
            ),
            const Divider(height: 1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = request.message ?? '';
    final refMatch = RegExp(r'Reference: #([^\s.]+)').firstMatch(message);
    final fileMatch = RegExp(r'File: ([^\s.]+\.[a-zA-Z0-9]+)').firstMatch(message);
    final priceMatch = RegExp(r'\(([^)]+)\)').firstMatch(message);

    final refNum = refMatch?.group(1);
    final fileName = fileMatch?.group(1);
    final amountStr = priceMatch?.group(1) ?? '1,500,000 ETB';

    final isBankTransfer = refNum != null;

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
          
          if (isBankTransfer) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7), // Light amber/yellow
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.payment_rounded, color: Color(0xFFD97706), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Bank Transfer Payment',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E), fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Reference: #$refNum', style: const TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w700)),
                  Text('Amount: $amountStr', style: const TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 28,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD97706)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
                      ),
                      onPressed: () => _showReceiptDialog(context, request.userFullName ?? 'Payer', amountStr, refNum, fileName ?? 'receipt.png'),
                      icon: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFFD97706)),
                      label: const Text('View Uploaded Receipt', style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (request.message != null && request.message!.isNotEmpty) ...[
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

class _ReceiptField extends StatelessWidget {
  const _ReceiptField({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.slate, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt_rounded, size: 40, color: AppColors.slate),
            SizedBox(height: AppSpacing.md),
            Text('No role upgrade requests waiting on review.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: AppColors.slate)),
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
