import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/broker.dart' show Broker;
import '../models/asset.dart';
import '../models/auth_response.dart';
import '../services/agent_service.dart';
import '../theme/app_theme.dart';

enum _ReferralStatus { pending, accepted, closed, declined }

extension _ReferralStatusX on _ReferralStatus {
  String get label => switch (this) {
        _ReferralStatus.pending => 'Pending',
        _ReferralStatus.accepted => 'In progress',
        _ReferralStatus.closed => 'Closed — fee paid',
        _ReferralStatus.declined => 'Declined',
      };

  Color get color => switch (this) {
        _ReferralStatus.pending => AppColors.slate,
        _ReferralStatus.accepted => AppColors.primaryYellow,
        _ReferralStatus.closed => AppColors.success,
        _ReferralStatus.declined => AppColors.danger,
      };
}

/// One referral sent to, or received from, another broker on the network.
///
/// TODO: replace with a real `/api/referrals` backend once the referral
/// program has server-side support — this local, in-memory list is enough
/// to build and test the full UI/UX in the meantime.
class _Referral {
  final String id;
  final bool isSent;
  final String counterpartName;
  final String clientName;
  final String clientPhone;
  final AssetCategorySlug category;
  final double feePercent;
  _ReferralStatus status;
  final DateTime date;
  final String? notes;

  _Referral({
    required this.id,
    required this.isSent,
    required this.counterpartName,
    required this.clientName,
    required this.clientPhone,
    required this.category,
    required this.feePercent,
    required this.status,
    required this.date,
    this.notes,
  });
}

class AgentReferralsScreen extends StatefulWidget {
  const AgentReferralsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AgentReferralsScreen> createState() => _AgentReferralsScreenState();
}

