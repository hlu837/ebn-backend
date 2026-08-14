import 'package:flutter/material.dart';

import '../models/agent_account.dart';
import '../models/auth_response.dart';
import '../services/agent_service.dart';
import '../theme/app_theme.dart';

String _formatMoney(double value) {
  final s = value.abs().toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final posFromEnd = s.length - i;
    buffer.write(s[i]);
    if (posFromEnd > 1 && posFromEnd % 3 == 1) buffer.write(',');
  }
  return '${value < 0 ? '-' : ''}${buffer.toString()}';
}

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// The agent's balance, itemized commission/withdrawal history, and a
/// withdraw-to-bank flow — backed by `GET/POST /api/agents/:id/wallet*`.
class AgentWalletScreen extends StatefulWidget {
  const AgentWalletScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AgentWalletScreen> createState() => _AgentWalletScreenState();
}

class _AgentWalletScreenState extends State<AgentWalletScreen> {
  final _service = AgentService();
  late Future<(AgentWallet, AgentSettingsData)> _future = _load();

  Future<(AgentWallet, AgentSettingsData)> _load() async {
    // Loaded together so the withdraw sheet always shows the payout
    // account that's actually on file, instead of a hardcoded placeholder.
    final results = await Future.wait([
      _service.getWallet(widget.user.id, token: widget.user.token ?? ''),
      _service.getSettings(widget.user.id, token: widget.user.token ?? ''),
    ]);
    return (results[0] as AgentWallet, results[1] as AgentSettingsData);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  void _openWithdrawSheet(AgentWallet wallet, AgentSettingsData settings) {
    final hasBankAccount = (settings.bankAccountLast4 ?? '').isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cloud,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _WithdrawSheet(
        available: wallet.balance,
        bankName: settings.bankName,
        bankAccountLast4: settings.bankAccountLast4,
        canSubmit: hasBankAccount,
        onConfirm: (amount) async {
          Navigator.of(context).pop();
          try {
            await _service.requestWithdrawal(
              widget.user.id,
              amount: amount,
              token: widget.user.token ?? '',
            );
            if (!mounted) return;
            await _refresh();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Withdrawal of ETB ${_formatMoney(amount)} requested.')));
          } on AgentServiceException catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Wallet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Download statement',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Statement will be emailed to you shortly.'))),
          ),
        ],
      ),
      body: FutureBuilder<(AgentWallet, AgentSettingsData)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error is AgentServiceException ? (snapshot.error as AgentServiceException).message : 'Something went wrong.',
              onRetry: _refresh,
            );
          }
          final (wallet, settings) = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(AppRadii.lg)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AVAILABLE BALANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryYellow, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      Text('ETB ${_formatMoney(wallet.balance)}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('ETB ${_formatMoney(wallet.pendingClearance)} pending clearance', style: const TextStyle(fontSize: 12.5, color: Colors.white60, fontWeight: FontWeight.w600)),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryYellow, foregroundColor: Colors.white),
                          onPressed: () => _openWithdrawSheet(wallet, settings),
                          icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                          label: const Text('Withdraw'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('Transaction History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: AppSpacing.sm),
                if (wallet.transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Center(child: Text('No transactions yet.', style: TextStyle(fontSize: 13, color: AppColors.slate))),
                  ),
                for (final t in wallet.transactions) ...[
                  _TransactionTile(tx: t),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          );
        },
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
            const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.slate)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});
  final AgentWalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.amount >= 0;
    final pending = tx.status == 'pending';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: (isCredit ? AppColors.success : AppColors.ink).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(isCredit ? Icons.south_west_rounded : Icons.north_east_rounded, size: 17, color: isCredit ? AppColors.success : AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(_formatDate(tx.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.slate)),
                    if (pending) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.primaryYellow.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
                        child: const Text('Pending', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primaryYellow)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : ''}ETB ${_formatMoney(tx.amount)}',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: isCredit ? AppColors.success : AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _WithdrawSheet extends StatefulWidget {
  const _WithdrawSheet({
    required this.available,
    required this.bankName,
    required this.bankAccountLast4,
    required this.canSubmit,
    required this.onConfirm,
  });
  final double available;
  final String? bankName;
  final String? bankAccountLast4;
  final bool canSubmit;
  final ValueChanged<double> onConfirm;

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text.trim());

  String? get _error {
    final a = _amount;
    if (_amountController.text.trim().isEmpty) return null;
    if (a == null || a <= 0) return 'Enter a valid amount';
    if (a > widget.available) return 'Amount exceeds available balance';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = widget.canSubmit && _amount != null && _error == null;
    final hasAccount = (widget.bankAccountLast4 ?? '').isNotEmpty;
    final accountLabel = hasAccount
        ? '${(widget.bankName ?? '').isNotEmpty ? widget.bankName : 'Bank account'} ····${widget.bankAccountLast4}'
        : 'No payout account on file';
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const Text('Withdraw to Bank', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text('Available: ETB ${_formatMoney(widget.available)}', style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: hasAccount ? AppColors.border : AppColors.danger)),
            child: Row(
              children: [
                Icon(Icons.account_balance_outlined, size: 18, color: hasAccount ? AppColors.ink : AppColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    accountLabel,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: hasAccount ? AppColors.ink : AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
          if (!hasAccount) ...[
            const SizedBox(height: 6),
            const Text('Add a payout account under Settings → Payout & banking before withdrawing.', style: TextStyle(fontSize: 11.5, color: AppColors.slate)),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: widget.canSubmit,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: 'Amount (ETB)', errorText: _error),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(onPressed: canSubmit ? () => widget.onConfirm(_amount!) : null, child: const Text('Confirm Withdrawal')),
        ],
      ),
    );
  }
}
