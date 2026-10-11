import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/ai/core/location_decision_engine.dart';
import 'package:dsa_incentive_tracker/maps/models/map_models.dart';
import 'package:dsa_incentive_tracker/network/models/cell_signal_info.dart';

void main() {
  group('LocationDecisionEngine Tests (FTTH vs FWA vs Out of Coverage)', () {
    const userLat = -7.7123;
    const userLng = 109.0123;

    final ftthNear = HomepassPoint(
      id: 'HP-FTTH-001',
      cluster: 'CILACAP',
      district: 'CILACAP TENGAH',
      village: 'SIDAYU',
      netType: 'FTTH',
      priority: '1',
      category: 'A',
      latitude: userLat + 0.0002, // ~22 meter
      longitude: userLng + 0.0002,
    );

    final fwaNear = HomepassPoint(
      id: 'HP-FWA-001',
      cluster: 'CILACAP',
      district: 'KROYA',
      village: 'KROYA',
      netType: 'FWA INDOOR/OUTDOOR',
      priority: '1',
      category: 'A',
      latitude: userLat + 0.0003, // ~33 meter
      longitude: userLng + 0.0003,
    );

    final hpFar = HomepassPoint(
      id: 'HP-FAR-001',
      cluster: 'CILACAP',
      district: 'MAJENANG',
      village: 'MAJENANG',
      netType: 'FTTH',
      priority: '1',
      category: 'A',
      latitude: userLat + 0.05, // ~5 km
      longitude: userLng + 0.05,
    );

    final existingCustomerHp = HomepassPoint(
      id: 'HP-EXISTING-001',
      cluster: 'CILACAP',
      district: 'CILACAP SELATAN',
      village: 'SIDAKAYA',
      netType: 'FTTH',
      priority: '9 (Existing)',
      category: 'A',
      latitude: userLat + 0.0001,
      longitude: userLng + 0.0001,
    );

    test('Rekomendasikan FTTH jika Homepass FTTH berada dalam radius 100 meter', () {
      final card = LocationDecisionEngine.evaluateLocation(
        userLat: userLat,
        userLng: userLng,
        homepassList: [ftthNear, fwaNear, hpFar],
      );

      expect(card.decisionType, equals(LocationDecisionType.ftthRecommended));
      expect(card.actualDistanceMeters, isNotNull);
      expect(card.actualDistanceMeters!, lessThanOrEqualTo(100.0));
      expect(card.nearestPoint?.id, equals('HP-FTTH-001'));
      expect(card.recommendedPackages, isNotEmpty);
      expect(card.recommendedScript, contains('XL SATU FIBER'));
    });

    test('Rekomendasikan FWA jika Homepass FWA dekat dan skor RF bagus (>= 60)', () {
      const goodCell = CellData(
        cellType: 'LTE',
        rsrp: -85,
        sinr: 15,
        rsrq: -8,
        cqi: 12,
        pci: 100,
        band: 'B3',
      );
      final rfSnapshot = TelephonySnapshot(
        networkType: 'LTE',
        networkOperatorName: 'XL Axiata',
        servingCell: goodCell,
        timestamp: DateTime.now(),
      );

      final card = LocationDecisionEngine.evaluateLocation(
        userLat: userLat,
        userLng: userLng,
        homepassList: [fwaNear, hpFar],
        currentRfSignal: rfSnapshot,
      );

      expect(card.decisionType, equals(LocationDecisionType.fwaRecommended));
      expect(card.actualDistanceMeters!, lessThanOrEqualTo(100.0));
      expect(card.recommendedScript, contains('FWA'));
    });

    test('FWA Weak Signal jika Homepass FWA dekat tetapi skor RF buruk (< 60)', () {
      const weakCell = CellData(
        cellType: 'LTE',
        rsrp: -118,
        sinr: -2,
        rsrq: -18,
        cqi: 3,
        pci: 100,
        band: 'B3',
      );
      final weakRfSnapshot = TelephonySnapshot(
        networkType: 'LTE',
        networkOperatorName: 'XL Axiata',
        servingCell: weakCell,
        timestamp: DateTime.now(),
      );

      final card = LocationDecisionEngine.evaluateLocation(
        userLat: userLat,
        userLng: userLng,
        homepassList: [fwaNear],
        currentRfSignal: weakRfSnapshot,
      );

      expect(card.decisionType, equals(LocationDecisionType.fwaWeakSignal));
      expect(card.title, contains('Kurang Optimal'));
    });

    test('Out of Coverage jika tidak ada Homepass dalam radius 100 meter', () {
      final card = LocationDecisionEngine.evaluateLocation(
        userLat: userLat,
        userLng: userLng,
        homepassList: [hpFar],
      );

      expect(card.decisionType, equals(LocationDecisionType.outOfCoverage));
      expect(card.actualDistanceMeters!, greaterThan(100.0));
      expect(card.title, contains('Di Luar Radius'));
    });

    test('Flag isExistingCustomer aktif jika Homepass adalah Existing Customer', () {
      final card = LocationDecisionEngine.evaluateLocation(
        userLat: userLat,
        userLng: userLng,
        homepassList: [existingCustomerHp],
      );

      expect(card.isExistingCustomer, isTrue);
      expect(card.description, contains('Existing FTTH Customer'));
    });
  });
}
