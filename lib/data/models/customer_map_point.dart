import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Kategori bergulir bulan pasang terhadap bulan berjalan (zona waktu WIB / lokal).
enum InstallMonthCategory {
  thisMonth('Bulan ini', Color(0xFFE53935)),
  lastMonth('Bulan lalu', Color(0xFF1E3A8A)),
  twoMonthsAgo('2 bulan lalu', Color(0xFFEC407A)),
  threeMonthsAgo('3 bulan lalu', Color(0xFF6D4C41)),
  older('Lebih lama / tanpa tanggal', Color(0xFF757575));

  final String label;
  final Color color;

  const InstallMonthCategory(this.label, this.color);
}

/// Fungsi murni untuk menghitung kategori bulan pasang dari `installDate` relatif terhadap `now`.
/// Menangani pergantian tahun (misal: Januari 2027 melihat Desember 2026 sebagai bulan lalu).
InstallMonthCategory installMonthBucket(DateTime? installDate, DateTime now) {
  if (installDate == null) {
    return InstallMonthCategory.older;
  }
  final int diffMonths =
      (now.year - installDate.year) * 12 + (now.month - installDate.month);

  switch (diffMonths) {
    case 0:
      return InstallMonthCategory.thisMonth;
    case 1:
      return InstallMonthCategory.lastMonth;
    case 2:
      return InstallMonthCategory.twoMonthsAgo;
    case 3:
      return InstallMonthCategory.threeMonthsAgo;
    default:
      return InstallMonthCategory.older;
  }
}

/// Model data titik pelanggan terpasang untuk layer Peta Coverage.
class CustomerMapPoint {
  final String customerId;
  final double latitude;
  final double longitude;
  final DateTime? installDate;
  final String address;
  final String packageName;
  final String salesName;
  final String spvName;
  final String tscName;
  final String syncedAt;

  const CustomerMapPoint({
    required this.customerId,
    required this.latitude,
    required this.longitude,
    this.installDate,
    this.address = '',
    this.packageName = '',
    this.salesName = '',
    this.spvName = '',
    this.tscName = '',
    required this.syncedAt,
  });

  LatLng get location => LatLng(latitude, longitude);

  String? get installDateString {
    final dt = installDate;
    if (dt == null) return null;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  InstallMonthCategory getMonthCategory([DateTime? now]) {
    return installMonthBucket(installDate, now ?? DateTime.now());
  }

  static DateTime? _parseDateOnly(dynamic raw) {
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

  static double _parseDouble(dynamic raw, [double fallback = 0.0]) {
    if (raw == null) return fallback;
    if (raw is num) return raw.toDouble();
    final parsed = double.tryParse(raw.toString().trim());
    return parsed ?? fallback;
  }

  factory CustomerMapPoint.fromSupabaseJson(
    Map<String, dynamic> json, {
    String? syncedAt,
  }) {
    return CustomerMapPoint(
      customerId: (json['customer_id'] as String? ?? '').trim(),
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      installDate: _parseDateOnly(json['install_date']),
      address: (json['address'] as String? ?? '').trim(),
      packageName: (json['package_name'] as String? ?? '').trim(),
      salesName: (json['sales_name'] as String? ?? '').trim().toUpperCase(),
      spvName: (json['spv_name'] as String? ?? '').trim().toUpperCase(),
      tscName: (json['tsc_name'] as String? ?? '').trim().toUpperCase(),
      syncedAt: syncedAt ?? DateTime.now().toUtc().toIso8601String(),
    );
  }

  factory CustomerMapPoint.fromMap(Map<String, dynamic> map) {
    return CustomerMapPoint(
      customerId: (map['customer_id'] as String? ?? '').trim(),
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      installDate: _parseDateOnly(map['install_date']),
      address: (map['address'] as String? ?? '').trim(),
      packageName: (map['package_name'] as String? ?? '').trim(),
      salesName: (map['sales_name'] as String? ?? '').trim().toUpperCase(),
      spvName: (map['spv_name'] as String? ?? '').trim().toUpperCase(),
      tscName: (map['tsc_name'] as String? ?? '').trim().toUpperCase(),
      syncedAt: (map['synced_at'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customer_id': customerId,
      'latitude': latitude,
      'longitude': longitude,
      'install_date': installDateString,
      'address': address,
      'package_name': packageName,
      'sales_name': salesName,
      'spv_name': spvName,
      'tsc_name': tscName,
      'synced_at': syncedAt,
    };
  }
}
