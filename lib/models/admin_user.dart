import 'user_role.dart';

/// One row from `GET /api/users` / `GET /api/users/:id` — the real account
/// record, as seen by an admin. Replaces the old page-local `UserSummary`
/// scaffolding model in admin_users_screen.dart.
class AdminUser {
  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String? phone;
  final DateTime createdAt;
  final bool isSuspended;
  final DateTime? suspendedAt;

  const AdminUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.phone,
    required this.createdAt,
    required this.isSuspended,
    required this.suspendedAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: _roleFromApi(json['role'] as String?),
      phone: json['phone'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isSuspended: json['isSuspended'] as bool? ?? false,
      suspendedAt: json['suspendedAt'] != null ? DateTime.tryParse(json['suspendedAt'] as String) : null,
    );
  }

  static UserRole _roleFromApi(String? value) {
    for (final r in UserRole.values) {
      if (r.apiValue == value) return r;
    }
    return UserRole.user;
  }
}
