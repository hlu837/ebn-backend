import 'package:flutter/material.dart';
import '../models/agent_account.dart' show SupportTicket;
import '../models/auth_response.dart';
import '../services/support_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// Full ticket view + resolve toggle for a single support submission —
/// backed by `POST /api/support-tickets/:id/resolve`.
class AdminSupportMessageDetailScreen extends StatefulWidget {
  const AdminSupportMessageDetailScreen({super.key, required this.ticket, required this.user});

  final SupportTicket ticket;
  final AppUser user;

  @override
  State<AdminSupportMessageDetailScreen> createState() => _AdminSupportMessageDetailScreenState();
}

class _AdminSupportMessageDetailScreenState extends State<AdminSupportMessageDetailScreen> {
  final _replyCtrl = TextEditingController();
  final _service = SupportService();

  late SupportTicket _ticket = widget.ticket;
  bool _resolving = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  bool _sending = false;

  void _send() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    final token = widget.user.token;
    if (token == null) {
      AppToast.showError(context, 'Please sign in again.');
      return;
    }
    setState(() => _sending = true);
    try {
      final updated = await _service.adminReply(token: token, id: _ticket.id, response: text);
      if (!mounted) return;
      setState(() {
        _ticket = updated;
        _sending = false;
      });
      _replyCtrl.clear();
      AppToast.showSuccess(context, 'Reply sent — the sender has been notified.');
    } on SupportServiceException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _toggleResolved() async {
    final token = widget.user.token;
    if (token == null) {
      AppToast.showError(context, 'Please sign in again.');
      return;
    }
    if (_ticket.status == 'resolved') {
      // The backend only exposes a one-way "resolve" action — there's no
      // "reopen" endpoint, so that direction stays local-only for now.
      setState(() {
        _ticket = SupportTicket(
          id: _ticket.id,
          category: _ticket.category,
          subject: _ticket.subject,
          body: _ticket.body,
          status: 'open',
          createdAt: _ticket.createdAt,
          senderName: _ticket.senderName,
          senderContact: _ticket.senderContact,
          updatedAt: _ticket.updatedAt,
          adminResponse: _ticket.adminResponse,
          adminResponseAt: _ticket.adminResponseAt,
        );
      });
      return;
    }
    setState(() => _resolving = true);
    try {
      final updated = await _service.adminResolve(token: token, id: _ticket.id);
      if (!mounted) return;
      setState(() {
        _ticket = updated;
        _resolving = false;
      });
      AppToast.showSuccess(context, 'Marked as resolved.');
    } on SupportServiceException catch (e) {
      if (!mounted) return;
      setState(() => _resolving = false);
      AppToast.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _ticket;
    final isResolved = m.status == 'resolved';
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Message', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(m.subject, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('${m.senderName ?? 'Unknown'} · ${m.senderContact ?? '—'}',
                style: const TextStyle(fontSize: 13, color: AppColors.slate)),
            Text(_formatDate(m.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.slate)),
            const SizedBox(height: AppSpacing.lg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
              child: Text(m.body, style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.5)),
            ),

            if (m.adminResponse != null && m.adminResponse!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const Text('Your reply', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.slate)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryYellow.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppColors.primaryYellow.withValues(alpha: 0.25)),
                ),
                child: Text(m.adminResponse!, style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.5)),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
            Text(
              m.adminResponse == null || m.adminResponse!.trim().isEmpty ? 'Reply' : 'Send another reply',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _replyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Type your reply…'),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(label: _sending ? 'Sending…' : 'Send reply', onPressed: _sending ? null : _send),

            const SizedBox(height: AppSpacing.xl),
            SecondaryButton(
              label: isResolved ? 'Mark as open' : 'Mark as resolved',
              borderColor: isResolved ? AppColors.slate : AppColors.success,
              textColor: isResolved ? AppColors.slate : AppColors.success,
              onPressed: _resolving ? null : _toggleResolved,
            ),
          ],
        ),
      ),
    );
  }
}
