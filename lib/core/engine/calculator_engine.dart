import '../models/calculator_models.dart';

class CalculatorEngine {
  static const String defaultCity = 'KAB. CILACAP';

  static double getBasicFee(PositionType position) {
    switch (position) {
      case PositionType.ojt:
        return 1900000.0;
      case PositionType.pro:
        return 2600000.0;
      case PositionType.elite:
        return 2773184.0;
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

    double progInc = 0.0;
    double multRate = 0.0;
    double multBonus = 0.0;
    double lumpSumBonus = 0.0;
    List<TierRow> tierRows = [];

    if (position == PositionType.ojt) {
      // --- SKEMA KHUSUS AE OJT (Slide 4 & Guiding Principle Poin 6) ---
      // Tiering Progresif SA OJT:
      // 1–2 @ 80k, 3–4 @ 100k, 5–6 @ 130k, 7–9 @ 150k, ≥10 @ 200k
      final int b1 = totalSa.clamp(0, 2);
      final int b2 = (totalSa - 2).clamp(0, 2);
      final int b3 = (totalSa - 4).clamp(0, 2);
      final int b4 = (totalSa - 6).clamp(0, 3);
      final int b5 = (totalSa - 9) > 0 ? (totalSa - 9) : 0;

      progInc = (b1 * 80000.0) +
          (b2 * 100000.0) +
          (b3 * 130000.0) +
          (b4 * 150000.0) +
          (b5 * 200000.0);

      // OJT TIDAK memiliki Multiplier terhadap Product Mix
      multRate = 0.0;
      multBonus = 0.0;

      // Lump Sum Bonus OJT: min 3 SA = 325.000, min 7 SA = 600.000
      if (totalSa >= 7) {
        lumpSumBonus = 600000.0;
      } else if (totalSa >= 3) {
        lumpSumBonus = 325000.0;
      }

      tierRows = [
        TierRow(
          tierRange: '1 – 2 akt',
          ratePerAkt: 80000,
          multiplier: 0,
          unitsInTier: b1,
          subtotalProgressive: b1 * 80000.0,
          isCurrentTier: totalSa > 0 && totalSa <= 2,
        ),
        TierRow(
          tierRange: '3 – 4 akt',
          ratePerAkt: 100000,
          multiplier: 0,
          unitsInTier: b2,
          subtotalProgressive: b2 * 100000.0,
          isCurrentTier: totalSa >= 3 && totalSa <= 4,
        ),
        TierRow(
          tierRange: '5 – 6 akt',
          ratePerAkt: 130000,
          multiplier: 0,
          unitsInTier: b3,
          subtotalProgressive: b3 * 130000.0,
          isCurrentTier: totalSa >= 5 && totalSa <= 6,
        ),
        TierRow(
          tierRange: '7 – 9 akt',
          ratePerAkt: 150000,
          multiplier: 0,
          unitsInTier: b4,
          subtotalProgressive: b4 * 150000.0,
          isCurrentTier: totalSa >= 7 && totalSa <= 9,
        ),
        TierRow(
          tierRange: '≥ 10 akt',
          ratePerAkt: 200000,
          multiplier: 0,
          unitsInTier: b5,
          subtotalProgressive: b5 * 200000.0,
          isCurrentTier: totalSa >= 10,
        ),
      ];
    } else {
      // --- SKEMA AE PRO & AE ELITE (Slide 4 & Guiding Principle Poin 6) ---
      // Tiering Progresif SA:
      // 1–6 @ 80k, 7–9 @ 150k, 10–13 @ 175k, 14–29 @ 200k, 30–39 @ 225k, 40–49 @ 250k, ≥50 @ 275k
      final int b1 = totalSa.clamp(0, 6);
      final int b2 = (totalSa - 6).clamp(0, 3);
      final int b3 = (totalSa - 9).clamp(0, 4);
      final int b4 = (totalSa - 13).clamp(0, 16);
      final int b5 = (totalSa - 29).clamp(0, 10);
      final int b6 = (totalSa - 39).clamp(0, 10);
      final int b7 = (totalSa - 49) > 0 ? (totalSa - 49) : 0;

      final double prog1 = b1 * 80000.0;
      final double prog2 = b2 * 150000.0;
      final double prog3 = b3 * 175000.0;
      final double prog4 = b4 * 200000.0;
      final double prog5 = b5 * 225000.0;
      final double prog6 = b6 * 250000.0;
      final double prog7 = b7 * 275000.0;

      // Multiplier dihitung per tier terhadap subtotal progresif masing-masing tier
      final double multBonus1 = 0.0;
      final double multBonus2 = prog2 * 1.50;
      final double multBonus3 = prog3 * 2.00;
      final double multBonus4 = prog4 * 4.00;
      final double multBonus5 = prog5 * 4.25;
      final double multBonus6 = prog6 * 4.50;
      final double multBonus7 = prog7 * 4.65;

      multBonus = multBonus1 +
          multBonus2 +
          multBonus3 +
          multBonus4 +
          multBonus5 +
          multBonus6 +
          multBonus7;

      // multRate merepresentasikan tier pengali tertinggi yang dicapai
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
      } else {
        multRate = 0.0;
      }

      // REVISI ATURAN:
      // Nilai insentif Progresif SA akan HILANG jika perhitungan multiplier sudah ada (total SA >= 7 / multBonus > 0).
      // Sedangkan jika aktivasi < 7 SA (multiplier belum ada / 0x), Progresif SA tetap diterima (1-6 @ 80k).
      if (multBonus > 0) {
        progInc = 0.0;
      } else {
        progInc = prog1;
      }

      lumpSumBonus = 0.0;

      tierRows = [
        TierRow(
          tierRange: '1 – 6 akt',
          ratePerAkt: 80000,
          multiplier: 0,
          unitsInTier: b1,
          subtotalProgressive: prog1,
          multiplierBonus: multBonus1,
          isCurrentTier: totalSa > 0 && totalSa <= 6,
        ),
        TierRow(
          tierRange: '7 – 9 akt',
          ratePerAkt: 150000,
          multiplier: 1.5,
          unitsInTier: b2,
          subtotalProgressive: prog2,
          multiplierBonus: multBonus2,
          isCurrentTier: totalSa >= 7 && totalSa <= 9,
        ),
        TierRow(
          tierRange: '10 – 13 akt',
          ratePerAkt: 175000,
          multiplier: 2.0,
          unitsInTier: b3,
          subtotalProgressive: prog3,
          multiplierBonus: multBonus3,
          isCurrentTier: totalSa >= 10 && totalSa <= 13,
        ),
        TierRow(
          tierRange: '14 – 29 akt',
          ratePerAkt: 200000,
          multiplier: 4.0,
          unitsInTier: b4,
          subtotalProgressive: prog4,
          multiplierBonus: multBonus4,
          isCurrentTier: totalSa >= 14 && totalSa <= 29,
        ),
        TierRow(
          tierRange: '30 – 39 akt',
          ratePerAkt: 225000,
          multiplier: 4.25,
          unitsInTier: b5,
          subtotalProgressive: prog5,
          multiplierBonus: multBonus5,
          isCurrentTier: totalSa >= 30 && totalSa <= 39,
        ),
        TierRow(
          tierRange: '40 – 49 akt',
          ratePerAkt: 250000,
          multiplier: 4.5,
          unitsInTier: b6,
          subtotalProgressive: prog6,
          multiplierBonus: multBonus6,
          isCurrentTier: totalSa >= 40 && totalSa <= 49,
        ),
        TierRow(
          tierRange: '≥ 50 akt',
          ratePerAkt: 275000,
          multiplier: 4.65,
          unitsInTier: b7,
          subtotalProgressive: prog7,
          multiplierBonus: multBonus7,
          isCurrentTier: totalSa >= 50,
        ),
      ];
    }

    final double basicFee = getBasicFee(position);
    final double monthlySubtotal = basicFee +
        progInc +
        pmBase +
        multBonus +
        specialInc +
        lumpSumBonus;
    final double grandTotal = monthlySubtotal;

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
      lumpSumBonus: lumpSumBonus,
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
      'lumpSumBonus': result.lumpSumBonus,
      'monthlySubtotal': result.monthlySubtotal,
      'grandTotal': result.grandTotal,
      'tierRows': result.tierRows,
    };
  }
}
