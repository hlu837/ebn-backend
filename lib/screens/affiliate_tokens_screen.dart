import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../services/affiliate_service.dart';

const _kAccentGold = Color(0xFFB8860B);

/// Tokens earned from referral signups — view balance, redeem for cash, and
/// see the full earn/redeem history. Redeeming files a normal payout
/// request (source: token_redemption) that goes through the same admin
/// review as commission payouts — see AffiliateEarningsScreen.
class AffiliateTokensScreen extends StatefulWidget {
  const AffiliateTokensScreen({super.key, required this.token});

  final String token;

  @override
  State<AffiliateTokensScreen> createState() => _AffiliateTokensScreenState();
}

class _AffiliateTokensScreenState extends State<AffiliateTokensScreen> {
  final _svc = AffiliateService();
  final _tokensController = TextEditingController();

  TokenSummary? _summary;
  List<TokenLedgerEntry> _ledger = [];
  bool _loading = true;
  bool _redeeming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tokensController.dispose();
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
        _svc.getTokenSummary(token),
        _svc.getTokenLedger(token),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as TokenSummary;
        _ledger = results[1] as List<TokenLedgerEntry>;
        _loading = false;
      });
    } on AffiliateException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load tokens.'; _loading = false; });
    }
  }

  Future<void> _redeem() async {
    final token = _token();
    if (token == null) return;

    final summary = _summary;
    if (summary == null || !summary.canRedeem) {
      AppToast.showError(
        context,
        'You need at least ${summary?.minRedeemableTokens ?? 0} tokens to redeem.',
      );
      return;
    }

    int? requestedTokens;
    final raw = _tokensController.text.trim();
    if (raw.isNotEmpty) {
      requestedTokens = int.tryParse(raw);
      if (requestedTokens == null || requestedTokens <= 0) {
        AppToast.showError(context, 'Enter a valid whole number of tokens.');
        return;
      }
      if (requestedTokens > summary.balance) {
        AppToast.showError(context, 'You only have ${summary.balance} tokens available.');
        return;
      }
      if (requestedTokens < summary.minRedeemableTokens) {
        AppToast.showError(context, 'Redeem at least ${summary.minRedeemableTokens} tokens at a time.');
        return;
      }
    }

    setState(() => _redeeming = true);
    try {
      final payout = await _svc.redeemTokens(token, tokens: requestedTokens);
      if (!mounted) return;
      _tokensController.clear();
      AppToast.showSuccess(
        context,
        'Redeemed for ${payout.amount.toStringAsFixed(0)} ${payout.currency} — payout is processing.',
      );
      await _load();
    } on AffiliateException catch (e) {
      if (!mounted) return;
      setState(() => _redeeming = false);
      AppToast.showError(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _redeeming = false);
      AppToast.showError(context, 'Redemption failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Tokens', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : () { setState(() { _loading = true; _error = null; }); _load(); },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccentGold))
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
                  color: _kAccentGold,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _TokenBalanceCard(
                        summary: _summary!,
                        tokensController: _tokensController,
                        redeeming: _redeeming,
                        onRedeem: _redeem,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(child: _StatTile(label: 'Total earned', value: '${_summary!.totalEarned}', color: AppColors.ink)),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _StatTile(label: 'Redeemed', value: '${_summary!.totalRedeemed}', color: AppColors.success)),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(child: _StatTile(label: 'Rate', value: '${_summary!.etbPerToken.toStringAsFixed(2)} ETB', color: _kAccentGold)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text('Token History', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.md),
                      if (_ledger.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                          child: Center(
                            child: Text(
                              "No token activity yet — share your referral link to start earning.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600),
                            ),
                          ),
                        )
                      else
                        ..._ledger.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _LedgerTile(entry: e),
                            )),
                    ],
                  ),
                ),
    );
  }
}

// ── Token balance card with redeem input ───────────────────────────────────

class _TokenBalanceCard extends StatelessWidget {
  const _TokenBalanceCard({
    required this.summary,
    required this.tokensController,
    required this.redeeming,
    required this.onRedeem,
  });

  final TokenSummary summary;
  final TextEditingController tokensController;
  final bool redeeming;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kAccentGold, Color(0xFF8A6100)],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [BoxShadow(color: Color(0x33B8860B), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.toll_rounded, color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Text('Token Balance', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${summary.balance} tokens',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            '≈ ${summary.cashValue.toStringAsFixed(0)} ETB at ${summary.etbPerToken.toStringAsFixed(2)} ETB/token',
            style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Tokens-to-redeem input ───────────────────────────────────
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
                    controller: tokensController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Tokens (leave blank for all)',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    cursorColor: Colors.white,
                  ),
                ),
                const Text('tokens', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Minimum ${summary.minRedeemableTokens} tokens per redemption.',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),

          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: redeeming
                ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                : PrimaryButton(
                    label: summary.canRedeem ? 'Redeem for Cash' : 'Not Enough Tokens Yet',
                    onPressed: summary.canRedeem ? onRedeem : null,
                    backgroundColor: Colors.white.withOpacity(summary.canRedeem ? 0.18 : 0.1),
                    foregroundColor: Colors.white,
                  ),
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
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Ledger history tile ─────────────────────────────────────────────────────

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});

  final TokenLedgerEntry entry;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _fmt(DateTime dt) => '${_months[dt.month - 1]} ${dt.day}, ${dt.year}';

  @override
  Widget build(BuildContext context) {
    final earned = entry.type == TokenEntryType.earned;
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
              color: (earned ? AppColors.success : _kAccentGold).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              earned ? Icons.add_circle_outline_rounded : Icons.swap_horiz_rounded,
              color: earned ? AppColors.success : _kAccentGold,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.reason,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  _fmt(entry.createdAt),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: AppColors.slate),
                ),
              ],
            ),
          ),
          Text(
            earned ? '+${entry.amount}' : '${entry.amount}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: earned ? AppColors.success : _kAccentGold),
          ),
        ],
      ),
    );
  }
}
