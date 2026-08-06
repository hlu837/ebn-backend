import 'package:flutter/material.dart';

import '../models/investment_commitment.dart';
import '../services/investment_commitment_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Admin-only screen: review pending investor commitments (see
/// InvestorInvestmentOpportunitiesScreen's "Commit" flow) and
/// approve/reject each one. Approving does not move money automatically —
/// there's no payment rail wired to this yet — it just flips the
/// commitment's status, which will feed the wallet/payout work next.
class AdminInvestmentCommitmentsScreen extends StatefulWidget {
  const AdminInvestmentCommitmentsScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminInvestmentCommitmentsScreen> createState() => _AdminInvestmentCommitmentsScreenState();
}

class _AdminInvestmentCommitmentsScreenState extends State<AdminInvestmentCommitmentsScreen> {
  final InvestmentCommitmentService _service = InvestmentCommitmentService();

  List<InvestmentCommitment> _commitments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final commitments = await _service.listPending(token: widget.token);
      if (!mounted) return;
      setState(() {
        _commitments = commitments;
        _loading = false;
      });
    } on InvestmentCommitmentException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _approve(InvestmentCommitment commitment) async {
    try {
      await _service.approve(token: widget.token, id: commitment.id);
      if (!mounted) return;
      setState(() => _commitments.removeWhere((c) => c.id == commitment.id));
      AppToast.showSuccess(context, 'Commitment confirmed.');
    } on InvestmentCommitmentException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _reject(InvestmentCommitment commitment) async {
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _RejectDialog(commitment: commitment),
    );
    if (note == null) return;

    try {
      await _service.reject(token: widget.token, id: commitment.id, adminNote: note);
      if (!mounted) return;
      setState(() => _commitments.removeWhere((c) => c.id == commitment.id));
      AppToast.showSuccess(context, 'Commitment declined.');
    } on InvestmentCommitmentException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        title: const Text('Investment Commitments'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _commitments.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(
                          child: Text('No pending commitments.', style: TextStyle(color: AppColors.slate)),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: _commitments
                        .map((c) => _CommitmentCard(
                              commitment: c,
                              onApprove: () => _approve(c),
                              onReject: () => _reject(c),
                            ))
                        .toList(),
                  ),
      ),
    );
  }
}

class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({required this.commitment, required this.onApprove, required this.onReject});

  final InvestmentCommitment commitment;
  final VoidCallback onApprove;
  final VoidCallback onReject;

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
          Text(
            commitment.opportunityTitle ?? 'Investment opportunity',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 4),
          Text(
            '${commitment.userFullName ?? 'Investor'} · ${commitment.userEmail ?? ''}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
          ),
          const SizedBox(height: 6),
          Text(
            '${commitment.amount.toStringAsFixed(0)} ETB',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: PrimaryButton(label: 'Confirm', onPressed: onApprove)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog({required this.commitment});

  final InvestmentCommitment commitment;

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Decline commitment?'),
      content: TextField(
        controller: _noteController,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Reason (optional)',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_noteController.text.trim()),
          child: const Text('Decline'),
        ),
      ],
    );
  }
}
