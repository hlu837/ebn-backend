import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/customer_note_entry.dart';
import '../models/order_request.dart';
import '../models/sell_request.dart';
import '../providers/order_request_controller.dart';
import '../providers/sell_request_controller.dart';
import '../services/agent_service.dart';
import '../services/order_request_service.dart' show OrderRequestException;
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

enum _CustomerRole { buyer, seller }

enum _CustomerFilter { all, active, past }

/// One unified row combining both directions of business an Agent does
/// with a person: an "Order Us" requester (buyer/renter) they were
/// assigned, or a "Sell/Rent" owner whose property they claimed/inspected.
class _Customer {
  final String id;
  final String customerUserId;
  final String name;
  final String phone;
  final _CustomerRole role;
  final AssetCategorySlug category;
  final String statusLabel;
  final bool isActive;
  final DateTime since;

  /// Only set for [_CustomerRole.buyer] rows — the underlying order
  /// request's id/status, needed to offer the "Mark as Completed" action.
  final String? orderRequestId;
  final OrderRequestStatus? orderRequestStatus;

  const _Customer({
    required this.id,
    required this.customerUserId,
    required this.name,
    required this.phone,
    required this.role,
    required this.category,
    required this.statusLabel,
    required this.isActive,
    required this.since,
    this.orderRequestId,
    this.orderRequestStatus,
  });
}

/// Everyone the Agent has worked with, on either side of the platform:
/// people who submitted an "Order Us" requirement and got matched to this
/// agent, and property owners whose "Sell/Rent" submission this agent
/// claimed. Built from the same [OrderRequestController] /
/// [SellRequestController] state that powers the Leads and Property
/// Management tabs, so there's a single source of truth once this reads
/// from the real backend.
class AgentCustomersScreen extends StatefulWidget {
  const AgentCustomersScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AgentCustomersScreen> createState() => _AgentCustomersScreenState();
}

class _AgentCustomersScreenState extends State<AgentCustomersScreen> {
  final TextEditingController _search = TextEditingController();
  _CustomerFilter _filter = _CustomerFilter.all;

  final AgentService _agentService = AgentService();

