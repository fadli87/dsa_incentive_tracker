import 'package:uuid/uuid.dart';

/// Fungsi murni untuk mem-parse teks `periode` lama (misal "Nov 2026",
/// "November 2026", "Oktober 2026", "Okt 2026", "2026-11", "2026-11-01")
/// menjadi string tanggal 1 bulan tersebut dalam format `yyyy-MM-01`.
/// Mengembalikan `null` bila teks tidak dapat dikenali.
String? tryParsePeriodMonth(String periode) {
  final raw = periode.trim();
  if (raw.isEmpty) return null;

  // 1. Cek format ISO langsung: yyyy-MM atau yyyy-MM-dd
  final isoMatch = RegExp(r'^(\d{4})-(\d{2})(?:-(\d{2}))?$').firstMatch(raw);
  if (isoMatch != null) {
    final year = int.tryParse(isoMatch.group(1)!);
    final month = int.tryParse(isoMatch.group(2)!);
    if (year != null &&
        year >= 1970 &&
        year <= 2100 &&
        month != null &&
        month >= 1 &&
        month <= 12) {
      return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    }
  }

  // 2. Kamus nama bulan singkat & lengkap (Indonesia & Inggris)
  const monthMap = <String, int>{
    'jan': 1,
    'januari': 1,
    'january': 1,
    'feb': 2,
    'februari': 2,
    'february': 2,
    'mar': 3,
    'maret': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'mei': 5,
    'may': 5,
    'jun': 6,
    'juni': 6,
    'june': 6,
    'jul': 7,
    'juli': 7,
    'july': 7,
    'agu': 8,
    'ags': 8,
    'agustus': 8,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'okt': 10,
    'oktober': 10,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'nop': 11,
    'november': 11,
    'nopember': 11,
    'des': 12,
    'desember': 12,
    'dec': 12,
    'december': 12,
  };

  final tokens = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  if (tokens.length < 2) return null;

  int? foundMonth;
  int? foundYear;

  for (final token in tokens) {
    final m = monthMap[token];
    if (m != null && foundMonth == null) {
      foundMonth = m;
      continue;
    }
    if (RegExp(r'^\d{4}$').hasMatch(token) && foundYear == null) {
      final y = int.tryParse(token);
      if (y != null && y >= 1970 && y <= 2100) {
        foundYear = y;
      }
    }
  }

  if (foundMonth != null && foundYear != null) {
    return '${foundYear.toString().padLeft(4, '0')}-${foundMonth.toString().padLeft(2, '0')}-01';
  }

  return null;
}

class IncentiveRecord {
  static const Uuid _uuid = Uuid();

  final int? id;
  final String clientId;
  final String periode;
  final String? periodMonth;
  final String position;
  final String city;
  final double basicFee;
  final int totalSa;
  final double pmBase;
  final double multRate;
  final double multBonus;
  final double progInc;
  final double specialInc;
  final double monthlySubtotal;
  final double grandTotal;
  // --- Input mentah, disimpan supaya bisa direkalkulasi ulang saat edit ---
  final int f0;
  final int f50;
  final int f100;
  final int f125;
  final int f200;
  final int fwa;
  final int p35;
  final int p6;
  // --- Kolom sinkronisasi Fase 11 (SQLite v9) ---
  final int syncState;
  final String updatedAt;
  final bool deleted;

  IncentiveRecord({
    this.id,
    String? clientId,
    required this.periode,
    this.periodMonth,
    this.position = 'Elite',
    this.city = 'KAB. CILACAP',
    this.basicFee = 0.0,
    required this.totalSa,
    required this.pmBase,
    required this.multRate,
    required this.multBonus,
    required this.progInc,
    required this.specialInc,
    double? monthlySubtotal,
    required this.grandTotal,
    this.f0 = 0,
    this.f50 = 0,
    this.f100 = 0,
    this.f125 = 0,
    this.f200 = 0,
    this.fwa = 0,
    this.p35 = 0,
    this.p6 = 0,
    this.syncState = 0,
    String? updatedAt,
    this.deleted = false,
  }) : clientId = (clientId != null && clientId.trim().isNotEmpty)
           ? clientId.trim()
           : _uuid.v4(),
       updatedAt = (updatedAt != null && updatedAt.trim().isNotEmpty)
           ? updatedAt.trim()
           : DateTime.now().toUtc().toIso8601String(),
       monthlySubtotal = monthlySubtotal ?? grandTotal;

