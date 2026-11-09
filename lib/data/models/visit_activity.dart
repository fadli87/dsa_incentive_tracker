/// Kategori aktivitas visit harian
enum VisitCategory {
  rvai,
  dismantle,
  unpaid;

  static VisitCategory fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'dismantle':
        return VisitCategory.dismantle;
      case 'unpaid':
        return VisitCategory.unpaid;
      case 'rvai':
      default:
        return VisitCategory.rvai;
    }
  }

  String toDbString() => name;

  String get displayLabel {
    switch (this) {
      case VisitCategory.rvai:
        return 'RVAI';
      case VisitCategory.dismantle:
        return 'Dismantle';
      case VisitCategory.unpaid:
        return 'Unpaid';
    }
  }

  /// Label persis untuk prefill Google Form manajemen
  String get googleFormLabel {
    switch (this) {
      case VisitCategory.rvai:
        return 'VISIT RVAI';
      case VisitCategory.dismantle:
        return 'DISMANTLE';
      case VisitCategory.unpaid:
        return 'UNPAID';
    }
  }
}

/// Status pelaksanaan visit harian
enum VisitStatus {
  belum,
  sudahVisit,
  followUp;

  static VisitStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'sudah_visit':
      case 'sudahvisit':
        return VisitStatus.sudahVisit;
      case 'follow_up':
      case 'followup':
        return VisitStatus.followUp;
      case 'belum':
      default:
        return VisitStatus.belum;
    }
  }

  String toDbString() {
    switch (this) {
      case VisitStatus.belum:
        return 'belum';
      case VisitStatus.sudahVisit:
        return 'sudah_visit';
      case VisitStatus.followUp:
        return 'follow_up';
    }
  }

  String get displayLabel {
    switch (this) {
      case VisitStatus.belum:
        return 'Belum Visit';
      case VisitStatus.sudahVisit:
        return 'Sudah Visit';
      case VisitStatus.followUp:
        return 'Follow-up';
    }
  }
}

/// Model data aktivitas visit harian pelanggan (RVAI / Dismantle / Unpaid)
class VisitActivity {
  final int? id;
  final String clientId;
  final String ownerUserId;
  final String customerId;
  final String customerName;
  final VisitCategory category;
  final VisitStatus status;
  final String address;
  final String packageName;
  final double? latitude;
  final double? longitude;
  final String plannedDate; // yyyy-MM-dd
  final String? visitedAt; // ISO-8601
  final String note;
  final bool formSubmitted;
  final int syncState; // 0 = pending, 1 = synced
  final String updatedAt; // ISO-8601
  final bool deleted;

  const VisitActivity({
    this.id,
    required this.clientId,
    this.ownerUserId = '',
    required this.customerId,
    this.customerName = '',
    required this.category,
    this.status = VisitStatus.belum,
    this.address = '',
    this.packageName = '',
    this.latitude,
    this.longitude,
    required this.plannedDate,
    this.visitedAt,
    this.note = '',
    this.formSubmitted = false,
    this.syncState = 0,
    required this.updatedAt,
    this.deleted = false,
  });

  bool get hasLocation => latitude != null && longitude != null;
  bool get isSynced => syncState == 1;

