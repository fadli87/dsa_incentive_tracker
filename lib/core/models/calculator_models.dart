import 'package:flutter/material.dart';

enum PositionType {
  ojt('OJT', 'On Job Training', Icons.school),
  pro('Pro', 'Professional', Icons.star),
  elite('Elite', 'Elite Agent', Icons.diamond),
  spv('SPV', 'Supervisor', Icons.military_tech);

  final String label;
  final String subtitle;
  final IconData icon;

  const PositionType(this.label, this.subtitle, this.icon);
}

class TierRow {
  final String tierRange;
  final double ratePerAkt;
  final double multiplier;
  final int unitsInTier;
  final double subtotalProgressive;
  final double multiplierBonus;
  final bool isCurrentTier;

  const TierRow({
    required this.tierRange,
    required this.ratePerAkt,
    required this.multiplier,
    required this.unitsInTier,
    required this.subtotalProgressive,
    this.multiplierBonus = 0.0,
    this.isCurrentTier = false,
  });
}

class DsaSurvivalDetail {
  final int m3Base;
  final int m3Surv;
  final double m3Rate;
  final bool m3GatePassed;
  final double m3Total;

  final int m5Base;
  final int m5Surv;
  final double m5Rate;
  final bool m5GatePassed;
  final double m5Total;

  final double totalSurvivalBonus;

  const DsaSurvivalDetail({
    required this.m3Base,
    required this.m3Surv,
    required this.m3Rate,
    required this.m3GatePassed,
    required this.m3Total,
    required this.m5Base,
    required this.m5Surv,
    required this.m5Rate,
    required this.m5GatePassed,
    required this.m5Total,
    required this.totalSurvivalBonus,
  });

  static const empty = DsaSurvivalDetail(
    m3Base: 0,
    m3Surv: 0,
    m3Rate: 0.0,
    m3GatePassed: false,
    m3Total: 0.0,
    m5Base: 0,
    m5Surv: 0,
    m5Rate: 0.0,
    m5GatePassed: false,
    m5Total: 0.0,
    totalSurvivalBonus: 0.0,
  );
}

class DsaQuarterlyDetail {
  final int quarterlySa;
  final double m3SurvivalRate;
  final bool isGatePassed;
  final double baseBonus;
  final int incrementalSa;
  final double incrementalBonus;
  final double totalQuarterlyBonus;

  const DsaQuarterlyDetail({
    required this.quarterlySa,
    required this.m3SurvivalRate,
    required this.isGatePassed,
    required this.baseBonus,
    required this.incrementalSa,
    required this.incrementalBonus,
    required this.totalQuarterlyBonus,
  });

  static const empty = DsaQuarterlyDetail(
    quarterlySa: 0,
    m3SurvivalRate: 0.0,
    isGatePassed: false,
    baseBonus: 0.0,
    incrementalSa: 0,
    incrementalBonus: 0.0,
    totalQuarterlyBonus: 0.0,
  );
}

class DsaNetAddDetail {
  final int baselineActiveSubs;
  final int currentActiveSubs;
  final int incrementalSa;
  final double ratePerSa;
  final double totalNetAddBonus;

  const DsaNetAddDetail({
    required this.baselineActiveSubs,
    required this.currentActiveSubs,
    required this.incrementalSa,
    required this.ratePerSa,
    required this.totalNetAddBonus,
  });

  static const empty = DsaNetAddDetail(
    baselineActiveSubs: 0,
    currentActiveSubs: 0,
    incrementalSa: 0,
    ratePerSa: 0.0,
    totalNetAddBonus: 0.0,
  );
}

class CalculationResult {
  final PositionType position;
  final String city;
  final double basicFee;
  final int totalSa;
  final double pmBase;
  final double multRate;
  final double multBonus;
  final double progInc;
  final double specialInc;
  final double lumpSumBonus;
  final List<TierRow> tierRows;
  final double monthlySubtotal;
  final double grandTotal;

  // Komponen Tambahan (Survival Rate, Quarterly & Net Add)
  final DsaSurvivalDetail survivalDetail;
  final DsaQuarterlyDetail quarterlyDetail;
  final DsaNetAddDetail netAddDetail;

  const CalculationResult({
    required this.position,
    required this.city,
    required this.basicFee,
    required this.totalSa,
    required this.pmBase,
    required this.multRate,
    required this.multBonus,
    required this.progInc,
    required this.specialInc,
    this.lumpSumBonus = 0.0,
    required this.tierRows,
    required this.monthlySubtotal,
    required this.grandTotal,
    this.survivalDetail = DsaSurvivalDetail.empty,
    this.quarterlyDetail = DsaQuarterlyDetail.empty,
    this.netAddDetail = DsaNetAddDetail.empty,
  });

  double get totalComprehensive =>
      grandTotal +
      survivalDetail.totalSurvivalBonus +
      quarterlyDetail.totalQuarterlyBonus +
      netAddDetail.totalNetAddBonus;

