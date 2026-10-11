import 'package:intl/intl.dart';
import '../../core/engine/calculator_engine.dart';
import '../../core/engine/incentive_bucket.dart';
import '../../core/models/calculator_models.dart';
import '../core/entity_extractor.dart';
import '../models/quick_action.dart';

/// Handler untuk intent perhitungan dan informasi skema insentif.
/// Menghitung seluruh angka secara dinamis via CalculatorEngine tanpa angka hardcoded.
class IncentiveHandlers {
  IncentiveHandlers._();

  static final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Handler untuk `incentive_calc`
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleCalc({
    required ExtractedEntities entities,
    PositionType defaultPosition = PositionType.elite,
    Map<String, int>? currentStateCounts,
  }) {
    final pos = entities.position ?? defaultPosition;

    int f0 = entities.productCounts['f0'] ?? 0;
    int f50 = entities.productCounts['f50'] ?? 0;
    int f100 = entities.productCounts['f100'] ?? 0;
    int f125 = entities.productCounts['f125'] ?? 0;
    int f200 = entities.productCounts['f200'] ?? 0;
    int fwa = entities.productCounts['fwa'] ?? 0;
    int p35 = entities.productCounts['p35'] ?? 0;
    int p6 = entities.productCounts['p6'] ?? 0;

    String assumptionNote = '';

    // Jika user hanya memberi total SA tanpa rincian bucket (misal: "15 SA")
    if (!entities.hasProductCounts && entities.totalSa != null && entities.totalSa! > 0) {
      final total = entities.totalSa!;
      // Asumsi paket terlaris di lapangan: FTTH 229K-299K (f50)
      f50 = total;
      assumptionNote = '💡 *Asumsi simulasi:* Menggunakan paket terlaris (${IncentiveBucket.getLabel(IncentiveBucket.f50)}) sejumlah $total aktivasi.\n\n';
    } else if (!entities.hasProductCounts && (entities.totalSa == null || entities.totalSa == 0)) {
      if (currentStateCounts != null && currentStateCounts.values.any((c) => c > 0)) {
        f0 = currentStateCounts['f0'] ?? 0;
        f50 = currentStateCounts['f50'] ?? 0;
        f100 = currentStateCounts['f100'] ?? 0;
        f125 = currentStateCounts['f125'] ?? 0;
        f200 = currentStateCounts['f200'] ?? 0;
        fwa = currentStateCounts['fwa'] ?? 0;
        p35 = currentStateCounts['p35'] ?? 0;
        p6 = currentStateCounts['p6'] ?? 0;
        assumptionNote = '💡 *Sumber data:* Mengambil input dari state kalkulator Anda saat ini.\n\n';
      } else {
        // Default contoh 15 SA
        f50 = 15;
        assumptionNote = '💡 *Asumsi simulasi:* Contoh kalkulasi 15 SA paket ${IncentiveBucket.getLabel(IncentiveBucket.f50)}.\n\n';
      }
    }

    final result = CalculatorEngine.calculateDetailed(
      position: pos,
      f0: f0,
      f50: f50,
      f100: f100,
      f125: f125,
      f200: f200,
      fwa: fwa,
      p35: p35,
      p6: p6,
    );

    final sb = StringBuffer();
    sb.writeln('💰 **Hasil Simulasi Insentif (${pos.label})**\n');
    if (assumptionNote.isNotEmpty) {
      sb.write(assumptionNote);
    }

    sb.writeln('• **Total SA:** ${result.totalSa} Aktivasi');
    sb.writeln('• **Gaji Pokok / Basic Fee:** ${_currencyFmt.format(result.basicFee)}');
    sb.writeln('• **Product Mix Base (PM):** ${_currencyFmt.format(result.pmBase)}');
    if (result.multBonus > 0) {
      sb.writeln('• **Multiplier Bonus (${result.multRate}x):** ${_currencyFmt.format(result.multBonus)}');
    }
    sb.writeln('• **Insentif Progresif:** ${_currencyFmt.format(result.progInc)}');
    if (result.specialInc > 0) {
      sb.writeln('• **Special Incentive PXGY:** ${_currencyFmt.format(result.specialInc)}');
    }
    if (result.lumpSumBonus > 0) {
      sb.writeln('• **Lump Sum Bonus:** ${_currencyFmt.format(result.lumpSumBonus)}');
    }

    sb.writeln('\n🏆 **ESTIMASI TOTAL PENDAPATAN:**');
    sb.writeln('👉 **${_currencyFmt.format(result.grandTotal)}**');

    // Ringkasan tier progresif yang sedang aktif
    final activeTier = result.tierRows.where((t) => t.isCurrentTier).toList();
    if (activeTier.isNotEmpty) {
      sb.writeln('\n📊 **Tier Progresif Saat Ini:** ${activeTier.first.tierRange} (Tarif ${_currencyFmt.format(activeTier.first.ratePerAkt)}/SA)');
    }

    final actions = [
      const QuickAction(
        label: 'Hitung 20 SA',
        intent: 'incentive_calc',
        args: {'totalSa': 20},
      ),
      const QuickAction(
        label: 'Hitung 30 SA',
        intent: 'incentive_calc',
        args: {'totalSa': 30},
      ),
      QuickAction.nav(
        label: 'Buka Kalkulator Detail',
        destination: CoachDestination.calculator,
      ),
    ];

    return (
      text: sb.toString().trim(),
      actions: actions,
      metadata: {
        'grandTotal': result.grandTotal,
        'totalSa': result.totalSa,
        'position': pos.label,
      },
    );
  }

