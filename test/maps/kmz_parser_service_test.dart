import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/maps/models/cluster_map_models.dart';
import 'package:dsa_incentive_tracker/maps/services/kmz_parser_service.dart';

Uint8List _createKmzArchive(String kmlContent, {String fileName = 'doc.kml'}) {
  final archive = Archive();
  final kmlBytes = utf8.encode(kmlContent);
  archive.addFile(ArchiveFile(fileName, kmlBytes.length, kmlBytes));
  final zipBytes = ZipEncoder().encode(archive);
  return Uint8List.fromList(zipBytes);
}

void main() {
  group('KmzParserService Tests — KML & KMZ Parsing', () {
    const parser = KmzParserService();

    test('Konversi warna KML aabbggrr ke Flutter Color ARGB', () {
      // ff0000ff: a=ff (255), b=00, g=00, r=ff (255) -> Merah pekat
      final colRed = KmzParserService.parseKmlColor('ff0000ff');
      expect(colRed, const Color(0xFFFF0000));

      // 7f00ff00: a=7f (127), b=00, g=ff (255), r=00 -> Hijau 50% transparan
      final colGreen = KmzParserService.parseKmlColor('7f00ff00');
      expect(colGreen, const Color(0x7F00FF00));

      // ffff0000: a=ff (255), b=ff (255), g=00, r=00 -> Biru pekat
      final colBlue = KmzParserService.parseKmlColor('ffff0000');
      expect(colBlue, const Color(0xFF0000FF));

      // 6 digit RRGGBB fallback
      final colHex6 = KmzParserService.parseKmlColor('002b66');
      expect(colHex6, const Color(0xFF002B66));

      // Null / invalid fallback ke default
      expect(KmzParserService.parseKmlColor(null, defaultColor: Colors.black), Colors.black);
      expect(KmzParserService.parseKmlColor('invalid', defaultColor: Colors.black), Colors.black);
    });

    test('Pembalikan urutan lon,lat KML menjadi LatLng(lat, lon)', () {
      const raw = '109.012345,-7.654321,0 109.020000,-7.660000,15';
      final pts = KmzParserService.parseCoordinateList(raw);

      expect(pts.length, 2);
      expect(pts[0].latitude, -7.654321);
      expect(pts[0].longitude, 109.012345);
      expect(pts[1].latitude, -7.660000);
      expect(pts[1].longitude, 109.020000);
    });

    test('Pembersihan HTML description dan decode entitas', () {
      const html = '''
        <table>
          <tr><td>Nama ODP</td><td>ODP-CLP-01/04</td></tr>
          <tr><td>Kapasitas</td><td>8 &amp; 16 Port</td></tr>
        </table>
        <br>
        <i>Status: &quot;Ready for Sale&quot;</i>
      ''';
      final cleaned = KmzParserService.cleanKmlDescription(html);
      expect(cleaned.contains('Nama ODP: ODP-CLP-01/04'), isTrue);
      expect(cleaned.contains('Kapasitas: 8 & 16 Port'), isTrue);
      expect(cleaned.contains('Status: "Ready for Sale"'), isTrue);
      expect(cleaned.contains('<table>'), isFalse);
    });

    test('Parse lengkap dokumen KML dengan Point, LineString, Polygon, Folder, dan Style', () {
      const kmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Style id="odpStyle">
      <IconStyle>
        <color>ff0000ff</color>
      </IconStyle>
    </Style>
    <Style id="cableStyle">
      <LineStyle>
        <color>ffff0000</color>
        <width>4</width>
      </LineStyle>
    </Style>
    <Style id="boundaryStyle">
      <LineStyle>
        <color>ff00ff00</color>
        <width>2</width>
      </LineStyle>
      <PolyStyle>
        <color>7f00ff00</color>
      </PolyStyle>
    </Style>

    <Placemark>
      <name>Root Marker</name>
      <Point>
        <coordinates>109.001,-7.651,0</coordinates>
      </Point>
    </Placemark>

    <Folder>
      <name>ODP Cluster</name>
      <Placemark>
        <name>ODP-01</name>
        <description><![CDATA[<b>Kapasitas:</b> 8 Port]]></description>
        <styleUrl>#odpStyle</styleUrl>
        <Point>
          <coordinates>109.010,-7.650,0</coordinates>
        </Point>
      </Placemark>
    </Folder>

    <Folder>
      <name>Distribusi Kabel</name>
      <Placemark>
        <name>Kabel Feeder 24C</name>
        <styleUrl>#cableStyle</styleUrl>
        <LineString>
          <coordinates>
            109.010,-7.650,0
            109.015,-7.655,0
          </coordinates>
        </LineString>
      </Placemark>
    </Folder>

    <Folder>
      <name>Boundary Area</name>
      <Placemark>
        <name>Area Cluster 1947</name>
        <styleUrl>#boundaryStyle</styleUrl>
        <Polygon>
          <outerBoundaryIs>
            <LinearRing>
              <coordinates>
                109.005,-7.645,0
                109.020,-7.645,0
                109.020,-7.660,0
                109.005,-7.660,0
                109.005,-7.645,0
              </coordinates>
            </LinearRing>
          </outerBoundaryIs>
        </Polygon>
      </Placemark>
    </Folder>
  </Document>
</kml>''';

      final data = parser.parseKmlString(kmlContent);

      expect(data.isEmpty, isFalse);
      expect(data.layers.length, 4); // 'Umum', 'ODP Cluster', 'Distribusi Kabel', 'Boundary Area'

      // Layer Umum
      final generalLayer = data.layers.firstWhere((l) => l.name == 'Umum');
      expect(generalLayer.features.length, 1);
      expect(generalLayer.features.first.name, 'Root Marker');

      // Layer ODP Cluster (Point)
      final odpLayer = data.layers.firstWhere((l) => l.name == 'ODP Cluster');
      expect(odpLayer.features.length, 1);
      final odpFeat = odpLayer.features.first;
      expect(odpFeat.name, 'ODP-01');
      expect(odpFeat.geometryType, ClusterGeometryType.point);
      expect(odpFeat.geometry.point!.latitude, -7.650);
      expect(odpFeat.geometry.point!.longitude, 109.010);
      expect(odpFeat.color, const Color(0xFFFF0000)); // ff0000ff -> Red
      expect(odpFeat.description?.contains('Kapasitas: 8 Port'), isTrue);

      // Layer Distribusi Kabel (LineString)
      final cableLayer = data.layers.firstWhere((l) => l.name == 'Distribusi Kabel');
      expect(cableLayer.features.length, 1);
      final cableFeat = cableLayer.features.first;
      expect(cableFeat.name, 'Kabel Feeder 24C');
      expect(cableFeat.geometryType, ClusterGeometryType.lineString);
      expect(cableFeat.geometry.points.length, 2);
      expect(cableFeat.color, const Color(0xFF0000FF)); // ffff0000 -> Blue
      expect(cableFeat.strokeWidth, 4.0);

      // Layer Boundary Area (Polygon)
      final boundaryLayer = data.layers.firstWhere((l) => l.name == 'Boundary Area');
      expect(boundaryLayer.features.length, 1);
      final polyFeat = boundaryLayer.features.first;
      expect(polyFeat.name, 'Area Cluster 1947');
      expect(polyFeat.geometryType, ClusterGeometryType.polygon);
      expect(polyFeat.geometry.points.length, 5);
      expect(polyFeat.color, const Color(0xFF00FF00)); // Green

      // Bounds kalkulasi
      expect(data.bounds, isNotNull);
      expect(data.bounds!.south, closeTo(-7.660, 0.001));
      expect(data.bounds!.north, closeTo(-7.645, 0.001));
      expect(data.bounds!.west, closeTo(109.001, 0.001));
      expect(data.bounds!.east, closeTo(109.020, 0.001));
    });

    test('Parse file KMZ biner (ZIP terkompresi)', () {
      const kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Placemark>
    <name>Titik Zip</name>
    <Point><coordinates>109.05,-7.70,0</coordinates></Point>
  </Placemark>
</kml>''';
      final kmzBytes = _createKmzArchive(kml, fileName: 'doc.kml');
      final data = parser.parseKmzBytes(kmzBytes);

      expect(data.isEmpty, isFalse);
      expect(data.totalFeatures, 1);
      expect(data.layers.first.features.first.name, 'Titik Zip');
      expect(data.bounds!.center.latitude, closeTo(-7.70, 0.001));
      expect(data.bounds!.center.longitude, closeTo(109.05, 0.001));
    });

    test('Error handling ramah: KMZ kosong, rusak, atau tanpa koordinat', () {
      // 1. Kosong
      expect(
        () => parser.parseKmzBytes(Uint8List(0)),
        throwsA(isA<ClusterMapParseException>()),
      );

      // 2. Corrupted zip
      expect(
        () => parser.parseKmzBytes(Uint8List.fromList([0x50, 0x4B, 0x01, 0x02, 0x99])),
        throwsA(isA<ClusterMapParseException>()),
      );

      // 3. KML tanpa koordinat sama sekali
      const emptyKml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document><name>Hanya Judul</name></Document>
</kml>''';
      expect(
        () => parser.parseKmlString(emptyKml),
        throwsA(isA<ClusterMapParseException>()),
      );
    });
  });
}
