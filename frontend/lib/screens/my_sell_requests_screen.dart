import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../models/sell_request.dart';
import '../providers/sell_request_controller.dart';
import '../theme/app_theme.dart';

/// Lets a Visitor track every property they've submitted to sell, through
/// every stage of the pipeline (see [SellRequestStatus]).
class MySellRequestsScreen extends StatefulWidget {
  const MySellRequestsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<MySellRequestsScreen> createState() => _MySellRequestsScreenState();
}

class _MySellRequestsScreenState extends State<MySellRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SellRequestController>().fetchByOwner(widget.user.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SellRequestController>();
    final requests = controller.byOwner(widget.user.id);

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('My sell requests', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: requests.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _SellRequestCard(request: requests[index]),
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
            const Icon(Icons.sell_outlined, size: 40, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            const Text("You haven't submitted a property yet.",
                textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 6),
            const Text(
              'Tap "Sell it here" from your dashboard to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.slate),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellRequestCard extends StatelessWidget {
  const _SellRequestCard({required this.request});
  final SellRequest request;

  Color get _statusColor => switch (request.status) {
        SellRequestStatus.pendingAdminApproval => AppColors.primaryYellowDark,
        SellRequestStatus.submissionRejected => AppColors.danger,
        SellRequestStatus.broadcasting => AppColors.primaryYellowDark,
        SellRequestStatus.openToBrokers => AppColors.primaryYellowDark,
        SellRequestStatus.claimed => const Color(0xFF3B82C4),
        SellRequestStatus.reportPendingApproval => AppColors.primaryYellowDark,
        SellRequestStatus.reportRejected => AppColors.danger,
        SellRequestStatus.listed => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    final rejectionNote = request.status == SellRequestStatus.submissionRejected
        ? request.submissionRejectionReason
        : request.status == SellRequestStatus.reportRejected
            ? request.reportRejectionReason
            : null;

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
          Text('${request.category.label} · ${request.city}', style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
          const SizedBox(height: 8),
          Text(request.statusDescription, style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4)),
          if (rejectionNote != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadii.sm)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(child: Text(rejectionNote, style: const TextStyle(fontSize: 12, color: AppColors.danger))),
                ],
              ),
            ),
          ],
          if (!request.isAgentListing && request.agentName != null && request.status != SellRequestStatus.submissionRejected) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.badge_outlined, size: 16, color: AppColors.slate),
                const SizedBox(width: 6),
                Text('Broker: ${request.agentName}', style: const TextStyle(fontSize: 12, color: AppColors.slate, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
