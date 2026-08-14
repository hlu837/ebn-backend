import 'package:flutter/material.dart';
import '../models/broker.dart';
import '../services/agent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/admin_list_widgets.dart';
import 'admin_agent_detail_screen.dart';

/// Admin's "Agents & Team" directory — a real read of `GET /api/agents`
/// (the same Broker Network directory endpoint the dispatch sheet on
/// [AdminHomeScreen] and the Visitor/Agent sides already use), mapped
/// through the shared [Broker] model rather than a page-local mock.
/// "Online" mirrors the same signal the Agent side's own dashboard uses:
/// whether the agent has a saved location on file.
class AdminAgentsScreen extends StatefulWidget {
  const AdminAgentsScreen({super.key});

  @override
  State<AdminAgentsScreen> createState() => _AdminAgentsScreenState();
}

class _AdminAgentsScreenState extends State<AdminAgentsScreen> {
  final AgentService _agentService = AgentService();

  String _filter = 'All';
  String _query = '';

  List<Broker> _agents = const [];
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
      final rows = await _agentService.fetchDirectory();
      if (!mounted) return;
      setState(() {
        _agents = rows.map(Broker.fromDirectoryJson).toList();
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

  List<Broker> get _filtered {
    return _agents.where((a) {
      final matchesFilter = switch (_filter) {
        'Online' => a.hasPreciseLocation,
        'Offline' => !a.hasPreciseLocation,
        _ => true,
      };
      final matchesQuery = _query.trim().isEmpty || a.name.toLowerCase().contains(_query.trim().toLowerCase());
      return matchesFilter && matchesQuery;
    }).toList();
  }

  void _openAddAgent() {
    // Agents self-register through the normal Sign Up flow (role: agent) —
    // there's no separate admin-side "create agent" endpoint, so this
    // just points admins at how it actually works instead of faking a form.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Agents sign up themselves via the app — there\'s no separate admin "add agent" flow yet.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final agents = _filtered;
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Agents & Team', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(tooltip: 'Add agent', onPressed: _openAddAgent, icon: const Icon(Icons.person_add_alt_1_rounded)),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: Column(
                children: [
                  AdminSearchField(hintText: 'Search agents by name', onChanged: (v) => setState(() => _query = v)),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AdminFilterChips(
                      options: const ['All', 'Online', 'Offline'],
                      selected: _filter,
                      onSelected: (v) => setState(() => _filter = v),
                    ),
                  ),
                ],
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
                      : agents.isEmpty
                          ? const AdminEmptyState(message: 'No agents match this filter.', icon: Icons.groups_outlined)
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                                itemCount: agents.length,
                                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final agent = agents[index];
                                  final online = agent.hasPreciseLocation;
                                  return AdminEntityRow(
                                    leadingIcon: Icons.person_rounded,
                                    title: agent.name,
                                    subtitle: [
                                      if (agent.phone != null && agent.phone!.isNotEmpty) agent.phone!,
                                      '${agent.tier.label} tier',
                                      agent.rating > 0 ? '${agent.rating.toStringAsFixed(1)}★' : 'No reviews yet',
                                    ].join(' · '),
                                    trailingText: online ? 'ONLINE' : 'OFFLINE',
                                    trailingColor: online ? AppColors.success : AppColors.slate,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => AdminAgentDetailScreen(agent: agent)),
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
