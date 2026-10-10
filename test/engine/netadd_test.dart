import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/core/models/calculator_models.dart';
import 'package:dsa_incentive_tracker/core/engine/calculator_engine.dart';

void main() {
  group('DSA Net Add Incentive Tests (September 2026)', () {
    test('(85, 86) -> 50.000 (incremental 1, rate 50k)', () {
      final res = CalculatorEngine.calculateDsaNetAdd(
        position: PositionType.pro,
        baselineActiveSubs: 85,
        currentActiveSubs: 86,
      );
      expect(res.incrementalSa, 1);
      expect(res.ratePerSa, 50000.0);
      expect(res.totalNetAddBonus, 50000.0);
    });

    test('(90, 95) -> 250.000 (incremental 5, rate 50k)', () {
      final res = CalculatorEngine.calculateDsaNetAdd(
        position: PositionType.elite,
        baselineActiveSubs: 90,
        currentActiveSubs: 95,
      );
      expect(res.incrementalSa, 5);
      expect(res.ratePerSa, 50000.0);
      expect(res.totalNetAddBonus, 250000.0);
    });

    test('(95, 106) -> 1.000.000 (incremental 11 di-cap 10, rate 100k)', () {
      final res = CalculatorEngine.calculateDsaNetAdd(
        position: PositionType.pro,
        baselineActiveSubs: 95,
        currentActiveSubs: 106,
      );
      expect(res.incrementalSa, 10);
      expect(res.ratePerSa, 100000.0);
      expect(res.totalNetAddBonus, 1000000.0);
    });

    test('(106, 110) -> 400.000 (incremental 4, rate 100k)', () {
      final res = CalculatorEngine.calculateDsaNetAdd(
        position: PositionType.elite,
        baselineActiveSubs: 106,
        currentActiveSubs: 110,
      );
      expect(res.incrementalSa, 4);
      expect(res.ratePerSa, 100000.0);
      expect(res.totalNetAddBonus, 400000.0);
    });

    test('(110, 150) -> 1.000.000 (incremental 40 di-cap 10, rate 100k)', () {
      final res = CalculatorEngine.calculateDsaNetAdd(
        position: PositionType.pro,
        baselineActiveSubs: 110,
        currentActiveSubs: 150,
      );
      expect(res.incrementalSa, 10);
      expect(res.ratePerSa, 100000.0);
      expect(res.totalNetAddBonus, 1000000.0);
    });

    test('(150, 200) -> 1.500.000 (incremental 50 di-cap 10, rate 150k)', () {
      final res = CalculatorEngine.calculateDsaNetAdd(
        position: PositionType.elite,
        baselineActiveSubs: 150,
        currentActiveSubs: 200,
      );
      expect(res.incrementalSa, 10);
      expect(res.ratePerSa, 150000.0);
      expect(res.totalNetAddBonus, 1500000.0);
    });

    test('(120, 119) -> 0 (negative incremental)', () {
      final res = CalculatorEngine.calculateDsaNetAdd(
        position: PositionType.pro,
        baselineActiveSubs: 120,
        currentActiveSubs: 119,
      );
      expect(res.incrementalSa, 0);
      expect(res.totalNetAddBonus, 0.0);
    });

    test('(80, 79) -> 0 (current < 80, tidak eligible)', () {
      final res = CalculatorEngine.calculateDsaNetAdd(
        position: PositionType.pro,
        baselineActiveSubs: 80,
        currentActiveSubs: 79,
      );
      expect(res.incrementalSa, 0);
      expect(res.ratePerSa, 0.0);
      expect(res.totalNetAddBonus, 0.0);
    });

    test('OJT position returns DsaNetAddDetail.empty', () {
      final res = CalculatorEngine.calculateDsaNetAdd(
        position: PositionType.ojt,
        baselineActiveSubs: 100,
        currentActiveSubs: 150,
      );
      expect(res.incrementalSa, 0);
      expect(res.totalNetAddBonus, 0.0);
    });
  });
}
