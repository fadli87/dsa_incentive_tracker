import 'package:intl/intl.dart';
import '../../core/engine/calculator_engine.dart';
import '../../core/engine/incentive_bucket.dart';
import '../../core/models/calculator_models.dart';

/// Hasil simulasi target gap
class TargetGapResult {
  final int currentSa;
  final double currentGrandTotal;
  final String currentTier;
  final int? nextTierSa;
  final String? nextTierName;
  final double? nextTierGrandTotal;
  final int? neededForNextTier;
  final int? nextLumpSumSa;
  final double? nextLumpSumBonus;
  final int? neededForNextLumpSum;
  final Map<int, double> plusGrandTotals; // delta grand total for +1, +2, +3, +5

  const TargetGapResult({
    required this.currentSa,
    required this.currentGrandTotal,
    required this.currentTier,
    this.nextTierSa,
    this.nextTierName,
    this.nextTierGrandTotal,
    this.neededForNextTier,
    this.nextLumpSumSa,
    this.nextLumpSumBonus,
    this.neededForNextLumpSum,
    required this.plusGrandTotals,
  });
}

/// Hasil analisis marginal per bucket produk
class ProductMixRanking {
  final String bucketCode;
  final double deltaGrandTotal;
  final double simulatedGrandTotal;

  const ProductMixRanking({
    required this.bucketCode,
    required this.deltaGrandTotal,
    required this.simulatedGrandTotal,
  });
}

/// Engine murni untuk perhitungan Target Coach lapangan tanpa AI
class TargetCoachEngine {
  TargetCoachEngine._();

  static final _currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static const List<String> supportedBuckets = [
    IncentiveBucket.f200,
    IncentiveBucket.p6,
    IncentiveBucket.f125,
    IncentiveBucket.p35,
    IncentiveBucket.f100,
    IncentiveBucket.f50,
    IncentiveBucket.fwa,
    IncentiveBucket.f0,
  ];

  static String _getCurrentTierName(CalculationResult res) {
    if (res.tierRows.isEmpty) return 'Tier Dasar';
    final active = res.tierRows.where((r) => r.isCurrentTier).toList();
    if (active.isNotEmpty) return active.first.tierRange;
    return res.tierRows.first.tierRange;
  }

  /// Hitung selisih target aktivasi (target gap) menuju tier berikutnya dan simulasi +1..+5 SA
  static TargetGapResult calculateGap({
    Map<String, int>? currentCalcState,
    PositionType position = PositionType.elite,
  }) {
    final state = currentCalcState ?? const {};
    final baseResult = CalculatorEngine.calculateDetailed(
      fwa: state['fwa'] ?? 0,
      f100: state['f100'] ?? 0,
      f200: state['f200'] ?? 0,
      f125: state['f125'] ?? 0,
      f50: state['f50'] ?? 0,
      f0: state['f0'] ?? 0,
      p35: state['p35'] ?? 0,
      p6: state['p6'] ?? 0,
      position: position,
    );

    final currentSa = baseResult.totalSa;
    final currentTier = _getCurrentTierName(baseResult);
    final currentLumpSum = baseResult.lumpSumBonus;

    int? nextTierSa;
    String? nextTierName;
    double? nextTierGrandTotal;
    int? neededForNextTier;

    int? nextLumpSumSa;
    double? nextLumpSumBonus;
    int? neededForNextLumpSum;

    // Cari SA minimum tambahan untuk loncat tier atau multiplier (maksimum loop 50 SA)
    for (int add = 1; add <= 50; add++) {
      final simResult = CalculatorEngine.calculateDetailed(
        fwa: (state['fwa'] ?? 0) + add,
        f100: state['f100'] ?? 0,
        f200: state['f200'] ?? 0,
        f125: state['f125'] ?? 0,
        f50: state['f50'] ?? 0,
        f0: state['f0'] ?? 0,
        p35: state['p35'] ?? 0,
        p6: state['p6'] ?? 0,
        position: position,
      );

      final simTier = _getCurrentTierName(simResult);
      if (neededForNextTier == null && (simTier != currentTier || simResult.multRate > baseResult.multRate) && simResult.progInc > baseResult.progInc) {
        nextTierSa = simResult.totalSa;
        nextTierName = simTier;
        nextTierGrandTotal = simResult.grandTotal;
        neededForNextTier = add;
      }

      if (neededForNextLumpSum == null && simResult.lumpSumBonus > currentLumpSum) {
        nextLumpSumSa = simResult.totalSa;
        nextLumpSumBonus = simResult.lumpSumBonus;
        neededForNextLumpSum = add;
      }

      if (neededForNextTier != null && (position != PositionType.ojt || neededForNextLumpSum != null)) break;
    }

    // Hitung proyeksi kenaikan untuk +1, +2, +3, +5 SA
    final Map<int, double> plusGrandTotals = {};
    for (final step in [1, 2, 3, 5]) {
      final stepRes = CalculatorEngine.calculateDetailed(
        fwa: (state['fwa'] ?? 0) + step,
        f100: state['f100'] ?? 0,
        f200: state['f200'] ?? 0,
        f125: state['f125'] ?? 0,
        f50: state['f50'] ?? 0,
        f0: state['f0'] ?? 0,
        p35: state['p35'] ?? 0,
        p6: state['p6'] ?? 0,
        position: position,
      );
      plusGrandTotals[step] = stepRes.grandTotal - baseResult.grandTotal;
    }

    return TargetGapResult(
      currentSa: currentSa,
      currentGrandTotal: baseResult.grandTotal,
      currentTier: currentTier,
      nextTierSa: nextTierSa,
      nextTierName: nextTierName,
      nextTierGrandTotal: nextTierGrandTotal,
      neededForNextTier: neededForNextTier,
      nextLumpSumSa: nextLumpSumSa,
      nextLumpSumBonus: nextLumpSumBonus,
      neededForNextLumpSum: neededForNextLumpSum,
      plusGrandTotals: plusGrandTotals,
    );
  }

