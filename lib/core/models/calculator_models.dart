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
  });

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
  final double totalIncentive; // Total Poin 1 + 2 + 3 + 4
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
    required this.totalIncentive,
    required this.grandTotal,
  });
}

