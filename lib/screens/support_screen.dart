import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/faq_data.dart';
import '../models/agent_account.dart' show SupportTicket;
import '../models/auth_response.dart';
import '../services/support_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

enum _TicketCategory { account, payments, listings, bug, other }

extension _TicketCategoryX on _TicketCategory {
  String get label {
    switch (this) {
      case _TicketCategory.account:
        return 'Account';
      case _TicketCategory.payments:
        return 'Payments';
      case _TicketCategory.listings:
        return 'Listings & requests';
      case _TicketCategory.bug:
        return 'Report a bug';
      case _TicketCategory.other:
        return 'Other';
    }
  }

  String get apiValue {
    switch (this) {
      case _TicketCategory.account:
        return 'account';
      case _TicketCategory.payments:
        return 'payments';
      case _TicketCategory.listings:
        return 'listings';
      case _TicketCategory.bug:
        return 'bug';
      case _TicketCategory.other:
        return 'other';
    }
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'open':
      return 'Open';
    case 'in_progress':
      return 'In progress';
    case 'resolved':
      return 'Resolved';
    case 'closed':
      return 'Closed';
    default:
      return status;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'resolved':
    case 'closed':
      return AppColors.success;
    case 'in_progress':
      return AppColors.primaryYellow;
    default:
      return AppColors.slate;
  }
}

/// Real Support / Contact page: FAQs, a ticket submission form backed by
/// `POST /api/support-tickets`, that same user's ticket history via
/// `GET /api/support-tickets/me`, and direct contact details.
///
/// The backend route only requires *any* signed-in user (no role check),
/// so this one screen works for Visitor, Affiliater, Investor, etc. — not
/// just Agent, which is the only role that had a real version of this
/// before.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _service = SupportService();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  _TicketCategory _category = _TicketCategory.account;
  int? _expandedFaq;
  bool _submitting = false;

  List<SupportTicket> _tickets = [];
  bool _ticketsLoading = true;
  String? _ticketsError;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String? get _token => widget.user.token;

  bool get _canSubmit =>
      _subjectController.text.trim().isNotEmpty && _messageController.text.trim().isNotEmpty && !_submitting && _token != null;

  Future<void> _loadTickets() async {
    final token = _token;
    if (token == null) {
      setState(() {
        _ticketsLoading = false;
        _ticketsError = 'Sign in again to see your ticket history.';
      });
      return;
    }
    setState(() {
      _ticketsLoading = true;
      _ticketsError = null;
    });
    try {
      final tickets = await _service.myTickets(token: token);
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _ticketsLoading = false;
      });
    } on SupportServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _ticketsLoading = false;
        _ticketsError = e.message;
      });
    }
  }

  Future<void> _submitTicket() async {
    final token = _token;
    if (token == null) {
      AppToast.showError(context, 'Sign in again to submit a ticket.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final ticket = await _service.submitTicket(
        category: _category.apiValue,
        subject: _subjectController.text.trim(),
        body: _messageController.text.trim(),
        token: token,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _subjectController.clear();
        _messageController.clear();
        _category = _TicketCategory.account;
        _tickets = [ticket, ..._tickets];
      });
      AppToast.showSuccess(context, 'Ticket submitted. Our team typically replies within 24 hours.');
    } on SupportServiceException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _call() => launchUrl(Uri.parse('tel:+251900000000'));
  Future<void> _email() => launchUrl(Uri.parse('mailto:hello@ebn.et'));
  Future<void> _telegram() => launchUrl(Uri.parse('https://t.me/ebn_support'));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Support', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.lg)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.support_agent_outlined, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text('Talk to the EBN team', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  "Have a question about a request, a listing, or your account? Send us a ticket below and we'll get back to you.",
                  style: TextStyle(fontSize: 12.5, color: Colors.white60, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Frequently asked questions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                for (int i = 0; i < faqItems.length; i++) ...[
                  _FaqTile(
                    entry: faqItems[i],
                    expanded: _expandedFaq == i,
                    onTap: () => setState(() => _expandedFaq = _expandedFaq == i ? null : i),
                  ),
                  if (i != faqItems.length - 1) const Divider(height: 1, color: AppColors.border, indent: AppSpacing.md, endIndent: AppSpacing.md),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Submit a ticket', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<_TicketCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _TicketCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(controller: _subjectController, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Subject')),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _messageController,
                  onChanged: (_) => setState(() {}),
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Describe the issue', alignLabelWithHint: true),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(width: double.infinity, child: PrimaryButton(label: 'Submit ticket', isLoading: _submitting, onPressed: _canSubmit ? _submitTicket : null)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Your tickets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm),
          _buildTicketHistory(),
          const SizedBox(height: AppSpacing.lg),
          const Text('Other ways to reach us', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                _ContactRow(icon: Icons.call_outlined, label: 'Call support', value: '+251 90 000 0000', onTap: _call),
                const Divider(height: 1, color: AppColors.border, indent: AppSpacing.md, endIndent: AppSpacing.md),
                _ContactRow(icon: Icons.email_outlined, label: 'Email support', value: 'hello@ebn.et', onTap: _email),
                const Divider(height: 1, color: AppColors.border, indent: AppSpacing.md, endIndent: AppSpacing.md),
                _ContactRow(icon: Icons.send_outlined, label: 'Telegram', value: '@ebn_support', onTap: _telegram, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketHistory() {
    if (_ticketsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_ticketsError != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Expanded(child: Text(_ticketsError!, style: const TextStyle(fontSize: 12.5, color: AppColors.slate))),
            TextButton(onPressed: _loadTickets, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_tickets.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
        child: const Text(
          "You haven't submitted a ticket yet. Anything you send above will show up here.",
          style: TextStyle(fontSize: 12.5, color: AppColors.slate),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          for (int i = 0; i < _tickets.length; i++) ...[
            _TicketTile(ticket: _tickets[i]),
            if (i != _tickets.length - 1) const Divider(height: 1, color: AppColors.border, indent: AppSpacing.md, endIndent: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.entry, required this.expanded, required this.onTap});
  final FaqItem entry;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(entry.question, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink))),
                  Icon(expanded ? Icons.remove_circle_outline : Icons.add_circle_outline, size: 19, color: AppColors.slate),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 8),
                Text(entry.answer, style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket.subject, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 3),
                Text(
                  ticket.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.35),
                ),
                const SizedBox(height: 6),
                Text(
                  '${ticket.createdAt.day}/${ticket.createdAt.month}/${ticket.createdAt.year}',
                  style: const TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _statusColor(ticket.status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
            child: Text(
              _statusLabel(ticket.status),
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _statusColor(ticket.status)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.label, required this.value, required this.onTap, this.isLast = false});
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.ink),
              const SizedBox(width: AppSpacing.md),
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
