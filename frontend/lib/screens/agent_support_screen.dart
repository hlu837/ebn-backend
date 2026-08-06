import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_response.dart';
import '../services/agent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

enum _TicketCategory { account, payments, listings, bug, other }

extension _TicketCategoryX on _TicketCategory {
  String get label {
    switch (this) {
      case _TicketCategory.account:
        return 'Account';
      case _TicketCategory.payments:
        return 'Payments & payouts';
      case _TicketCategory.listings:
        return 'Listings';
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

class _FaqEntry {
  final String question;
  final String answer;
  const _FaqEntry(this.question, this.answer);
}

const _kFaqs = [
  _FaqEntry('How do I get credited when a lead I claimed sells?', 'Your commission is added to your Wallet once the sale is confirmed by Admin. It shows as "Pending" until the deal clears, then moves to your available balance.'),
  _FaqEntry('Why am I not receiving nearby order dispatches?', 'Dispatches only reach you while you\'re marked Online (toggle on the Home tab) and your location has been set. Make sure location permissions are enabled for the app.'),
  _FaqEntry('How does the membership tier affect my listings?', 'Higher tiers raise your active listing cap and how prominently you appear in search and the Broker Network. See the Membership screen for the full perk breakdown per tier.'),
  _FaqEntry('How long do withdrawals take to clear?', 'Bank withdrawals from your Wallet are typically reviewed within 1–2 business days before the transfer is sent.'),
  _FaqEntry('Can I collaborate with other agents on a listing?', 'Yes — the Broker Network lets you browse nearby agents by specialty and start a referral or co-listing conversation directly from their profile.'),
];

/// FAQs, a live-chat entry point, a ticket submission form, and direct
/// contact details for the EBN support team.
///
/// FAQs are hardcoded copy (fine to keep static, or move to a CMS later).
/// "Start live chat" deep-links to the in-app Communication tab — there's
/// no separate real-time support inbox to wire it to yet. Ticket
/// submission posts to `POST /api/support-tickets`, which lands in the
/// Admin side's `admin_support_inbox` screen.
class AgentSupportScreen extends StatefulWidget {
  const AgentSupportScreen({super.key, required this.user, this.onStartLiveChat});

  final AppUser user;

  /// Optional callback to jump to the in-app chat tab. Falls back to a
  /// snackbar if not provided.
  final VoidCallback? onStartLiveChat;

  @override
  State<AgentSupportScreen> createState() => _AgentSupportScreenState();
}

class _AgentSupportScreenState extends State<AgentSupportScreen> {
  final _service = AgentService();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  _TicketCategory _category = _TicketCategory.account;
  int? _expandedFaq;
  bool _submitting = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _subjectController.text.trim().isNotEmpty && _messageController.text.trim().isNotEmpty && !_submitting;

  Future<void> _submitTicket() async {
    setState(() => _submitting = true);
    try {
      await _service.submitSupportTicket(
        category: _category.apiValue,
        subject: _subjectController.text.trim(),
        body: _messageController.text.trim(),
        token: widget.user.token ?? '',
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _subjectController.clear();
        _messageController.clear();
        _category = _TicketCategory.account;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket submitted. Our team typically replies within 24 hours.')),
      );
    } on AgentServiceException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _startLiveChat() {
    if (widget.onStartLiveChat != null) {
      widget.onStartLiveChat!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Live chat is opening in the Communication tab.')));
    }
  }

  Future<void> _call() => launchUrl(Uri.parse('tel:+251911000000'));
  Future<void> _email() => launchUrl(Uri.parse('mailto:support@ebn.et'));
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.support_agent_outlined, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text('Talk to the EBN team', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('Live chat is the fastest way to get help during business hours.', style: TextStyle(fontSize: 12.5, color: Colors.white60)),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryYellow, foregroundColor: Colors.white),
                    onPressed: _startLiveChat,
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Start live chat'),
                  ),
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
                for (int i = 0; i < _kFaqs.length; i++) ...[
                  _FaqTile(
                    entry: _kFaqs[i],
                    expanded: _expandedFaq == i,
                    onTap: () => setState(() => _expandedFaq = _expandedFaq == i ? null : i),
                  ),
                  if (i != _kFaqs.length - 1) const Divider(height: 1, color: AppColors.border, indent: AppSpacing.md, endIndent: AppSpacing.md),
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
                TextField(controller: _messageController, onChanged: (_) => setState(() {}), maxLines: 4, decoration: const InputDecoration(labelText: 'Describe the issue', alignLabelWithHint: true)),
                const SizedBox(height: AppSpacing.md),
                SizedBox(width: double.infinity, child: PrimaryButton(label: 'Submit ticket', isLoading: _submitting, onPressed: _canSubmit ? _submitTicket : null)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Other ways to reach us', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                _ContactRow(icon: Icons.call_outlined, label: 'Call support', value: '+251 91 100 0000', onTap: _call),
                const Divider(height: 1, color: AppColors.border, indent: AppSpacing.md, endIndent: AppSpacing.md),
                _ContactRow(icon: Icons.email_outlined, label: 'Email support', value: 'support@ebn.et', onTap: _email),
                const Divider(height: 1, color: AppColors.border, indent: AppSpacing.md, endIndent: AppSpacing.md),
                _ContactRow(icon: Icons.send_outlined, label: 'Telegram', value: '@ebn_support', onTap: _telegram, isLast: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.entry, required this.expanded, required this.onTap});
  final _FaqEntry entry;
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