  VisitActivity copyWith({
    int? id,
    String? clientId,
    String? ownerUserId,
    String? customerId,
    String? customerName,
    VisitCategory? category,
    VisitStatus? status,
    String? address,
    String? packageName,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
    String? plannedDate,
    String? visitedAt,
    bool clearVisitedAt = false,
    String? note,
    bool? formSubmitted,
    int? syncState,
    String? updatedAt,
    bool? deleted,
  }) {
    return VisitActivity(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      category: category ?? this.category,
      status: status ?? this.status,
      address: address ?? this.address,
      packageName: packageName ?? this.packageName,
      latitude: clearLocation ? null : (latitude ?? this.latitude),
      longitude: clearLocation ? null : (longitude ?? this.longitude),
      plannedDate: plannedDate ?? this.plannedDate,
      visitedAt: clearVisitedAt ? null : (visitedAt ?? this.visitedAt),
      note: note ?? this.note,
      formSubmitted: formSubmitted ?? this.formSubmitted,
      syncState: syncState ?? this.syncState,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': ?id,
      'client_id': clientId,
      'owner_user_id': ownerUserId,
      'customer_id': customerId,
      'customer_name': customerName,
      'category': category.toDbString(),
      'status': status.toDbString(),
      'address': address,
      'package_name': packageName,
      'latitude': latitude,
      'longitude': longitude,
      'planned_date': plannedDate,
      'visited_at': visitedAt,
      'note': note,
      'form_submitted': formSubmitted ? 1 : 0,
      'sync_state': syncState,
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory VisitActivity.fromMap(Map<String, dynamic> map) {
    final rawFormSubmitted = map['form_submitted'];
    final isFormSubmitted = rawFormSubmitted == 1 || rawFormSubmitted == true;
    final rawDeleted = map['deleted'];
    final isDeleted = rawDeleted == 1 || rawDeleted == true || map['deleted_at'] != null;

    return VisitActivity(
      id: map['id'] is int ? map['id'] as int : null,
      clientId: (map['client_id'] as String?) ?? '',
      ownerUserId: (map['owner_user_id'] as String?) ?? '',
      customerId: (map['customer_id'] as String?) ?? '',
      customerName: (map['customer_name'] as String?) ?? '',
      category: VisitCategory.fromString(map['category'] as String?),
      status: VisitStatus.fromString(map['status'] as String?),
      address: (map['address'] as String?) ?? '',
      packageName: (map['package_name'] as String?) ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      plannedDate: (map['planned_date'] as String?) ?? '',
      visitedAt: map['visited_at'] as String?,
      note: (map['note'] as String?) ?? '',
      formSubmitted: isFormSubmitted,
      syncState: (map['sync_state'] as int?) ?? 0,
      updatedAt: (map['updated_at'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
      deleted: isDeleted,
    );
  }

  /// Konversi ke payload JSON untuk upsert ke tabel `public.visit_activities` di Supabase.
  /// Hanya mengirim `form_submitted: true` bila bernilai `true` (tidak pernah mengirim `false`
  /// agar tidak menimpa penanda server).
  Map<String, dynamic> toSupabaseJson({String? userId}) {
    return {
      'user_id': ?userId,
      'client_id': clientId,
      'customer_id': customerId,
      'customer_name': customerName,
      'category': category.toDbString(),
      'status': status.toDbString(),
      'address': address,
      'package_name': packageName,
      'latitude': latitude,
      'longitude': longitude,
      'planned_date': plannedDate,
      'visited_at': visitedAt,
      'note': note,
      if (formSubmitted) 'form_submitted': true,
      'updated_at': updatedAt,
      'deleted_at': deleted ? updatedAt : null,
    };
  }

  /// Buat instance lokal dari baris Supabase (saat restore)
  factory VisitActivity.fromSupabaseJson(Map<String, dynamic> json) {
    return VisitActivity(
      clientId: (json['client_id'] as String?) ?? '',
      ownerUserId: (json['user_id']?.toString()) ?? '',
      customerId: (json['customer_id'] as String?) ?? '',
      customerName: (json['customer_name'] as String?) ?? '',
      category: VisitCategory.fromString(json['category'] as String?),
      status: VisitStatus.fromString(json['status'] as String?),
      address: (json['address'] as String?) ?? '',
      packageName: (json['package_name'] as String?) ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      plannedDate: (json['planned_date'] as String?) ?? '',
      visitedAt: json['visited_at'] as String?,
      note: (json['note'] as String?) ?? '',
      formSubmitted: (json['form_submitted'] as bool?) ?? false,
      syncState: 1,
      updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
      deleted: json['deleted_at'] != null,
    );
  }
}
