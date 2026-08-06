import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../models/investment_commitment.dart';
import '../services/investment_commitment_service.dart';
import '../theme/app_theme.dart';

/// Investor-facing read of `/api/investment-commitments/me` — every
/// commitment this investor has made, newest first, with its current
/// status (Pending/Confirmed/Rejected) and which opportunity it's for.
/// Purely a read view: decisions happen on AdminInvestmentCommitmentsScreen.
class InvestorMyInvestmentsScreen extends StatefulWidget {
  const InvestorMyInvestmentsScreen({super.key, required this.user, this.showBackButton = true});

  final AppUser user;

  /// False when embedded as the Investor bottom nav's "Portfolio" tab
  /// (nothing to go back to); true when pushed as its own route.
  final bool showBackButton;

  @override
  State<InvestorMyInvestmentsScreen> createState() => _InvestorMyInvestmentsScreenState();
}

class _InvestorMyInvestmentsScreenState extends State<InvestorMyInvestmentsScreen> {
  final InvestmentCommitmentService _service = InvestmentCommitmentService();

  List<InvestmentCommitment> _commitments = [];
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
      final commitments = await _service.listMine(token: widget.user.token ?? '');
      if (!mounted) return;
      setState(() {
        _commitments = commitments;
        _loading = false;
      });
    } on InvestmentCommitmentException catch (e) {
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
        title: const Text('My Investments'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        automaticallyImplyLeading: widget.showBackButton,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _commitments.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 80, horizontal: AppSpacing.lg),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.pie_chart_outline_rounded, size: 32, color: AppColors.slate),
                                  SizedBox(height: AppSpacing.sm),
                                  Text(
                                    'You haven\'t committed to any opportunities yet.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: AppColors.slate),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: _commitments.map((c) => _CommitmentCard(commitment: c)).toList(),
                      ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 80, horizontal: AppSpacing.lg),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.wifi_off_rounded, size: 32, color: AppColors.slate),
                const SizedBox(height: AppSpacing.sm),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate)),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({required this.commitment});

  final InvestmentCommitment commitment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                child: Text(
                  commitment.opportunityTitle ?? 'Investment opportunity',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              _StatusChip(status: commitment.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatTile(label: 'Amount', value: '${_fmtAmount(commitment.amount)} ETB'),
              _StatTile(label: 'Submitted', value: _fmtDate(commitment.createdAt)),
            ],
          ),
          if (commitment.decidedAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _StatTile(label: 'Decided', value: _fmtDate(commitment.decidedAt!)),
                if (commitment.adminNote != null && commitment.adminNote!.isNotEmpty)
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin note',
                            style: TextStyle(fontSize: 10.5, color: AppColors.slate, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(commitment.adminNote!, style: const TextStyle(fontSize: 12.5, height: 1.3)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (commitment.status == 'Confirmed' && commitment.termMonths != null) ...[
            const SizedBox(height: 12),
            _PayoutProgress(commitment: commitment),
          ],
        ],
      ),
    );
  }

  static String _fmtAmount(double value) {
    final s = value.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _PayoutProgress extends StatelessWidget {
  const _PayoutProgress({required this.commitment});

  final InvestmentCommitment commitment;

  @override
  Widget build(BuildContext context) {
    final total = commitment.termMonths!;
    final done = commitment.payoutsMade.clamp(0, total);
    final matured = commitment.maturedAt != null;
    final nextDue = commitment.nextPayoutDueAt;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.cloud,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  matured ? 'Investment matured' : 'Payout schedule',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
              ),
              Text('$done of $total payouts', style: const TextStyle(fontSize: 11, color: AppColors.slate)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? done / total : 0,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(matured ? AppColors.success : AppColors.primaryYellow),
            ),
          ),
          if (!matured && nextDue != null) ...[
            const SizedBox(height: 6),
            Text('Next payout due ${_CommitmentCard._fmtDate(nextDue)}',
                style: const TextStyle(fontSize: 11, color: AppColors.slate)),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.slate, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'Confirmed':
        bg = AppColors.success.withOpacity(0.12);
        fg = AppColors.success;
        break;
      case 'Rejected':
        bg = AppColors.danger.withOpacity(0.12);
        fg = AppColors.danger;
        break;
      default: // Pending
        bg = AppColors.ink;
        fg = AppColors.primaryYellow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
