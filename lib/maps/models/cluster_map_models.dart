import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Jenis geometri fitur peta cluster
enum ClusterGeometryType {
  point,
  lineString,
  polygon,
}

/// Representasi geometri koordinat geografis
class ClusterGeometry {
  final ClusterGeometryType type;
  final LatLng? point;
  final List<LatLng> points;

  const ClusterGeometry.point(LatLng p)
      : type = ClusterGeometryType.point,
        point = p,
        points = const [];

  const ClusterGeometry.lineString(List<LatLng> pts)
      : type = ClusterGeometryType.lineString,
        point = null,
        points = pts;

  const ClusterGeometry.polygon(List<LatLng> outerRing)
      : type = ClusterGeometryType.polygon,
        point = null,
        points = outerRing;

  /// Semua koordinat untuk kalkulasi bounds
  Iterable<LatLng> get allPoints sync* {
    if (point != null) yield point!;
    for (final p in points) {
      yield p;
    }
  }
}

/// Fitur individual pada peta cluster (Placemark)
class ClusterMapFeature {
  final String name;
  final String? description;
  final ClusterGeometry geometry;
  final Color color;
  final Color? fillColor;
  final double strokeWidth;

  const ClusterMapFeature({
    required this.name,
    this.description,
    required this.geometry,
    this.color = const Color(0xFF002B66),
    this.fillColor,
    this.strokeWidth = 3.0,
  });

  ClusterGeometryType get geometryType => geometry.type;
}

/// Layer pengelompokan fitur peta (berasal dari `<Folder>` KML)
class ClusterMapLayer {
  final String name;
  final List<ClusterMapFeature> features;
  final bool isVisibleByDefault;

  const ClusterMapLayer({
    required this.name,
    required this.features,
    this.isVisibleByDefault = true,
  });

  bool get isEmpty => features.isEmpty;
  int get count => features.length;
}

/// Data lengkap peta cluster hasil parsing KMZ/KML
class ClusterMapData {
  final List<ClusterMapLayer> layers;
  final LatLngBounds? bounds;

  const ClusterMapData({
    required this.layers,
    this.bounds,
  });

  static const ClusterMapData empty = ClusterMapData(layers: [], bounds: null);

  bool get isEmpty => layers.isEmpty || totalFeatures == 0;
  bool get isNotEmpty => !isEmpty;

  int get totalFeatures =>
      layers.fold<int>(0, (sum, layer) => sum + layer.features.length);

  int get pointCount => layers.fold<int>(
        0,
        (sum, l) =>
            sum +
            l.features
                .where((f) => f.geometryType == ClusterGeometryType.point)
                .length,
      );

  int get lineCount => layers.fold<int>(
        0,
        (sum, l) =>
            sum +
            l.features
                .where((f) => f.geometryType == ClusterGeometryType.lineString)
                .length,
      );

  int get polygonCount => layers.fold<int>(
        0,
        (sum, l) =>
            sum +
            l.features
                .where((f) => f.geometryType == ClusterGeometryType.polygon)
                .length,
      );
}

/// Item ringkasan cluster dari tabel database cluster_maps
class ClusterMapItem {
  final String clusterCode;
  final String name;
  final String? kelurahan;
  final String? rw;
  final String kmzPath;
  final String? pdfPath;
  final int? kmzSize;
  final DateTime updatedAt;

  const ClusterMapItem({
    required this.clusterCode,
    required this.name,
    this.kelurahan,
    this.rw,
    required this.kmzPath,
    this.pdfPath,
    this.kmzSize,
    required this.updatedAt,
  });

  factory ClusterMapItem.fromJson(Map<String, dynamic> json) {
    return ClusterMapItem(
      clusterCode: (json['cluster_code'] ?? '').toString().trim().toUpperCase(),
      name: (json['name'] ?? '').toString().trim(),
      kelurahan: json['kelurahan']?.toString().trim(),
      rw: json['rw']?.toString().trim(),
      kmzPath: (json['kmz_path'] ?? '').toString().trim(),
      pdfPath: json['pdf_path']?.toString().trim(),
      kmzSize: json['kmz_size'] is int
          ? json['kmz_size'] as int
          : int.tryParse(json['kmz_size']?.toString() ?? ''),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cluster_code': clusterCode,
      'name': name,
      'kelurahan': kelurahan,
      'rw': rw,
      'kmz_path': kmzPath,
      'pdf_path': pdfPath,
      'kmz_size': kmzSize,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get displaySubtitle {
    final parts = <String>[];
    if (kelurahan != null && kelurahan!.isNotEmpty) {
      parts.add('Kel. $kelurahan');
    }
    if (rw != null && rw!.isNotEmpty) {
      parts.add('RW $rw');
    }
    if (parts.isEmpty) return clusterCode;
    return '${parts.join(', ')} • $clusterCode';
  }
}
