import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dsa_incentive_tracker/maps/models/map_models.dart';
import 'package:dsa_incentive_tracker/maps/services/geojson_service.dart';
import 'package:dsa_incentive_tracker/maps/utils/location_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Coverage Map & BTS Tower GIS Tests', () {
    test('BtsTower model parses geojson feature and retains original KMZ color', () {
      final feature = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [109.025, -7.712]
        },
        "properties": {
          "name": "CILACAP KOTA 01",
          "TOWER_ID": "TOW-CLP-001",
          "ENODEB_ID": "412589",
          "ANTENNA_HEIGHT": "42",
          "color": "#C2185B",
          "SPV": "SPV_JOHNDOE" // SPV is ignored in model
        }
      };

      final tower = BtsTower.fromGeoJsonFeature(feature);
      expect(tower.siteName, 'CILACAP KOTA 01');
      expect(tower.towerId, 'TOW-CLP-001');
      expect(tower.enodebId, '412589');
      expect(tower.antennaHeight, '42');
      expect(tower.colorHex, '#C2185B');
      expect(tower.markerColor, const Color(0xFFC2185B));
      expect(tower.latitude, -7.712);
      expect(tower.longitude, 109.025);
    });

    test('HomepassPoint parses categories and returns correct priority colors', () {
      final featExisting = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [109.01764, -7.735806]
        },
        "properties": {
          "id": "qqtebz8-233333",
          "c": "3301-42",
          "d": "CILACAP SELATAN",
          "v": "CILACAP",
          "net": "FTTH",
          "prio": "9. Existing Homeconnect",
          "cat": "C1"
        }
      };
      final hpExisting = HomepassPoint.fromGeoJsonFeature(featExisting);
      expect(hpExisting.isExistingCustomer, isTrue);
      expect(hpExisting.categoryColor, const Color(0xFF9C27B0)); // Ungu Pelanggan Aktif

      final featNonPrio = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [109.0177, -7.736023]
        },
        "properties": {
          "id": "qqtebz8-233310",
          "prio": "8. Non Priority",
          "cat": "B"
        }
      };
      final hpNonPrio = HomepassPoint.fromGeoJsonFeature(featNonPrio);
      expect(hpNonPrio.isNonPriority, isTrue);
      expect(hpNonPrio.categoryColor, const Color(0xFF78909C)); // Abu-abu Slate

      final featA = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [109.0073, -7.7045]
        },
        "properties": {
          "id": "qqts0t2-234080",
          "c": "3301-34",
          "d": "CILACAP TENGAH",
          "v": "LOMANIS",
          "net": "FTTH",
          "prio": "1. P1 Priority",
          "cat": "A"
        }
      };
      final hpA = HomepassPoint.fromGeoJsonFeature(featA);
      expect(hpA.id, 'qqts0t2-234080');
      expect(hpA.categoryColor, const Color(0xFFE53935)); // Merah

      final featB = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [109.0033, -7.7138]
        },
        "properties": {
          "id": "qqts07t-272353",
          "prio": "3. P3 Regular",
          "cat": "B"
        }
      };
      final hpB = HomepassPoint.fromGeoJsonFeature(featB);
      expect(hpB.categoryColor, const Color(0xFFFB8C00)); // Oranye

      final featC1 = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [109.017675, -7.736301]
        },
        "properties": {
          "id": "qqtebz8-242433",
          "prio": "4. P4 Regular visited last 30 days",
          "cat": "C1"
        }
      };
      final hpC1 = HomepassPoint.fromGeoJsonFeature(featC1);
      expect(hpC1.categoryColor, const Color(0xFF43A047)); // Hijau C1

      final featC2 = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [109.017648, -7.735984]
        },
        "properties": {
          "id": "qqtebz8-233311",
          "cat": "C2"
        }
      };
      final hpC2 = HomepassPoint.fromGeoJsonFeature(featC2);
      expect(hpC2.categoryColor, const Color(0xFF00ACC1)); // Cyan C2

      final featD = {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [109.015991, -7.741136]
        },
        "properties": {
          "id": "qqtebwz-228648",
          "cat": "D"
        }
      };
      final hpD = HomepassPoint.fromGeoJsonFeature(featD);
      expect(hpD.categoryColor, const Color(0xFF1E88E5)); // Biru D
    });

    test('GeoJsonService loadDistricts returns 24 districts with valid coordinates', () async {
      final service = GeoJsonService.instance;
      final districts = await service.loadDistricts();
      expect(districts.length, 24);
      expect(districts.any((d) => d.name.contains('Cilacap Tengah')), isTrue);
      expect(districts.any((d) => d.name.contains('Kroya')), isTrue);
      expect(districts.any((d) => d.name.contains('Majenang')), isTrue);
    });

    test('GeoJsonService calculates distance and nearest tower accurately', () {
      final service = GeoJsonService.instance;

      const p1 = LatLng(-7.7188, 109.0156);
      const p2 = LatLng(-7.7288, 109.0156); // approx 1.1 km south

      final dist = service.calculateDistanceMeters(p1, p2);
      expect(dist, greaterThan(1000));
      expect(dist, lessThan(1200));

      const tower1 = BtsTower(
        siteName: 'Near Tower',
        towerId: 'T1',
        enodebId: 'E1',
        antennaHeight: '30',
        latitude: -7.7190,
        longitude: 109.0160,
      );

      const tower2 = BtsTower(
        siteName: 'Far Tower',
        towerId: 'T2',
        enodebId: 'E2',
        antennaHeight: '45',
        latitude: -7.8000,
        longitude: 109.1000,
      );

      final nearest = service.findNearestTower(p1, [tower1, tower2]);
      expect(nearest, isNotNull);
      expect(nearest!.siteName, 'Near Tower');
    });

    test('LocationParser parses various Lat/Long formats, WhatsApp shareloc, and Google Maps URLs', () async {
      // 1. Plain coordinates
      final res1 = await LocationParser.parse('-7.718821, 109.015632');
      expect(res1, isNotNull);
      expect(res1!.point.latitude, closeTo(-7.718821, 0.0001));
      expect(res1.point.longitude, closeTo(109.015632, 0.0001));

      // 2. Google Maps URL query format
      final res2 = await LocationParser.parse('https://maps.google.com/?q=-7.7250,109.0120');
      expect(res2, isNotNull);
      expect(res2!.point.latitude, closeTo(-7.7250, 0.0001));
      expect(res2.point.longitude, closeTo(109.0120, 0.0001));

      // 3. WhatsApp message containing Google Maps link
      final res3 = await LocationParser.parse('Lokasi rumah calon pelanggan: https://www.google.com/maps?q=-7.6315,109.2485 tolong cek');
      expect(res3, isNotNull);
      expect(res3!.point.latitude, closeTo(-7.6315, 0.0001));
      expect(res3.point.longitude, closeTo(109.2485, 0.0001));

      // 4. Geo URI
      final res4 = await LocationParser.parse('geo:-7.7188,109.0156?z=17');
      expect(res4, isNotNull);
      expect(res4!.point.latitude, closeTo(-7.7188, 0.0001));
      expect(res4.point.longitude, closeTo(109.0156, 0.0001));

      // 5. Invalid string returns null
      final res5 = await LocationParser.parse('halo apa kabar');
      expect(res5, isNull);
    });
  });
}
