import 'user_role.dart';

enum RoleUpgradeStatus { pending, approved, rejected }

RoleUpgradeStatus _statusFromString(String value) => switch (value) {
      'approved' => RoleUpgradeStatus.approved,
      'rejected' => RoleUpgradeStatus.rejected,
      _ => RoleUpgradeStatus.pending,
    };

extension RoleUpgradeStatusX on RoleUpgradeStatus {
  String get label => switch (this) {
        RoleUpgradeStatus.pending => 'In review',
        RoleUpgradeStatus.approved => 'Approved',
        RoleUpgradeStatus.rejected => 'Not approved',
      };
}

/// A Visitor's request to switch to a different role (Affiliater, Agent /
/// Broker, or Investor). Backed by `POST/GET /api/role-upgrade-requests`
/// — see `RoleUpgradeService`.
class RoleUpgradeRequest {
  final String id;
  final UserRole requestedRole;
  final RoleUpgradeStatus status;
  final String? message;
  final String? agencyOrLicense;
  final bool interestedInFractionalInvesting;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime? decidedAt;

  /// Present only on admin-facing rows (the pending queue) — the
  /// requester's identity and current role, joined server-side.
  final String? userFullName;
  final String? userEmail;
  final String? currentRole;

  const RoleUpgradeRequest({
    required this.id,
    required this.requestedRole,
    required this.status,
    this.message,
    this.agencyOrLicense,
    this.interestedInFractionalInvesting = false,
    this.adminNote,
    required this.createdAt,
    this.decidedAt,
    this.userFullName,
    this.userEmail,
    this.currentRole,
  });

  factory RoleUpgradeRequest.fromJson(Map<String, dynamic> json) => RoleUpgradeRequest(
        id: json['id'] as String,
        requestedRole: UserRole.values.firstWhere(
          (r) => r.apiValue == json['requestedRole'],
          orElse: () => UserRole.affiliater,
        ),
        status: _statusFromString(json['status'] as String? ?? 'pending'),
        message: json['message'] as String?,
        agencyOrLicense: json['agencyOrLicense'] as String?,
        interestedInFractionalInvesting: json['interestedInFractionalInvesting'] as bool? ?? false,
        adminNote: json['adminNote'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        decidedAt: json['decidedAt'] != null ? DateTime.tryParse(json['decidedAt'] as String) : null,
        userFullName: json['userFullName'] as String?,
        userEmail: json['userEmail'] as String?,
        currentRole: json['currentRole'] as String?,
      );
}
