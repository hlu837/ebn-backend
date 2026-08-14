import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../models/order_request.dart';
import '../providers/order_request_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Admin's oversight of the "Order Us" pipeline — every request is
/// broadcast to nearby agents automatically; Admin just watches: who's
/// still waiting on an agent, who's been confirmed, and who's been
/// reported so it can be re-broadcast.
class AdminOrderRequestsScreen extends StatefulWidget {
  const AdminOrderRequestsScreen({super.key});

  @override
  State<AdminOrderRequestsScreen> createState() => _AdminOrderRequestsScreenState();
}

class _AdminOrderRequestsScreenState extends State<AdminOrderRequestsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrderRequestController>().fetchAdminQueues();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _repost(OrderRequest request) async {
    final controller = context.read<OrderRequestController>();
    await _run(() async {
      await controller.adminRepost(request.id);
      if (!mounted) return;
      final updated = controller.all.firstWhere((r) => r.id == request.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Re-broadcast to ${updated.broadcastAgentIds.length} nearby agent(s).')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OrderRequestController>();

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Order requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.ink,
          unselectedLabelColor: AppColors.slate,
          indicatorColor: AppColors.primaryYellow,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Awaiting (${controller.broadcasting.length})'),
            Tab(text: 'Confirmed (${controller.confirmed.length})'),
            Tab(text: 'Disputed (${controller.disputed.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RequestsList(
            requests: controller.broadcasting,
            emptyMessage: 'Nothing waiting on an agent right now.',
            trailingBuilder: (r) => Text(
              r.broadcastAgentIds.isEmpty ? 'No agents nearby yet' : 'Sent to ${r.broadcastAgentIds.length} nearby agent(s)',
              style: const TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600),
            ),
          ),
          _RequestsList(
            requests: controller.confirmed,
            emptyMessage: 'No confirmed requests right now.',
            trailingBuilder: (r) => Text(
              'Agent: ${r.assignedAgentName ?? '—'} · ${r.assignedAgentPhone ?? ''}',
              style: const TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600),
            ),
          ),
          _RequestsList(
            requests: controller.disputed,
            emptyMessage: 'No disputes right now.',
            trailingBuilder: (r) => Text(
              r.disputeReason?.trim().isNotEmpty == true ? 'Reason: ${r.disputeReason}' : 'No reason given.',
              style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
            primaryLabel: 'Repost',
            onPrimary: _repost,
          ),
        ],
      ),
    );
  }
}

class _RequestsList extends StatelessWidget {
  const _RequestsList({
    required this.requests,
    required this.emptyMessage,
    required this.trailingBuilder,
    this.primaryLabel,
    this.onPrimary,
  });

  final List<OrderRequest> requests;
  final String emptyMessage;
  final Widget Function(OrderRequest r) trailingBuilder;
  final String? primaryLabel;
  final ValueChanged<OrderRequest>? onPrimary;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_rounded, size: 36, color: AppColors.slate),
              const SizedBox(height: AppSpacing.sm),
              Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final r = requests[index];
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
              Text(r.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 2),
              Text('${r.category.label} · ${r.budgetSummary}', style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
              const SizedBox(height: 6),
              Text('From: ${r.requesterName} · ${r.requesterPhone}', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
              Text('Location: ${r.locationSummary}', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
              const SizedBox(height: 6),
              Text(r.description, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.slate, height: 1.4)),
              const SizedBox(height: AppSpacing.sm),
              trailingBuilder(r),
              if (primaryLabel != null && onPrimary != null) ...[
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(label: primaryLabel!, backgroundColor: AppColors.primaryYellow, foregroundColor: Colors.white, onPressed: () => onPrimary!(r)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
