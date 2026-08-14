import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/affiliate_service.dart';

const _kAccentRed = AppColors.primaryYellow;

/// Formats a 'YYYY-MM' month key (as returned by the backend) into
/// something readable, e.g. '2026-07' -> 'July 2026'.
String _formatMonth(String key) {
  final parts = key.split('-');
  if (parts.length != 2) return key;
  final year = parts[0];
  final month = int.tryParse(parts[1]);
  if (month == null || month < 1 || month > 12) return key;
  const fullNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${fullNames[month - 1]} $year';
}

/// Performance overview for the Affiliater role: link clicks, conversion
/// rate, total referrals/commission, and a month-by-month breakdown.
///
/// Backed by the real `GET /api/affiliates/me/reports` endpoint via
/// [AffiliateService.getReports] — clicks come from the affiliate_clicks
/// table (logged every time a referral link is generated), referrals and
/// commission come from affiliate_referrals.
class AffiliateReportsScreen extends StatefulWidget {
  const AffiliateReportsScreen({super.key, required this.token});

  final String token;

  @override
  State<AffiliateReportsScreen> createState() => _AffiliateReportsScreenState();
}

class _AffiliateReportsScreenState extends State<AffiliateReportsScreen> {
  final _svc = AffiliateService();

  ReportsSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _token() => widget.token.isNotEmpty ? widget.token : null;

  Future<void> _load() async {
    final token = _token();
    if (token == null) {
      setState(() { _error = 'Not logged in.'; _loading = false; });
      return;
    }
    try {
      final summary = await _svc.getReports(token);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on AffiliateException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load reports.'; _loading = false; });
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : () { setState(() { _loading = true; _error = null; }); _load(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccentRed))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.slate, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.slate)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildLoaded(context, _summary!),
    );
  }

  Widget _buildLoaded(BuildContext context, ReportsSummary summary) {
    return RefreshIndicator(
      color: _kAccentRed,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.7,
            children: [
              _StatCard(icon: Icons.ads_click_rounded, label: 'Total Clicks', value: '${summary.totalClicks}', color: AppColors.ink),
              _StatCard(icon: Icons.groups_2_outlined, label: 'Referrals', value: '${summary.totalReferrals}', color: AppColors.ink),
              _StatCard(icon: Icons.percent_rounded, label: 'Conversion Rate', value: '${summary.conversionRate.toStringAsFixed(1)}%', color: AppColors.success),
              _StatCard(icon: Icons.payments_outlined, label: 'Total Commission', value: '${summary.totalCommission.toStringAsFixed(0)} ETB', color: _kAccentRed),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Monthly Breakdown', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          if (summary.monthly.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Text(
                  "No activity yet — share your referral link to start generating clicks.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            ...summary.monthly.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _MonthTile(data: m),
                )),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const _MonthTile({required this.data});

  final MonthlyReport data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_formatMonth(data.month), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _MiniStat(label: 'Clicks', value: '${data.clicks}'),
              _MiniStat(label: 'Referrals', value: '${data.referrals}'),
              _MiniStat(label: 'Commission', value: '${data.commission.toStringAsFixed(0)} ETB'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.slate)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