  /// Format teks hasil analisis Target Gap untuk sales coach
  static String formatTargetGap(TargetGapResult gap) {
    final sb = StringBuffer();
    sb.writeln('🎯 **Analisis Kejar Target & Simulasi Kenaikan Insentif**\n');
    sb.writeln('• **Pencapaian Saat Ini:** ${gap.currentSa} SA (${gap.currentTier})');
    sb.writeln('• **Estimasi Insentif Sekarang:** ${_currencyFormatter.format(gap.currentGrandTotal)}\n');

    if (gap.neededForNextTier != null) {
      sb.writeln('🚀 **Target Tier Berikutnya (${gap.nextTierName}):**');
      sb.writeln('• Cukup tambah **+${gap.neededForNextTier} SA** lagi untuk tembus **${gap.nextTierSa} SA**!');
      sb.writeln('• Potensi Take-Home Pay naik menjadi: **${_currencyFormatter.format(gap.nextTierGrandTotal)}**\n');
    } else {
      sb.writeln('🏆 **Selamat!** Anda telah berada di Tier Tertinggi.\n');
    }

    if (gap.neededForNextLumpSum != null) {
      sb.writeln('🎁 **Target Bonus Lump Sum:**');
      sb.writeln('• Tambah **+${gap.neededForNextLumpSum} SA** lagi untuk klaim Bonus Lump Sum **${_currencyFormatter.format(gap.nextLumpSumBonus)}**!\n');
    }

    sb.writeln('📊 **Tabel Kenaikan Tambahan (Marginal Grand Total):**');
    sb.writeln('| Tambahan SA | Ekstra Pendapatan |');
    sb.writeln('| :--- | :--- |');
    gap.plusGrandTotals.forEach((step, delta) {
      sb.writeln('| +$step SA | +${_currencyFormatter.format(delta)} |');
    });

    return sb.toString().trim();
  }

  /// Hitung peringkat produk berdasarkan pertambahan insentif marginal (+1 SA)
  static List<ProductMixRanking> rankProductMix({
    Map<String, int>? currentCalcState,
    PositionType position = PositionType.elite,
  }) {
    final state = currentCalcState ?? const {};
    final baseResult = CalculatorEngine.calculateDetailed(
      fwa: state['fwa'] ?? 0,
      f100: state['f100'] ?? 0,
      f200: state['f200'] ?? 0,
      f125: state['f125'] ?? 0,
      f50: state['f50'] ?? 0,
      f0: state['f0'] ?? 0,
      p35: state['p35'] ?? 0,
      p6: state['p6'] ?? 0,
      position: position,
    );

    final List<ProductMixRanking> rankings = [];

    for (final bucket in supportedBuckets) {
      final simState = Map<String, int>.from(state);
      simState[bucket] = (simState[bucket] ?? 0) + 1;

      final simResult = CalculatorEngine.calculateDetailed(
        fwa: simState['fwa'] ?? 0,
        f100: simState['f100'] ?? 0,
        f200: simState['f200'] ?? 0,
        f125: simState['f125'] ?? 0,
        f50: simState['f50'] ?? 0,
        f0: simState['f0'] ?? 0,
        p35: simState['p35'] ?? 0,
        p6: simState['p6'] ?? 0,
        position: position,
      );

      final delta = simResult.grandTotal - baseResult.grandTotal;
      rankings.add(ProductMixRanking(
        bucketCode: bucket,
        deltaGrandTotal: delta,
        simulatedGrandTotal: simResult.grandTotal,
      ));
    }

    rankings.sort((a, b) => b.deltaGrandTotal.compareTo(a.deltaGrandTotal));
    return rankings;
  }

