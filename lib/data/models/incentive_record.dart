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
  // --- Input mentah, disimpan supaya bisa direkalkulasi ulang saat edit ---
  final int f0;
  final int f50;
  final int f100;
  final int f125;
  final int f200;
  final int fwa;
  final int p35;
  final int p6;

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
    this.f0 = 0,
    this.f50 = 0,
    this.f100 = 0,
    this.f125 = 0,
    this.f200 = 0,
    this.fwa = 0,
    this.p35 = 0,
    this.p6 = 0,
  }) : monthlySubtotal = monthlySubtotal ?? grandTotal;

  IncentiveRecord copyWith({
    int? id,
    String? periode,
    String? position,
    String? city,
    double? basicFee,
    int? totalSa,
    double? pmBase,
    double? multRate,
    double? multBonus,
    double? progInc,
    double? specialInc,
    double? monthlySubtotal,
    double? grandTotal,
    int? f0,
    int? f50,
    int? f100,
    int? f125,
    int? f200,
    int? fwa,
    int? p35,
    int? p6,
  }) {
    return IncentiveRecord(
      id: id ?? this.id,
      periode: periode ?? this.periode,
      position: position ?? this.position,
      city: city ?? this.city,
      basicFee: basicFee ?? this.basicFee,
      totalSa: totalSa ?? this.totalSa,
      pmBase: pmBase ?? this.pmBase,
      multRate: multRate ?? this.multRate,
      multBonus: multBonus ?? this.multBonus,
      progInc: progInc ?? this.progInc,
      specialInc: specialInc ?? this.specialInc,
      monthlySubtotal: monthlySubtotal ?? this.monthlySubtotal,
      grandTotal: grandTotal ?? this.grandTotal,
      f0: f0 ?? this.f0,
      f50: f50 ?? this.f50,
      f100: f100 ?? this.f100,
      f125: f125 ?? this.f125,
      f200: f200 ?? this.f200,
      fwa: fwa ?? this.fwa,
      p35: p35 ?? this.p35,
      p6: p6 ?? this.p6,
    );
  }

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
      'f0': f0,
      'f50': f50,
      'f100': f100,
      'f125': f125,
      'f200': f200,
      'fwa': fwa,
      'p35': p35,
      'p6': p6,
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
      f0: (map['f0'] as int?) ?? 0,
      f50: (map['f50'] as int?) ?? 0,
      f100: (map['f100'] as int?) ?? 0,
      f125: (map['f125'] as int?) ?? 0,
      f200: (map['f200'] as int?) ?? 0,
      fwa: (map['fwa'] as int?) ?? 0,
      p35: (map['p35'] as int?) ?? 0,
      p6: (map['p6'] as int?) ?? 0,
    );
  }
}
