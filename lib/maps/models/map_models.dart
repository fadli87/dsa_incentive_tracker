import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Model untuk Tower BTS XL di Kabupaten Cilacap (380 Titik).
/// Warna marker mengikuti nilai hex asli dari file KMZ/GeoJSON.
/// SPV Area tidak ditampilkan sesuai instruksi pengguna.
class BtsTower {
  final String siteName;
  final String towerId;
  final String enodebId;
  final String antennaHeight;
  final double latitude;
  final double longitude;
  final String? colorHex;
  final String? ranType;
  final String? city5g;
  final String? payload;

  const BtsTower({
    required this.siteName,
    required this.towerId,
    required this.enodebId,
    required this.antennaHeight,
    required this.latitude,
    required this.longitude,
    this.colorHex,
    this.ranType,
    this.city5g,
    this.payload,
  });

  LatLng get location => LatLng(latitude, longitude);

  Color get markerColor {
    if (colorHex != null && colorHex!.isNotEmpty) {
      try {
        final clean = colorHex!.replaceAll('#', '').trim();
        if (clean.length == 6) {
          return Color(int.parse('0xFF$clean'));
        }
      } catch (_) {}
    }
    return const Color(0xFF0F9D58); // Default Hijau XL KMZ
  }

  factory BtsTower.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coords = (geometry['coordinates'] as List<dynamic>?) ?? [0.0, 0.0];

    final double lng = (coords[0] as num).toDouble();
    final double lat = (coords[1] as num).toDouble();

    return BtsTower(
      siteName: props['name']?.toString() ?? props['SITE_NAME']?.toString() ?? 'Tower XL',
      towerId: props['tower_id']?.toString() ?? props['TOWER_ID']?.toString() ?? '-',
      enodebId: props['enbid']?.toString() ?? props['ENODEB_ID']?.toString() ?? props['enodeb_id']?.toString() ?? '-',
      antennaHeight: props['antenna_height']?.toString() ?? props['ANTENNA_HEIGHT']?.toString() ?? props['height']?.toString() ?? '-',
      latitude: lat,
      longitude: lng,
      colorHex: props['color']?.toString(),
      ranType: props['ran_type']?.toString(),
      city5g: props['city_5g']?.toString(),
      payload: props['payload']?.toString(),
    );
  }
}

/// Model untuk Titik Target Bangunan / Homepass Prospek XL Satu.
class HomepassPoint {
  final String id;
  final String cluster;
  final String district;
  final String village;
  final String netType;
  final String priority;
  final String category;
  final double latitude;
  final double longitude;

  const HomepassPoint({
    required this.id,
    required this.cluster,
    required this.district,
    required this.village,
    required this.netType,
    required this.priority,
    required this.category,
    required this.latitude,
    required this.longitude,
  });

  LatLng get location => LatLng(latitude, longitude);

  /// Pewarnaan asli Homepass XL Satu:
  /// 1. Ungu (#9C27B0)  : Existing Homeconnect (Pelanggan aktif terpasang)
  /// 2. Orange (#FB8C00): Prospek Prioritas / P3 Not Visited (Target utama sales)
  /// 3. Hijau (#43A047) : Prospek Reguler / P4 Visited / C / D (Target reguler)
  Color get categoryColor {
    final pLower = priority.toLowerCase().trim();
    final pTrim = priority.trim();

    // 1. Ungu: Existing Homeconnect
    if (pTrim.startsWith('9') || pLower.contains('existing') || pLower.contains('homeconnect')) {
      return const Color(0xFF9C27B0); // Ungu
    }

    // 2. Orange: Priority A / B / P1 / P2 / P3 / Not Visited
    final catUpper = category.toUpperCase().trim();
    if (catUpper == 'A' ||
        catUpper == 'B' ||
        pTrim.startsWith('1') ||
        pTrim.startsWith('2') ||
        pTrim.startsWith('3') ||
        pLower.contains('not visited') ||
        pLower.contains('p3')) {
      return const Color(0xFFFB8C00); // Orange
    }

    // 3. Hijau: Prospek Reguler (P4 / C1 / C2 / D / Lainnya)
    return const Color(0xFF43A047); // Hijau
  }

  bool get isExistingCustomer {
    final pLower = priority.toLowerCase().trim();
    return priority.trim().startsWith('9') || pLower.contains('existing') || pLower.contains('homeconnect');
  }

  bool get isNonPriority {
    final pLower = priority.toLowerCase().trim();
    return priority.trim().startsWith('8') || priority.trim().startsWith('100') || pLower.contains('non priority') || pLower.contains('null');
  }

  String get displayPriorityLabel {
    if (isExistingCustomer) return 'Existing Homeconnect';
    if (isNonPriority) return 'Non-Priority / Null';
    if (priority.isNotEmpty) return priority;
    if (category.isNotEmpty) return 'Kategori $category';
    return 'Homepass Prospek';
  }

  factory HomepassPoint.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
    final coords = (geometry['coordinates'] as List<dynamic>?) ?? [0.0, 0.0];

    return HomepassPoint(
      id: props['id']?.toString() ?? '',
      cluster: props['c']?.toString() ?? '',
      district: props['d']?.toString() ?? '',
      village: props['v']?.toString() ?? '',
      netType: props['net']?.toString() ?? 'FWA',
      priority: props['prio']?.toString() ?? '',
      category: props['cat']?.toString() ?? '',
      longitude: (coords[0] as num).toDouble(),
      latitude: (coords[1] as num).toDouble(),
    );
  }
}

/// Model untuk Kecamatan di Kabupaten Cilacap (24 Kecamatan).
class DistrictInfo {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final int count;

  const DistrictInfo({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.count = 0,
  });

  LatLng get center => LatLng(lat, lng);

  factory DistrictInfo.fromJson(Map<String, dynamic> json) {
    return DistrictInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? -7.70,
      lng: (json['lng'] as num?)?.toDouble() ?? 109.02,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Model Poligon Area Coverage (Dissolved / Smooth Area).
class CoveragePolygonData {
  final String district;
  final String netType;
  final List<List<LatLng>> rings; // Outer ring & inner holes
  final Color fillColor;
  final Color borderColor;

  const CoveragePolygonData({
    required this.district,
    required this.netType,
    required this.rings,
    required this.fillColor,
    required this.borderColor,
  });
}
