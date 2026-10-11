import 'member_status.dart';

/// Model representasi data anggota tim untuk panel Superadmin
class TeamMemberItem {
  final String userId;
  final String email;
  final String name;
  final MemberStatus status;
  final TeamRole role;
  final DateTime? createdAt;
  final DateTime? approvedAt;

  const TeamMemberItem({
    required this.userId,
    required this.email,
    required this.name,
    required this.status,
    required this.role,
    this.createdAt,
    this.approvedAt,
  });

  bool get isSuperadmin => role.isSuperadmin;
  bool get isApproved => status == MemberStatus.approved;
  bool get isPending => status == MemberStatus.pending;
  bool get isRevoked => status == MemberStatus.revoked;

  factory TeamMemberItem.fromJson(Map<String, dynamic> json) {
    return TeamMemberItem(
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: MemberStatus.fromString(json['status'] as String?),
      role: TeamRole.fromString(json['role'] as String?),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      approvedAt: DateTime.tryParse(json['approved_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'name': name,
      'status': status.toDbString(),
      'role': role.toDbString(),
      'created_at': createdAt?.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
    };
  }
}
