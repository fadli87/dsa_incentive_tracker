import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import '../models/cluster_map_models.dart';

/// Exception ramah pengguna untuk kegagalan membaca file KMZ/KML
class ClusterMapParseException implements Exception {
  final String message;
  const ClusterMapParseException(this.message);

  @override
  String toString() => message;
}

/// Service untuk parsing file KMZ (Keyhole Markup Zip) dan KML
class KmzParserService {
  const KmzParserService();

  /// Parse bytes file KMZ atau KML di latar belakang (isolate)
  static Future<ClusterMapData> parseKmzInIsolate(Uint8List bytes) {
    return compute(_parseKmzIsolateEntry, bytes);
  }

  /// Entrypoint murni untuk compute isolate
  static ClusterMapData _parseKmzIsolateEntry(Uint8List bytes) {
    final service = KmzParserService();
    return service.parseKmzBytes(bytes);
  }

  /// Parse bytes file KMZ atau KML secara sinkron
  ClusterMapData parseKmzBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const ClusterMapParseException('File peta cluster kosong atau tidak dapat dibaca.');
    }

    final kmlString = extractKmlStringFromKmz(bytes);
    return parseKmlString(kmlString);
  }

  /// Ekstrak teks KML dari file KMZ (ZIP) atau string KML mentah
  String extractKmlStringFromKmz(Uint8List bytes) {
    // Periksa magic header ZIP ('PK' -> 0x50, 0x4B)
    final bool isZip = bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

    if (isZip) {
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes, verify: false);
      } catch (_) {
        throw const ClusterMapParseException('File KMZ rusak atau bukan arsip ZIP yang valid.');
      }

      ArchiveFile? kmlFile;
      // 1. Utamakan doc.kml
      for (final file in archive.files) {
        if (!file.isFile) continue;
        if (file.name.toLowerCase().endsWith('doc.kml')) {
          kmlFile = file;
          break;
        }
      }

      // 2. Fallback ke file .kml pertama
      if (kmlFile == null) {
        for (final file in archive.files) {
          if (!file.isFile) continue;
          if (file.name.toLowerCase().endsWith('.kml')) {
            kmlFile = file;
            break;
          }
        }
      }

      if (kmlFile == null) {
        throw const ClusterMapParseException('File KMZ tidak berisi dokumen KML (.kml).');
      }

      try {
        final content = kmlFile.content;
        return utf8.decode(content, allowMalformed: true);
      } catch (_) {
        throw const ClusterMapParseException('Gagal membaca isi dokumen KML dari KMZ.');
      }
    }

    // Bila bukan ZIP, coba decode langsung sebagai teks KML
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      throw const ClusterMapParseException('Format file tidak dikenal sebagai KMZ maupun KML.');
    }
  }

  /// Parse dokumen KML string menjadi struktur ClusterMapData
  ClusterMapData parseKmlString(String kmlString) {
    XmlDocument document;
    try {
      document = XmlDocument.parse(kmlString);
    } catch (e) {
      throw ClusterMapParseException('Dokumen KML tidak valid: $e');
    }

    // 1. Ekstrak Styles dan StyleMaps
    final styleMapLookup = <String, String>{}; // styleMapId -> styleId
    final styles = <String, _KmlStyle>{}; // styleId -> style data

    for (final styleMapEl in document.findAllElements('StyleMap')) {
      final id = styleMapEl.getAttribute('id');
      if (id == null) continue;
      for (final pair in styleMapEl.findElements('Pair')) {
        final key = pair.findElements('key').firstOrNull?.innerText.trim();
        final url = pair.findElements('styleUrl').firstOrNull?.innerText.trim();
        if (key == 'normal' && url != null) {
          final cleanId = url.replaceFirst('#', '');
          styleMapLookup[id] = cleanId;
        }
      }
    }

    for (final styleEl in document.findAllElements('Style')) {
      final id = styleEl.getAttribute('id');
      if (id == null) continue;

      Color? lineColor;
      double? lineWidth;
      Color? polyColor;
      Color? iconColor;

      // LineStyle
      final lineStyle = styleEl.findElements('LineStyle').firstOrNull;
      if (lineStyle != null) {
        final colStr = lineStyle.findElements('color').firstOrNull?.innerText.trim();
        lineColor = parseKmlColor(colStr);
        final wStr = lineStyle.findElements('width').firstOrNull?.innerText.trim();
        if (wStr != null) lineWidth = double.tryParse(wStr);
      }

      // PolyStyle
      final polyStyle = styleEl.findElements('PolyStyle').firstOrNull;
      if (polyStyle != null) {
        final colStr = polyStyle.findElements('color').firstOrNull?.innerText.trim();
        polyColor = parseKmlColor(colStr);
      }

      // IconStyle
      final iconStyle = styleEl.findElements('IconStyle').firstOrNull;
      if (iconStyle != null) {
        final colStr = iconStyle.findElements('color').firstOrNull?.innerText.trim();
        iconColor = parseKmlColor(colStr);
      }

      styles[id] = _KmlStyle(
        lineColor: lineColor,
        lineWidth: lineWidth,
        polyColor: polyColor,
        iconColor: iconColor,
      );
    }

    _KmlStyle? resolveStyle(String? styleUrl) {
      if (styleUrl == null || styleUrl.isEmpty) return null;
      var cleanId = styleUrl.replaceFirst('#', '');
      if (styleMapLookup.containsKey(cleanId)) {
        cleanId = styleMapLookup[cleanId]!;
      }
      return styles[cleanId];
    }

    // 2. Ekstrak Folder sebagai Layer
    final List<ClusterMapLayer> layers = [];
    final allPoints = <LatLng>[];

    final folderElements = document.findAllElements('Folder');

    if (folderElements.isNotEmpty) {
      for (final folderEl in folderElements) {
        final folderName = folderEl.findElements('name').firstOrNull?.innerText.trim() ?? 'Layer';
        final placemarks = folderEl.findElements('Placemark');
        final features = <ClusterMapFeature>[];

        for (final p in placemarks) {
          final feat = _parsePlacemark(p, resolveStyle);
          if (feat != null) {
            features.add(feat);
            allPoints.addAll(feat.geometry.allPoints);
          }
        }

        if (features.isNotEmpty) {
          layers.add(ClusterMapLayer(
            name: folderName,
            features: features,
          ));
        }
      }
    }

    // 3. Tangani Placemark yang berada di luar Folder (misal langsung di bawah Document)
    final rootPlacemarks = document.findAllElements('Placemark').where((p) {
      return p.parentElement?.name.local.toLowerCase() != 'folder';
    });

    if (rootPlacemarks.isNotEmpty) {
      final features = <ClusterMapFeature>[];
      for (final p in rootPlacemarks) {
        final feat = _parsePlacemark(p, resolveStyle);
        if (feat != null) {
          features.add(feat);
          allPoints.addAll(feat.geometry.allPoints);
        }
      }
      if (features.isNotEmpty) {
        layers.insert(0, ClusterMapLayer(
          name: 'Umum',
          features: features,
        ));
      }
    }

    if (allPoints.isEmpty) {
      throw const ClusterMapParseException('Dokumen KMZ/KML tidak memiliki fitur koordinat yang valid.');
    }

    // 4. Hitung Bounding Box (Bounds)
    final bounds = LatLngBounds.fromPoints(allPoints);

    return ClusterMapData(
      layers: layers,
      bounds: bounds,
    );
  }

  /// Parse Placemark XML element
  ClusterMapFeature? _parsePlacemark(XmlElement el, _KmlStyle? Function(String?) styleResolver) {
    final name = el.findElements('name').firstOrNull?.innerText.trim() ?? 'Fitur';
    final descRaw = el.findElements('description').firstOrNull?.innerText.trim();
    final description = descRaw != null ? cleanKmlDescription(descRaw) : null;
    final styleUrl = el.findElements('styleUrl').firstOrNull?.innerText.trim();
    final style = styleResolver(styleUrl);

    // 1. Cek Polygon
    final polyEl = el.findElements('Polygon').firstOrNull ??
        el.findAllElements('Polygon').firstOrNull;
    if (polyEl != null) {
      final outerCoordsEl = polyEl.findAllElements('coordinates').firstOrNull;
      if (outerCoordsEl != null) {
        final pts = parseCoordinateList(outerCoordsEl.innerText);
        if (pts.length >= 3) {
          final strokeColor = style?.lineColor ?? style?.polyColor ?? const Color(0xFF1E88E5);
          final fillColor = style?.polyColor ?? strokeColor.withValues(alpha: 0.25);
          return ClusterMapFeature(
            name: name,
            description: description,
            geometry: ClusterGeometry.polygon(pts),
            color: strokeColor,
            fillColor: fillColor,
            strokeWidth: style?.lineWidth ?? 2.5,
          );
        }
      }
    }

    // 2. Cek LineString
    final lineEl = el.findElements('LineString').firstOrNull ??
        el.findAllElements('LineString').firstOrNull;
    if (lineEl != null) {
      final coordsEl = lineEl.findAllElements('coordinates').firstOrNull;
      if (coordsEl != null) {
        final pts = parseCoordinateList(coordsEl.innerText);
        if (pts.length >= 2) {
          final col = style?.lineColor ?? const Color(0xFFD32F2F);
          return ClusterMapFeature(
            name: name,
            description: description,
            geometry: ClusterGeometry.lineString(pts),
            color: col,
            strokeWidth: style?.lineWidth ?? 3.0,
          );
        }
      }
    }

    // 3. Cek Point
    final pointEl = el.findElements('Point').firstOrNull ??
        el.findAllElements('Point').firstOrNull;
    if (pointEl != null) {
      final coordsEl = pointEl.findAllElements('coordinates').firstOrNull;
      if (coordsEl != null) {
        final pts = parseCoordinateList(coordsEl.innerText);
        if (pts.isNotEmpty) {
          final col = style?.iconColor ?? style?.lineColor ?? const Color(0xFF002B66);
          return ClusterMapFeature(
            name: name,
            description: description,
            geometry: ClusterGeometry.point(pts.first),
            color: col,
          );
        }
      }
    }

    return null;
  }

  /// Parse daftar koordinat dari string KML format `lon,lat[,alt] lon,lat[,alt] ...`
  /// dan dibalik menjadi LatLng(lat, lon)
  static List<LatLng> parseCoordinateList(String raw) {
    final list = <LatLng>[];
    if (raw.trim().isEmpty) return list;

    // Pisahkan berdasarkan spasi, tab, atau baris baru
    final tokens = raw.trim().split(RegExp(r'\s+'));
    for (final token in tokens) {
      final parts = token.split(',');
      if (parts.length >= 2) {
        final lon = double.tryParse(parts[0].trim());
        final lat = double.tryParse(parts[1].trim());
        if (lat != null && lon != null) {
          if (lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0) {
            if (lat != 0.0 || lon != 0.0) {
              list.add(LatLng(lat, lon));
            }
          }
        }
      }
    }
    return list;
  }

  /// Konversi warna KML format `aabbggrr` (Alpha, Blue, Green, Red) ke Flutter Color
  static Color? parseKmlColor(String? hexString, {Color? defaultColor}) {
    if (hexString == null || hexString.trim().isEmpty) return defaultColor;
    final cleaned = hexString.trim().replaceAll('#', '');

    if (cleaned.length == 8) {
      try {
        final a = int.parse(cleaned.substring(0, 2), radix: 16);
        final b = int.parse(cleaned.substring(2, 4), radix: 16);
        final g = int.parse(cleaned.substring(4, 6), radix: 16);
        final r = int.parse(cleaned.substring(6, 8), radix: 16);
        return Color.fromARGB(a, r, g, b);
      } catch (_) {
        return defaultColor;
      }
    } else if (cleaned.length == 6) {
      // Kadang KML memakai format RRGGBB
      try {
        final r = int.parse(cleaned.substring(0, 2), radix: 16);
        final g = int.parse(cleaned.substring(2, 4), radix: 16);
        final b = int.parse(cleaned.substring(4, 6), radix: 16);
        return Color.fromARGB(255, r, g, b);
      } catch (_) {
        return defaultColor;
      }
    }

    return defaultColor;
  }

  /// Bersihkan tag HTML dari description KML dan konversi entitas HTML ke teks polos
  static String cleanKmlDescription(String html) {
    if (html.isEmpty) return '';

    var text = html;

    // Ganti baris tabel atau tag <br> menjadi baris baru
    text = text.replaceAll(RegExp(r'</?(tr|p|div|br)[^>]*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</td>\s*<td[^>]*>', caseSensitive: false), ': ');

    // Buang semua tag HTML lainnya
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Unescape HTML entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");

    // Rapikan spasi dan baris kosong berlebih
    final lines = text
        .split('\n')
        .map((l) => l.trim().replaceAll(RegExp(r'[ \t]+'), ' '))
        .where((l) => l.isNotEmpty);

    return lines.join('\n');
  }
}

class _KmlStyle {
  final Color? lineColor;
  final double? lineWidth;
  final Color? polyColor;
  final Color? iconColor;

  const _KmlStyle({
    this.lineColor,
    this.lineWidth,
    this.polyColor,
    this.iconColor,
  });
}
