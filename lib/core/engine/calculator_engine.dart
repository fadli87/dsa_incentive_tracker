import '../models/calculator_models.dart';

class CalculatorEngine {
  static const String defaultCity = 'KAB. CILACAP';

  static double getBasicFee(PositionType position) {
    switch (position) {
      case PositionType.ojt:
        return 2000000.0;
      case PositionType.pro:
        return 2500000.0;
      case PositionType.elite:
        return 2773184.0; // Angka pasti Cilacap sesuai acuan
      case PositionType.spv:
        return 3500000.0;
    }
  }

  /// Perhitungan terstruktur dan lengkap yang mengembalikan CalculationResult
  static CalculationResult calculateDetailed({
    PositionType position = PositionType.elite,
    String city = defaultCity,
    required int f0,
    required int f50,
    required int f100,
    required int f125,
    required int f200,
    required int fwa,
    required int p35,
    required int p6,
  }) {
    final int totalSa = f0 + f50 + f100 + f125 + f200 + fwa + p35 + p6;

    final double pmBase = (f50 * 50000.0) +
        (f100 * 100000.0) +
        (f125 * 125000.0) +
        (f200 * 200000.0) +
        (fwa * 50000.0) +
        (p35 * 125000.0) +
        (p6 * 150000.0);

    final double specialInc = (p35 * 125000.0) + (p6 * 150000.0);

    // Tiering Progresif SA berdasarkan Slide September
    final int b1 = totalSa.clamp(0, 6);
    final int b2 = (totalSa - 6).clamp(0, 3);
    final int b3 = (totalSa - 9).clamp(0, 4);
    final int b4 = (totalSa - 13).clamp(0, 16);
    final int b5 = (totalSa - 29).clamp(0, 10);
    final int b6 = (totalSa - 39).clamp(0, 10);
    final int b7 = (totalSa - 49) > 0 ? (totalSa - 49) : 0;

    final double progInc = (b1 * 80000.0) +
        (b2 * 150000.0) +
        (b3 * 175000.0) +
        (b4 * 200000.0) +
        (b5 * 225000.0) +
        (b6 * 250000.0) +
        (b7 * 275000.0);

    // Multiplier Rate
    double multRate = 0.0;
    if (totalSa >= 50) {
      multRate = 4.65;
    } else if (totalSa >= 40) {
      multRate = 4.50;
    } else if (totalSa >= 30) {
      multRate = 4.25;
    } else if (totalSa >= 14) {
      multRate = 4.00;
    } else if (totalSa >= 10) {
      multRate = 2.00;
    } else if (totalSa >= 7) {
      multRate = 1.50;
    }

    final double multBonus = multRate * pmBase;
    final double basicFee = getBasicFee(position);
    final double monthlySubtotal =
        basicFee + progInc + pmBase + multBonus + specialInc;
    final double grandTotal = monthlySubtotal;

    // Rincian Baris Tabel Tier Produktivitas
    final tierRows = [
      TierRow(
        tierRange: '1 – 6 akt',
        ratePerAkt: 80000,
        multiplier: 0,
        unitsInTier: b1,
        subtotalProgressive: b1 * 80000.0,
        isCurrentTier: totalSa > 0 && totalSa <= 6,
      ),
      TierRow(
        tierRange: '7 – 9 akt',
        ratePerAkt: 150000,
        multiplier: 1.5,
        unitsInTier: b2,
        subtotalProgressive: b2 * 150000.0,
        isCurrentTier: totalSa >= 7 && totalSa <= 9,
      ),
      TierRow(
        tierRange: '10 – 13 akt',
        ratePerAkt: 175000,
        multiplier: 2.0,
        unitsInTier: b3,
        subtotalProgressive: b3 * 175000.0,
        isCurrentTier: totalSa >= 10 && totalSa <= 13,
      ),
      TierRow(
        tierRange: '14 – 29 akt',
        ratePerAkt: 200000,
        multiplier: 4.0,
        unitsInTier: b4,
        subtotalProgressive: b4 * 200000.0,
        isCurrentTier: totalSa >= 14 && totalSa <= 29,
      ),
      TierRow(
        tierRange: '30 – 39 akt',
        ratePerAkt: 225000,
        multiplier: 4.25,
        unitsInTier: b5,
        subtotalProgressive: b5 * 225000.0,
        isCurrentTier: totalSa >= 30 && totalSa <= 39,
      ),
      TierRow(
        tierRange: '40 – 49 akt',
        ratePerAkt: 250000,
        multiplier: 4.5,
        unitsInTier: b6,
        subtotalProgressive: b6 * 250000.0,
        isCurrentTier: totalSa >= 40 && totalSa <= 49,
      ),
      TierRow(
        tierRange: '≥ 50 akt',
        ratePerAkt: 275000,
        multiplier: 4.65,
        unitsInTier: b7,
        subtotalProgressive: b7 * 275000.0,
        isCurrentTier: totalSa >= 50,
      ),
    ];

    return CalculationResult(
      position: position,
      city: city,
      basicFee: basicFee,
      totalSa: totalSa,
      pmBase: pmBase,
      multRate: multRate,
      multBonus: multBonus,
      progInc: progInc,
      specialInc: specialInc,
      tierRows: tierRows,
      monthlySubtotal: monthlySubtotal,
      grandTotal: grandTotal,
    );
  }

  /// Backward-compatible calculate method yang tetap mengembalikan Map
  static Map<String, dynamic> calculate({
    PositionType position = PositionType.elite,
    String city = defaultCity,
    required int f0,
    required int f50,
    required int f100,
    required int f125,
    required int f200,
    required int fwa,
    required int p35,
    required int p6,
  }) {
    final result = calculateDetailed(
      position: position,
      city: city,
      f0: f0,
      f50: f50,
      f100: f100,
      f125: f125,
      f200: f200,
      fwa: fwa,
      p35: p35,
      p6: p6,
    );

    return {
      'position': result.position.label,
      'city': result.city,
      'basicFee': result.basicFee,
      'totalSa': result.totalSa,
      'pmBase': result.pmBase,
      'multRate': result.multRate,
      'multBonus': result.multBonus,
      'progInc': result.progInc,
      'specialInc': result.specialInc,
      'monthlySubtotal': result.monthlySubtotal,
      'grandTotal': result.grandTotal,
      'tierRows': result.tierRows,
    };
  }
}
