import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';

class GeoJsonService {
  GeoJsonService._();
  static final GeoJsonService instance = GeoJsonService._();

  List<DistrictInfo>? _cachedDistricts;
  List<BtsTower>? _cachedTowers;
  final Map<String, List<CoveragePolygonData>> _cachedCoverages = {};
  final Map<String, List<HomepassPoint>> _cachedHomepass = {};

  static const Map<String, LatLng> _districtCoordinates = {
    'ADIPALA': LatLng(-7.6625, 109.1558),
    'BANTARSARI': LatLng(-7.5412, 108.8812),
    'BINANGUN': LatLng(-7.6890, 109.2815),
    'CILACAP_SELATAN': LatLng(-7.7412, 109.0098),
    'CILACAP_TENGAH': LatLng(-7.7188, 109.0156),
    'CILACAP_UTARA': LatLng(-7.6895, 109.0345),
    'CIMANGGU': LatLng(-7.3512, 108.8415),
    'CIPARI': LatLng(-7.4312, 108.7655),
    'DAYEUHLUHUR': LatLng(-7.2412, 108.6012),
    'GANDRUNGMANGU': LatLng(-7.5255, 108.8415),
    'JERUKLEGI': LatLng(-7.5955, 108.9890),
    'KAMPUNG_LAUT': LatLng(-7.6812, 108.8612),
    'KARANGPUCUNG': LatLng(-7.4085, 108.8912),
    'KAWUNGANTEN': LatLng(-7.5890, 108.9185),
    'KEDUNGREJA': LatLng(-7.5312, 108.7612),
    'KESUGIHAN': LatLng(-7.6185, 109.0832),
    'KROYA': LatLng(-7.6315, 109.2485),
    'MAJENANG': LatLng(-7.2985, 108.7612),
    'MAOS': LatLng(-7.6190, 109.1412),
    'NUSAWUNGU': LatLng(-7.7015, 109.3512),
    'PATIMUAN': LatLng(-7.6015, 108.7412),
    'SAMPANG': LatLng(-7.5855, 109.1985),
    'SIDAREJA': LatLng(-7.4812, 108.7985),
    'WANAREJA': LatLng(-7.3285, 108.6812),
  };

  /// Memuat daftar 24 kecamatan di Cilacap
  Future<List<DistrictInfo>> loadDistricts() async {
    if (_cachedDistricts != null) return _cachedDistricts!;
    try {
      final str = await rootBundle.loadString('assets/map_data/districts.json');
      final dynamic decoded = jsonDecode(str);

      final List<DistrictInfo> list = [];

      if (decoded is Map<String, dynamic>) {
        decoded.forEach((key, val) {
          final cleanId = key.trim().replaceAll(' ', '_').toUpperCase();
          final coords = _districtCoordinates[cleanId] ?? const LatLng(-7.70, 109.02);
          final name = key.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '').join(' ');
          
          final coverageCount = val is Map<String, dynamic> ? (val['coverage'] as num?)?.toInt() ?? 0 : 0;

          list.add(DistrictInfo(
            id: cleanId,
            name: name,
            lat: coords.latitude,
            lng: coords.longitude,
            count: coverageCount,
          ));
        });
      } else if (decoded is List<dynamic>) {
        for (final item in decoded) {
          list.add(DistrictInfo.fromJson(item as Map<String, dynamic>));
        }
      }

      list.sort((a, b) => a.name.compareTo(b.name));
      _cachedDistricts = list;
      return _cachedDistricts!;
    } catch (_) {
      // Fallback built-in list of all 24 districts in Cilacap
      final fallback = _districtCoordinates.entries.map((e) {
        final name = e.key.split('_').map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}').join(' ');
        return DistrictInfo(
          id: e.key,
          name: name,
          lat: e.value.latitude,
          lng: e.value.longitude,
        );
      }).toList()..sort((a, b) => a.name.compareTo(b.name));

