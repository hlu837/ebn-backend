/// One timestamped entry in an agent's running note log for a customer —
/// e.g. "called 8/1 — wants to see it Saturday". Entries are append-only:
/// there's no editing or deleting a past one, only adding a new one.
class CustomerNoteEntry {
  final String id;
  final String customerUserId;
  final String body;
  final DateTime createdAt;

  const CustomerNoteEntry({
    required this.id,
    required this.customerUserId,
    required this.body,
    required this.createdAt,
  });

  factory CustomerNoteEntry.fromJson(Map<String, dynamic> json) {
    return CustomerNoteEntry(
      id: json['id'] as String,
      customerUserId: json['customerUserId'] as String,
      body: json['body'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
