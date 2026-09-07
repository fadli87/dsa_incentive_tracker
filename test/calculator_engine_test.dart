import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/core/engine/calculator_engine.dart';
import 'package:dsa_incentive_tracker/core/models/calculator_models.dart';

void main() {
  group('CalculatorEngine Tests', () {
    test('Nilai default Cilacap dan Basic Fee Elite adalah Rp 2.773.184', () {
      final res = CalculatorEngine.calculateDetailed(
        position: PositionType.elite,
        f0: 0,
        f50: 0,
        f100: 0,
        f125: 0,
        f200: 0,
        fwa: 0,
        p35: 0,
        p6: 0,
      );

      expect(res.city, 'KAB. CILACAP');
      expect(res.basicFee, 2773184.0);
      expect(res.totalSa, 0);
      expect(res.grandTotal, 2773184.0);
    });

    test('Perhitungan 20 SA dengan tiering September', () {
      // 5 x f100, 5 x f125, 5 x f200, 5 x fwa = 20 SA
      final res = CalculatorEngine.calculateDetailed(
        position: PositionType.elite,
        f0: 0,
        f50: 0,
        f100: 5,
        f125: 5,
        f200: 5,
        fwa: 5,
        p35: 0,
        p6: 0,
      );

      expect(res.totalSa, 20);

      // pmBase = 5*100k + 5*125k + 5*200k + 5*50k = 500k + 625k + 1000k + 250k = 2.375.000
      expect(res.pmBase, 2375000.0);

      // totalSa = 20 falls into tier 14-29 => multRate = 4.0
      expect(res.multRate, 4.0);
      expect(res.multBonus, 4.0 * 2375000.0); // 9.500.000

      // Progresif 20 SA:
      // b1 (1-6) = 6 * 80.000 = 480.000
      // b2 (7-9) = 3 * 150.000 = 450.000
      // b3 (10-13) = 4 * 175.000 = 700.000
      // b4 (14-29) = 7 * 200.000 = 1.400.000
      // progInc = 480k + 450k + 700k + 1400k = 3.030.000
      expect(res.progInc, 3030000.0);

      // Grand Total = Basic Fee (2.773.184) + progInc (3.030.000) + pmBase (2.375.000) + multBonus (9.500.000)
      expect(res.grandTotal, 2773184.0 + 3030000.0 + 2375000.0 + 9500000.0);
      expect(res.tierRows.length, 7);
      expect(res.tierRows[3].isCurrentTier, isTrue); // tier 14-29 is active
    });
  });
}
