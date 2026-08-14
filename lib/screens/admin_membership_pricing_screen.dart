import 'package:flutter/material.dart';

import '../models/membership_pricing_models.dart';
import '../services/admin_settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

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

/// Admin page to configure membership tier pricing for agents and affiliates.
/// Prices set here determine what users pay when they sign up or upgrade
/// their membership tier.
class AdminMembershipPricingScreen extends StatefulWidget {
  const AdminMembershipPricingScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminMembershipPricingScreen> createState() =>
      _AdminMembershipPricingScreenState();
}

class _AdminMembershipPricingScreenState
    extends State<AdminMembershipPricingScreen> {
  final _service = AdminSettingsService();
  late Future<MembershipPricing> _future = _load();

  final _agentControllers = <String, TextEditingController>{
    'bronze': TextEditingController(text: '0'),
    'silver': TextEditingController(text: '800'),
    'gold': TextEditingController(text: '2200'),
    'diamond': TextEditingController(text: '5000'),
  };

  final _affiliateControllers = <String, TextEditingController>{
    'bronze': TextEditingController(text: '0'),
    'silver': TextEditingController(text: '500'),
    'gold': TextEditingController(text: '1500'),
    'diamond': TextEditingController(text: '3500'),
  };

  bool _saving = false;

  Future<MembershipPricing> _load() =>
      _service.fetchMembershipPricing(token: widget.token);

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    final pricing = await next;
    if (!mounted) return;
    _updateControllers(pricing);
  }

  void _updateControllers(MembershipPricing pricing) {
    _agentControllers['bronze']!.text =
        pricing.agent['bronze']?.toStringAsFixed(0) ?? '0';
    _agentControllers['silver']!.text =
        pricing.agent['silver']?.toStringAsFixed(0) ?? '0';
    _agentControllers['gold']!.text =
        pricing.agent['gold']?.toStringAsFixed(0) ?? '0';
    _agentControllers['diamond']!.text =
        pricing.agent['diamond']?.toStringAsFixed(0) ?? '0';

    _affiliateControllers['bronze']!.text =
        pricing.affiliate['bronze']?.toStringAsFixed(0) ?? '0';
    _affiliateControllers['silver']!.text =
        pricing.affiliate['silver']?.toStringAsFixed(0) ?? '0';
    _affiliateControllers['gold']!.text =
        pricing.affiliate['gold']?.toStringAsFixed(0) ?? '0';
    _affiliateControllers['diamond']!.text =
        pricing.affiliate['diamond']?.toStringAsFixed(0) ?? '0';
  }

  @override
  void dispose() {
    for (final c in _agentControllers.values) c.dispose();
    for (final c in _affiliateControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _saveAll() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final tiers = ['bronze', 'silver', 'gold', 'diamond'];

      // Save agent prices
      for (final tier in tiers) {
        final value = double.tryParse(_agentControllers[tier]!.text) ?? 0;
        await _service.updateMembershipPrice(
          role: 'agent',
          tier: tier,
          monthlyFeeEtb: value,
          token: widget.token,
        );
      }

      // Save affiliate prices
      for (final tier in tiers) {
        final value = double.tryParse(_affiliateControllers[tier]!.text) ?? 0;
        await _service.updateMembershipPrice(
          role: 'affiliate',
          tier: tier,
          monthlyFeeEtb: value,
          token: widget.token,
        );
      }

      if (!mounted) return;
      await _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membership pricing updated.')),
      );
    } on AdminSettingsServiceException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Membership Pricing',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: FutureBuilder<MembershipPricing>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error is AdminSettingsServiceException
                  ? (snapshot.error as AdminSettingsServiceException).message
                  : 'Something went wrong.',
              onRetry: _refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const Text(
                  'Agent Membership Pricing',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.md),
                _PricingCard(
                  tiers: ['bronze', 'silver', 'gold', 'diamond'],
                  controllers: _agentControllers,
                  labels: const {
                    'bronze': 'Bronze (free)',
                    'silver': 'Silver',
                    'gold': 'Gold',
                    'diamond': 'Diamond',
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  'Affiliate Membership Pricing',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.md),
                _PricingCard(
                  tiers: ['bronze', 'silver', 'gold', 'diamond'],
                  controllers: _affiliateControllers,
                  labels: const {
                    'bronze': 'Bronze (free)',
                    'silver': 'Silver',
                    'gold': 'Gold',
                    'diamond': 'Diamond',
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: _saving ? 'Saving...' : 'Save All Changes',
                    onPressed: _saving ? null : _saveAll,
                    isLoading: _saving,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.tiers,
    required this.controllers,
    required this.labels,
  });

  final List<String> tiers;
  final Map<String, TextEditingController> controllers;
  final Map<String, String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < tiers.length; i++) ...[
            _PricingRow(
              label: labels[tiers[i]] ?? tiers[i],
              controller: controllers[tiers[i]]!,
            ),
            if (i != tiers.length - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _PricingRow extends StatelessWidget {
  const _PricingRow({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 120,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              suffixText: 'ETB',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
          ),
        ),
      ],
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
            const Icon(Icons.error_outline_rounded,
                size: 40, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: AppColors.slate)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