class _AgentReferralsScreenState extends State<AgentReferralsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  final List<_Referral> _referrals = [
    _Referral(
      id: 'r1',
      isSent: true,
      counterpartName: 'Amanuel Tesfaye — Prime Realty',
      clientName: 'Selam Girma',
      clientPhone: '+251911223344',
      category: AssetCategorySlug.apartments,
      feePercent: 10,
      status: _ReferralStatus.accepted,
      date: DateTime(2026, 7, 24),
      notes: 'Looking for a 2-bed near Bole, budget ~6M ETB.',
    ),
    _Referral(
      id: 'r2',
      isSent: false,
      counterpartName: 'Hana Bekele — Skyline Brokers',
      clientName: 'Yonas Alemu',
      clientPhone: '+251922334455',
      category: AssetCategorySlug.vehicles,
      feePercent: 8,
      status: _ReferralStatus.pending,
      date: DateTime(2026, 7, 27),
      notes: 'Wants an SUV, cash buyer.',
    ),
    _Referral(
      id: 'r3',
      isSent: true,
      counterpartName: 'Dawit Mekonnen — Horizon Properties',
      clientName: 'Ruth Assefa',
      clientPhone: '+251933445566',
      category: AssetCategorySlug.house,
      feePercent: 10,
      status: _ReferralStatus.closed,
      date: DateTime(2026, 7, 2),
    ),
  ];

  List<_Referral> get _sent => _referrals.where((r) => r.isSent).toList()..sort((a, b) => b.date.compareTo(a.date));
  List<_Referral> get _received => _referrals.where((r) => !r.isSent).toList()..sort((a, b) => b.date.compareTo(a.date));

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openSendReferralSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cloud,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _SendReferralSheet(
        onSend: (referral) => setState(() => _referrals.insert(0, referral)),
        currentUserId: widget.user.id,
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
        title: const Text('Referrals', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.ink,
          unselectedLabelColor: AppColors.slate,
          indicatorColor: AppColors.primaryYellow,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Sent (${_sent.length})'),
            Tab(text: 'Received (${_received.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        onPressed: _openSendReferralSheet,
        icon: const Icon(Icons.handshake_outlined),
        label: const Text('Send Referral', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _referralList(_sent, emptyText: "You haven't sent any referrals yet."),
          _referralList(_received, emptyText: 'No referrals from other agents yet.'),
        ],
      ),
    );
  }

  Widget _referralList(List<_Referral> items, {required String emptyText}) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.handshake_outlined, size: 40, color: AppColors.slate),
              const SizedBox(height: AppSpacing.sm),
              Text(emptyText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppColors.slate)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 96),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => _ReferralCard(referral: items[i]),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.referral});
  final _Referral referral;

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: referral.clientPhone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final r = referral;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.clientName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(
                      r.isSent ? 'Referred to ${r.counterpartName}' : 'Referred by ${r.counterpartName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.slate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: r.status.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
                child: Text(r.status.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: r.status.color)),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),
          Row(
            children: [
              Icon(Icons.sell_outlined, size: 15, color: AppColors.slate),
              const SizedBox(width: 6),
              Text(r.category.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(width: 14),
              const Icon(Icons.percent_rounded, size: 15, color: AppColors.slate),
              const SizedBox(width: 6),
              Text('${r.feePercent.toStringAsFixed(0)}% fee share', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ],
          ),
          if (r.notes != null) ...[
            const SizedBox(height: 8),
            Text(r.notes!, style: const TextStyle(fontSize: 12.5, color: AppColors.slate, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: AppColors.cloud,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    onTap: _call,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.call_rounded, size: 15, color: AppColors.ink),
                          SizedBox(width: 5),
                          Text('Call client', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SendReferralSheet extends StatefulWidget {
  const _SendReferralSheet({required this.onSend, required this.currentUserId});
  final ValueChanged<_Referral> onSend;
  final String currentUserId;

  @override
  State<_SendReferralSheet> createState() => _SendReferralSheetState();
}

class _SendReferralSheetState extends State<_SendReferralSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  Broker? _broker;
  AssetCategorySlug _category = AssetCategorySlug.apartments;
  double _fee = 10;

  final AgentService _agentService = AgentService();
  List<Broker> _brokers = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBrokers();
  }

  Future<void> _loadBrokers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _agentService.fetchDirectory(excludeUserId: widget.currentUserId);
      final brokers = rows.map(Broker.fromDirectoryJson).toList();
      if (!mounted) return;
      setState(() {
        _brokers = brokers;
        _loading = false;
      });
    } on AgentServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canSend => _broker != null && _nameController.text.trim().isNotEmpty && _phoneController.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSend) return;
    widget.onSend(_Referral(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      isSent: true,
      counterpartName: '${_broker!.name} — ${_broker!.company}',
      clientName: _nameController.text.trim(),
      clientPhone: _phoneController.text.trim(),
      category: _category,
      feePercent: _fee,
      status: _ReferralStatus.pending,
      date: DateTime.now(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    ));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral sent.')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSpacing.md), decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const Text('Send a Referral', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: AppSpacing.md),
            const Text('Refer to', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.slate)),
            const SizedBox(height: 6),
            DropdownButtonFormField<Broker>(
              initialValue: _broker,
              hint: Text(_loading ? 'Loading brokers…' : 'Choose a broker'),
              isExpanded: true,
              items: _brokers
                  .map((b) => DropdownMenuItem(value: b, child: Text('${b.name} — ${b.company}', overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: _loading ? null : (b) => setState(() => _broker = b),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                    ),
                    TextButton(onPressed: _loadBrokers, child: const Text('Retry')),
                  ],
                ),
              )
            else if (!_loading && _brokers.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('No other brokers on the platform yet.', style: TextStyle(fontSize: 12, color: AppColors.slate)),
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Client's name"), onChanged: (_) => setState(() {})),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Client's phone"),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('What are they looking for?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.slate)),
            const SizedBox(height: 6),
            DropdownButtonFormField<AssetCategorySlug>(
              initialValue: _category,
              isExpanded: true,
              items: AssetCategorySlug.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
              onChanged: (c) => setState(() => _category = c ?? _category),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Fee share: ${_fee.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.slate)),
            Slider(
              value: _fee,
              min: 5,
              max: 20,
              divisions: 15,
              activeColor: AppColors.primaryYellow,
              label: '${_fee.toStringAsFixed(0)}%',
              onChanged: (v) => setState(() => _fee = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(controller: _notesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: _canSend ? _submit : null, child: const Text('Send Referral')),
          ],
        ),
      ),
    );
  }
}