  /// Mengembalikan format `yyyy-MM-01` untuk bulan berjalan dari [now] (default `DateTime.now()`).
  static String currentMonthIso([DateTime? now]) {
    final dt = now ?? DateTime.now();
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-01';
  }

  /// Alias statis ke fungsi murni [tryParsePeriodMonth].
  static String? parsePeriodMonth(String periode) =>
      tryParsePeriodMonth(periode);

  IncentiveRecord copyWith({
    int? id,
    String? clientId,
    String? periode,
    String? periodMonth,
    bool clearPeriodMonth = false,
    String? position,
    String? city,
    double? basicFee,
    int? totalSa,
    double? pmBase,
    double? multRate,
    double? multBonus,
    double? progInc,
    double? specialInc,
    double? monthlySubtotal,
    double? grandTotal,
    int? f0,
    int? f50,
    int? f100,
    int? f125,
    int? f200,
    int? fwa,
    int? p35,
    int? p6,
    int? syncState,
    String? updatedAt,
    bool? deleted,
  }) {
    return IncentiveRecord(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      periode: periode ?? this.periode,
      periodMonth: clearPeriodMonth ? null : (periodMonth ?? this.periodMonth),
      position: position ?? this.position,
      city: city ?? this.city,
      basicFee: basicFee ?? this.basicFee,
      totalSa: totalSa ?? this.totalSa,
      pmBase: pmBase ?? this.pmBase,
      multRate: multRate ?? this.multRate,
      multBonus: multBonus ?? this.multBonus,
      progInc: progInc ?? this.progInc,
      specialInc: specialInc ?? this.specialInc,
      monthlySubtotal: monthlySubtotal ?? this.monthlySubtotal,
      grandTotal: grandTotal ?? this.grandTotal,
      f0: f0 ?? this.f0,
      f50: f50 ?? this.f50,
      f100: f100 ?? this.f100,
      f125: f125 ?? this.f125,
      f200: f200 ?? this.f200,
      fwa: fwa ?? this.fwa,
      p35: p35 ?? this.p35,
      p6: p6 ?? this.p6,
      syncState: syncState ?? this.syncState,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'periode': periode,
      'period_month': periodMonth,
      'position': position,
      'city': city,
      'basic_fee': basicFee,
      'total_sa': totalSa,
      'pm_base': pmBase,
      'mult_rate': multRate,
      'mult_bonus': multBonus,
      'prog_inc': progInc,
      'special_inc': specialInc,
      'monthly_subtotal': monthlySubtotal,
      'grand_total': grandTotal,
      'f0': f0,
      'f50': f50,
      'f100': f100,
      'f125': f125,
      'f200': f200,
      'fwa': fwa,
      'p35': p35,
      'p6': p6,
      'sync_state': syncState,
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory IncentiveRecord.fromMap(Map<String, dynamic> map) {
    final grandTotalVal = (map['grand_total'] as num).toDouble();
    final rawPeriodMonth = map['period_month']?.toString().trim();
    final periodeStr = map['periode'] as String;
    return IncentiveRecord(
      id: map['id'] as int?,
      clientId: map['client_id']?.toString(),
      periode: periodeStr,
      periodMonth: (rawPeriodMonth != null && rawPeriodMonth.isNotEmpty)
          ? rawPeriodMonth
          : tryParsePeriodMonth(periodeStr),
      position: (map['position'] as String?) ?? 'Elite',
      city: (map['city'] as String?) ?? 'KAB. CILACAP',
      basicFee: (map['basic_fee'] as num?)?.toDouble() ?? 0.0,
      totalSa: (map['total_sa'] as num).toInt(),
      pmBase: (map['pm_base'] as num).toDouble(),
      multRate: (map['mult_rate'] as num).toDouble(),
      multBonus: (map['mult_bonus'] as num).toDouble(),
      progInc: (map['prog_inc'] as num).toDouble(),
      specialInc: (map['special_inc'] as num).toDouble(),
      monthlySubtotal:
          (map['monthly_subtotal'] as num?)?.toDouble() ?? grandTotalVal,
      grandTotal: grandTotalVal,
      f0: (map['f0'] as num?)?.toInt() ?? 0,
      f50: (map['f50'] as num?)?.toInt() ?? 0,
      f100: (map['f100'] as num?)?.toInt() ?? 0,
      f125: (map['f125'] as num?)?.toInt() ?? 0,
      f200: (map['f200'] as num?)?.toInt() ?? 0,
      fwa: (map['fwa'] as num?)?.toInt() ?? 0,
      p35: (map['p35'] as num?)?.toInt() ?? 0,
      p6: (map['p6'] as num?)?.toInt() ?? 0,
      syncState: (map['sync_state'] as num?)?.toInt() ?? 0,
      updatedAt: map['updated_at']?.toString(),
      deleted: ((map['deleted'] as num?)?.toInt() ?? 0) == 1,
    );
  }

  /// Konversi ke payload JSON untuk tabel `public.incentive_records` di Supabase.
  Map<String, dynamic> toSupabaseJson({String? userId}) {
    final normalizedPeriodMonth =
        (periodMonth != null && periodMonth!.trim().isNotEmpty)
        ? tryParsePeriodMonth(periodMonth!)
        : tryParsePeriodMonth(periode);
    final payload = <String, dynamic>{
      'client_id': clientId,
      'periode': periode,
      'period_month': normalizedPeriodMonth,
      'position': position,
      'city': city,
      'basic_fee': basicFee,
      'total_sa': totalSa,
      'pm_base': pmBase,
      'mult_rate': multRate,
      'mult_bonus': multBonus,
      'prog_inc': progInc,
      'special_inc': specialInc,
      'monthly_subtotal': monthlySubtotal,
      'grand_total': grandTotal,
      'f0': f0,
      'f50': f50,
      'f100': f100,
      'f125': f125,
      'f200': f200,
      'fwa': fwa,
      'p35': p35,
      'p6': p6,
      'updated_at': updatedAt,
      'deleted_at': deleted ? updatedAt : null,
    };
    if (userId != null && userId.trim().isNotEmpty) {
      payload['user_id'] = userId.trim();
    }
    return payload;
  }

  /// Membuat [IncentiveRecord] dari baris JSON Supabase `public.incentive_records`.
  factory IncentiveRecord.fromSupabaseJson(Map<String, dynamic> json) {
    final grandTotalVal = (json['grand_total'] as num?)?.toDouble() ?? 0.0;
    final rawPeriodMonth = json['period_month']?.toString().trim();
    final periodeStr = (json['periode'] ?? '').toString();
    return IncentiveRecord(
      clientId: json['client_id']?.toString(),
      periode: periodeStr,
      periodMonth: (rawPeriodMonth != null && rawPeriodMonth.isNotEmpty)
          ? tryParsePeriodMonth(rawPeriodMonth)
          : tryParsePeriodMonth(periodeStr),
      position: (json['position'] as String?) ?? 'Elite',
      city: (json['city'] as String?) ?? 'KAB. CILACAP',
      basicFee: (json['basic_fee'] as num?)?.toDouble() ?? 0.0,
      totalSa: (json['total_sa'] as num?)?.toInt() ?? 0,
      pmBase: (json['pm_base'] as num?)?.toDouble() ?? 0.0,
      multRate: (json['mult_rate'] as num?)?.toDouble() ?? 0.0,
      multBonus: (json['mult_bonus'] as num?)?.toDouble() ?? 0.0,
      progInc: (json['prog_inc'] as num?)?.toDouble() ?? 0.0,
      specialInc: (json['special_inc'] as num?)?.toDouble() ?? 0.0,
      monthlySubtotal:
          (json['monthly_subtotal'] as num?)?.toDouble() ?? grandTotalVal,
      grandTotal: grandTotalVal,
      f0: (json['f0'] as num?)?.toInt() ?? 0,
      f50: (json['f50'] as num?)?.toInt() ?? 0,
      f100: (json['f100'] as num?)?.toInt() ?? 0,
      f125: (json['f125'] as num?)?.toInt() ?? 0,
      f200: (json['f200'] as num?)?.toInt() ?? 0,
      fwa: (json['fwa'] as num?)?.toInt() ?? 0,
      p35: (json['p35'] as num?)?.toInt() ?? 0,
      p6: (json['p6'] as num?)?.toInt() ?? 0,
      syncState: 1,
      updatedAt: json['updated_at']?.toString(),
      deleted: json['deleted_at'] != null,
    );
  }
}
