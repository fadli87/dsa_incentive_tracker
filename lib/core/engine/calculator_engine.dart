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
        return 2773184.0; // Angka pasti Cilacap sesuai acuan
      case PositionType.spv:
        return 4500000.0; // Sesuai acuan skema SPV September 2026
    }
  }

  /// Helper untuk mendapatkan tarif per SA Regular (ARPU < 279k)
  static double getSpvRegularRate(int count) {
    if (count >= 101) return 60000.0;
    if (count >= 61) return 35000.0;
    if (count >= 41) return 25000.0;
    if (count >= 11) return 20000.0;
    return 0.0;
  }

  /// Helper untuk mendapatkan tarif per SA PXGY & High ARPU (>= 279k)
  static double getSpvPxgyRate(int count) {
    if (count >= 101) return 80000.0;
    if (count >= 61) return 40000.0;
    if (count >= 41) return 35000.0;
    if (count >= 11) return 30000.0;
    return 20000.0;
  }

  /// Helper untuk menghitung Participation Bonus Multiplier
  static double getSpvParticipationMultiplier(double rate) {
    if (rate >= 0.805) return 1.25;
    if (rate >= 0.705) return 1.00;
    if (rate >= 0.605) return 0.75;
    if (rate >= 0.505) return 0.60;
    return 0.0;
  }

  /// Helper untuk menghitung KPI Multiplier SPV
  static double getSpvKpiMultiplier({
    required int mobSpv,
    required int activeAgents,
    required double ojtRatio,
  }) {
    if (mobSpv <= 3) {
      return 1.0; // 100% dari Product Mix
    }
    if (activeAgents >= 8) {
      return ojtRatio >= 0.40 ? 1.05 : 1.20;
    } else if (activeAgents == 7) {
      return ojtRatio >= 0.40 ? 0.75 : 1.00;
    } else if (activeAgents == 6) {
      return ojtRatio >= 0.40 ? 0.55 : 0.60;
    } else if (activeAgents == 5) {
      return ojtRatio >= 0.40 ? 0.50 : 0.55;
    }
    return 0.0;
  }

  /// Perhitungan terstruktur dan lengkap untuk skema SPV September 2026
  /// Perhitungan terstruktur dan lengkap untuk skema SPV September 2026
  static SpvCalculationResult calculateSpvDetailed({
    String city = defaultCity,
    required int qtyRegular,
    required int qtyPxgy,
    required int totalActiveAgents,
    required int agentEarnAf,
    required int mobSpv,
    required int ojtCount,
    required int m3Baseline,
    required int m3Surviving,
    required int m5Baseline,
    required int m5Surviving,
    required int ojtToProNormal,
    required int ojtToProAccel,
    required int proToEliteNormal,
    required int proToEliteAccel,
    int quarterlyTeamSa = 0,
    double quarterlyM3SurvivalRate = 0.0,
  }) {
    final double basicFee = getBasicFee(PositionType.spv);
    final int totalTeamSa = qtyRegular + qtyPxgy;

    // 1. Productivity Mix
    final double rateReg = getSpvRegularRate(qtyRegular);
    final double subtotalReg = qtyRegular * rateReg;
    final double ratePx = getSpvPxgyRate(qtyPxgy);
    final double subtotalPx = qtyPxgy * ratePx;
    final double totalProductMix = subtotalReg + subtotalPx;

    final productMixDetail = SpvProductMixDetail(
      qtyRegular: qtyRegular,
      rateRegular: rateReg,
      subtotalRegular: subtotalReg,
      qtyPxgy: qtyPxgy,
      ratePxgy: ratePx,
      subtotalPxgy: subtotalPx,
      totalProductMix: totalProductMix,
    );

    // 2. Participation Bonus
    final double partRate = totalActiveAgents > 0
        ? (agentEarnAf / totalActiveAgents)
        : 0.0;
    final double partMultiplier = (mobSpv <= 3)
        ? 0.0
        : getSpvParticipationMultiplier(partRate);
    final double partBonus = (mobSpv <= 3)
        ? 0.0
        : partMultiplier * totalProductMix;

    final participationDetail = SpvParticipationDetail(
      agentEarnAf: agentEarnAf,
      totalActiveAgents: totalActiveAgents,
      participationRate: partRate,
      multiplier: partMultiplier,
      participationBonus: partBonus,
    );

    // 3. KPI Bonus
    final double ojtRatio = totalActiveAgents > 0
        ? (ojtCount / totalActiveAgents)
        : 0.0;
    final double kpiMultiplier = getSpvKpiMultiplier(
      mobSpv: mobSpv,
      activeAgents: totalActiveAgents,
      ojtRatio: ojtRatio,
    );

    final double totalKpiBonus = (mobSpv <= 3)
        ? (1.0 * totalProductMix)
        : (kpiMultiplier * (totalProductMix + partBonus));

    final kpiBonusDetail = SpvKpiBonusDetail(
      mobSpv: mobSpv,
      totalActiveAgents: totalActiveAgents,
      ojtCount: ojtCount,
      ojtRatio: ojtRatio,
      kpiMultiplier: kpiMultiplier,
      productMix: productMixDetail,
      participation: participationDetail,
      totalKpiBonus: totalKpiBonus,
    );

    // 4. Survival Rate M3 & M5
    final double m3Rate = m3Baseline > 0 ? (m3Surviving / m3Baseline) : 0.0;
    final bool m3Passed = m3Rate >= 0.8999;
    final double m3AmountSubs = m3Passed ? (m3Surviving * 25000.0) : 0.0;
    final double m3LumpSum = m3Passed ? 2000000.0 : 0.0;
    final double m3Total = m3AmountSubs + m3LumpSum;

    final m3Detail = SpvSurvivalDetail(
      saBaseline: m3Baseline,
      saSurviving: m3Surviving,
      survivalRate: m3Rate,
      gateRequired: 0.90,
      isGatePassed: m3Passed,
      ratePerSubs: 25000.0,
      amountSubs: m3AmountSubs,
      lumpSumBonus: m3LumpSum,
      totalBonus: m3Total,
    );

    final double m5Rate = m5Baseline > 0 ? (m5Surviving / m5Baseline) : 0.0;
    final bool m5Passed = m5Rate >= 0.7999;
    final double m5AmountSubs = m5Passed ? (m5Surviving * 25000.0) : 0.0;
    final double m5LumpSum = m5Passed ? 2000000.0 : 0.0;
    final double m5Total = m5AmountSubs + m5LumpSum;

    final m5Detail = SpvSurvivalDetail(
      saBaseline: m5Baseline,
      saSurviving: m5Surviving,
      survivalRate: m5Rate,
      gateRequired: 0.80,
      isGatePassed: m5Passed,
      ratePerSubs: 25000.0,
      amountSubs: m5AmountSubs,
      lumpSumBonus: m5LumpSum,
      totalBonus: m5Total,
    );

    final double totalSurvivalIncentive = m3Total + m5Total;

    // 5. Graduation Bonus
    final double totalGraduation = (ojtToProNormal * 500000.0) +
        (ojtToProAccel * 700000.0) +
        (proToEliteNormal * 600000.0) +
        (proToEliteAccel * 800000.0);

    final graduationDetail = SpvGraduationDetail(
      ojtToProNormal: ojtToProNormal,
      ojtToProAccel: ojtToProAccel,
      proToEliteNormal: proToEliteNormal,
      proToEliteAccel: proToEliteAccel,
      totalBonus: totalGraduation,
    );

    // 6. Monthly Performance Bonus (Lump Sum)
    double monthlyPerfBonus = 0.0;
    String monthlyPerfDesc = '< 160 SA (Belum memenuhi syarat)';
    if (totalTeamSa >= 250) {
      monthlyPerfBonus = 5000000.0;
      monthlyPerfDesc = '>= 250 SA (Lump sum Rp 5.000.000)';
    } else if (totalTeamSa >= 200) {
      monthlyPerfBonus = 3500000.0;
      monthlyPerfDesc = '200 – 249 SA (Lump sum Rp 3.500.000)';
    } else if (totalTeamSa >= 160) {
      monthlyPerfBonus = 2500000.0;
      monthlyPerfDesc = '160 – 199 SA (Lump sum Rp 2.500.000)';
    }

    final monthlyPerfDetail = SpvMonthlyPerformanceDetail(
      totalTeamSa: totalTeamSa,
      bonusAmount: monthlyPerfBonus,
      tierDescription: monthlyPerfDesc,
    );

    // 7. Quarterly Bonus SPV (Poin 5)
    final quarterlyDetail = calculateSpvQuarterly(
      quarterlyTeamSa: quarterlyTeamSa,
      m3SurvivalRate: quarterlyM3SurvivalRate,
    );

    // Total Insentif (Poin 1 + Poin 2 + Poin 3 + Poin 4 + Poin 5)
    final double totalIncentive = totalKpiBonus +
        totalSurvivalIncentive +
        totalGraduation +
        monthlyPerfBonus +
        quarterlyDetail.totalQuarterlyBonus;

    final double grandTotal = basicFee + totalIncentive;

    return SpvCalculationResult(
      city: city,
      basicFee: basicFee,
      totalTeamSa: totalTeamSa,
      kpiBonus: kpiBonusDetail,
      m3Survival: m3Detail,
      m5Survival: m5Detail,
      totalSurvivalIncentive: totalSurvivalIncentive,
      graduation: graduationDetail,
      monthlyPerformance: monthlyPerfDetail,
      quarterlyDetail: quarterlyDetail,
      totalIncentive: totalIncentive,
      grandTotal: grandTotal,
    );
  }

  /// Perhitungan Quarterly Bonus untuk SPV
  static SpvQuarterlyDetail calculateSpvQuarterly({
    required int quarterlyTeamSa,
    required double m3SurvivalRate,
  }) {
    final bool isGatePassed = m3SurvivalRate >= 0.7999;
    double baseBonus = 0.0;
    int incrementalSa = 0;
    double incrementalBonus = 0.0;

    if (quarterlyTeamSa >= 500) {
      baseBonus = 12000000.0;
      incrementalSa = quarterlyTeamSa - 500;
      incrementalBonus = incrementalSa * 30000.0;
    } else if (quarterlyTeamSa >= 450) {
      baseBonus = 12000000.0;
    } else if (quarterlyTeamSa >= 400) {
      baseBonus = 10000000.0;
    } else if (quarterlyTeamSa >= 350) {
      baseBonus = 8000000.0;
    } else if (quarterlyTeamSa >= 300) {
      baseBonus = 6000000.0;
    } else if (quarterlyTeamSa >= 250) {
      baseBonus = 4500000.0;
    } else if (quarterlyTeamSa >= 200) {
      baseBonus = 3000000.0;
    } else if (quarterlyTeamSa >= 150) {
      baseBonus = 2000000.0;
    } else if (quarterlyTeamSa >= 50) {
      baseBonus = 1500000.0;
    }

    final double total = isGatePassed ? (baseBonus + incrementalBonus) : 0.0;

    return SpvQuarterlyDetail(
      quarterlyTeamSa: quarterlyTeamSa,
      m3SurvivalRate: m3SurvivalRate,
      isGatePassed: isGatePassed,
      baseBonus: baseBonus,
      incrementalSa: incrementalSa,
      incrementalBonus: incrementalBonus,
      totalQuarterlyBonus: total,
    );
  }

  /// Perhitungan Survival Rate untuk DSA / AE (M3 & M5)
  static DsaSurvivalDetail calculateDsaSurvival({
    required int m3Base,
    required int m3Surv,
    required int m5Base,
    required int m5Surv,
  }) {
    final double m3Rate = m3Base > 0 ? (m3Surv / m3Base) : 0.0;
    final bool m3GatePassed = m3Rate >= 0.8999;
    final double m3Total = m3GatePassed ? (m3Surv * 100000.0) : 0.0;

    final double m5Rate = m5Base > 0 ? (m5Surv / m5Base) : 0.0;
    final bool m5GatePassed = m5Rate >= 0.7999;
    final double m5Total = m5GatePassed ? (m5Surv * 80000.0) : 0.0;

    return DsaSurvivalDetail(
      m3Base: m3Base,
      m3Surv: m3Surv,
      m3Rate: m3Rate,
      m3GatePassed: m3GatePassed,
      m3Total: m3Total,
      m5Base: m5Base,
      m5Surv: m5Surv,
      m5Rate: m5Rate,
      m5GatePassed: m5GatePassed,
      m5Total: m5Total,
      totalSurvivalBonus: m3Total + m5Total,
    );
  }

  /// Perhitungan Quarterly Bonus untuk DSA / AE (Pro & Elite)
  static DsaQuarterlyDetail calculateDsaQuarterly({
    required PositionType position,
    required int quarterlySa,
    required double m3SurvivalRate,
  }) {
    if (position == PositionType.ojt) {
      return DsaQuarterlyDetail.empty;
    }

    final bool isGatePassed = m3SurvivalRate >= 0.8999;
    double baseBonus = 0.0;
    int incrementalSa = 0;
    double incrementalBonus = 0.0;

    if (quarterlySa >= 60) {
      baseBonus = 20000000.0;
      incrementalSa = quarterlySa - 60;
      incrementalBonus = incrementalSa * 10000.0;
    } else if (quarterlySa >= 45) {
      baseBonus = 15000000.0;
    } else if (quarterlySa >= 30) {
      baseBonus = 2000000.0;
    }

    final double total = isGatePassed ? (baseBonus + incrementalBonus) : 0.0;

    return DsaQuarterlyDetail(
      quarterlySa: quarterlySa,
      m3SurvivalRate: m3SurvivalRate,
      isGatePassed: isGatePassed,
      baseBonus: baseBonus,
      incrementalSa: incrementalSa,
      incrementalBonus: incrementalBonus,
      totalQuarterlyBonus: total,
    );
  }

  /// Perhitungan Net Add Incentive untuk DSA / AE (Pro & Elite)
  static DsaNetAddDetail calculateDsaNetAdd({
    required PositionType position,
    required int baselineActiveSubs,
    required int currentActiveSubs,
  }) {
    if (position == PositionType.ojt) {
      return DsaNetAddDetail.empty;
    }

    final int diff = currentActiveSubs - baselineActiveSubs;
    final int incrementalSa = diff > 0 ? (diff > 10 ? 10 : diff) : 0;
    double ratePerSa = 0.0;

    if (baselineActiveSubs >= 200) {
      ratePerSa = 150000.0;
    } else if (baselineActiveSubs >= 100) {
      ratePerSa = 100000.0;
    } else if (baselineActiveSubs >= 80) {
      ratePerSa = 50000.0;
    }

    final double total = incrementalSa * ratePerSa;

    return DsaNetAddDetail(
      baselineActiveSubs: baselineActiveSubs,
      currentActiveSubs: currentActiveSubs,
      incrementalSa: incrementalSa,
      ratePerSa: ratePerSa,
      totalNetAddBonus: total,
    );
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
    int m3Base = 0,
    int m3Surv = 0,
    int m5Base = 0,
    int m5Surv = 0,
    int quarterlySa = 0,
    double quarterlyM3SurvivalRate = 0.0,
    int baselineActiveSubs = 0,
    int currentActiveSubs = 0,
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

    final survivalDetail = calculateDsaSurvival(
      m3Base: m3Base,
      m3Surv: m3Surv,
      m5Base: m5Base,
      m5Surv: m5Surv,
    );

    final quarterlyDetail = calculateDsaQuarterly(
      position: position,
      quarterlySa: quarterlySa,
      m3SurvivalRate: quarterlyM3SurvivalRate,
    );

    final netAddDetail = calculateDsaNetAdd(
      position: position,
      baselineActiveSubs: baselineActiveSubs,
      currentActiveSubs: currentActiveSubs,
    );

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
      survivalDetail: survivalDetail,
      quarterlyDetail: quarterlyDetail,
      netAddDetail: netAddDetail,
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
