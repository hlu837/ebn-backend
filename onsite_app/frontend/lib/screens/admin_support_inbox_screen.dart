import 'package:flutter/material.dart';
import '../models/agent_account.dart' show SupportTicket;
import '../models/auth_response.dart';
import '../services/support_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_list_widgets.dart';
import 'admin_support_message_detail_screen.dart';

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// Admin's real support inbox — backed by `GET /api/support-tickets`, so
/// every ticket a Visitor/Agent/Affiliater actually submits through their
/// own Support screen lands here.
class AdminSupportInboxScreen extends StatefulWidget {
  const AdminSupportInboxScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AdminSupportInboxScreen> createState() => _AdminSupportInboxScreenState();
}

class _AdminSupportInboxScreenState extends State<AdminSupportInboxScreen> {
  final _service = SupportService();

  String _filter = 'Open';
  List<SupportTicket> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final token = widget.user.token;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Please sign in again.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tickets = await _service.adminList(token: token);
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } on SupportServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<SupportTicket> get _filtered => _tickets.where((t) {
        if (_filter == 'All') return true;
        if (_filter == 'Open') return t.status != 'resolved';
        return t.status == 'resolved';
      }).toList();

  @override
  Widget build(BuildContext context) {
    final messages = _filtered;
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Support Inbox', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AdminFilterChips(
                  options: const ['Open', 'Resolved', 'All'],
                  selected: _filter,
                  onSelected: (v) => setState(() => _filter = v),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _loadTickets)
                      : messages.isEmpty
                          ? const AdminEmptyState(message: 'Nothing here.', icon: Icons.mark_email_read_outlined)
                          : RefreshIndicator(
                              onRefresh: _loadTickets,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                                itemCount: messages.length,
                                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final m = messages[index];
                                  final isResolved = m.status == 'resolved';
                                  return AdminEntityRow(
                                    leadingIcon: Icons.mail_outline_rounded,
                                    title: m.subject,
                                    subtitle: '${m.senderName ?? 'Unknown'} · ${_formatDate(m.createdAt)}',
                                    trailingText: isResolved ? 'RESOLVED' : 'OPEN',
                                    trailingColor: isResolved ? AppColors.slate : AppColors.primaryYellowDark,
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => AdminSupportMessageDetailScreen(ticket: m, user: widget.user),
                                        ),
                                      );
                                      // Refetch — the detail screen may have changed the
                                      // ticket's resolved status server-side.
                                      _loadTickets();
                                    },
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.slate, fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
