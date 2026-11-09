import 'package:uuid/uuid.dart';

class SaRecord {
  static const Uuid _uuid = Uuid();

  final int? id;
  final String clientId;
  final String idPelanggan;
  final String nama;
  final String noHpUtama;
  final String noHpAlternatif;
  final String alamat;
  final double? latitude;
  final double? longitude;
  final String paket;
  final String tanggalPasang;
  // --- Kolom sinkronisasi Fase 11 (SQLite v9) ---
  final int syncState;
  final String updatedAt;
  final bool deleted;

  SaRecord({
    this.id,
    String? clientId,
    required this.idPelanggan,
    required this.nama,
    this.noHpUtama = '',
    this.noHpAlternatif = '',
    required this.alamat,
    this.latitude,
    this.longitude,
    required this.paket,
    required this.tanggalPasang,
    this.syncState = 0,
    String? updatedAt,
    this.deleted = false,
  }) : clientId = (clientId != null && clientId.trim().isNotEmpty)
           ? clientId.trim()
           : _uuid.v4(),
       updatedAt = (updatedAt != null && updatedAt.trim().isNotEmpty)
           ? updatedAt.trim()
           : DateTime.now().toUtc().toIso8601String();

  SaRecord copyWith({
    int? id,
    String? clientId,
    String? idPelanggan,
    String? nama,
    String? noHpUtama,
    String? noHpAlternatif,
    String? alamat,
    double? latitude,
    double? longitude,
    String? paket,
    String? tanggalPasang,
    int? syncState,
    String? updatedAt,
    bool? deleted,
  }) {
    return SaRecord(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      idPelanggan: idPelanggan ?? this.idPelanggan,
      nama: nama ?? this.nama,
      noHpUtama: noHpUtama ?? this.noHpUtama,
      noHpAlternatif: noHpAlternatif ?? this.noHpAlternatif,
      alamat: alamat ?? this.alamat,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      paket: paket ?? this.paket,
      tanggalPasang: tanggalPasang ?? this.tanggalPasang,
      syncState: syncState ?? this.syncState,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'id_pelanggan': idPelanggan,
      'nama': nama,
      'no_hp_utama': noHpUtama,
      'no_hp_alternatif': noHpAlternatif,
      'alamat': alamat,
      'latitude': latitude,
      'longitude': longitude,
      'paket': paket,
      'tanggal_pasang': tanggalPasang,
      'sync_state': syncState,
      'updated_at': updatedAt,
      'deleted': deleted ? 1 : 0,
    };
  }

  factory SaRecord.fromMap(Map<String, dynamic> map) {
    return SaRecord(
      id: map['id'] as int?,
      clientId: map['client_id']?.toString(),
      idPelanggan: map['id_pelanggan'] as String,
      nama: map['nama'] as String,
      noHpUtama: (map['no_hp_utama'] as String?) ?? '',
      noHpAlternatif: (map['no_hp_alternatif'] as String?) ?? '',
      alamat: map['alamat'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      paket: map['paket'] as String,
      tanggalPasang: map['tanggal_pasang'] as String,
      syncState: (map['sync_state'] as num?)?.toInt() ?? 0,
      updatedAt: map['updated_at']?.toString(),
      deleted: ((map['deleted'] as num?)?.toInt() ?? 0) == 1,
    );
  }

  /// Normalisasi string tanggal pasang ke `yyyy-MM-dd` atau `null` bila kosong/tidak valid.
  static String? normalizeIsoDate(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
    if (isoMatch != null) {
      return '${isoMatch.group(1)}-${isoMatch.group(2)}-${isoMatch.group(3)}';
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) {
      return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    }
    return null;
  }

  /// Konversi ke payload JSON untuk tabel `public.sa_customers` di Supabase.
  Map<String, dynamic> toSupabaseJson({String? userId}) {
    final payload = <String, dynamic>{
      'client_id': clientId,
      'id_pelanggan': idPelanggan,
      'nama': nama,
      'no_hp_utama': noHpUtama,
      'no_hp_alternatif': noHpAlternatif,
      'alamat': alamat,
      'latitude': latitude,
      'longitude': longitude,
      'paket': paket,
      'tanggal_pasang': normalizeIsoDate(tanggalPasang),
      'updated_at': updatedAt,
      'deleted_at': deleted ? updatedAt : null,
    };
    if (userId != null && userId.trim().isNotEmpty) {
      payload['user_id'] = userId.trim();
    }
    return payload;
  }

  /// Membuat [SaRecord] dari baris JSON Supabase `public.sa_customers`.
  factory SaRecord.fromSupabaseJson(Map<String, dynamic> json) {
    return SaRecord(
      clientId: json['client_id']?.toString(),
      idPelanggan: (json['id_pelanggan'] ?? '').toString(),
      nama: (json['nama'] ?? '').toString(),
      noHpUtama: (json['no_hp_utama'] ?? '').toString(),
      noHpAlternatif: (json['no_hp_alternatif'] ?? '').toString(),
      alamat: (json['alamat'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      paket: (json['paket'] ?? '').toString(),
      tanggalPasang: (json['tanggal_pasang'] ?? '').toString(),
      syncState: 1,
      updatedAt: json['updated_at']?.toString(),
      deleted: json['deleted_at'] != null,
    );
  }

  bool get hasLocation => latitude != null && longitude != null;
}
