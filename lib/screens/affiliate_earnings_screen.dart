import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../services/affiliate_service.dart';
import 'affiliate_tokens_screen.dart';

const _kAccentRed = AppColors.primaryYellow;

// ── Screen ────────────────────────────────────────────────────────────────

/// Earnings & payouts for the Affiliater role.
/// Loads real data from the backend and allows entering a custom payout amount.
class AffiliateEarningsScreen extends StatefulWidget {
  const AffiliateEarningsScreen({super.key, required this.token});

  final String token;

  @override
  State<AffiliateEarningsScreen> createState() => _AffiliateEarningsScreenState();
}

class _AffiliateEarningsScreenState extends State<AffiliateEarningsScreen> {
  final _svc = AffiliateService();
  final _amountController = TextEditingController();

  EarningsSummary? _summary;
  List<PayoutItem> _payouts = [];
  List<ReferralItem> _referrals = [];
  TokenSummary? _tokenSummary;
  bool _loading = true;
  bool _requesting = false;
  String? _error;

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

  String? _token() => widget.token.isNotEmpty ? widget.token : null;

  Future<void> _load() async {
    final token = _token();
    if (token == null) {
      setState(() { _error = 'Not logged in.'; _loading = false; });
      return;
    }
    try {
      final results = await Future.wait([
        _svc.getEarnings(token),
        _svc.listPayouts(token),
        _svc.getReferrals(token),
        _svc.getTokenSummary(token),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as EarningsSummary;
        _payouts = results[1] as List<PayoutItem>;
        _referrals = results[2] as List<ReferralItem>;
        _tokenSummary = results[3] as TokenSummary;
        _loading = false;
      });
    } on AffiliateException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load earnings.'; _loading = false; });
    }
  }

  Future<void> _requestPayout() async {
    final token = _token();
    if (token == null) return;

    final available = _summary?.availableForPayout ?? 0;
    if (available <= 0) {
      AppToast.showError(context, 'Nothing available to withdraw right now.');
      return;
    }

    // Parse amount from the text field; if empty → request everything available.
    double? requestedAmount;
    final raw = _amountController.text.trim();
    if (raw.isNotEmpty) {
      requestedAmount = double.tryParse(raw.replaceAll(',', ''));
      if (requestedAmount == null || requestedAmount <= 0) {
        AppToast.showError(context, 'Enter a valid amount.');
        return;
      }
      if (requestedAmount > available) {
        AppToast.showError(context, 'Amount exceeds available balance (${available.toStringAsFixed(0)} ETB).');
        return;
      }
    }

    setState(() => _requesting = true);
    try {
      final newPayout = await _svc.requestPayout(token, amount: requestedAmount);
      if (!mounted) return;
      setState(() {
        _payouts.insert(0, newPayout);
        // Optimistically update summary — server will confirm on next load.
        if (_summary != null) {
          final used = newPayout.amount;
          _summary = EarningsSummary(
            totalEarned: _summary!.totalEarned,
            pending: _summary!.pending,
            paidOut: _summary!.paidOut,
            processing: _summary!.processing + used,
            availableForPayout: (_summary!.availableForPayout - used).clamp(0, double.infinity),
          );
        }
        _amountController.clear();
        _requesting = false;
      });
      AppToast.showSuccess(context, 'Payout requested. Admin will review it shortly.');
    } on AffiliateException catch (e) {
      if (!mounted) return;
      setState(() => _requesting = false);
      AppToast.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _requesting = false);
      AppToast.showError(context, 'Request failed. Please try again.');
    }
  }

  Future<void> _openTokens() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AffiliateTokensScreen(token: widget.token),
    ));
    // Redeeming tokens there creates a payout — refresh so it shows up here.
    if (mounted) _load();
  }

  /// Merges commission-earning events (referrals) and payout requests into a
  /// single chronological ledger, mirroring how the agent wallet shows every
  /// transaction rather than just withdrawals. Referrals are credits (money
  /// coming in, pending until the sale clears); payouts are debits (money
  /// leaving as it's paid out or sent for review).
  List<_LedgerEntry> _ledgerEntries() {
    final entries = <_LedgerEntry>[
      ..._referrals.map((r) => _LedgerEntry(
            date: r.createdAt,
            title: '${r.customerName} — ${r.assetTitle}',
            amount: r.commissionAmount,
            currency: r.commissionCurrency,
            isCredit: true,
            statusLabel: r.isPending ? 'Pending' : 'Cleared',
            statusIsPositive: !r.isPending,
          )),
      ..._payouts.map((p) => _LedgerEntry(
            date: p.paidAt ?? p.requestedAt,
            title: p.isTokenRedemption ? 'Token redemption payout' : 'Payout requested',
            amount: p.amount,
            currency: p.currency,
            isCredit: false,
            statusLabel: p.status == 'paid' ? 'Paid' : 'Processing',
            statusIsPositive: p.status == 'paid',
          )),
    ];
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
              : RefreshIndicator(
                  color: _kAccentRed,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _BalanceCard(
                        summary: _summary!,
                        amountController: _amountController,
                        requesting: _requesting,
                        onRequestPayout: _requestPayout,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(child: _StatTile(label: 'Total earned', value: _summary!.totalEarned, color: AppColors.ink)),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _StatTile(label: 'Pending', value: _summary!.pending, color: const Color(0xFFB8860B))),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _StatTile(label: 'Paid out', value: _summary!.paidOut, color: AppColors.success)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (_tokenSummary != null) ...[
                        _TokenSummaryCard(summary: _tokenSummary!, onRedeem: _openTokens),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      Text('Transaction History', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      Builder(builder: (context) {
                        final entries = _ledgerEntries();
                        if (entries.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                            child: Center(
                              child: Text(
                                "No activity yet — commissions from your referrals will show up here.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: entries
                              .map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                    child: _TransactionTile(entry: e),
                                  ))
                              .toList(),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

// ── Balance card with amount input ────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.summary,
    required this.amountController,
    required this.requesting,
    required this.onRequestPayout,
  });

  final EarningsSummary summary;
  final TextEditingController amountController;
  final bool requesting;
  final VoidCallback onRequestPayout;

  @override
  Widget build(BuildContext context) {
    final available = summary.availableForPayout;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAccentRed, AppColors.primaryYellowDark],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [BoxShadow(color: Color(0x33E84C3D), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available for Payout',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${available.toStringAsFixed(0)} ETB',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Amount input ─────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: Colors.white30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Amount (leave blank for all)',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    cursorColor: Colors.white,
                  ),
                ),
                const Text('ETB', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: requesting
                ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                : PrimaryButton(
                    label: available <= 0 ? 'No Balance Available' : 'Request Payout',
                    onPressed: available <= 0 ? null : onRequestPayout,
                    backgroundColor: Colors.white.withOpacity(available <= 0 ? 0.1 : 0.18),
                    foregroundColor: Colors.white,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Token balance card — links out to the full redeem flow ────────────────

class _TokenSummaryCard extends StatelessWidget {
  const _TokenSummaryCard({required this.summary, required this.onRedeem});

  final TokenSummary summary;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _kAccentRed.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.toll_rounded, color: _kAccentRed, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${summary.balance} tokens',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(
                  '≈ ${summary.cashValue.toStringAsFixed(0)} ETB',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRedeem,
            style: TextButton.styleFrom(foregroundColor: _kAccentRed),
            child: Text(summary.canRedeem ? 'Redeem' : 'View'),
          ),
        ],
      ),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color});

  final String label;
  final double value;
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
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate)),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Transaction ledger: one row per commission earned or payout sent ───────

/// A single row in the affiliate's transaction history. Built from either a
/// [ReferralItem] (a commission credit) or a [PayoutItem] (a payout debit) —
/// see `_ledgerEntries()` above.
class _LedgerEntry {
  final DateTime date;
  final String title;
  final double amount;
  final String currency;
  final bool isCredit;
  final String statusLabel;
  final bool statusIsPositive;

  const _LedgerEntry({
    required this.date,
    required this.title,
    required this.amount,
    required this.currency,
    required this.isCredit,
    required this.statusLabel,
    required this.statusIsPositive,
  });
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.entry});

  final _LedgerEntry entry;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _fmt(DateTime dt) => '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';

  @override
  Widget build(BuildContext context) {
    final statusColor = entry.statusIsPositive ? AppColors.success : const Color(0xFFB8860B);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (entry.isCredit ? AppColors.success : AppColors.ink).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              entry.isCredit ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: entry.isCredit ? AppColors.success : AppColors.ink,
              size: 17,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_fmt(entry.date), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.slate)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.isCredit ? '+' : '-'}${entry.amount.toStringAsFixed(0)} ${entry.currency}',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: entry.isCredit ? AppColors.success : AppColors.ink),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  entry.statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
