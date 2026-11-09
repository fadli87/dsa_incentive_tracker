import 'member_status.dart';

/// Model representasi data anggota tim untuk panel Superadmin
class TeamMemberItem {
  final String userId;
  final String email;
  final String name;
  final MemberStatus status;
  final TeamRole role;
  final String? salesName;
  final DateTime? createdAt;
  final DateTime? approvedAt;

  const TeamMemberItem({
    required this.userId,
    required this.email,
    required this.name,
    required this.status,
    required this.role,
    this.salesName,
    this.createdAt,
    this.approvedAt,
  });

  bool get isSuperadmin => role.isSuperadmin;
  bool get canViewAll => role.canViewAll;
  bool get isApproved => status == MemberStatus.approved;
  bool get isPending => status == MemberStatus.pending;
  bool get isRevoked => status == MemberStatus.revoked;

  static String? _cleanNonEmpty(dynamic raw) {
    if (raw == null) return null;
    final trimmed = raw.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  factory TeamMemberItem.fromJson(Map<String, dynamic> json) {
    return TeamMemberItem(
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: MemberStatus.fromString(json['status'] as String?),
      role: TeamRole.fromString(json['role'] as String?),
      salesName: _cleanNonEmpty(json['sales_name']),
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
      if (salesName != null && salesName!.isNotEmpty) 'sales_name': salesName,
      'created_at': createdAt?.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
    };
  }
}
