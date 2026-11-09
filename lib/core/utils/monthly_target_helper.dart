import '../../data/models/incentive_record.dart';
import '../engine/calculator_engine.dart';
import '../models/calculator_models.dart';

/// Hasil simulasi jarak ke tier insentif berikutnya (murni memanggil CalculatorEngine).
class NextTierSimulationResult {
  final int missingSa;
  final String nextTierLabel;
  final double estimatedDeltaRupiah;
  final double simulatedGrandTotal;
  final String primaryCategoryLabel;

  const NextTierSimulationResult({
    required this.missingSa,
    required this.nextTierLabel,
    required this.estimatedDeltaRupiah,
    required this.simulatedGrandTotal,
    required this.primaryCategoryLabel,
  });
}

/// Memilih record insentif bulan berjalan (`period_month == yyyy-MM-01`)
/// yang belum dihapus (`!deleted`) dengan `updated_at` paling baru.
IncentiveRecord? selectCurrentMonthIncentiveRecord(
  List<IncentiveRecord> records, {
  DateTime? now,
}) {
  final targetMonth = IncentiveRecord.currentMonthIso(now);
  final candidates = records.where((r) {
    if (r.deleted) return false;
    final resolvedMonth = r.periodMonth ?? tryParsePeriodMonth(r.periode);
    return resolvedMonth == targetMonth;
  }).toList();

  if (candidates.isEmpty) return null;

  candidates.sort((a, b) {
    final dtA = DateTime.tryParse(a.updatedAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final dtB = DateTime.tryParse(b.updatedAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final cmp = dtB.compareTo(dtA);
    if (cmp != 0) return cmp;
    return (b.id ?? 0).compareTo(a.id ?? 0);
  });

  return candidates.first;
}

/// Fungsi murni untuk mensimulasikan jarak aktivasi SA ke tier berikutnya
/// dengan memanggil `CalculatorEngine.calculateDetailed` tanpa mengubah engine.
/// Maksimal 50 langkah simulasi.
NextTierSimulationResult? simulateNextTierGap(IncentiveRecord record) {
  final posNorm = record.position.trim().toLowerCase();
  PositionType position;
  if (posNorm.contains('spv')) {
    return null;
  } else if (posNorm.contains('ojt')) {
    position = PositionType.ojt;
  } else if (posNorm.contains('pro')) {
    position = PositionType.pro;
  } else {
    position = PositionType.elite;
  }

  final bool inferredLeadsFromDtd = record.specialInc > 0;

  final baseResult = CalculatorEngine.calculateDetailed(
    position: position,
    city: record.city.isNotEmpty ? record.city : CalculatorEngine.defaultCity,
    f0: record.f0,
    f50: record.f50,
    f100: record.f100,
    f125: record.f125,
    f200: record.f200,
    fwa: record.fwa,
    p35: record.p35,
    p6: record.p6,
    leadsFromDtd: inferredLeadsFromDtd,
  );

  final int currentTierIdx =
      baseResult.tierRows.indexWhere((t) => t.isCurrentTier);

  // Bila sudah berada di tier tertinggi pada tabel tierRows, tidak ada tier berikutnya
  if (currentTierIdx == baseResult.tierRows.length - 1 &&
      baseResult.tierRows.isNotEmpty) {
    return null;
  }

  // Tentukan kategori utama (default FTTH 100k, atau kategori dengan jumlah terbanyak)
  final categoryCounts = <String, int>{
    'f100': record.f100,
    'f50': record.f50,
    'f125': record.f125,
    'f200': record.f200,
    'fwa': record.fwa,
    'p35': record.p35,
    'p6': record.p6,
  };

  String primaryKey = 'f100';
  int maxCount = record.f100;
  categoryCounts.forEach((key, value) {
    if (value > maxCount) {
      maxCount = value;
      primaryKey = key;
    }
  });

  const categoryLabels = <String, String>{
    'f50': 'FTTH 50k',
    'f100': 'FTTH 100k',
    'f125': 'FTTH 125k',
    'f200': 'FTTH 200k',
    'fwa': 'FWA',
    'p35': 'P35',
    'p6': 'P6',
  };

  for (int step = 1; step <= 50; step++) {
    final simResult = CalculatorEngine.calculateDetailed(
      position: position,
      city: record.city.isNotEmpty ? record.city : CalculatorEngine.defaultCity,
      f0: record.f0,
      f50: record.f50 + (primaryKey == 'f50' ? step : 0),
      f100: record.f100 + (primaryKey == 'f100' ? step : 0),
      f125: record.f125 + (primaryKey == 'f125' ? step : 0),
      f200: record.f200 + (primaryKey == 'f200' ? step : 0),
      fwa: record.fwa + (primaryKey == 'fwa' ? step : 0),
      p35: record.p35 + (primaryKey == 'p35' ? step : 0),
      p6: record.p6 + (primaryKey == 'p6' ? step : 0),
      leadsFromDtd: inferredLeadsFromDtd,
    );

    final int simTierIdx =
        simResult.tierRows.indexWhere((t) => t.isCurrentTier);

    final bool tierIncreased = currentTierIdx == -1
        ? simTierIdx > 0 ||
            simResult.multRate > baseResult.multRate ||
            simResult.lumpSumBonus > baseResult.lumpSumBonus
        : simTierIdx > currentTierIdx;

    if (tierIncreased && simTierIdx >= 0) {
      final tierRow = simResult.tierRows[simTierIdx];
      final double delta = simResult.grandTotal - baseResult.grandTotal;
      return NextTierSimulationResult(
        missingSa: step,
        nextTierLabel: tierRow.tierRange,
        estimatedDeltaRupiah: delta > 0 ? delta : 0,
        simulatedGrandTotal: simResult.grandTotal,
        primaryCategoryLabel: categoryLabels[primaryKey] ?? 'FTTH 100k',
      );
    }
  }

  return null;
}