  /// customerUserId -> that customer's note log, newest entry first.
  /// Loaded once up front so each card can show its latest entry
  /// immediately rather than firing its own request.
  Map<String, List<CustomerNoteEntry>> _notes = const {};
  bool _notesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final token = widget.user.token;
    if (token == null) return;
    try {
      final notes = await _agentService.fetchCustomerNotes(widget.user.id, token: token);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _notesLoaded = true;
      });
    } on AgentServiceException catch (_) {
      // Notes are a nice-to-have on this screen — leave cards editable
      // (they'll just start blank) rather than blocking the whole list.
      if (!mounted) return;
      setState(() => _notesLoaded = true);
    }
  }

  /// Appends a new entry to a customer's log. Optimistically shows it
  /// right away (with a local timestamp), then reconciles with the
  /// server's copy — or rolls back and surfaces an error if it fails.
  Future<void> _addNoteEntry(String customerUserId, String body) async {
    final token = widget.user.token;
    if (token == null) return;
    final existing = _notes[customerUserId] ?? const <CustomerNoteEntry>[];
    final optimistic = CustomerNoteEntry(id: 'pending-${DateTime.now().microsecondsSinceEpoch}', customerUserId: customerUserId, body: body, createdAt: DateTime.now());
    setState(() => _notes = {..._notes, customerUserId: [optimistic, ...existing]});
    try {
      final saved = await _agentService.addCustomerNoteEntry(widget.user.id, customerUserId, body, token: token);
      if (!mounted) return;
      setState(() => _notes = {..._notes, customerUserId: [saved, ...existing]});
    } on AgentServiceException catch (e) {
      if (!mounted) return;
      setState(() => _notes = {..._notes, customerUserId: existing});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Couldn't save note: ${e.message}")));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Customer> _buildCustomers(OrderRequestController orders, SellRequestController sells) {
    final buyers = orders.assignedToAgent(widget.user.id).map((r) => _Customer(
          id: 'order-${r.id}',
          customerUserId: r.requesterUserId,
          name: r.requesterName,
          phone: r.requesterPhone,
          role: _CustomerRole.buyer,
          category: r.category,
          statusLabel: r.status.agentLabel,
          isActive: r.status != OrderRequestStatus.closed,
          since: r.confirmedAt ?? r.submittedAt,
          orderRequestId: r.id,
          orderRequestStatus: r.status,
        ));

    final sellerRequests = <String, SellRequest>{};
    for (final r in [...sells.claimedBy(widget.user.id), ...sells.reportsPendingBy(widget.user.id), ...sells.listedBy(widget.user.id)]) {
      sellerRequests[r.id] = r;
    }
    final sellers = sellerRequests.values.map((r) => _Customer(
          id: 'sell-${r.id}',
          customerUserId: r.ownerUserId,
          name: r.ownerName,
          phone: r.ownerPhone,
          role: _CustomerRole.seller,
          category: r.category,
          statusLabel: r.status.label,
          isActive: r.status != SellRequestStatus.listed,
          since: r.claimedAt ?? r.submittedAt,
        ));

    final combined = [...buyers, ...sellers];
    combined.sort((a, b) => b.since.compareTo(a.since));
    return combined;
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderRequestController>();
    final sells = context.watch<SellRequestController>();
    var customers = _buildCustomers(orders, sells);

    if (_filter == _CustomerFilter.active) {
      customers = customers.where((c) => c.isActive).toList();
    } else if (_filter == _CustomerFilter.past) {
      customers = customers.where((c) => !c.isActive).toList();
    }
    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      customers = customers.where((c) => c.name.toLowerCase().contains(query)).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Customers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search customers',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slate),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.slate),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    for (final f in _CustomerFilter.values) ...[
                      Expanded(child: _FilterChip(label: _filterLabel(f), selected: _filter == f, onTap: () => setState(() => _filter = f))),
                      if (f != _CustomerFilter.values.last) const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: customers.isEmpty
                ? _EmptyState(hasAny: _buildCustomers(orders, sells).isNotEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _CustomerCard(
                      customer: customers[i],
                      agentId: widget.user.id,
                      entries: _notes[customers[i].customerUserId] ?? const [],
                      onAddNoteEntry: (body) async => _addNoteEntry(customers[i].customerUserId, body),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(_CustomerFilter f) => switch (f) {
        _CustomerFilter.all => 'All',
        _CustomerFilter.active => 'Active',
        _CustomerFilter.past => 'Past',
      };
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.pill), border: Border.all(color: selected ? AppColors.ink : AppColors.border)),
          child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.ink)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAny});
  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 40, color: AppColors.slate),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hasAny ? 'No customers match this filter.' : "You haven't worked with any customers yet — accepted leads and claimed listings will show up here.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.slate, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatefulWidget {
  const _CustomerCard({required this.customer, required this.agentId, required this.entries, required this.onAddNoteEntry});
  final _Customer customer;
  final String agentId;

  /// This customer's note log, newest entry first (may be empty). Owned
  /// by the parent screen so it stays in sync across every row for the
  /// same customer (e.g. a buyer who's also a past seller).
  final List<CustomerNoteEntry> entries;
  final Future<void> Function(String body) onAddNoteEntry;

  @override
  State<_CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<_CustomerCard> {
  bool _completing = false;
  bool _reporting = false;

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: widget.customer.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _message() async {
    final uri = Uri(scheme: 'sms', path: widget.customer.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openNoteLog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cloud,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NoteLogSheet(customerName: widget.customer.name, entries: widget.entries, onAddEntry: widget.onAddNoteEntry),
    );
  }

  Future<void> _markCompleted() async {
    final orderRequestId = widget.customer.orderRequestId;
    if (orderRequestId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as completed?'),
        content: const Text("Confirm you've completed this request?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _completing = true);
    try {
      await context.read<OrderRequestController>().agentComplete(orderRequestId, agentId: widget.agentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request marked as completed.')));
    } on OrderRequestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Future<void> _reportIssue() async {
    final orderRequestId = widget.customer.orderRequestId;
    if (orderRequestId == null) return;

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report an issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This sends the request back to Admin to find another agent — use it when you can't complete this one (client unreachable, deal fell through, etc).",
              style: TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'What happened? (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Report')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final reason = reasonController.text.trim();
    setState(() => _reporting = true);
    try {
      await context.read<OrderRequestController>().agentReport(orderRequestId, agentId: widget.agentId, reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reported to Admin — they'll find another agent for this one.")));
    } on OrderRequestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;
    final canComplete = c.role == _CustomerRole.buyer && c.orderRequestStatus == OrderRequestStatus.agentConfirmed;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.border,
            child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(c.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    _RoleBadge(role: c.role),
                  ],
                ),
                const SizedBox(height: 3),
                Text('${c.category.label} · ${c.statusLabel}', style: const TextStyle(fontSize: 12, color: AppColors.slate), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _ActionButton(icon: Icons.call_rounded, label: 'Call', onTap: _call)),
                    const SizedBox(width: 8),
                    Expanded(child: _ActionButton(icon: Icons.sms_outlined, label: 'Message', onTap: _message)),
                  ],
                ),
                const SizedBox(height: 8),
                _NotePreview(entries: widget.entries, onTap: _openNoteLog),
                if (canComplete) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Mark as Completed',
                      isLoading: _completing,
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      onPressed: _completing ? null : _markCompleted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                      onPressed: _reporting ? null : _reportIssue,
                      icon: _reporting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.flag_outlined, size: 16),
                      label: const Text('Report an Issue'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});
  final _CustomerRole role;

  @override
  Widget build(BuildContext context) {
    final label = role == _CustomerRole.buyer ? 'Buyer' : 'Seller';
    final color = role == _CustomerRole.buyer ? AppColors.success : AppColors.primaryYellow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cloud,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: AppColors.ink),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

const List<String> _noteMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _formatNoteTimestamp(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final ampm = dt.hour < 12 ? 'AM' : 'PM';
  final min = dt.minute.toString().padLeft(2, '0');
  return '${_noteMonths[dt.month - 1]} ${dt.day} · $h:$min $ampm';
}

/// Tappable strip under a customer's actions showing the latest note
/// entry (or a placeholder prompting the agent to log one) plus how many
/// prior entries exist — mirrors the whole card's pill/border language
/// rather than looking like a plain text row.
class _NotePreview extends StatelessWidget {
  const _NotePreview({required this.entries, required this.onTap});
  final List<CustomerNoteEntry> entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasEntries = entries.isNotEmpty;
    final latest = hasEntries ? entries.first : null;
    return Material(
      color: AppColors.cloud,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Icon(hasEntries ? Icons.sticky_note_2_outlined : Icons.note_add_outlined, size: 15, color: AppColors.slate),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasEntries ? latest!.body : 'Log a note about this customer',
                  style: TextStyle(fontSize: 12, color: hasEntries ? AppColors.ink : AppColors.slate, fontStyle: hasEntries ? FontStyle.normal : FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (entries.length > 1) ...[
                const SizedBox(width: 6),
                Text('+${entries.length - 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slate)),
              ],
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet showing a customer's full note log, newest first, with a
/// field at the bottom to log a new entry — e.g. "called 8/1 — wants to
/// see it Saturday". Each entry is saved as soon as it's added (via
/// [onAddEntry]) rather than batched on close, so logging several calls
/// in one sitting still produces several distinct, separately-timestamped
/// entries. Past entries are never edited, only added to.
class _NoteLogSheet extends StatefulWidget {
  const _NoteLogSheet({required this.customerName, required this.entries, required this.onAddEntry});
  final String customerName;
  final List<CustomerNoteEntry> entries;
  final Future<void> Function(String body) onAddEntry;

  @override
  State<_NoteLogSheet> createState() => _NoteLogSheetState();
}

class _NoteLogSheetState extends State<_NoteLogSheet> {
  final TextEditingController _controller = TextEditingController();
  final List<CustomerNoteEntry> _localAdds = [];
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _localAdds.insert(0, CustomerNoteEntry(id: 'local', customerUserId: '', body: text, createdAt: DateTime.now()));
      _controller.clear();
    });
    try {
      await widget.onAddEntry(text);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allEntries = [..._localAdds, ...widget.entries];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              Row(
                children: [
                  Expanded(child: Text('Notes · ${widget.customerName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink))),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text('Only visible to you — a running log of calls, preferences, and follow-ups.', style: TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.35)),
              const SizedBox(height: AppSpacing.md),
              if (allEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('No notes yet — log your first one below.', style: TextStyle(fontSize: 12.5, color: AppColors.slate, fontStyle: FontStyle.italic)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: allEntries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = allEntries[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.sm), border: Border.all(color: AppColors.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatNoteTimestamp(e.createdAt), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.slate)),
                            const SizedBox(height: 2),
                            Text(e.body, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.3)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      decoration: InputDecoration(
                        hintText: 'e.g. Called — wants to see it Saturday',
                        filled: true,
                        fillColor: AppColors.card,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: const BorderSide(color: AppColors.border)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(onPressed: _saving ? null : _add, icon: const Icon(Icons.arrow_upward_rounded)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
