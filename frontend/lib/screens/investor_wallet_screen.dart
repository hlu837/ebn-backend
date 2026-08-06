import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../models/investor_wallet.dart';
import '../services/investor_wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Investor-facing wallet: balance, pending clearance, full transaction
/// ledger, and a withdraw action. Payouts land here only once an admin
/// credits them against a confirmed investment commitment (see
/// AdminConfirmedInvestmentsScreen) — this screen is read + withdraw only.
class InvestorWalletScreen extends StatefulWidget {
  const InvestorWalletScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<InvestorWalletScreen> createState() => _InvestorWalletScreenState();
}

class _InvestorWalletScreenState extends State<InvestorWalletScreen> {
  final InvestorWalletService _service = InvestorWalletService();

  InvestorWalletSummary? _summary;
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
      final summary = await _service.getWallet(token: widget.user.token ?? '', investorId: widget.user.id);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on InvestorWalletException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _withdraw() async {
    final balance = _summary?.balance ?? 0;
    if (balance <= 0) {
      AppToast.showError(context, 'No available balance to withdraw.');
      return;
    }
    final result = await showDialog<_WithdrawRequest>(
      context: context,
      builder: (dialogContext) => _WithdrawDialog(availableBalance: balance),
    );
    if (result == null) return;

    try {
      await _service.withdraw(
        token: widget.user.token ?? '',
        investorId: widget.user.id,
        amount: result.amount,
        bankAccountLast4: result.bankAccountLast4,
      );
      if (!mounted) return;
      AppToast.showSuccess(context, 'Withdrawal requested — awaiting admin clearance.');
      await _load();
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
        title: const Text('Wallet'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _BalanceCard(summary: _summary!, onWithdraw: _withdraw),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Transaction History', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      if (_summary!.transactions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                          child: Center(child: Text('No transactions yet.', style: TextStyle(color: AppColors.slate))),
                        )
                      else
                        ..._summary!.transactions.map((tx) => _TransactionRow(transaction: tx)),
                    ],
                  ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary, required this.onWithdraw});

  final InvestorWalletSummary summary;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            '${summary.balance.toStringAsFixed(0)} ETB',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          if (summary.pendingClearance > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${summary.pendingClearance.toStringAsFixed(0)} ETB pending clearance',
              style: const TextStyle(color: AppColors.primaryYellow, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(label: 'Withdraw', onPressed: onWithdraw),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final InvestorWalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.amount >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.success : AppColors.danger).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 18,
              color: isCredit ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  '${transaction.status[0].toUpperCase()}${transaction.status.substring(1)} · '
                  '${transaction.createdAt.toLocal().toString().split('.').first}',
                  style: const TextStyle(fontSize: 11, color: AppColors.slate),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : ''}${transaction.amount.toStringAsFixed(0)} ETB',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              color: isCredit ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
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

class _WithdrawRequest {
  final double amount;
  final String? bankAccountLast4;
  const _WithdrawRequest({required this.amount, this.bankAccountLast4});
}

class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog({required this.availableBalance});

  final double availableBalance;

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _accountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (amount > widget.availableBalance) {
      setState(() => _error = 'Amount exceeds your available balance.');
      return;
    }
    Navigator.of(context).pop(_WithdrawRequest(
      amount: amount,
      bankAccountLast4: _accountController.text.trim().isEmpty ? null : _accountController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Withdraw'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available: ${widget.availableBalance.toStringAsFixed(0)} ETB',
            style: const TextStyle(fontSize: 12.5, color: AppColors.slate),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(labelText: 'Amount (ETB)', border: const OutlineInputBorder(), errorText: _error),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _accountController,
            decoration: const InputDecoration(labelText: 'Bank account number (optional)', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Request Withdrawal')),
      ],
    );
  }
}
