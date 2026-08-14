import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_list_widgets.dart';

/// Analytics/reporting page, scoped to what the backend can actually
/// answer today: sell/order request volume + conversion, and the live
/// catalog's category breakdown. Agent leaderboard and approval-speed
/// stats aren't in this cut — there's no per-agent aggregate or
/// timestamp-diff query for those yet.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final ReportService _reportService = ReportService();

  Map<String, dynamic>? _overview;
  bool _loading = true;
  String? _error;

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
      final overview = await _reportService.fetchOverview(token: widget.token);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
    } on ReportServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
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
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded, size: 34, color: AppColors.slate),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 14),
                          OutlinedButton(onPressed: _load, child: const Text('Try again')),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _buildOverview(_overview!),
                  ),
      ),
    );
  }

  Widget _buildOverview(Map<String, dynamic> overview) {
    final sellRequests = overview['sellRequests'] as Map<String, dynamic>;
    final orderRequests = overview['orderRequests'] as Map<String, dynamic>;
    final byCategory = (overview['listingsByCategory'] as List).cast<Map<String, dynamic>>();
    final dailyVolume = (overview['dailyVolume'] as List).cast<Map<String, dynamic>>();

    final dailyCounts = dailyVolume.map((d) => (d['count'] as num).toInt()).toList();
    final maxVolume = dailyCounts.isEmpty ? 1 : dailyCounts.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // ── Summary stat cards ───────────────────────────────────────
        Row(
          children: [
            AdminStatCard(value: '${sellRequests['total']}', label: 'Sell Requests'),
            const SizedBox(width: AppSpacing.sm),
            AdminStatCard(value: '${sellRequests['conversionRatePercent']}%', label: 'Sell Conversion'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            AdminStatCard(value: '${orderRequests['total']}', label: 'Order Requests'),
            const SizedBox(width: AppSpacing.sm),
            AdminStatCard(value: '${orderRequests['conversionRatePercent']}%', label: 'Order Conversion'),
          ],
        ),

        // ── Simple bar chart ─────────────────────────────────────────
        const SizedBox(height: AppSpacing.xl),
        const Text('Sell request submissions — last 7 days', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 140,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
          child: dailyCounts.every((c) => c == 0)
              ? const Center(
                  child: Text('No submissions in the last 7 days.', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < dailyCounts.length; i++) ...[
                      Expanded(
                        child: FractionallySizedBox(
                          heightFactor: dailyCounts[i] / maxVolume,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primaryYellow,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                          ),
                        ),
                      ),
                      if (i != dailyCounts.length - 1) const SizedBox(width: 6),
                    ],
                  ],
                ),
        ),

        // ── Category breakdown table ─────────────────────────────────
        const SizedBox(height: AppSpacing.xl),
        const Text('Live catalog by category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
          child: byCategory.isEmpty
              ? const Text('No active listings yet.', style: TextStyle(fontSize: 13, color: AppColors.slate))
              : Column(
                  children: [
                    for (var i = 0; i < byCategory.length; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              byCategory[i]['category'] as String,
                              style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text('${byCategory[i]['count']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
                        ],
                      ),
                      if (i != byCategory.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),

        // ── Funnel detail ────────────────────────────────────────────
        const SizedBox(height: AppSpacing.xl),
        const Text('Sell request funnel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: AppSpacing.sm),
        AdminEntityRow(leadingIcon: Icons.check_circle_outline_rounded, title: 'Listed', subtitle: 'Reached a live listing', trailingText: '${sellRequests['listed']}'),
        const SizedBox(height: AppSpacing.sm),
        AdminEntityRow(leadingIcon: Icons.hourglass_empty_rounded, title: 'In progress', subtitle: 'Still moving through the pipeline', trailingText: '${sellRequests['inProgress']}'),
        const SizedBox(height: AppSpacing.sm),
        AdminEntityRow(leadingIcon: Icons.cancel_outlined, title: 'Rejected', subtitle: 'Submission or report rejected', trailingText: '${sellRequests['rejected']}'),

        const SizedBox(height: AppSpacing.xl),
        const Text('Order request funnel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: AppSpacing.sm),
        AdminEntityRow(leadingIcon: Icons.check_circle_outline_rounded, title: 'Closed', subtitle: 'Fulfilled or resolved', trailingText: '${orderRequests['closed']}'),
        const SizedBox(height: AppSpacing.sm),
        AdminEntityRow(leadingIcon: Icons.hourglass_empty_rounded, title: 'In progress', subtitle: 'Broadcasting or agent-confirmed', trailingText: '${orderRequests['inProgress']}'),
        const SizedBox(height: AppSpacing.sm),
        AdminEntityRow(leadingIcon: Icons.report_gmailerrorred_rounded, title: 'Disputed', subtitle: 'Reported — may get re-broadcast', trailingText: '${orderRequests['disputed']}'),
      ],
    );
  }
}
