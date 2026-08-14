import 'package:flutter/material.dart';
import '../models/admin_transaction.dart';
import '../services/admin_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_list_widgets.dart';

/// Admin's "Transactions" ledger — a real read of `GET /api/transactions`,
/// which exposes the same `payments` table every Chapa checkout already
/// writes to (see backend/src/routes/payments.js). Was page-local mock
/// data (`_sampleTransactions`) until this route existed.
class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminTransactionsScreen> createState() => _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState extends State<AdminTransactionsScreen> {
  final AdminService _adminService = AdminService();

  String _filter = 'All';
  List<AdminTransaction> _transactions = const [];
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
      final rows = await _adminService.fetchTransactions(token: widget.token);
      if (!mounted) return;
      setState(() {
        _transactions = rows;
        _loading = false;
      });
    } on AdminServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  List<AdminTransaction> get _filtered =>
      _transactions.where((t) => _filter == 'All' || _statusLabel(t.status) == _filter).toList();

  static String _statusLabel(String status) => switch (status) {
        'success' => 'Paid',
        'pending' => 'Pending',
        'failed' => 'Failed',
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'success' => AppColors.success,
        'pending' => AppColors.primaryYellowDark,
        'failed' => AppColors.danger,
        _ => AppColors.slate,
      };

  String _purposeLabel(String purpose) {
    // Backend purposes are snake_case identifiers (e.g. 'sell_request_fee') —
    // this is the only place that needs a human label for one.
    return purpose.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  void _openDetail(AdminTransaction t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_purposeLabel(t.purpose), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 8),
            Text('Payer: ${t.payerLabel}', style: const TextStyle(fontSize: 13, color: AppColors.slate)),
            Text('Amount: ${t.currency} ${t.amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: AppColors.slate)),
            Text('Reference: ${t.txRef}', style: const TextStyle(fontSize: 13, color: AppColors.slate)),
            Text('Date: ${_dateLabel(t.createdAt)}', style: const TextStyle(fontSize: 13, color: AppColors.slate)),
            Text('Status: ${_statusLabel(t.status)}', style: const TextStyle(fontSize: 13, color: AppColors.slate)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = _filtered;
    final now = DateTime.now();
    final totalCollected = _transactions.where((t) => t.status == 'success').fold<double>(0, (sum, t) => sum + t.amount);
    final pendingCount = _transactions.where((t) => t.status == 'pending').length;
    final thisMonth = _transactions
        .where((t) => t.status == 'success' && t.createdAt.year == now.year && t.createdAt.month == now.month)
        .fold<double>(0, (sum, t) => sum + t.amount);

    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Transactions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Column(
                children: [
                  Row(
                    children: [
                      AdminStatCard(value: 'ETB ${totalCollected.toStringAsFixed(0)}', label: 'Total Collected'),
                      const SizedBox(width: AppSpacing.sm),
                      AdminStatCard(value: '$pendingCount', label: 'Pending'),
                      const SizedBox(width: AppSpacing.sm),
                      AdminStatCard(value: 'ETB ${thisMonth.toStringAsFixed(0)}', label: 'This Month'),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AdminFilterChips(
                      options: const ['All', 'Paid', 'Pending', 'Failed'],
                      selected: _filter,
                      onSelected: (v) => setState(() => _filter = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorState(message: _error!, onRetry: _load)
                      : transactions.isEmpty
                          ? const AdminEmptyState(message: 'No transactions match this filter.', icon: Icons.receipt_long_outlined)
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                                itemCount: transactions.length,
                                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final t = transactions[index];
                                  return AdminEntityRow(
                                    leadingIcon: Icons.receipt_long_outlined,
                                    title: _purposeLabel(t.purpose),
                                    subtitle: '${t.payerLabel} · ${t.currency} ${t.amount.toStringAsFixed(0)} · ${_dateLabel(t.createdAt)}',
                                    trailingText: _statusLabel(t.status).toUpperCase(),
                                    trailingColor: _statusColor(t.status),
                                    onTap: () => _openDetail(t),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.slate),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