  /// Handler untuk `incentive_scheme_info`
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleSchemeInfo() {
    // Generate skema resmi dinamis dari CalculatorEngine
    final elite15 = CalculatorEngine.calculateDetailed(
      position: PositionType.elite,
      f0: 0, f50: 15, f100: 0, f125: 0, f200: 0, fwa: 0, p35: 0, p6: 0,
    );
    final elite30 = CalculatorEngine.calculateDetailed(
      position: PositionType.elite,
      f0: 0, f50: 30, f100: 0, f125: 0, f200: 0, fwa: 0, p35: 0, p6: 0,
    );

    final sb = StringBuffer();
    sb.writeln('📋 **Struktur Skema Insentif Resmi September 2026**\n');
    sb.writeln('Komponen insentif terdiri dari 5 elemen:');
    sb.writeln('1. **Basic Fee**: Sesuai level DSA (OJT, Pro, Elite, SPV).');
    sb.writeln('2. **Product Mix Base (PM)**: Komisi per paket yang terjual (Exc. PPN):');
    sb.writeln('   • ${IncentiveBucket.getLabel(IncentiveBucket.f50)}: ${_currencyFmt.format(IncentiveBucket.getBaseCommission(IncentiveBucket.f50))}');
    sb.writeln('   • ${IncentiveBucket.getLabel(IncentiveBucket.f100)}: ${_currencyFmt.format(IncentiveBucket.getBaseCommission(IncentiveBucket.f100))}');
    sb.writeln('   • ${IncentiveBucket.getLabel(IncentiveBucket.f125)}: ${_currencyFmt.format(IncentiveBucket.getBaseCommission(IncentiveBucket.f125))}');
    sb.writeln('   • ${IncentiveBucket.getLabel(IncentiveBucket.f200)}: ${_currencyFmt.format(IncentiveBucket.getBaseCommission(IncentiveBucket.f200))}');
    sb.writeln('   • ${IncentiveBucket.getLabel(IncentiveBucket.fwa)}: ${_currencyFmt.format(IncentiveBucket.getBaseCommission(IncentiveBucket.fwa))}');
    sb.writeln('   • ${IncentiveBucket.getLabel(IncentiveBucket.p35)}: ${_currencyFmt.format(IncentiveBucket.getBaseCommission(IncentiveBucket.p35))}');
    sb.writeln('   • ${IncentiveBucket.getLabel(IncentiveBucket.p6)}: ${_currencyFmt.format(IncentiveBucket.getBaseCommission(IncentiveBucket.p6))}');
    sb.writeln('3. **Multiplier Bonus (Pro & Elite)**: Pengali PM Base hingga 4.65x mulai dari 7 SA.');
    sb.writeln('4. **Insentif Progresif**: Akumulasi tiering bertingkat per aktivasi.');
    sb.writeln('5. **Bonus Tambahan**: Survival M3/M5, Quarterly Bonus, dan Net Add (Special Incentive PXGY berlaku khusus leads DTD).\n');

    sb.writeln('🎯 **Contoh Simulasi Pendapatan Elite:**');
    sb.writeln('• **15 SA FTTH 229K:** ${_currencyFmt.format(elite15.grandTotal)} (Multiplier ${elite15.multRate}x)');
    sb.writeln('• **30 SA FTTH 229K:** ${_currencyFmt.format(elite30.grandTotal)} (Multiplier ${elite30.multRate}x)');

    final actions = [
      const QuickAction(
        label: 'Hitung Insentif 15 SA',
        intent: 'incentive_calc',
        args: {'totalSa': 15},
      ),
      const QuickAction(
        label: 'Hitung Insentif 30 SA',
        intent: 'incentive_calc',
        args: {'totalSa': 30},
      ),
      QuickAction.nav(
        label: 'Buka Kalkulator Insentif',
        destination: CoachDestination.calculator,
      ),
    ];

    return (
      text: sb.toString().trim(),
      actions: actions,
      metadata: {'type': 'scheme_info'},
    );
  }
}