      _cachedDistricts = fallback;
      return _cachedDistricts!;
    }
  }

  /// Memuat 380 titik Tower BTS XL Cilacap secara async
  Future<List<BtsTower>> loadTowers() async {
    if (_cachedTowers != null) return _cachedTowers!;
    try {
      final str = await rootBundle.loadString('assets/map_data/tower.geojson');
      final result = await compute(_parseTowersJson, str);
      _cachedTowers = result;
      return _cachedTowers!;
    } catch (_) {
      return [];
    }
  }

  /// Memuat poligon coverage on-demand per kecamatan di background isolate
  Future<List<CoveragePolygonData>> loadDistrictCoverage(String districtId) async {
    final cleanId = districtId.trim().toUpperCase();
    if (_cachedCoverages.containsKey(cleanId)) {
      return _cachedCoverages[cleanId]!;
    }

    try {
      final path = 'assets/map_data/coverage/$cleanId.geojson';
      final str = await rootBundle.loadString(path);
      final result = await compute(_parseCoverageJson, {
        'districtId': cleanId,
        'jsonString': str,
      });

      _cachedCoverages[cleanId] = result;
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Memuat titik target Homepass / Building on-demand per kecamatan di background isolate
  Future<List<HomepassPoint>> loadDistrictHomepass(String districtId) async {
    final cleanId = districtId.trim().toUpperCase();
    if (_cachedHomepass.containsKey(cleanId)) {
      return _cachedHomepass[cleanId]!;
    }

    try {
      final path = 'assets/map_data/buildings/$cleanId.geojson';
      final str = await rootBundle.loadString(path);
      final result = await compute(_parseHomepassJson, str);

      _cachedHomepass[cleanId] = result;
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Menghitung jarak BTS terdekat dalam meter
  double calculateDistanceMeters(LatLng p1, LatLng p2) {
    const double r = 6371000; // Radius Bumi dalam meter
    final dLat = _degToRad(p2.latitude - p1.latitude);
    final dLon = _degToRad(p2.longitude - p1.longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(p1.latitude)) *
            math.cos(_degToRad(p2.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Mencari tower terdekat dari lokasi sales
  BtsTower? findNearestTower(LatLng salesLocation, List<BtsTower> towers) {
    if (towers.isEmpty) return null;
    BtsTower? nearest;
    double minDistance = double.infinity;

    for (final tower in towers) {
      final d = calculateDistanceMeters(salesLocation, tower.location);
      if (d < minDistance) {
        minDistance = d;
        nearest = tower;
      }
    }
    return nearest;
  }
}

// Background Isolate Parsers for Maximum 60FPS Map Performance

List<BtsTower> _parseTowersJson(String jsonString) {
  try {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final features = (data['features'] as List<dynamic>?) ?? [];
    return features
        .map((f) => BtsTower.fromGeoJsonFeature(f as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

List<CoveragePolygonData> _parseCoverageJson(Map<String, dynamic> params) {
  try {
    final cleanId = params['districtId'] as String;
    final jsonString = params['jsonString'] as String;
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final features = (data['features'] as List<dynamic>?) ?? [];

    final List<CoveragePolygonData> result = [];

    for (final f in features) {
      final feat = f as Map<String, dynamic>;
      final props = feat['properties'] as Map<String, dynamic>? ?? {};
      final geom = feat['geometry'] as Map<String, dynamic>? ?? {};
      final geomType = geom['type'] as String? ?? '';
      final net = props['net']?.toString().toUpperCase() ?? 'FWA';

      final Color fillColor = net.contains('FTTH') || net.contains('FIBER')
          ? const Color(0xFF6366F1).withValues(alpha: 0.25)
          : const Color(0xFF00B0FF).withValues(alpha: 0.22);

      final Color borderColor = net.contains('FTTH') || net.contains('FIBER')
          ? const Color(0xFF4F46E5).withValues(alpha: 0.8)
          : const Color(0xFF0091EA).withValues(alpha: 0.7);

      if (geomType == 'Polygon') {
        final coords = geom['coordinates'] as List<dynamic>? ?? [];
        final List<List<LatLng>> rings = [];
        for (final ring in coords) {
          final List<LatLng> latLngList = [];
          for (final pt in ring) {
            final double lng = (pt[0] as num).toDouble();
            final double lat = (pt[1] as num).toDouble();
            latLngList.add(LatLng(lat, lng));
          }
          if (latLngList.isNotEmpty) rings.add(latLngList);
        }
        if (rings.isNotEmpty) {
          result.add(CoveragePolygonData(
            district: cleanId,
            netType: net,
            rings: rings,
            fillColor: fillColor,
            borderColor: borderColor,
          ));
        }
      } else if (geomType == 'MultiPolygon') {
        final multiCoords = geom['coordinates'] as List<dynamic>? ?? [];
        for (final polyCoords in multiCoords) {
          final List<List<LatLng>> rings = [];
          for (final ring in polyCoords) {
            final List<LatLng> latLngList = [];
            for (final pt in ring) {
              final double lng = (pt[0] as num).toDouble();
              final double lat = (pt[1] as num).toDouble();
              latLngList.add(LatLng(lat, lng));
            }
            if (latLngList.isNotEmpty) rings.add(latLngList);
          }
          if (rings.isNotEmpty) {
            result.add(CoveragePolygonData(
              district: cleanId,
              netType: net,
              rings: rings,
              fillColor: fillColor,
              borderColor: borderColor,
            ));
          }
        }
      }
    }
    return result;
  } catch (_) {
    return [];
  }
}

List<HomepassPoint> _parseHomepassJson(String jsonString) {
  try {
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final features = (data['features'] as List<dynamic>?) ?? [];
    return features
        .map((f) => HomepassPoint.fromGeoJsonFeature(f as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}