  /// Format teks rekomendasi Best Product Mix
  static String formatProductMix(List<ProductMixRanking> rankings) {
    final sb = StringBuffer();
    sb.writeln('💡 **Rekomendasi Product Mix (Prioritas Nilai Insentif):**\n');
    sb.writeln('Berikut urutan produk berdasarkan tambahan insentif marginal per +1 unit aktivasi dari state kalkulator Anda saat ini:\n');

    for (int i = 0; i < rankings.length; i++) {
      final item = rankings[i];
      final emoji = i == 0 ? '🥇' : (i == 1 ? '🥈' : (i == 2 ? '🥉' : '•'));
      final label = IncentiveBucket.getLabel(item.bucketCode);
      final rate = IncentiveBucket.getBaseCommission(item.bucketCode);
      sb.writeln('$emoji **$label**');
      sb.writeln('   Tambahan Insentif: **+${_currencyFormatter.format(item.deltaGrandTotal)}** per aktivasi');
      sb.writeln('   Komponen: ${_currencyFormatter.format(rate)} (Basic Rate Exc. PPN) + Dampak Tiering\n');
    }

    sb.writeln('⚠️ *Catatan: Urutan ini murni berdasarkan nilai insentif finansial resmi skema September 2026. Di lapangan, kombinasikan dengan kemudahan penetrasi segmen dan ketersediaan jaringan.*');
    return sb.toString().trim();
  }

  /// Hitung kecepatan laju harian (pace) yang dibutuhkan menuju target
  static String calculatePace({
    required int currentSa,
    DateTime? now,
    int targetSa = 20,
  }) {
    final date = now ?? DateTime.now();
    final totalDaysInMonth = DateTime(date.year, date.month + 1, 0).day;
    final currentDay = date.day;
    final remainingDays = totalDaysInMonth - currentDay + 1; // Termasuk hari ini

    final remainingSa = targetSa > currentSa ? targetSa - currentSa : 0;
    final dailyPaceNeeded = remainingDays > 0 ? (remainingSa / remainingDays) : 0.0;
    final currentDailyRate = currentDay > 0 ? (currentSa / currentDay) : 0.0;

    const indonesianMonths = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final monthName = indonesianMonths[date.month - 1];

    final sb = StringBuffer();
    sb.writeln('⏱️ **Pace & Monitoring Laju Penjualan Harian**\n');
    sb.writeln('• **Periode Berjalan:** $monthName ${date.year}');
    sb.writeln('• **Hari ke:** $currentDay dari $totalDaysInMonth hari (Sisa: **$remainingDays hari**) di bulan ini');
    sb.writeln('• **Pencapaian:** $currentSa SA (Rata-rata: **${currentDailyRate.toStringAsFixed(1)} SA/hari**)\n');

    if (remainingSa <= 0) {
      sb.writeln('🎉 **Target $targetSa SA sudah tercapai!** Pertahankan performa untuk mengunci Tier Tertinggi dan bonus maksimal.');
    } else {
      sb.writeln('🎯 **Target $targetSa SA:**');
      sb.writeln('• Kekurangan: **$remainingSa SA**');
      sb.writeln('• Laju yang dibutuhkan: **${dailyPaceNeeded.toStringAsFixed(1)} SA/hari** selama $remainingDays hari ke depan.\n');

      if (currentDailyRate >= dailyPaceNeeded) {
        sb.writeln('🟢 **Status:** On Track! Laju Anda saat ini mencukupi untuk tembus target tepat waktu.');
      } else {
        sb.writeln('🟠 **Status:** Perlu Akselerasi! Tambah 1-2 prospek closing per hari untuk mengejar ketertinggalan.');
      }
    }

    return sb.toString().trim();
  }
}
