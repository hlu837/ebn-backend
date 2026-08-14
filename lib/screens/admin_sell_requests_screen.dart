import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../models/sell_request.dart';
import '../providers/sell_request_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Admin's queue for the "sell my property" pipeline — two stages to
/// screen: brand-new Visitor submissions, and Agent inspection reports
/// that are ready for final sign-off before going live.
class AdminSellRequestsScreen extends StatefulWidget {
  const AdminSellRequestsScreen({super.key});

  @override
  State<AdminSellRequestsScreen> createState() => _AdminSellRequestsScreenState();
}

class _AdminSellRequestsScreenState extends State<AdminSellRequestsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SellRequestController>().fetchAdminQueues();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Runs a backend action and surfaces any failure as a SnackBar instead
  /// of letting it become an unhandled Future rejection.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<String?> _promptReason(String title, String hint) {
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SellRequestController>();

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Sell requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.ink,
          unselectedLabelColor: AppColors.slate,
          indicatorColor: AppColors.primaryYellow,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Submissions (${controller.pendingSubmissions.length})'),
            Tab(text: 'Reports (${controller.pendingReports.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SubmissionsTab(
            requests: controller.pendingSubmissions,
            onApprove: (id) => _run(() => controller.adminApproveSubmission(id)),
            onReject: (id) async {
              final reason = await _promptReason('Reject submission', 'Why is this being rejected?');
              if (reason != null) _run(() => controller.adminRejectSubmission(id, reason: reason));
            },
          ),
          _ReportsTab(
            requests: controller.pendingReports,
            onApprove: (id) => _run(() => controller.adminApproveReport(id)),
            onReject: (id) async {
              final reason = await _promptReason('Send report back', 'What needs to change?');
              if (reason != null) _run(() => controller.adminRejectReport(id, reason: reason));
            },
          ),
        ],
      ),
    );
  }
}

class _SubmissionsTab extends StatelessWidget {
  const _SubmissionsTab({required this.requests, required this.onApprove, required this.onReject});

  final List<SellRequest> requests;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _EmptyQueue(message: 'No new submissions waiting on review.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final r = requests[index];
        return _QueueCard(
          title: r.title,
          subtitle: '${r.category.label} · ${r.city} · ETB ${r.askingPrice.toStringAsFixed(0)}',
          badge: r.isAgentListing ? 'Agent listing' : null,
          detailLines: [
            r.isAgentListing
                ? 'Agent (own listing): ${r.agentName ?? r.ownerName} · ${r.ownerPhone}'
                : 'From: ${r.ownerName} · ${r.ownerPhone}',
            r.addressLine,
            r.description,
            if (r.isAgentListing)
              '${r.reportMedia.where((m) => !m.isVideo).length} photo(s) · ${r.reportMedia.where((m) => m.isVideo).length} video(s)',
            if (r.isAgentListing && r.reportNotes?.isNotEmpty == true) r.reportNotes!,
            'Fee paid: ETB ${r.feeAmount.toStringAsFixed(0)}',
          ],
          primaryLabel: r.isAgentListing ? 'Approve & publish listing' : 'Approve → open to brokers',
          onPrimary: () => onApprove(r.id),
          onSecondary: () => onReject(r.id),
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({required this.requests, required this.onApprove, required this.onReject});

  final List<SellRequest> requests;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const _EmptyQueue(message: 'No inspection reports waiting on review.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final r = requests[index];
        return _QueueCard(
          title: r.title,
          subtitle: '${r.category.label} · ${r.city} · ETB ${r.askingPrice.toStringAsFixed(0)}',
          detailLines: [
            'Inspected by: ${r.agentName ?? 'Agent'}',
            '${r.reportMedia.where((m) => !m.isVideo).length} photo(s) · ${r.reportMedia.where((m) => m.isVideo).length} video(s)',
            if (r.reportNotes?.isNotEmpty == true) r.reportNotes!,
          ],
          primaryLabel: 'Approve & publish listing',
          onPrimary: () => onApprove(r.id),
          onSecondary: () => onReject(r.id),
        );
      },
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({
    required this.title,
    required this.subtitle,
    required this.detailLines,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    this.badge,
  });

  final String title;
  final String subtitle;
  final List<String> detailLines;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final String? badge;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink))),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.16), borderRadius: BorderRadius.circular(AppRadii.pill)),
                  child: Text(badge!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primaryYellowDark)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
          const SizedBox(height: 8),
          for (final line in detailLines.where((l) => l.trim().isNotEmpty)) ...[
            Text(line, style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.4)),
            const SizedBox(height: 2),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(label: 'Reject', borderColor: AppColors.danger, textColor: AppColors.danger, onPressed: onSecondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: PrimaryButton(label: primaryLabel, backgroundColor: AppColors.primaryYellow, foregroundColor: Colors.white, onPressed: onPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_rounded, size: 36, color: AppColors.slate),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
