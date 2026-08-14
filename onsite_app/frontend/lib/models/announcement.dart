/// A single admin-authored news/announcement post — backs the "News &
/// Announcements" feed (investor-facing read) and the admin management
/// screen (create/delete).
class Announcement {
  final String id;
  final String title;
  final String content;
  final String category;
  final bool isPinned;
  final DateTime createdAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.isPinned,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String? ?? 'General',
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
