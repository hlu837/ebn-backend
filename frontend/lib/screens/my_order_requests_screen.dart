import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_response.dart';
import '../models/order_request.dart';
import '../providers/order_request_controller.dart';
import '../services/order_request_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Lets a Visitor track every "Order Us" requirement they've submitted —
/// mirrors [MySellRequestsScreen]'s pattern, just reading from
/// [OrderRequestController] instead of [SellRequestController].
class MyOrderRequestsScreen extends StatefulWidget {
  const MyOrderRequestsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<MyOrderRequestsScreen> createState() => _MyOrderRequestsScreenState();
}

class _MyOrderRequestsScreenState extends State<MyOrderRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<OrderRequestController>().fetchByRequester(widget.user.id);
    });
  }

  Future<void> _report(OrderRequest request) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
          title: const Text('Report this request', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Let us know what went wrong with this agent — we'll find you another one right away, no need to fill the form again.",
                style: TextStyle(fontSize: 12.5, color: AppColors.slate),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "What happened? (optional)",
                  filled: true,
                  fillColor: AppColors.cloud,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
    if (reason == null) return; // cancelled

    if (!mounted) return;
    try {
      await context.read<OrderRequestController>().report(
            request.id,
            requesterUserId: widget.user.id,
            reason: reason.isEmpty ? null : reason,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reported — we're finding you another agent.")),
      );
    } on OrderRequestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OrderRequestController>();
    final requests = controller.byRequester(widget.user.id);

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('My order requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: requests.isEmpty
          ? (controller.isLoading ? const Center(child: CircularProgressIndicator()) : const _EmptyState())
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _OrderRequestCard(request: requests[index], onReport: _report),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_add_check_circle_outlined, size: 40, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            const Text("You haven't submitted an order request yet.",
                textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text(
              'Tap "Order Us" from your dashboard to tell us what you\'re looking for.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderRequestCard extends StatelessWidget {
  const _OrderRequestCard({required this.request, required this.onReport});

  final OrderRequest request;
  final ValueChanged<OrderRequest> onReport;

  Color get _statusColor => switch (request.status) {
        OrderRequestStatus.broadcasting => AppColors.primaryYellowDark,
        OrderRequestStatus.agentConfirmed => AppColors.success,
        OrderRequestStatus.disputed => AppColors.danger,
        OrderRequestStatus.closed => AppColors.slate,
      };

  String get _submittedLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final d = request.submittedAt;
    return 'Submitted ${months[d.month - 1]} ${d.day}';
  }

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
              Expanded(
                child: Text(request.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _statusColor.withOpacity(0.14), borderRadius: BorderRadius.circular(AppRadii.pill)),
                child: Text(request.status.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${request.budgetSummary} · $_submittedLabel', style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
          const SizedBox(height: 2),
          Text('Location: ${request.locationSummary}', style: const TextStyle(fontSize: 12, color: AppColors.slate)),
          const SizedBox(height: 8),
          Text(request.status.visitorDescription, style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4)),

          if (request.status == OrderRequestStatus.agentConfirmed) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadii.sm)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${request.assignedAgentName ?? 'Your agent'} · ${request.assignedAgentPhone ?? ''}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                label: "Didn't work out? Report it",
                borderColor: AppColors.danger,
                textColor: AppColors.danger,
                onPressed: () => onReport(request),
              ),
            ),
          ],

          if (request.status == OrderRequestStatus.disputed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadii.sm)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      "We're re-broadcasting this to other nearby agents now.",
                      style: TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
