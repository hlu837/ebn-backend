import 'package:flutter/material.dart';

import '../models/investment_opportunity.dart';
import '../services/investment_opportunity_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';

const List<String> _kCategories = ['Real Estate', 'Vehicle', 'Machinery', 'Other'];
const List<String> _kStatuses = ['Open', 'Funded', 'Closed'];

/// Admin-only screen: compose a new investment opportunity and manage
/// (update status / delete) existing ones. Investor side reads the same
/// `/api/investment-opportunities` feed read-only — see
/// InvestorInvestmentOpportunitiesScreen.
class AdminInvestmentOpportunitiesScreen extends StatefulWidget {
  const AdminInvestmentOpportunitiesScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminInvestmentOpportunitiesScreen> createState() =>
      _AdminInvestmentOpportunitiesScreenState();
}

class _AdminInvestmentOpportunitiesScreenState extends State<AdminInvestmentOpportunitiesScreen> {
  final InvestmentOpportunityService _service = InvestmentOpportunityService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _minInvestmentController = TextEditingController();
  final _expectedReturnController = TextEditingController();
  final _termMonthsController = TextEditingController();

  String _category = _kCategories.first;
  bool _submitting = false;

  List<InvestmentOpportunity> _opportunities = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _minInvestmentController.dispose();
    _expectedReturnController.dispose();
    _termMonthsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final opportunities = await _service.listAll(token: widget.token);
      if (!mounted) return;
      setState(() {
        _opportunities = opportunities;
        _loading = false;
      });
    } on InvestmentOpportunityException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final targetAmount = double.tryParse(_targetAmountController.text.trim());
    final minInvestment = double.tryParse(_minInvestmentController.text.trim());
    final expectedReturn = double.tryParse(_expectedReturnController.text.trim());
    final termMonths = int.tryParse(_termMonthsController.text.trim());

    if (title.isEmpty || description.isEmpty) {
      AppToast.showError(context, 'Title and description are required.');
      return;
    }
    if (targetAmount == null || targetAmount <= 0) {
      AppToast.showError(context, 'Enter a valid target amount.');
      return;
    }
    if (minInvestment == null || minInvestment <= 0) {
      AppToast.showError(context, 'Enter a valid minimum investment.');
      return;
    }
    if (minInvestment > targetAmount) {
      AppToast.showError(context, 'Minimum investment cannot exceed the target amount.');
      return;
    }
    if (expectedReturn == null || expectedReturn < 0) {
      AppToast.showError(context, 'Enter a valid expected return %.');
      return;
    }
    if (termMonths == null || termMonths <= 0) {
      AppToast.showError(context, 'Enter a valid term in months.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.create(
        token: widget.token,
        title: title,
        description: description,
        category: _category,
        targetAmount: targetAmount,
        minInvestment: minInvestment,
        expectedReturnPct: expectedReturn,
        termMonths: termMonths,
      );
      _titleController.clear();
      _descriptionController.clear();
      _targetAmountController.clear();
      _minInvestmentController.clear();
      _expectedReturnController.clear();
      _termMonthsController.clear();
      if (!mounted) return;
      setState(() {
        _category = _kCategories.first;
        _submitting = false;
      });
      await _load();
    } on InvestmentOpportunityException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _changeStatus(InvestmentOpportunity opportunity, String status) async {
    try {
      await _service.updateStatus(token: widget.token, id: opportunity.id, status: status);
      if (!mounted) return;
      await _load();
    } on InvestmentOpportunityException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    }
  }

  Future<void> _delete(InvestmentOpportunity opportunity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete opportunity?'),
        content: Text('"${opportunity.title}" will be removed for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.delete(token: widget.token, id: opportunity.id);
      if (!mounted) return;
      setState(() => _opportunities.removeWhere((o) => o.id == opportunity.id));
    } on InvestmentOpportunityException catch (e) {
      if (!mounted) return;
      AppToast.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        title: const Text('Investment Opportunities'),
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _ComposeCard(
              titleController: _titleController,
              descriptionController: _descriptionController,
              targetAmountController: _targetAmountController,
              minInvestmentController: _minInvestmentController,
              expectedReturnController: _expectedReturnController,
              termMonthsController: _termMonthsController,
              category: _category,
              submitting: _submitting,
              onCategoryChanged: (value) => setState(() => _category = value),
              onSubmit: _submit,
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Posted', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_opportunities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(child: Text('No opportunities yet.', style: TextStyle(color: AppColors.slate))),
              )
            else
              ..._opportunities.map((o) => _OpportunityCard(
                    opportunity: o,
                    onStatusChanged: (status) => _changeStatus(o, status),
                    onDelete: () => _delete(o),
                  )),
          ],
        ),
      ),
    );
  }
}

class _ComposeCard extends StatelessWidget {
  const _ComposeCard({
    required this.titleController,
    required this.descriptionController,
    required this.targetAmountController,
    required this.minInvestmentController,
    required this.expectedReturnController,
    required this.termMonthsController,
    required this.category,
    required this.submitting,
    required this.onCategoryChanged,
    required this.onSubmit,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController targetAmountController;
  final TextEditingController minInvestmentController;
  final TextEditingController expectedReturnController;
  final TextEditingController termMonthsController;
  final String category;
  final bool submitting;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Investment Opportunity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            items: _kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (value) {
              if (value != null) onCategoryChanged(value);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: targetAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Target Amount (ETB)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: minInvestmentController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Min. Investment (ETB)', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: expectedReturnController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Expected Return (%)', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: termMonthsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Term (months)', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: submitting ? 'Posting…' : 'Post Opportunity',
            onPressed: submitting ? null : onSubmit,
          ),
        ],
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.opportunity,
    required this.onStatusChanged,
    required this.onDelete,
  });

  final InvestmentOpportunity opportunity;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDelete;

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
            children: [
              Expanded(
                child: Text(
                  opportunity.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
          Text(
            '${opportunity.category} · Target ${opportunity.targetAmount.toStringAsFixed(0)} ETB · '
            '${opportunity.expectedReturnPct}% · ${opportunity.termMonths} mo',
            style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
          ),
          const SizedBox(height: 6),
          Text(opportunity.description, style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: opportunity.status,
                items: _kStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (value) {
                  if (value != null && value != opportunity.status) onStatusChanged(value);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
