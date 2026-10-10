import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dsa_incentive_tracker/maps/models/map_models.dart';
import 'package:dsa_incentive_tracker/maps/providers/serving_tower_matcher.dart';
import 'package:dsa_incentive_tracker/maps/providers/coverage_map_provider.dart';
import 'package:dsa_incentive_tracker/network/models/cell_signal_info.dart';

void main() {
  group('ServingTowerMatcher Tests', () {
    // Dummy towers around Cilacap
    // Tower A: Cilacap Tengah (lat: -7.728, lng: 109.006), eNodeB 310101
    // Tower B: Kroya (lat: -7.630, lng: 109.250), eNodeB 310202 (Jarak > 20 km dari Cilacap Kota)
    // Tower C: Cilacap Selatan (lat: -7.735, lng: 109.010), eNodeB 310303
    final towers = [
      const BtsTower(
        towerId: 'CLP001',
        siteName: 'CILACAP TENGAH 1',
        enodebId: '310101',
        antennaHeight: '42m',
        latitude: -7.7280,
        longitude: 109.0060,
      ),
      const BtsTower(
        towerId: 'KRY001',
        siteName: 'KROYA CENTRAL',
        enodebId: '310202',
        antennaHeight: '52m',
        latitude: -7.6300,
        longitude: 109.2500,
      ),
      const BtsTower(
        towerId: 'CLP002',
        siteName: 'CILACAP SELATAN 1',
        enodebId: '310303',
        antennaHeight: '36m',
        latitude: -7.7350,
        longitude: 109.0100,
      ),
    ];

    test('LTE exact match eNodeB dalam jarak wajar (<= 15 km)', () {
      final userLoc = const LatLng(-7.7290, 109.0070); // Dekat CLP001 (~150m)
      // CellId untuk eNodeB 310101 (20-bit): cellId = (310101 << 8) + 1 = 79385857
      final cell = const CellData(
        cellType: 'LTE',
        cellId: (310101 << 8) | 1,
        isRegistered: true,
      );

      final result = ServingTowerMatcher.match(
        towers: towers,
        servingCell: cell,
        userLocation: userLoc,
      );

      expect(result.tower, isNotNull);
      expect(result.tower!.towerId, 'CLP001');
      expect(result.source, ServingMatchSource.enodebExact);
      expect(result.distanceAnomaly, isFalse);
      expect(result.distanceMeters, lessThan(1000.0));
    });

    test('LTE eNodeB cocok tapi jarak > 15 km -> distance anomaly flag & fallback nearest', () {
      // User di Cilacap Kota (-7.729, 109.007), tapi eNodeB melaporkan Kroya 310202 (> 25 km)
      final userLoc = const LatLng(-7.7290, 109.0070);
      final cell = const CellData(
        cellType: 'LTE',
        cellId: (310202 << 8) | 1,
        isRegistered: true,
      );

      final result = ServingTowerMatcher.match(
        towers: towers,
        servingCell: cell,
        userLocation: userLoc,
      );

      expect(result.tower, isNotNull);
      expect(result.distanceAnomaly, isTrue);
      // Fallback ke tower terdekat (CLP001)
      expect(result.tower!.towerId, 'CLP001');
      expect(result.source, ServingMatchSource.nearestEstimate);
    });

    test('Non-LTE (GSM/WCDMA) -> Fallback ke nearestEstimate', () {
      final userLoc = const LatLng(-7.7340, 109.0090); // Dekat CLP002
      final cell = const CellData(
        cellType: 'GSM',
        cellId: 12345,
        isRegistered: true,
      );

      final result = ServingTowerMatcher.match(
        towers: towers,
        servingCell: cell,
        userLocation: userLoc,
      );

      expect(result.tower, isNotNull);
      expect(result.tower!.towerId, 'CLP002');
      expect(result.source, ServingMatchSource.nearestEstimate);
      expect(result.distanceAnomaly, isFalse);
    });

    test('Cell UNKNOWN atau null -> empty match (ServingMatchSource.none)', () {
      final userLoc = const LatLng(-7.7280, 109.0060);
      final unknownCell = const CellData(
        cellType: 'UNKNOWN',
      );

      final result = ServingTowerMatcher.match(
        towers: towers,
        servingCell: unknownCell,
        userLocation: userLoc,
      );

      expect(result.tower, isNull);
      expect(result.source, ServingMatchSource.none);
    });

    test('CoverageMapState copyWith(clearServingTower: true) membersihkan matchedServingTower dan source', () {
      const stateWithTower = CoverageMapState(
        matchedServingTower: BtsTower(
          towerId: 'CLP001',
          siteName: 'CILACAP TENGAH 1',
          enodebId: '310101',
          antennaHeight: '42m',
          latitude: -7.7280,
          longitude: 109.0060,
        ),
        servingMatchSource: ServingMatchSource.enodebExact,
        distanceAnomaly: true,
      );

      expect(stateWithTower.matchedServingTower, isNotNull);
      expect(stateWithTower.servingMatchSource, ServingMatchSource.enodebExact);
      expect(stateWithTower.distanceAnomaly, isTrue);

      final clearedState = stateWithTower.copyWith(clearServingTower: true);
      expect(clearedState.matchedServingTower, isNull);
      expect(clearedState.servingMatchSource, ServingMatchSource.none);
      expect(clearedState.distanceAnomaly, isFalse);
    });
  });
}
