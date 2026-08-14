/// A single item on the agent's to-do list — backs the dashboard's "Tasks"
/// quick action. `createdBy == 'admin'` is what "Shared tasks from Admin"
/// (in the old placeholder's description) actually means once Admin gets
/// its own UI for assigning these; for now every task an agent creates
/// here is `'agent'`.
class AgentTask {
  final String id;
  final String agentId;
  final String title;
  final bool done;
  final DateTime? dueAt;
  final String? linkedTourRequestId;
  final String? linkedOrderRequestId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AgentTask({
    required this.id,
    required this.agentId,
    required this.title,
    required this.done,
    this.dueAt,
    this.linkedTourRequestId,
    this.linkedOrderRequestId,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFromAdmin => createdBy == 'admin';

  factory AgentTask.fromJson(Map<String, dynamic> json) {
    return AgentTask(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      title: json['title'] as String,
      done: json['done'] as bool? ?? false,
      dueAt: json['dueAt'] != null ? DateTime.tryParse(json['dueAt'] as String) : null,
      linkedTourRequestId: json['linkedTourRequestId'] as String?,
      linkedOrderRequestId: json['linkedOrderRequestId'] as String?,
      createdBy: json['createdBy'] as String? ?? 'agent',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  AgentTask copyWith({bool? done}) {
    return AgentTask(
      id: id,
      agentId: agentId,
      title: title,
      done: done ?? this.done,
      dueAt: dueAt,
      linkedTourRequestId: linkedTourRequestId,
      linkedOrderRequestId: linkedOrderRequestId,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
