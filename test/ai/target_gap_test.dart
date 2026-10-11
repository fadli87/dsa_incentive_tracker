import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/ai/core/target_coach_engine.dart';
import 'package:dsa_incentive_tracker/core/engine/calculator_engine.dart';
import 'package:dsa_incentive_tracker/core/models/calculator_models.dart';

void main() {
  group('TargetCoachEngine Tests (Gap, Multiplier Jumps & Product Mix)', () {
    test('Simulasi lompatan multiplier 6 -> 7 SA pada posisi Elite/Pro', () {
      final gapAt6 = TargetCoachEngine.calculateGap(
        currentCalcState: {'f50': 6},
        position: PositionType.elite,
      );

      expect(gapAt6.currentSa, equals(6));
      expect(gapAt6.neededForNextTier, equals(1)); // 6 + 1 = 7 SA
      expect(gapAt6.nextTierSa, equals(7));

      // Verifikasi konsistensi angka dengan CalculatorEngine
      final calc6 = CalculatorEngine.calculateDetailed(
        f0: 0, f50: 6, f100: 0, f125: 0, f200: 0, fwa: 0, p35: 0, p6: 0,
        position: PositionType.elite,
      );
      final calc7 = CalculatorEngine.calculateDetailed(
        f0: 0, f50: 7, f100: 0, f125: 0, f200: 0, fwa: 0, p35: 0, p6: 0,
        position: PositionType.elite,
      );

      expect(gapAt6.currentGrandTotal, equals(calc6.grandTotal));
      expect(gapAt6.nextTierGrandTotal, equals(calc7.grandTotal));
      expect(calc7.grandTotal - calc6.grandTotal, equals(gapAt6.plusGrandTotals[1]));
    });

    test('Simulasi lompatan multiplier 13 -> 14 SA pada posisi Elite', () {
      final gapAt13 = TargetCoachEngine.calculateGap(
        currentCalcState: {'f50': 13},
        position: PositionType.elite,
      );

      expect(gapAt13.currentSa, equals(13));
      expect(gapAt13.neededForNextTier, equals(1)); // 13 + 1 = 14 SA
      expect(gapAt13.nextTierSa, equals(14));

      final calc13 = CalculatorEngine.calculateDetailed(
        f0: 0, f50: 13, f100: 0, f125: 0, f200: 0, fwa: 0, p35: 0, p6: 0,
        position: PositionType.elite,
      );
      final calc14 = CalculatorEngine.calculateDetailed(
        f0: 0, f50: 14, f100: 0, f125: 0, f200: 0, fwa: 0, p35: 0, p6: 0,
        position: PositionType.elite,
      );

      expect(gapAt13.currentGrandTotal, equals(calc13.grandTotal));
      expect(gapAt13.nextTierGrandTotal, equals(calc14.grandTotal));
      expect(gapAt13.plusGrandTotals[1], equals(calc14.grandTotal - calc13.grandTotal));
    });

    test('OJT Target Lump Sum bonus 3 SA dan 7 SA', () {
      final gapAt2 = TargetCoachEngine.calculateGap(
        currentCalcState: {'fwa': 2},
        position: PositionType.ojt,
      );

      expect(gapAt2.currentSa, equals(2));
      expect(gapAt2.neededForNextLumpSum, equals(1)); // 2 + 1 = 3 SA
      expect(gapAt2.nextLumpSumSa, equals(3));
      expect(gapAt2.nextLumpSumBonus, equals(325000.0));
    });

    test('Best Product Mix mengurutkan bucket berdasarkan deltaGrandTotal marginal', () {
      final rankings = TargetCoachEngine.rankProductMix(
        currentCalcState: {'f50': 10},
        position: PositionType.elite,
      );

      expect(rankings, isNotEmpty);
      // Urutan pertama harus memberikan delta tertinggi
      for (int i = 0; i < rankings.length - 1; i++) {
        expect(rankings[i].deltaGrandTotal, greaterThanOrEqualTo(rankings[i + 1].deltaGrandTotal));
      }
    });

    test('Pace kalkulasi sisa hari dan laju harian secara akurat', () {
      final fixedDate = DateTime(2026, 9, 15); // Pertengahan September (30 hari total)
      final paceResult = TargetCoachEngine.calculatePace(
        currentSa: 10,
        now: fixedDate,
        targetSa: 20,
      );

      expect(paceResult, contains('September 2026'));
      expect(paceResult, contains('15 dari 30 hari'));
      expect(paceResult, contains('16 hari'));
      expect(paceResult, contains('20 SA'));
    });
  });
}
