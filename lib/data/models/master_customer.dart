/// Model lokal & remote untuk Master Pelanggan KCLP (`customer_master` / `customer_master_local`).
/// Hanya memuat kolom yang diizinkan (tanpa nomor seri ONT/WiFi/SIM, WO, SO, dll.).
class MasterCustomer {
  final String customerId;
  final DateTime? installDate;
  final String address;
  final String packageName;
  final double? latitude;
  final double? longitude;
  final String salesName;
  final String spvName;
  final String tscName;
  final String ownerUserId;
  final String syncedAt;

  const MasterCustomer({
    required this.customerId,
    this.installDate,
    this.address = '',
    this.packageName = '',
    this.latitude,
    this.longitude,
    this.salesName = '',
    this.spvName = '',
    this.tscName = '',
    this.ownerUserId = '',
    required this.syncedAt,
  });

  /// Mengembalikan tanggal install dalam format `yyyy-MM-dd`, atau `null` bila kosong.
  String? get installDateString {
    final dt = installDate;
    if (dt == null) return null;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude != 0.0 &&
      longitude != 0.0;

  static DateTime? parseDateOnly(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) {
      return DateTime(raw.year, raw.month, raw.day);
    }
    final text = raw.toString().trim();
    if (text.length < 10) return null;
    final sub = text.substring(0, 10);
    final parsed = DateTime.tryParse(sub);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static double? _parseDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      final val = raw.toDouble();
      return val == 0.0 ? null : val;
    }
    final parsed = double.tryParse(raw.toString().trim());
    if (parsed == null || parsed == 0.0) return null;
    return parsed;
  }

  MasterCustomer copyWith({
    String? customerId,
    DateTime? installDate,
    bool clearInstallDate = false,
    String? address,
    String? packageName,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    String? salesName,
    String? spvName,
    String? tscName,
    String? ownerUserId,
    String? syncedAt,
  }) {
    return MasterCustomer(
      customerId: customerId ?? this.customerId,
      installDate: clearInstallDate ? null : (installDate ?? this.installDate),
      address: address ?? this.address,
      packageName: packageName ?? this.packageName,
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      salesName: salesName ?? this.salesName,
      spvName: spvName ?? this.spvName,
      tscName: tscName ?? this.tscName,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customer_id': customerId,
      'install_date': installDateString,
      'address': address,
      'package_name': packageName,
      'latitude': latitude,
      'longitude': longitude,
      'sales_name': salesName,
      'spv_name': spvName,
      'tsc_name': tscName,
      'owner_user_id': ownerUserId,
      'synced_at': syncedAt,
    };
  }

  factory MasterCustomer.fromMap(Map<String, dynamic> map) {
    return MasterCustomer(
      customerId: (map['customer_id'] as String? ?? '').trim(),
      installDate: parseDateOnly(map['install_date']),
      address: map['address'] as String? ?? '',
      packageName: map['package_name'] as String? ?? '',
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      salesName: map['sales_name'] as String? ?? '',
      spvName: map['spv_name'] as String? ?? '',
      tscName: map['tsc_name'] as String? ?? '',
      ownerUserId: map['owner_user_id'] as String? ?? '',
      syncedAt:
          map['synced_at'] as String? ??
          DateTime.now().toUtc().toIso8601String(),
    );
  }

  factory MasterCustomer.fromSupabaseJson(
    Map<String, dynamic> json, {
    String ownerUserId = '',
    String? syncedAt,
  }) {
    return MasterCustomer(
      customerId: (json['customer_id'] as String? ?? '').trim(),
      installDate: parseDateOnly(json['install_date']),
      address: json['address'] as String? ?? '',
      packageName: json['package_name'] as String? ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      salesName: json['sales_name'] as String? ?? '',
      spvName: json['spv_name'] as String? ?? '',
      tscName: json['tsc_name'] as String? ?? '',
      ownerUserId: ownerUserId,
      syncedAt: syncedAt ?? DateTime.now().toUtc().toIso8601String(),
    );
  }
}

/// Opsi nama sales dari RPC `list_master_sales_names()` untuk layar klaim nama sales.
class MasterSalesNameOption {
  final String salesName;
  final String spvName;
  final int total;

  const MasterSalesNameOption({
    required this.salesName,
    this.spvName = '',
    required this.total,
  });

  factory MasterSalesNameOption.fromJson(Map<String, dynamic> json) {
    return MasterSalesNameOption(
      salesName: (json['sales_name'] as String? ?? '').trim(),
      spvName: (json['spv_name'] as String? ?? '').trim(),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Ringkasan status impor master pelanggan dari RPC `get_master_status()`.
class MasterStatusSummary {
  final int total;
  final DateTime? lastImport;
  final String lastBatch;
  final int withSales;

  const MasterStatusSummary({
    required this.total,
    this.lastImport,
    this.lastBatch = '',
    required this.withSales,
  });

  int get withoutSales => (total - withSales).clamp(0, total);

  bool isImportStale({DateTime? now, int thresholdDays = 35}) {
    if (lastImport == null) return total == 0;
    final ref = now ?? DateTime.now();
    return ref.difference(lastImport!).inDays > thresholdDays;
  }

  factory MasterStatusSummary.fromJson(Map<String, dynamic> json) {
    return MasterStatusSummary(
      total: (json['total'] as num?)?.toInt() ?? 0,
      lastImport: DateTime.tryParse(json['last_import']?.toString() ?? ''),
      lastBatch: json['last_batch'] as String? ?? '',
      withSales: (json['with_sales'] as num?)?.toInt() ?? 0,
    );
  }
}

