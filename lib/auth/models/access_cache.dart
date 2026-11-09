import 'member_status.dart';

/// Model cache status akses yang disimpan terenkripsi di local storage
class AccessCache {
  final MemberStatus status;
  final DateTime checkedAt;
  final DateTime
  validUntil; // checkedAt + graceDuration (hanya relevan jika status == approved)
  final TeamRole role;
  final String? salesName;

  const AccessCache({
    required this.status,
    required this.checkedAt,
    required this.validUntil,
    this.role = TeamRole.member,
    this.salesName,
  });

  /// Cek apakah pengguna memiliki akses superadmin/admin
  bool get isSuperadmin => role.isSuperadmin;

  /// Cek apakah pengguna memiliki hak melihat seluruh data tim (SPV/TSC/Admin/Superadmin)
  bool get canViewAll => role.canViewAll;

  /// Cek apakah pengguna dapat mengubah role anggota tim (khusus Superadmin)
  bool get canEditRoles => role.canEditRoles;

  /// Cek apakah masa tenggang offline sudah kedaluwarsa
  bool get isExpired => DateTime.now().isAfter(validUntil);

  /// Cek apakah akses diizinkan masuk ke aplikasi utama
  bool get isAccessAllowed => status == MemberStatus.approved && !isExpired;

  static String? _cleanSalesName(dynamic raw) {
    if (raw == null) return null;
    final trimmed = raw.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status.toDbString(),
      'checked_at': checkedAt.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'role': role.toDbString(),
      if (salesName != null && salesName!.isNotEmpty) 'sales_name': salesName,
    };
  }

  factory AccessCache.fromJson(Map<String, dynamic> json) {
    return AccessCache(
      status: MemberStatus.fromString(json['status'] as String?),
      checkedAt:
          DateTime.tryParse(json['checked_at'] as String? ?? '') ??
          DateTime.now(),
      validUntil:
          DateTime.tryParse(json['valid_until'] as String? ?? '') ??
          DateTime.now(),
      role: TeamRole.fromString(json['role'] as String?),
      salesName: _cleanSalesName(json['sales_name']),
    );
  }

  @override
  String toString() =>
      'AccessCache(status: $status, role: $role, salesName: $salesName, checkedAt: $checkedAt, validUntil: $validUntil)';
}
