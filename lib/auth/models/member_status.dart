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
