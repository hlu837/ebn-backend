import 'package:flutter/material.dart';

import '../models/agent_task.dart';
import '../models/auth_response.dart';
import '../services/agent_task_service.dart';
import '../theme/app_theme.dart';

String _formatDue(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  if (day == today) return 'Today';
  if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
  if (day.isBefore(today)) return 'Overdue · ${months[d.month - 1]} ${d.day}';
  return '${months[d.month - 1]} ${d.day}';
}

/// The agent's real to-do list — replaces what used to be a static
/// PlaceholderPage behind the dashboard's "Tasks" quick action. Backed by
/// `/api/agent-tasks` (create, toggle done, delete); every task belongs to
/// exactly one agent.
class AgentTasksScreen extends StatefulWidget {
  const AgentTasksScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AgentTasksScreen> createState() => _AgentTasksScreenState();
}

class _AgentTasksScreenState extends State<AgentTasksScreen> {
  final _service = AgentTaskService();
  String get _token => widget.user.token ?? '';

  late Future<List<AgentTask>> _future = _service.list(token: _token);

  Future<void> _refresh() async {
    final next = _service.list(token: _token);
    setState(() => _future = next);
    await next;
  }

  void _showError(Object e) {
    final message =
        e is AgentTaskException ? e.message : 'Something went wrong.';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(AgentTask task) async {
    // Optimistic: flip it in the current list immediately, roll back if
    // the server call fails.
    final current = await _future;
    final optimistic = current
        .map((t) => t.id == task.id ? t.copyWith(done: !task.done) : t)
        .toList();
    setState(() => _future = Future.value(optimistic));
    try {
      await _service.setDone(token: _token, id: task.id, done: !task.done);
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _future = Future.value(current));
      _showError(e);
    }
  }

  Future<void> _delete(AgentTask task) async {
    final current = await _future;
    final optimistic = current.where((t) => t.id != task.id).toList();
    setState(() => _future = Future.value(optimistic));
    try {
      await _service.delete(token: _token, id: task.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _future = Future.value(current));
      _showError(e);
    }
  }

  Future<void> _openAddTask() async {
    final controller = TextEditingController();
    DateTime? dueAt;
    final title = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cloud,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  MediaQuery.of(sheetContext).viewInsets.bottom +
                      AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2)),
                      alignment: Alignment.center),
                  const Text('New task',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        hintText: 'e.g. Follow up with Abebe about the villa'),
                    onSubmitted: (v) => Navigator.of(sheetContext).pop(v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.event_outlined,
                          size: 18,
                          color: dueAt == null
                              ? AppColors.slate
                              : AppColors.primaryYellow),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dueAt == null
                              ? 'No due date'
                              : 'Due ${_formatDue(dueAt!)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: dueAt == null
                                  ? AppColors.slate
                                  : AppColors.ink),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: sheetContext,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setSheetState(() => dueAt = picked);
                          }
                        },
                        child: Text(dueAt == null ? 'Set date' : 'Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(controller.text),
                    child: const Text('Add task'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (title == null || title.trim().isEmpty || !mounted) return;
    if (_token.trim().isEmpty) {
      _showError(const AgentTaskException(
          'Your session has expired. Please sign in again.'));
      return;
    }
    try {
      await _service.create(token: _token, title: title.trim(), dueAt: dueAt);
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cloud,
      appBar: AppBar(
        backgroundColor: AppColors.cloud,
        foregroundColor: AppColors.ink,
        title: const Text('Tasks',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTask,
        backgroundColor: AppColors.primaryYellow,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: FutureBuilder<List<AgentTask>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error is AgentTaskException
                  ? (snapshot.error as AgentTaskException).message
                  : 'Something went wrong.',
              onRetry: _refresh,
            );
          }
          final tasks = snapshot.data!;
          if (tasks.isEmpty) {
            return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(children: const [_EmptyTasks()]));
          }
          final open = tasks.where((t) => !t.done).toList();
          final done = tasks.where((t) => t.done).toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
              children: [
                if (open.isNotEmpty) ...[
                  Text('OPEN · ${open.length}',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate,
                          letterSpacing: 0.6)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final t in open) ...[
                    _TaskTile(
                        task: t,
                        onToggle: () => _toggle(t),
                        onDelete: () => _delete(t)),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
                if (done.isNotEmpty) ...[
                  Text('DONE · ${done.length}',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.slate,
                          letterSpacing: 0.6)),
                  const SizedBox(height: AppSpacing.sm),
                  for (final t in done) ...[
                    _TaskTile(
                        task: t,
                        onToggle: () => _toggle(t),
                        onDelete: () => _delete(t)),
                    const SizedBox(height: AppSpacing.sm),
                  ],
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

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_rounded, size: 40, color: AppColors.slate),
            SizedBox(height: AppSpacing.md),
            Text('No tasks yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            SizedBox(height: 6),
            Text('Tap the + button to add a follow-up, reminder, or to-do.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.slate)),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile(
      {required this.task, required this.onToggle, required this.onDelete});
  final AgentTask task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final overdue = !task.done &&
        task.dueAt != null &&
        task.dueAt!.isBefore(DateTime.now());
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadii.lg)),
        child:
            const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Icon(
                  task.done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: task.done ? AppColors.success : AppColors.slate,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: task.done ? AppColors.slate : AppColors.ink,
                          decoration:
                              task.done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (task.dueAt != null || task.isFromAdmin) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (task.dueAt != null)
                              Text(
                                _formatDue(task.dueAt!),
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: overdue
                                        ? AppColors.danger
                                        : AppColors.slate),
                              ),
                            if (task.dueAt != null && task.isFromAdmin)
                              const Text('  ·  ',
                                  style: TextStyle(
                                      fontSize: 11.5, color: AppColors.slate)),
                            if (task.isFromAdmin)
                              const Text('From Admin',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryYellow)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
