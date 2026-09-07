class IncentiveRecord {
  final int? id;
  final String periode;
  final String position;
  final String city;
  final double basicFee;
  final int totalSa;
  final double pmBase;
  final double multRate;
  final double multBonus;
  final double progInc;
  final double specialInc;
  final double monthlySubtotal;
  final double grandTotal;

  IncentiveRecord({
    this.id,
    required this.periode,
    this.position = 'Elite',
    this.city = 'KAB. CILACAP',
    this.basicFee = 0.0,
    required this.totalSa,
    required this.pmBase,
    required this.multRate,
    required this.multBonus,
    required this.progInc,
    required this.specialInc,
    double? monthlySubtotal,
    required this.grandTotal,
  }) : monthlySubtotal = monthlySubtotal ?? grandTotal;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'periode': periode,
      'position': position,
      'city': city,
      'basic_fee': basicFee,
      'total_sa': totalSa,
      'pm_base': pmBase,
      'mult_rate': multRate,
      'mult_bonus': multBonus,
      'prog_inc': progInc,
      'special_inc': specialInc,
      'monthly_subtotal': monthlySubtotal,
      'grand_total': grandTotal,
    };
  }

  factory IncentiveRecord.fromMap(Map<String, dynamic> map) {
    final grandTotalVal = (map['grand_total'] as num).toDouble();
    return IncentiveRecord(
      id: map['id'] as int?,
      periode: map['periode'] as String,
      position: (map['position'] as String?) ?? 'Elite',
      city: (map['city'] as String?) ?? 'KAB. CILACAP',
      basicFee: (map['basic_fee'] as num?)?.toDouble() ?? 0.0,
      totalSa: map['total_sa'] as int,
      pmBase: (map['pm_base'] as num).toDouble(),
      multRate: (map['mult_rate'] as num).toDouble(),
      multBonus: (map['mult_bonus'] as num).toDouble(),
      progInc: (map['prog_inc'] as num).toDouble(),
      specialInc: (map['special_inc'] as num).toDouble(),
      monthlySubtotal:
          (map['monthly_subtotal'] as num?)?.toDouble() ?? grandTotalVal,
      grandTotal: grandTotalVal,
    );
  }
}
