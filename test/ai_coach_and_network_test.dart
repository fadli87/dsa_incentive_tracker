import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/ai/engine/sales_ai_coach.dart';
import 'package:dsa_incentive_tracker/network/aura_network.dart';

void main() {
  group('AURA AI Coach & RF Diagnostic Tests', () {
    test('SalesAiCoach returns intelligent greeting and quick replies', () {
      final reply = SalesAiCoach.reply('Halo apa kabar?');
      expect(reply.text, contains('Halo'));
      expect(reply.quickReplies, isNotEmpty);
    });

    test('SalesAiCoach provides incentive guidance', () {
      final reply = SalesAiCoach.reply('Bagaimana skema insentif September 2026?');
      expect(reply.text, contains('DSA'));
      expect(reply.text, contains('Tier 1'));
      expect(reply.text, contains('SPV'));
    });

    test('SalesAiCoach provides sales closing scripts for houses and kos', () {
      final houseReply = SalesAiCoach.reply('script closing rumah tangga');
      expect(houseReply.text, contains('Bapak/Ibu'));
      expect(houseReply.text, contains('XL Satu'));

      final kosReply = SalesAiCoach.reply('script closing anak kos');
      expect(kosReply.text, contains('kos'));
      expect(kosReply.text, contains('Plug & Play'));
    });

    test('SalesAiCoach provides RF Evaluation when cell signal is provided', () {
      const cell = CellData(
        cellType: 'LTE',
        rsrp: -82,
        sinr: 16,
        rsrq: -8,
        cqi: 14,
        pci: 120,
        band: 'B3',
      );

      final snapshot = TelephonySnapshot(
        networkType: 'LTE',
        networkOperatorName: 'XL Axiata',
        servingCell: cell,
        timestamp: DateTime.now(),
      );

      final reply = SalesAiCoach.reply('cek sinyal lokasi ini', currentRfSignal: snapshot);
      expect(reply.text, contains('Hasil Analisis Cerdas Sinyal'));
      expect(reply.text, contains('Grade A'));
      expect(reply.metadata?['fwaReady'], isTrue);
    });

    test('EarfcnCalculator resolves Band 3 1800 MHz and Band 40 2300 MHz correctly', () {
      final b3 = EarfcnCalculator.calculate(1500);
      expect(b3, isNotNull);
      expect(b3!.bandNumber, 3);
      expect(b3.bandCode, 'L3');
      expect(b3.fDl, greaterThan(1800));

      final b40 = EarfcnCalculator.calculate(39000);
      expect(b40, isNotNull);
      expect(b40!.bandNumber, 40);
      expect(b40.bandCode, 'L40');
    });

    test('CellData calculates eNodeB ID and CID separation correctly', () {
      // 28-bit ECI: (eNodeB << 8) | CID
      // eNodeB = 12345, CID = 7 -> ECI = (12345 * 256) + 7 = 3160327
      const cell = CellData(
        cellType: 'LTE',
        cellId: 3160327,
      );

      expect(cell.eNodeBId, 12345);
      expect(cell.cid, 7);
      expect(cell.eNodeBCidDisplay, '12345-7');
    });
  });
}
