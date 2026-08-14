import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_response.dart';
import '../providers/loop_controller.dart';
import '../theme/app_theme.dart';

/// Full history of tour requests for either a Customer (every tour they've
/// ever requested) or an Agent (every tour ever dispatched/claimed to
/// them) — `GET /api/tour-requests?customerId=` or
/// `GET /api/tour-requests/agent/:agentId` respectively, any status.
class MyTourRequestsScreen extends StatefulWidget {
  const MyTourRequestsScreen({super.key, required this.user, this.forAgent = false});

  final AppUser user;

  /// False (default): this is the Customer's own tour-request history.
  /// True: this is an Agent viewing every tour ever routed to them.
  final bool forAgent;

  @override
  State<MyTourRequestsScreen> createState() => _MyTourRequestsScreenState();
}

class _MyTourRequestsScreenState extends State<MyTourRequestsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loop = context.read<LoopController>();
      final rows = widget.forAgent
          ? await loop.fetchAgentHistory(widget.user.id)
          : await loop.fetchCustomerHistory(widget.user.id);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: Text(
          widget.forAgent ? 'My Tour Dispatches' : 'My Tour Requests',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : _rows.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) => _TourRow(row: _rows[i], forAgent: widget.forAgent),
                        ),
        ),
      ),
    );
  }
}

class _TourRow extends StatelessWidget {
  const _TourRow({required this.row, required this.forAgent});

  final Map<String, dynamic> row;
  final bool forAgent;

  ({String label, Color color}) get _statusChip {
    switch (row['status'] as String?) {
      case 'pending_approval':
        return (label: 'Pending', color: AppColors.slate);
      case 'broadcasting':
        return (label: 'Broadcasting', color: AppColors.primaryYellow);
      case 'dispatched':
        return (label: 'Dispatched', color: AppColors.primaryYellow);
      case 'accepted':
        return (label: 'Accepted', color: AppColors.success);
      case 'declined':
        return (label: 'Declined', color: AppColors.danger);
      case 'expired':
        return (label: 'Expired', color: AppColors.danger);
      default:
        return (label: 'Unknown', color: AppColors.slate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chip = _statusChip;
    final title = row['asset_title'] as String? ?? 'Listing';
    final subtitleParts = <String>[
      if (forAgent) 'Customer: ${row['customer_name'] ?? 'Unknown'}' else if (row['agent_name'] != null) 'Agent: ${row['agent_name']}',
    ];
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                if (subtitleParts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitleParts.join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${createdAt.month}/${createdAt.day}/${createdAt.year}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: chip.color.withOpacity(0.15), borderRadius: BorderRadius.circular(AppRadii.pill)),
            child: Text(chip.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: chip.color)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tour_outlined, size: 48, color: AppColors.slate),
            SizedBox(height: AppSpacing.sm),
            Text('No tour requests yet.', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.slate)),
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
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate)),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
