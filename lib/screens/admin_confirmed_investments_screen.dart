import 'package:flutter/material.dart';

import '../models/investment_commitment.dart';
import '../services/investment_commitment_service.dart';
import '../services/investor_wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Admin-only screen: browse confirmed investment commitments (active
/// investor holdings) and credit a payout against one, crediting the
/// investor's wallet directly.
class AdminConfirmedInvestmentsScreen extends StatefulWidget {
  const AdminConfirmedInvestmentsScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminConfirmedInvestmentsScreen> createState() => _AdminConfirmedInvestmentsScreenState();
}

class _AdminConfirmedInvestmentsScreenState extends State<AdminConfirmedInvestmentsScreen> {
  final InvestmentCommitmentService _commitmentService = InvestmentCommitmentService();
  final InvestorWalletService _walletService = InvestorWalletService();

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
      final commitments = await _commitmentService.listConfirmed(token: widget.token);
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

  Future<void> _creditPayout(InvestmentCommitment commitment) async {
    final result = await showDialog<_PayoutRequest>(
      context: context,
      builder: (dialogContext) => _PayoutDialog(commitment: commitment),
    );
    if (result == null) return;

    try {
      await _walletService.creditPayout(
        token: widget.token,
        investorId: commitment.userId,
        amount: result.amount,
        label: result.label,
        commitmentId: commitment.id,
      );
      if (!mounted) return;
      AppToast.showSuccess(context, 'Payout credited to investor wallet.');
    } on InvestorWalletException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        title: const Text('Confirmed Investments'),
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
                          child: Text('No confirmed investments yet.', style: TextStyle(color: AppColors.slate)),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: _commitments
                        .map((c) => _CommitmentCard(commitment: c, onCreditPayout: () => _creditPayout(c)))
                        .toList(),
                  ),
      ),
    );
  }
}

class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({required this.commitment, required this.onCreditPayout});

  final InvestmentCommitment commitment;
  final VoidCallback onCreditPayout;

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
            'Committed: ${commitment.amount.toStringAsFixed(0)} ETB',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(label: 'Credit Payout', onPressed: onCreditPayout),
          ),
        ],
      ),
    );
  }
}

class _PayoutRequest {
  final double amount;
  final String label;
  const _PayoutRequest({required this.amount, required this.label});
}

class _PayoutDialog extends StatefulWidget {
  const _PayoutDialog({required this.commitment});

  final InvestmentCommitment commitment;

  @override
  State<_PayoutDialog> createState() => _PayoutDialogState();
}

class _PayoutDialogState extends State<_PayoutDialog> {
  final _amountController = TextEditingController();
  final _labelController = TextEditingController(text: 'Investment payout');
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (_labelController.text.trim().isEmpty) {
      setState(() => _error = 'Enter a label for this payout.');
      return;
    }
    Navigator.of(context).pop(_PayoutRequest(amount: amount, label: _labelController.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Credit payout — "${widget.commitment.opportunityTitle}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(labelText: 'Amount (ETB)', border: const OutlineInputBorder(), errorText: _error),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Credit')),
      ],
    );
  }
}
