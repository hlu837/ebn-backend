import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../models/investment_opportunity.dart';
import '../services/investment_commitment_service.dart';
import '../services/investment_opportunity_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Investor-facing read of `/api/investment-opportunities` — open deals
/// first, then newest first. Investors can commit capital to an open
/// opportunity here; the commitment goes to an admin approval queue (see
/// AdminInvestmentCommitmentsScreen) rather than moving money automatically
/// — there's no payment rail wired to this yet.
class InvestorInvestmentOpportunitiesScreen extends StatefulWidget {
  const InvestorInvestmentOpportunitiesScreen({super.key, required this.user, this.showBackButton = true});

  final AppUser user;

  /// False when embedded as the Investor bottom nav's "Opportunities" tab
  /// (nothing to go back to); true when pushed as its own route.
  final bool showBackButton;

  @override
  State<InvestorInvestmentOpportunitiesScreen> createState() =>
      _InvestorInvestmentOpportunitiesScreenState();
}

class _InvestorInvestmentOpportunitiesScreenState extends State<InvestorInvestmentOpportunitiesScreen> {
  final InvestmentOpportunityService _service = InvestmentOpportunityService();
  final InvestmentCommitmentService _commitmentService = InvestmentCommitmentService();

  List<InvestmentOpportunity> _opportunities = [];
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
      final opportunities = await _service.list();
      if (!mounted) return;
      setState(() {
        _opportunities = opportunities;
        _loading = false;
      });
    } on InvestmentOpportunityException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _commit(InvestmentOpportunity opportunity) async {
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => _CommitDialog(opportunity: opportunity),
    );
    if (amount == null) return;

    try {
      await _commitmentService.create(
        token: widget.user.token ?? '',
        opportunityId: opportunity.id,
        amount: amount,
      );
      if (!mounted) return;
      AppToast.showSuccess(context, 'Commitment submitted — awaiting admin confirmation.');
    } on InvestmentCommitmentException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: widget.showBackButton
          ? AppBar(
              title: const Text('Investment Opportunities'),
              backgroundColor: AppColors.cloud,
              foregroundColor: AppColors.ink,
              automaticallyImplyLeading: true,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _opportunities.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 80),
                            child: Center(
                              child: Text('No opportunities open right now.',
                                  style: TextStyle(color: AppColors.slate)),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: _opportunities
                            .map((o) => _OpportunityCard(
                                  opportunity: o,
                                  onCommit: o.status == 'Open' ? () => _commit(o) : null,
                                ))
                            .toList(),
                      ),
      ),
    );
  }
}

class _CommitDialog extends StatefulWidget {
  const _CommitDialog({required this.opportunity});

  final InvestmentOpportunity opportunity;

  @override
  State<_CommitDialog> createState() => _CommitDialogState();
}

class _CommitDialogState extends State<_CommitDialog> {
  final _amountController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (amount < widget.opportunity.minInvestment) {
      setState(() => _error = 'Minimum investment is ${widget.opportunity.minInvestment.toStringAsFixed(0)} ETB.');
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Commit to "${widget.opportunity.title}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Minimum investment: ${widget.opportunity.minInvestment.toStringAsFixed(0)} ETB',
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount (ETB)',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'This submits a request for admin review — it does not move money automatically yet.',
            style: TextStyle(fontSize: 11.5, color: AppColors.slate, height: 1.4),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Submit')),
      ],
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
              mainAxisSize: MainAxisSize.min,
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

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({required this.opportunity, required this.onCommit});

  final InvestmentOpportunity opportunity;
  final VoidCallback? onCommit;

  @override
  Widget build(BuildContext context) {
    final isOpen = opportunity.status == 'Open';

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
            children: [
              Expanded(
                child: Text(
                  opportunity.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              _StatusChip(status: opportunity.status, isOpen: isOpen),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            opportunity.category,
            style: const TextStyle(fontSize: 11.5, color: AppColors.slate, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(opportunity.description, style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatTile(label: 'Target', value: '${_fmtAmount(opportunity.targetAmount)} ETB'),
              _StatTile(label: 'Min. Investment', value: '${_fmtAmount(opportunity.minInvestment)} ETB'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StatTile(label: 'Expected Return', value: '${opportunity.expectedReturnPct}%'),
              _StatTile(label: 'Term', value: '${opportunity.termMonths} mo'),
            ],
          ),
          if (onCommit != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(label: 'Commit to this opportunity', onPressed: onCommit),
            ),
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
  const _StatusChip({required this.status, required this.isOpen});

  final String status;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.success.withOpacity(0.12) : AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isOpen ? AppColors.success : AppColors.primaryYellow,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
