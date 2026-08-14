import 'package:flutter/material.dart';

import '../models/auth_response.dart';
import '../models/investment_opportunity.dart';
import '../services/investment_opportunity_service.dart';
import '../services/investor_wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

/// Lets an investor roll part of their existing wallet balance straight
/// into a new investment opportunity, instead of withdrawing to a bank
/// account first. Reads the real wallet balance
/// (`GET /api/investors/:id/wallet`) and the real open-opportunities feed
/// (`GET /api/investment-opportunities`), then submits to
/// `POST /api/investors/:id/wallet/reinvest`, which debits the wallet and
/// creates a normal Pending investment commitment — same admin
/// approve/reject queue as any other commitment.
class InvestorReinvestScreen extends StatefulWidget {
  const InvestorReinvestScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<InvestorReinvestScreen> createState() => _InvestorReinvestScreenState();
}

class _InvestorReinvestScreenState extends State<InvestorReinvestScreen> {
  final InvestorWalletService _walletService = InvestorWalletService();
  final InvestmentOpportunityService _opportunityService = InvestmentOpportunityService();
  final _amountController = TextEditingController();

  bool _loading = true;
  String? _loadError;
  double _balance = 0;
  List<InvestmentOpportunity> _openOpportunities = [];
  InvestmentOpportunity? _selected;

  bool _submitting = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _walletService.getWallet(token: widget.user.token ?? '', investorId: widget.user.id),
        _opportunityService.list(),
      ]);
      if (!mounted) return;
      final wallet = results[0] as dynamic; // InvestorWalletSummary
      final opportunities = (results[1] as List<InvestmentOpportunity>)
          .where((o) => o.status == 'Open')
          .toList();
      setState(() {
        _balance = wallet.balance as double;
        _openOpportunities = opportunities;
        _selected = opportunities.isNotEmpty ? opportunities.first : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e is InvestorWalletException
            ? e.message
            : e is InvestmentOpportunityException
                ? e.message
                : 'Something went wrong.';
      });
    }
  }

  Future<void> _submit() async {
    final opportunity = _selected;
    if (opportunity == null) return;

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _formError = 'Enter a valid amount.');
      return;
    }
    if (amount < opportunity.minInvestment) {
      setState(() => _formError =
          'Minimum investment for this opportunity is ${_fmtAmount(opportunity.minInvestment)} ETB.');
      return;
    }
    if (amount > _balance) {
      setState(() => _formError = 'That\'s more than your available wallet balance.');
      return;
    }

    setState(() {
      _submitting = true;
      _formError = null;
    });

    try {
      final result = await _walletService.reinvest(
        token: widget.user.token ?? '',
        investorId: widget.user.id,
        opportunityId: opportunity.id,
        amount: amount,
      );
      if (!mounted) return;
      AppToast.showSuccess(
        context,
        'Reinvested ${_fmtAmount(result.transaction.amount.abs())} ETB — awaiting admin confirmation.',
      );
      Navigator.of(context).pop(true);
    } on InvestorWalletException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError = "Couldn't reach the server. Check your connection and try again.";
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        title: const Text('Reinvest'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorState(message: _loadError!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      // ── Wallet balance summary ─────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AVAILABLE TO REINVEST',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryYellow,
                                    letterSpacing: 1)),
                            const SizedBox(height: 6),
                            Text('${_fmtAmount(_balance)} ETB',
                                style: const TextStyle(
                                    fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 4),
                            const Text(
                              'Roll your profits and payouts straight into a new opportunity — no need to withdraw to your bank first.',
                              style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      if (_balance <= 0) ...[
                        _EmptyBalanceNotice(),
                      ] else if (_openOpportunities.isEmpty) ...[
                        const _NoOpportunitiesNotice(),
                      ] else ...[
                        const Text('Choose an opportunity',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: AppSpacing.sm),
                        for (final o in _openOpportunities) ...[
                          _OpportunityTile(
                            opportunity: o,
                            selected: _selected?.id == o.id,
                            onTap: () => setState(() {
                              _selected = o;
                              _formError = null;
                            }),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        const Text('Amount to reinvest',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Amount (ETB)',
                            border: const OutlineInputBorder(),
                            errorText: _formError,
                            helperText: _selected != null
                                ? 'Minimum ${_fmtAmount(_selected!.minInvestment)} ETB for this opportunity'
                                : null,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'This submits a request for admin review — the amount is reserved from your wallet immediately, but the investment isn\'t confirmed until an admin approves it.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.slate, height: 1.4),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: PrimaryButton(
                            label: 'Reinvest',
                            isLoading: _submitting,
                            onPressed: _selected == null ? null : _submit,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _EmptyBalanceNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 32, color: AppColors.slate),
          SizedBox(height: AppSpacing.sm),
          Text(
            'You don\'t have any wallet balance to reinvest yet. Once a payout is credited to your wallet, it\'ll show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _NoOpportunitiesNotice extends StatelessWidget {
  const _NoOpportunitiesNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.pie_chart_outline_rounded, size: 32, color: AppColors.slate),
          SizedBox(height: AppSpacing.sm),
          Text(
            'No opportunities are open for investment right now. Check back soon.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.slate, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _OpportunityTile extends StatelessWidget {
  const _OpportunityTile({required this.opportunity, required this.selected, required this.onTap});

  final InvestmentOpportunity opportunity;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: selected ? AppColors.primaryYellow : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primaryYellow : AppColors.slate,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opportunity.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${opportunity.category} · ${opportunity.expectedReturnPct}% · ${opportunity.termMonths} mo',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
                  ),
                ],
              ),
            ),
          ],
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
