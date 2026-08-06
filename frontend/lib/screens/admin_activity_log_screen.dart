import 'package:flutter/material.dart';
import '../services/activity_log_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_list_widgets.dart';

enum _ActivityType { approval, rejection }

/// One row in the log. Scope is deliberately narrow right now — approve/
/// reject decisions on investment commitments and role upgrade requests
/// only. Sell-request actions aren't logged yet: those routes have no
/// admin auth today, so there's no reliable actor to attribute them to
/// (see backend/migrations/048_activity_log.sql).
class _ActivityEntry {
  final _ActivityType type;
  final String description;
  final DateTime createdAt;

  const _ActivityEntry({required this.type, required this.description, required this.createdAt});

  static const _actionLabels = {
    'investment_commitment.approve': 'Approved investment commitment',
    'investment_commitment.reject': 'Rejected investment commitment',
    'role_upgrade_request.approve': 'Approved role upgrade request',
    'role_upgrade_request.reject': 'Rejected role upgrade request',
  };

  factory _ActivityEntry.fromJson(Map<String, dynamic> json) {
    final action = json['action'] as String? ?? '';
    final actorName = json['actorName'] as String? ?? 'Admin';
    final label = _actionLabels[action] ?? action;
    return _ActivityEntry(
      type: action.endsWith('.reject') ? _ActivityType.rejection : _ActivityType.approval,
      description: '$actorName · $label',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Small self-contained "time ago" formatter — no `intl` dependency in
/// this project, same convention as chat_inbox_screen.dart's.
String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = diff.inDays ~/ 7;
  if (weeks < 5) return '${weeks}w ago';
  return '${dt.month}/${dt.day}/${dt.year % 100}';
}

class AdminActivityLogScreen extends StatefulWidget {
  const AdminActivityLogScreen({super.key, required this.token});

  final String token;

  @override
  State<AdminActivityLogScreen> createState() => _AdminActivityLogScreenState();
}

class _AdminActivityLogScreenState extends State<AdminActivityLogScreen> {
  final ActivityLogService _service = ActivityLogService();

  String _filter = 'All';

  List<_ActivityEntry> _entries = const [];
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
      final page = await _service.fetchEntries(token: widget.token, limit: 50);
      if (!mounted) return;
      final rows = (page['entries'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _entries = rows.map(_ActivityEntry.fromJson).toList();
        _loading = false;
      });
    } on ActivityLogServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  List<_ActivityEntry> get _filtered {
    return _entries.where((e) {
      return switch (_filter) {
        'Approvals' => e.type == _ActivityType.approval,
        'Rejections' => e.type == _ActivityType.rejection,
        _ => true,
      };
    }).toList();
  }

  IconData _iconFor(_ActivityType type) =>
      type == _ActivityType.approval ? Icons.check_circle_outline_rounded : Icons.cancel_outlined;

  Color _colorFor(_ActivityType type) => type == _ActivityType.approval ? AppColors.success : AppColors.danger;

  @override
  Widget build(BuildContext context) {
    final entries = _filtered;
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Activity Log', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: AdminFilterChips(
                  options: const ['All', 'Approvals', 'Rejections'],
                  selected: _filter,
                  onSelected: (v) => setState(() => _filter = v),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off_rounded, size: 34, color: AppColors.slate),
                                const SizedBox(height: 12),
                                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.slate, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 14),
                                OutlinedButton(onPressed: _load, child: const Text('Try again')),
                              ],
                            ),
                          ),
                        )
                      : entries.isEmpty
                          ? const AdminEmptyState(message: 'No activity yet.', icon: Icons.history_rounded)
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                                itemCount: entries.length,
                                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final e = entries[index];
                                  return Container(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    decoration: BoxDecoration(
                                      color: AppColors.card,
                                      borderRadius: BorderRadius.circular(AppRadii.lg),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(_iconFor(e.type), size: 20, color: _colorFor(e.type)),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Text(e.description, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(_relativeTime(e.createdAt), style: const TextStyle(fontSize: 11.5, color: AppColors.slate)),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