  Map<String, dynamic> toLegacyMap() {
    return {
      'position': position.label,
      'city': city,
      'basicFee': basicFee,
      'totalSa': totalSa,
      'pmBase': pmBase,
      'multRate': multRate,
      'multBonus': multBonus,
      'progInc': progInc,
      'specialInc': specialInc,
      'lumpSumBonus': lumpSumBonus,
      'monthlySubtotal': monthlySubtotal,
      'grandTotal': grandTotal,
      'survivalBonus': survivalDetail.totalSurvivalBonus,
      'quarterlyBonus': quarterlyDetail.totalQuarterlyBonus,
      'netAddBonus': netAddDetail.totalNetAddBonus,
      'totalComprehensive': totalComprehensive,
    };
  }
}

class SpvProductMixDetail {
  final int qtyRegular;
  final double rateRegular;
  final double subtotalRegular;
  final int qtyPxgy;
  final double ratePxgy;
  final double subtotalPxgy;
  final double totalProductMix;

  const SpvProductMixDetail({
    required this.qtyRegular,
    required this.rateRegular,
    required this.subtotalRegular,
    required this.qtyPxgy,
    required this.ratePxgy,
    required this.subtotalPxgy,
    required this.totalProductMix,
  });
}

class SpvParticipationDetail {
  final int agentEarnAf;
  final int totalActiveAgents;
  final double participationRate;
  final double multiplier;
  final double participationBonus;

  const SpvParticipationDetail({
    required this.agentEarnAf,
    required this.totalActiveAgents,
    required this.participationRate,
    required this.multiplier,
    required this.participationBonus,
  });
}

class SpvKpiBonusDetail {
  final int mobSpv;
  final int totalActiveAgents;
  final int ojtCount;
  final double ojtRatio;
  final double kpiMultiplier;
  final SpvProductMixDetail productMix;
  final SpvParticipationDetail participation;
  final double totalKpiBonus;

  const SpvKpiBonusDetail({
    required this.mobSpv,
    required this.totalActiveAgents,
    required this.ojtCount,
    required this.ojtRatio,
    required this.kpiMultiplier,
    required this.productMix,
    required this.participation,
    required this.totalKpiBonus,
  });
}

class SpvSurvivalDetail {
  final int saBaseline;
  final int saSurviving;
  final double survivalRate;
  final double gateRequired;
  final bool isGatePassed;
  final double ratePerSubs;
  final double amountSubs;
  final double lumpSumBonus;
  final double totalBonus;

  const SpvSurvivalDetail({
    required this.saBaseline,
    required this.saSurviving,
    required this.survivalRate,
    required this.gateRequired,
    required this.isGatePassed,
    required this.ratePerSubs,
    required this.amountSubs,
    required this.lumpSumBonus,
    required this.totalBonus,
  });
}

class SpvGraduationDetail {
  final int ojtToProNormal;
  final int ojtToProAccel;
  final int proToEliteNormal;
  final int proToEliteAccel;
  final double totalBonus;

  const SpvGraduationDetail({
    required this.ojtToProNormal,
    required this.ojtToProAccel,
    required this.proToEliteNormal,
    required this.proToEliteAccel,
    required this.totalBonus,
  });
}

class SpvMonthlyPerformanceDetail {
  final int totalTeamSa;
  final double bonusAmount;
  final String tierDescription;

  const SpvMonthlyPerformanceDetail({
    required this.totalTeamSa,
    required this.bonusAmount,
    required this.tierDescription,
  });
}

class SpvQuarterlyDetail {
  final int quarterlyTeamSa;
  final double m3SurvivalRate;
  final bool isGatePassed;
  final double baseBonus;
  final int incrementalSa;
  final double incrementalBonus;
  final double totalQuarterlyBonus;

  const SpvQuarterlyDetail({
    required this.quarterlyTeamSa,
    required this.m3SurvivalRate,
    required this.isGatePassed,
    required this.baseBonus,
    required this.incrementalSa,
    required this.incrementalBonus,
    required this.totalQuarterlyBonus,
  });

  static const empty = SpvQuarterlyDetail(
    quarterlyTeamSa: 0,
    m3SurvivalRate: 0.0,
    isGatePassed: false,
    baseBonus: 0.0,
    incrementalSa: 0,
    incrementalBonus: 0.0,
    totalQuarterlyBonus: 0.0,
  );
}

class SpvCalculationResult {
  final String city;
  final double basicFee;
  final int totalTeamSa;
  final SpvKpiBonusDetail kpiBonus;
  final SpvSurvivalDetail m3Survival;
  final SpvSurvivalDetail m5Survival;
  final double totalSurvivalIncentive;
  final SpvGraduationDetail graduation;
  final SpvMonthlyPerformanceDetail monthlyPerformance;
  final SpvQuarterlyDetail quarterlyDetail;
  final double totalIncentive; // Total Poin 1 + 2 + 3 + 4 + 5
  final double grandTotal; // Basic Fee + Total Incentive

  const SpvCalculationResult({
    required this.city,
    required this.basicFee,
    required this.totalTeamSa,
    required this.kpiBonus,
    required this.m3Survival,
    required this.m5Survival,
    required this.totalSurvivalIncentive,
    required this.graduation,
    required this.monthlyPerformance,
    this.quarterlyDetail = SpvQuarterlyDetail.empty,
    required this.totalIncentive,
    required this.grandTotal,
  });
}

