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
  final bool isCurrentTier;

  const TierRow({
    required this.tierRange,
    required this.ratePerAkt,
    required this.multiplier,
    required this.unitsInTier,
    required this.subtotalProgressive,
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
      'monthlySubtotal': monthlySubtotal,
      'grandTotal': grandTotal,
    };
  }
}
