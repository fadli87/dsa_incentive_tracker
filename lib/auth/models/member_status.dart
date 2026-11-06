/// Status keanggotaan sales di tim
enum MemberStatus {
  pending,
  approved,
  revoked,
  unknown;

  static MemberStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'approved':
        return MemberStatus.approved;
      case 'pending':
        return MemberStatus.pending;
      case 'revoked':
        return MemberStatus.revoked;
      default:
        return MemberStatus.unknown;
    }
  }

  String toDbString() {
    switch (this) {
      case MemberStatus.approved:
        return 'approved';
      case MemberStatus.pending:
        return 'pending';
      case MemberStatus.revoked:
        return 'revoked';
      case MemberStatus.unknown:
        return 'unknown';
    }
  }
}

/// Role pengguna di sistem tim
enum TeamRole {
  member,
  spv,
  tsc,
  admin,
  superadmin;

  static TeamRole fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'superadmin':
        return TeamRole.superadmin;
      case 'admin':
        return TeamRole.admin;
      case 'spv':
        return TeamRole.spv;
      case 'tsc':
        return TeamRole.tsc;
      default:
        return TeamRole.member;
    }
  }

  String toDbString() => name;

  bool get isSuperadmin => this == TeamRole.superadmin || this == TeamRole.admin;

  bool get canViewAll => this != TeamRole.member;

  bool get canEditRoles => this == TeamRole.superadmin;

  String get displayLabel {
    switch (this) {
      case TeamRole.member:
        return 'Sales';
      case TeamRole.spv:
        return 'SPV';
      case TeamRole.tsc:
        return 'TSC';
      case TeamRole.admin:
        return 'Admin';
      case TeamRole.superadmin:
        return 'Superadmin';
    }
  }
}

