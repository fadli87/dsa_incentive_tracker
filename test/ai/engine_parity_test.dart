import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:dsa_incentive_tracker/ai/core/entity_extractor.dart';
import 'package:dsa_incentive_tracker/ai/intents/incentive_handlers.dart';
import 'package:dsa_incentive_tracker/core/engine/calculator_engine.dart';
import 'package:dsa_incentive_tracker/core/models/calculator_models.dart';

void main() {
  group('Engine Parity Tests (Coach vs CalculatorEngine)', () {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    test('Paritas angka untuk OJT 8 SA', () {
      final engineResult = CalculatorEngine.calculateDetailed(
        position: PositionType.ojt,
        f0: 0, f50: 8, f100: 0, f125: 0, f200: 0, fwa: 0, p35: 0, p6: 0,
      );

      final coachResult = IncentiveHandlers.handleCalc(
        entities: const ExtractedEntities(
          totalSa: 8,
          position: PositionType.ojt,
        ),
      );

      expect(coachResult.metadata['grandTotal'], equals(engineResult.grandTotal));
      expect(coachResult.text.contains(currencyFmt.format(engineResult.grandTotal)), isTrue);
      expect(coachResult.text.contains(currencyFmt.format(engineResult.basicFee)), isTrue);
      expect(coachResult.text.contains(currencyFmt.format(engineResult.progInc)), isTrue);
    });

    test('Paritas angka untuk Elite 15 SA (FTTH 229K)', () {
      final engineResult = CalculatorEngine.calculateDetailed(
        position: PositionType.elite,
        f0: 0, f50: 15, f100: 0, f125: 0, f200: 0, fwa: 0, p35: 0, p6: 0,
      );

      final coachResult = IncentiveHandlers.handleCalc(
        entities: const ExtractedEntities(
          totalSa: 15,
          position: PositionType.elite,
        ),
      );

      expect(coachResult.metadata['grandTotal'], equals(engineResult.grandTotal));
      expect(coachResult.text.contains(currencyFmt.format(engineResult.grandTotal)), isTrue);
      expect(coachResult.text.contains(currencyFmt.format(engineResult.pmBase)), isTrue);
      expect(coachResult.text.contains(currencyFmt.format(engineResult.multBonus)), isTrue);
    });

    test('Paritas angka untuk Pro 30 SA kombinasi produk', () {
      final productCounts = {
        'f0': 1,
        'f50': 10,
        'f100': 5,
        'f125': 2,
        'f200': 1,
        'fwa': 8,
        'p35': 2,
        'p6': 1,
      };

      final engineResult = CalculatorEngine.calculateDetailed(
        position: PositionType.pro,
        f0: 1, f50: 10, f100: 5, f125: 2, f200: 1, fwa: 8, p35: 2, p6: 1,
      );

      final coachResult = IncentiveHandlers.handleCalc(
        entities: ExtractedEntities(
          productCounts: productCounts,
          totalSa: 30,
          position: PositionType.pro,
        ),
      );

      expect(coachResult.metadata['grandTotal'], equals(engineResult.grandTotal));
      expect(coachResult.text.contains(currencyFmt.format(engineResult.grandTotal)), isTrue);
      expect(coachResult.text.contains(currencyFmt.format(engineResult.pmBase)), isTrue);
      expect(coachResult.text.contains(currencyFmt.format(engineResult.progInc)), isTrue);
      expect(coachResult.text.contains(currencyFmt.format(engineResult.multBonus)), isTrue);
    });
  });
}
