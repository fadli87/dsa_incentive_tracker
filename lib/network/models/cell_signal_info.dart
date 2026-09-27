import 'dart:math' as math;

// Models for cellular signal info.
// Ported from G-Net Track clone (l:/dev_app/network-monitor) — battle-tested on
// Xiaomi Mi A1 (PixelExperience 12) & Infinix Hot 12i (stock ROM).

/// Info satu SIM slot.
class SimSlotInfo {
  final int subscriptionId;
  final int simSlotIndex;
  final String carrierName;
  final String displayName;
  final String? iccId;
  final bool isActive;

  const SimSlotInfo({
    required this.subscriptionId,
    required this.simSlotIndex,
    this.carrierName = '',
    this.displayName = '',
    this.iccId,
    this.isActive = false,
  });

  factory SimSlotInfo.fromMap(Map<dynamic, dynamic> map) {
    return SimSlotInfo(
      subscriptionId: (map['subscriptionId'] as num?)?.toInt() ?? -1,
      simSlotIndex: (map['simSlotIndex'] as num?)?.toInt() ?? -1,
      carrierName: map['carrierName'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      iccId: map['iccId'] as String?,
      isActive: map['isActive'] as bool? ?? false,
    );
  }

  String get operatorTitle {
    if (carrierName.isNotEmpty && displayName.isNotEmpty && carrierName != displayName) {
      return '$carrierName ($displayName)';
    }
    return carrierName.isNotEmpty ? carrierName : displayName;
  }
}

/// Kualitas sinyal seluler berdasarkan RSRP/dBm.
enum SignalQuality {
  excellent, // >= -85 dBm
  good,      // >= -98 dBm
  fair,      // >= -110 dBm
  poor,      // < -110 dBm
  unknown,
}

extension SignalQualityExt on SignalQuality {
  String get label {
    switch (this) {
      case SignalQuality.excellent: return 'Excellent';
      case SignalQuality.good:      return 'Good';
      case SignalQuality.fair:      return 'Fair';
      case SignalQuality.poor:      return 'Poor';
      case SignalQuality.unknown:   return 'N/A';
    }
  }

  /// Hex color string untuk UI
  int get colorValue {
    switch (this) {
      case SignalQuality.excellent: return 0xFF4CAF50; // Green
      case SignalQuality.good:      return 0xFF8BC34A; // Light green
      case SignalQuality.fair:      return 0xFFFF9800; // Orange
      case SignalQuality.poor:      return 0xFFF44336; // Red
      case SignalQuality.unknown:   return 0xFF9E9E9E; // Grey
    }
  }
}

/// Data satu cell (bisa serving cell atau neighboring cell).
class CellData {
  final String cellType; // LTE, NR, WCDMA, GSM, UNKNOWN
  final bool isRegistered;
  final String connectionStatus; // PRIMARY, SECONDARY, NONE, UNKNOWN

  // Identifiers
  final int? cellId;
  final int? pci;
  final int? tac;
  final int? lac;
  final int? arfcn;
  final String? band;
  final int? bandwidth; // in MHz (e.g. 10, 15, 20)
  final String? mcc;
  final String? mnc;

  // Signal Metrics (LTE/5G)
  final int? rsrp;
  final int? rsrq;
  final int? sinr;
  final int? cqi;
  final int? timingAdvance;

  // Generic / GSM / WCDMA
  final int? rssi;
  final int? dbm;
  final int? level;

  // 5G NR Specific
  final int? ssRsrp;
  final int? ssRsrq;
  final int? ssSinr;
  final int? csiRsrp;
  final int? csiRsrq;
  final int? csiSinr;

  const CellData({
    this.cellType = 'UNKNOWN',
    this.isRegistered = false,
    this.connectionStatus = 'UNKNOWN',
    this.cellId,
    this.pci,
    this.tac,
    this.lac,
    this.arfcn,
    this.band,
    this.bandwidth,
    this.mcc,
    this.mnc,
    this.rsrp,
    this.rsrq,
    this.sinr,
    this.cqi,
    this.timingAdvance,
    this.rssi,
    this.dbm,
    this.level,
    this.ssRsrp,
    this.ssRsrq,
    this.ssSinr,
    this.csiRsrp,
    this.csiRsrq,
    this.csiSinr,
  });

  factory CellData.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const CellData();

    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final parsedRsrp = toInt(map['rsrp']) ?? toInt(map['ssRsrp']) ?? toInt(map['csiRsrp']);
    final parsedRsrq = toInt(map['rsrq']) ?? toInt(map['ssRsrq']) ?? toInt(map['csiRsrq']);
    final parsedSinr = toInt(map['sinr']) ?? toInt(map['ssSinr']) ?? toInt(map['csiSinr']);

    return CellData(
      cellType: (map['cellType'] as String?)?.toUpperCase() ?? 'UNKNOWN',
      isRegistered: map['isRegistered'] as bool? ?? false,
      connectionStatus: map['connectionStatus'] as String? ?? 'UNKNOWN',
      cellId: toInt(map['cellId']),
      pci: toInt(map['pci']),
      tac: toInt(map['tac']),
      lac: toInt(map['lac']),
      arfcn: toInt(map['arfcn']),
      band: map['band'] as String?,
      bandwidth: toInt(map['bandwidth']),
      mcc: map['mcc']?.toString(),
      mnc: map['mnc']?.toString(),
      rsrp: parsedRsrp,
      rsrq: parsedRsrq,
      sinr: parsedSinr,
      cqi: toInt(map['cqi']),
      timingAdvance: toInt(map['timingAdvance']),
      rssi: toInt(map['rssi']),
      dbm: toInt(map['dbm']),
      level: toInt(map['level']),
      ssRsrp: toInt(map['ssRsrp']),
      ssRsrq: toInt(map['ssRsrq']),
      ssSinr: toInt(map['ssSinr']),
      csiRsrp: toInt(map['csiRsrp']),
      csiRsrq: toInt(map['csiRsrq']),
      csiSinr: toInt(map['csiSinr']),
    );
  }

  // ---- Display helpers (graceful fallback: "N/A") ----
  String get networkType   => cellType;
  String get cellIdDisplay => cellId != null ? cellId.toString() : 'N/A';
  String get pciDisplay    => pci != null ? pci.toString() : 'N/A';
  String get tacDisplay    => tac != null ? tac.toString() : (lac != null ? lac.toString() : 'N/A');
  String get lacDisplay    => lac != null ? lac.toString() : 'N/A';
  String get arfcnDisplay  => arfcn != null ? arfcn.toString() : 'N/A';
  String get bandDisplay   => band ?? (arfcn != null ? 'ARFCN $arfcn' : 'N/A');

  /// Di 4G LTE, 28-bit Cell Identity (ECI) terdiri dari eNodeB ID (20 bit) dan CID/Sector (8 bit).
  int? get eNodeBId => (cellId != null && cellId! > 0) ? (cellId! >> 8) : null;
  int? get cid => (cellId != null && cellId! > 0) ? (cellId! & 0xFF) : null;
  String get eNodeBIdDisplay => eNodeBId != null ? eNodeBId.toString() : 'N/A';
  String get cidDisplay => cid != null ? cid.toString() : 'N/A';
  String get eNodeBCidDisplay => (eNodeBId != null && cid != null) ? '$eNodeBId-$cid' : cellIdDisplay;

  /// Estimasi jarak fisik BTS (dalam meter).
  /// Prioritas 1: Timing Advance (TA) dari hardware modem jika tersedia (78.12m LTE, 554m GSM).
  /// Prioritas 2: 3GPP Path Loss RF Propagation Model berbasis RSRP & Frekuensi Carrier jika TA null/idle.
  int? get distanceMeters {
    if (timingAdvance != null && timingAdvance! >= 0) {
      final multiplier = cellType == 'GSM' ? 554.0 : 78.12;
      return (timingAdvance! * multiplier).round();
    }
    return estimatedPathLossDistanceMeters;
  }

  /// Estimasi jarak menggunakan model propagasi 3GPP Path Loss (Cost231/Hata).
  int? get estimatedPathLossDistanceMeters {
    final signal = rsrp ?? ssRsrp ?? primarySignalDbm;
    if (signal == null || signal >= 0) return null;

    final freqMhz = fDlMhz ?? (arfcn != null && arfcn! > 0 ? 1800.0 : 1800.0);
    // Standar eNodeB Reference Signal Tx EPRE = +15 dBm
    const double txPowerDbm = 15.0;
    final double pathLoss = txPowerDbm - signal;

    // Log-distance Path Loss Model dengan eksponen lingkungan urban/suburban n = 3.2
    // PL = 20*log10(f) + 10*n*log10(d) - 27.55
    const double n = 3.2;
    final double freqTerm = 20.0 * (math.log(freqMhz) / math.ln10);
    final double exponent = (pathLoss - freqTerm + 27.55) / (10.0 * n);
    final double dist = math.pow(10.0, exponent).toDouble();

    // Batasi dalam rentang seluler realistis: 20 meter s/d 25.000 meter (25 km)
    return dist.clamp(20.0, 25000.0).round();
  }

  /// Teks jarak BTS untuk kartu HUD & analisis (contoh: ~78 m atau ~1.4 km)
  String get distanceDisplay {
    final m = distanceMeters;
    if (m == null) return 'N/A';
    if (m >= 1000) {
      return '~${(m / 1000).toStringAsFixed(1)} km';
    }
    return '~$m m';
  }

  /// Jarak via Timing Advance spesifik jika ada (atau fallback ke distanceDisplay)
  int? get timingAdvanceDistanceMeters => distanceMeters;
  String get timingAdvanceDistanceDisplay => distanceDisplay;

  /// Estimasi TA ekuivalen jika hardware TA null
  int? get estimatedTa {
    if (timingAdvance != null && timingAdvance! >= 0) return timingAdvance;
    final m = estimatedPathLossDistanceMeters;
    if (m == null) return null;
    final multiplier = cellType == 'GSM' ? 554.0 : 78.12;
    return (m / multiplier).round();
  }

  /// Kalkulasi frekuensi 3GPP EARFCN
  EarfcnInfo? get earfcnInfo => arfcn != null ? EarfcnCalculator.calculate(arfcn!) : null;
  double? get fDlMhz => earfcnInfo?.fDl;
  double? get fUlMhz => earfcnInfo?.fUl;
  String get fDlDisplay => fDlMhz != null ? '${fDlMhz!.toStringAsFixed(1)} MHz' : 'N/A';
  String get fUlDisplay => fUlMhz != null ? '${fUlMhz!.toStringAsFixed(1)} MHz' : 'N/A';
  String get bandShortCode => earfcnInfo?.bandCode ?? (band != null ? band! : 'N/A');
  String get bandwidthDisplay => bandwidth != null ? '$bandwidth MHz' : (earfcnInfo?.defaultBandwidth != null ? '${earfcnInfo!.defaultBandwidth} MHz' : 'N/A');

  String get plmnDisplay {
    if (mcc != null && mnc != null) return '$mcc-$mnc';
    return 'N/A';
  }

  String get rsrpDisplay {
    final val = rsrp ?? ssRsrp ?? csiRsrp;
    return val != null ? '$val dBm' : 'N/A';
  }

  String get rsrqDisplay {
    final val = rsrq ?? ssRsrq ?? csiRsrq;
    return val != null ? '$val dB' : 'N/A';
  }

  String get sinrDisplay {
    final val = sinr ?? ssSinr ?? csiSinr;
    return val != null ? '$val dB' : 'N/A';
  }

  String get rssiDisplay {
    if (rssi != null) return '$rssi dBm';
    if (dbm != null) return '$dbm dBm';
    return 'N/A';
  }

  String get cqiDisplay => cqi != null ? cqi.toString() : '-';
  String get timingAdvanceDisplay {
    if (timingAdvance != null && timingAdvance! >= 0) {
      return timingAdvance.toString();
    }
    if (estimatedTa != null) {
      return '~$estimatedTa';
    }
    return '-';
  }

  /// Primary signal metric untuk ranking/warna.
  int? get primarySignalDbm => rsrp ?? ssRsrp ?? csiRsrp ?? dbm ?? rssi;

  SignalQuality get signalQuality {
    final s = primarySignalDbm;
    if (s == null) return SignalQuality.unknown;
    if (s >= -85)  return SignalQuality.excellent;
    if (s >= -98)  return SignalQuality.good;
    if (s >= -110) return SignalQuality.fair;
    return SignalQuality.poor;
  }
}

/// Snapshot lengkap info jaringan seluler satu subscription.
class TelephonySnapshot {
  final int? subscriptionId;
  final String networkType;
  final String? simOperator;
  final String? simOperatorName;
  final String? networkOperator;
  final String? networkOperatorName;
  final CellData? servingCell;
  final List<CellData> neighborCells;
  final DateTime timestamp;

  const TelephonySnapshot({
    this.subscriptionId,
    this.networkType = 'UNKNOWN',
    this.simOperator,
    this.simOperatorName,
    this.networkOperator,
    this.networkOperatorName,
    this.servingCell,
    this.neighborCells = const [],
    required this.timestamp,
  });

  factory TelephonySnapshot.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return TelephonySnapshot(timestamp: DateTime.now());

    final servingRaw = map['servingCell'] as Map<dynamic, dynamic>?;
    final serving = servingRaw != null ? CellData.fromMap(servingRaw) : null;

    final neighborListRaw = map['neighborCells'] as List<dynamic>? ?? [];
    final neighbors = neighborListRaw
        .map((e) => CellData.fromMap(e as Map<dynamic, dynamic>?))
        .toList();

    return TelephonySnapshot(
      subscriptionId: (map['subscriptionId'] as num?)?.toInt(),
      networkType: map['networkType'] as String? ?? 'UNKNOWN',
      simOperator: map['simOperator'] as String?,
      simOperatorName: map['simOperatorName'] as String?,
      networkOperator: map['networkOperator'] as String?,
      networkOperatorName: map['networkOperatorName'] as String?,
      servingCell: serving,
      neighborCells: neighbors,
      timestamp: DateTime.now(),
    );
  }

  String get operatorDisplayName {
    if (networkOperatorName != null && networkOperatorName!.isNotEmpty) return networkOperatorName!;
    if (simOperatorName != null && simOperatorName!.isNotEmpty) return simOperatorName!;
    if (networkOperator != null && networkOperator!.isNotEmpty) return networkOperator!;
    return 'N/A';
  }
}

// =============================================================================
// 3GPP EARFCN CALCULATOR (LTE Band, Downlink & Uplink Frequency Resolution)
// Sesuai standar 3GPP TS 36.101
// =============================================================================

class EarfcnInfo {
  final int earfcn;
  final int bandNumber;
  final String bandCode;       // e.g. "L1", "L3", "L8", "L40"
  final String bandName;       // e.g. "2100 MHz FDD"
  final double fDl;            // Frequency Downlink (MHz)
  final double fUl;            // Frequency Uplink (MHz)
  final String duplexMode;     // "FDD" or "TDD"
  final int defaultBandwidth;  // Typical default MHz (e.g. 10, 15, 20)

  const EarfcnInfo({
    required this.earfcn,
    required this.bandNumber,
    required this.bandCode,
    required this.bandName,
    required this.fDl,
    required this.fUl,
    required this.duplexMode,
    this.defaultBandwidth = 10,
  });
}

class EarfcnCalculator {
  static EarfcnInfo? calculate(int n) {
    if (n < 0) return null;

    // Band 1: 0 .. 599 (FDD 2100 MHz) -> DL: 2110 + 0.1*(N-0), UL: 1920 + 0.1*(N-0)
    if (n <= 599) {
      final offset = (n - 0) * 0.1;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 1,
        bandCode: 'L1',
        bandName: '2100 MHz FDD',
        fDl: 2110.0 + offset,
        fUl: 1920.0 + offset,
        duplexMode: 'FDD',
        defaultBandwidth: 15,
      );
    }
    // Band 2: 600 .. 1199 (FDD 1900 PCS)
    if (n <= 1199) {
      final offset = (n - 600) * 0.1;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 2,
        bandCode: 'L2',
        bandName: '1900 MHz PCS',
        fDl: 1930.0 + offset,
        fUl: 1850.0 + offset,
        duplexMode: 'FDD',
        defaultBandwidth: 10,
      );
    }
    // Band 3: 1200 .. 1949 (FDD 1800+ DCS)
    if (n <= 1949) {
      final offset = (n - 1200) * 0.1;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 3,
        bandCode: 'L3',
        bandName: '1800 MHz DCS',
        fDl: 1805.0 + offset,
        fUl: 1710.0 + offset,
        duplexMode: 'FDD',
        defaultBandwidth: 20,
      );
    }
    // Band 4: 1950 .. 2399 (FDD 1700/2100 AWS-1)
    if (n <= 2399) {
      final offset = (n - 1950) * 0.1;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 4,
        bandCode: 'L4',
        bandName: '1700/2100 AWS',
        fDl: 2110.0 + offset,
        fUl: 1710.0 + offset,
        duplexMode: 'FDD',
        defaultBandwidth: 20,
      );
    }
    // Band 5: 2400 .. 2649 (FDD 850 CLR)
    if (n <= 2649) {
      final offset = (n - 2400) * 0.1;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 5,
        bandCode: 'L5',
        bandName: '850 MHz CLR',
        fDl: 869.0 + offset,
        fUl: 824.0 + offset,
        duplexMode: 'FDD',
        defaultBandwidth: 10,
      );
    }
    // Band 7: 2750 .. 3449 (FDD 2600 IMT-E)
    if (n >= 2750 && n <= 3449) {
      final offset = (n - 2750) * 0.1;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 7,
        bandCode: 'L7',
        bandName: '2600 MHz IMT',
        fDl: 2620.0 + offset,
        fUl: 2500.0 + offset,
        duplexMode: 'FDD',
        defaultBandwidth: 20,
      );
    }
    // Band 8: 3450 .. 3799 (FDD 900 GSM)
    if (n >= 3450 && n <= 3799) {
      final offset = (n - 3450) * 0.1;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 8,
        bandCode: 'L8',
        bandName: '900 MHz GSM',
        fDl: 925.0 + offset,
        fUl: 880.0 + offset,
        duplexMode: 'FDD',
        defaultBandwidth: 10,
      );
    }
    // Band 20: 6450 .. 6599 (FDD 800 DD)
    if (n >= 6450 && n <= 6599) {
      final offset = (n - 6450) * 0.1;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 20,
        bandCode: 'L20',
        bandName: '800 MHz DD',
        fDl: 791.0 + offset,
        fUl: 832.0 + offset,
        duplexMode: 'FDD',
        defaultBandwidth: 10,
      );
    }
    // Band 28: 9210 .. 9659 (FDD 700 APT)
    if (n >= 9210 && n <= 9659) {
      final offset = (n - 9210) * 0.1;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 28,
        bandCode: 'L28',
        bandName: '700 MHz APT',
        fDl: 758.0 + offset,
        fUl: 703.0 + offset,
        duplexMode: 'FDD',
        defaultBandwidth: 10,
      );
    }
    // Band 38: 37750 .. 38249 (TDD 2600)
    if (n >= 37750 && n <= 38249) {
      final offset = (n - 37750) * 0.1;
      final f = 2570.0 + offset;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 38,
        bandCode: 'L38',
        bandName: '2600 MHz TDD',
        fDl: f,
        fUl: f,
        duplexMode: 'TDD',
        defaultBandwidth: 20,
      );
    }
    // Band 40: 38650 .. 39649 (TDD 2300 - Smartfren & Telkomsel B40)
    if (n >= 38650 && n <= 39649) {
      final offset = (n - 38650) * 0.1;
      final f = 2300.0 + offset;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 40,
        bandCode: 'L40',
        bandName: '2300 MHz TDD',
        fDl: f,
        fUl: f,
        duplexMode: 'TDD',
        defaultBandwidth: 20,
      );
    }
    // Band 41: 39650 .. 41589 (TDD 2500 BRS/EBS)
    if (n >= 39650 && n <= 41589) {
      final offset = (n - 39650) * 0.1;
      final f = 2496.0 + offset;
      return EarfcnInfo(
        earfcn: n,
        bandNumber: 41,
        bandCode: 'L41',
        bandName: '2500 MHz TDD',
        fDl: f,
        fUl: f,
        duplexMode: 'TDD',
        defaultBandwidth: 20,
      );
    }

    return null;
  }
}

// =============================================================================
// AURA SMART RF ANALYZER — Evaluasi Otomatis & Diagnosa Cerdas
// =============================================================================

class RfAnalysisReport {
  final int overallScore;             // 0 - 100
  final String scoreGrade;            // A, B, C, D
  final String coverageRating;        // Sempurna, Baik, Cukup, Cell Edge
  final String coverageExplanation;
  final String interferenceRating;    // Sangat Bersih, Normal, Terinterferensi
  final String interferenceExplanation;
  final String modulationCapability;  // 256-QAM, 64-QAM, 16-QAM, QPSK
  final String distanceEstimate;      // e.g. "~78m - 156m dari BTS"
  final String verdictSummary;        // Narasi diagnosa otomatis ramah pengguna
  final List<String> practicalAdvice; // Tindakan yang disarankan
  final String? bestNeighborComparison; // Perbandingan sel tetangga

  const RfAnalysisReport({
    required this.overallScore,
    required this.scoreGrade,
    required this.coverageRating,
    required this.coverageExplanation,
    required this.interferenceRating,
    required this.interferenceExplanation,
    required this.modulationCapability,
    required this.distanceEstimate,
    required this.verdictSummary,
    required this.practicalAdvice,
    this.bestNeighborComparison,
  });
}

class RfAnalyzer {
  static RfAnalysisReport evaluate(TelephonySnapshot snapshot) {
    final cell = snapshot.servingCell;
    if (cell == null) {
      return const RfAnalysisReport(
        overallScore: 0,
        scoreGrade: 'N/A',
        coverageRating: 'Tidak Terhubung',
        coverageExplanation: 'Tidak ada serving cell aktif yang terdeteksi.',
        interferenceRating: 'N/A',
        interferenceExplanation: 'Menunggu sambungan sinyal seluler...',
        modulationCapability: 'N/A',
        distanceEstimate: 'N/A',
        verdictSummary: 'Perangkat belum terhubung ke jaringan seluler atau izin lokasi belum diberikan.',
        practicalAdvice: ['Pastikan mode pesawat dinonaktifkan', 'Aktifkan izin lokasi (Fine Location)'],
      );
    }

    final rsrp = cell.primarySignalDbm;
    final sinr = cell.sinr;
    final rsrq = cell.rsrq;
    final cqi = cell.cqi;

    // 1. Scoring Komprehensif (40% RSRP, 35% SINR, 15% RSRQ, 10% CQI)
    double score = 0;

    // RSRP Score (40 pts)
    if (rsrp != null) {
      if (rsrp >= -85) {
        score += 40;
      } else if (rsrp >= -95) {
        score += 32;
      } else if (rsrp >= -105) {
        score += 22;
      } else if (rsrp >= -115) {
        score += 12;
      } else {
        score += 5;
      }
    } else {
      score += 20;
    }

    // SINR Score (35 pts)
    if (sinr != null) {
      if (sinr >= 15) {
        score += 35;
      } else if (sinr >= 10) {
        score += 28;
      } else if (sinr >= 5) {
        score += 20;
      } else if (sinr >= 0) {
        score += 10;
      } else {
        score += 2;
      }
    } else {
      score += 18;
    }

    // RSRQ Score (15 pts)
    if (rsrq != null) {
      if (rsrq >= -9) {
        score += 15;
      } else if (rsrq >= -12) {
        score += 11;
      } else if (rsrq >= -15) {
        score += 7;
      } else {
        score += 3;
      }
    } else {
      score += 8;
    }

    // CQI Score (10 pts)
    if (cqi != null && cqi > 0) {
      if (cqi >= 12) {
        score += 10;
      } else if (cqi >= 8) {
        score += 7;
      } else if (cqi >= 4) {
        score += 4;
      } else {
        score += 2;
      }
    } else {
      score += 5;
    }

    final finalScore = score.round().clamp(0, 100);
    final String grade;
    if (finalScore >= 85) {
      grade = 'A (Sangat Baik)';
    } else if (finalScore >= 70) {
      grade = 'B (Baik & Stabil)';
    } else if (finalScore >= 50) {
      grade = 'C (Cukup / Moderat)';
    } else {
      grade = 'D (Kritis / Lemah)';
    }

    // 2. Coverage Evaluation
    final String covRating;
    final String covExpl;
    if (rsrp != null) {
      if (rsrp >= -85) {
        covRating = 'Optimal (Near Site)';
        covExpl = 'Kekuatan sinyal sangat prima ($rsrp dBm). Posisi dekat dengan menara eNodeB.';
      } else if (rsrp >= -98) {
        covRating = 'Kuat & Stabil';
        covExpl = 'Cakupan sinyal baik ($rsrp dBm). Ideal untuk streaming HD dan unduhan cepat.';
      } else if (rsrp > -110) {
        covRating = 'Cukup (Mid-Cell / Indoor)';
        covExpl = 'Sinyal dalam batas moderat ($rsrp dBm), umum terjadi di dalam ruangan berpenghalang.';
      } else {
        covRating = 'Cell Edge (Sinyal Lemah)';
        covExpl = 'Berada di pinggir jangkauan cell ($rsrp dBm). Redaman tinggi akibat jarak atau gedung tebal.';
      }
    } else {
      covRating = 'Tidak Diketahui';
      covExpl = 'Metrik RSRP tidak terbaca dari modem perangkat.';
    }

    // 3. Interference Evaluation
    final String infRating;
    final String infExpl;
    if (sinr != null) {
      if (sinr >= 13) {
        infRating = 'Sangat Bersih (Noise Rendah)';
        infExpl = 'Saluran radio sangat murni (SINR $sinr dB), modulasi data dapat bekerja pada kecepatan puncak.';
      } else if (sinr >= 8) {
        infRating = 'Bersih & Stabil';
        infExpl = 'Interferensi minimal (SINR $sinr dB), kinerja koneksi internet stabil.';
      } else if (sinr >= 2) {
        infRating = 'Moderat (Ada Noise)';
        infExpl = 'Terdeteksi derau sedang (SINR $sinr dB), kecepatan data mungkin berfluktuasi.';
      } else {
        infRating = 'Tinggi (Pilot Pollution)';
        infExpl = 'Interferensi frekuensi tinggi (SINR $sinr dB), sel tetangga mengganggu serving cell.';
      }
    } else {
      infRating = 'Standar';
      infExpl = 'Nilai SINR tidak dilaporkan oleh chipset.';
    }

    // 4. Modulation Tier
    final String modTier;
    if (cqi != null && cqi >= 12 || (sinr != null && sinr >= 15)) {
      modTier = '256-QAM (Throughput Puncak)';
    } else if (cqi != null && cqi >= 8 || (sinr != null && sinr >= 9)) {
      modTier = '64-QAM (Throughput Tinggi)';
    } else if (cqi != null && cqi >= 5 || (sinr != null && sinr >= 3)) {
      modTier = '16-QAM (Throughput Sedang)';
    } else {
      modTier = 'QPSK (Mode Ketahanan Tinggi)';
    }

    // 5. Distance
    final String distEst;
    if (cell.timingAdvance != null && cell.timingAdvance! >= 0) {
      distEst = '${cell.distanceDisplay} dari BTS (Akurat via TA: ${cell.timingAdvance})';
    } else if (cell.distanceMeters != null) {
      distEst = '${cell.distanceDisplay} dari BTS (Estimasi Model Path Loss)';
    } else {
      distEst = 'Tidak tersedia (Sinyal/TA N/A)';
    }

    // 6. Neighbor Handover Comparison
    String? neighborNote;
    if (snapshot.neighborCells.isNotEmpty) {
      final neighborsWithRsrp = snapshot.neighborCells.where((n) => n.primarySignalDbm != null).toList();
      if (neighborsWithRsrp.isNotEmpty) {
        neighborsWithRsrp.sort((a, b) => b.primarySignalDbm!.compareTo(a.primarySignalDbm!));
        final bestNeighbor = neighborsWithRsrp.first;
        final bestNeighborRsrp = bestNeighbor.primarySignalDbm!;
        if (rsrp != null && bestNeighborRsrp > rsrp + 3) {
          final delta = bestNeighborRsrp - rsrp;
          neighborNote = 'Neighbor PCI ${bestNeighbor.pciDisplay} (${bestNeighbor.rsrpDisplay}) lebih kuat +$delta dB dari serving cell. Potensi handover dalam waktu dekat.';
        } else {
          neighborNote = '${snapshot.neighborCells.length} sel tetangga terdeteksi. Sinyal serving cell masih yang terbaik.';
        }
      }
    }

    // 7. Human-friendly Narrative Verdict
    final StringBuffer verdict = StringBuffer();
    if (rsrp != null && rsrp < -105 && sinr != null && sinr >= 8) {
      verdict.write('Kondisi **Cell Edge Bersih**: Walaupun daya sinyal melemah ($rsrp dBm), saluran radio sangat bersih tanpa interferensi ($sinr dB). Browsing dan panggilan suara tetap jernih dan lancar.');
    } else if (rsrp != null && rsrp >= -95 && sinr != null && sinr < 4) {
      verdict.write('Kondisi **Pilot Pollution**: Sinyal fisik kuat ($rsrp dBm) namun kanal padat/terinterferensi ($sinr dB). Kecepatan transfer data mungkin melambat walau indikator sinyal penuh.');
    } else if (rsrp != null && rsrp >= -95 && sinr != null && sinr >= 8) {
      verdict.write('Kondisi **Sangat Optimal**: Kekuatan sinyal dan kemurnian spektrum berada di tingkat terbaik. Ideal untuk aktivitas berat seperti video call 4K dan trading real-time.');
    } else {
      verdict.write('Kondisi **$covRating**: Tingkat sinyal ${cell.rsrpDisplay} dengan kemurnian saluran ${cell.sinrDisplay}. Performa jaringan normal.');
    }

    // 8. Practical Advice
    final List<String> advice = [];
    if (rsrp != null && rsrp < -105) {
      advice.add('Bila membutuhkan transfer data besar, dekatkan perangkat ke jendela atau area luar ruangan.');
    }
    if (sinr != null && sinr < 4) {
      advice.add('Terdeteksi interferensi antar-sel; beralih ke frekuensi band lain atau WiFi disarankan.');
    }
    if (cell.timingAdvance != null && cell.timingAdvance! > 10) {
      advice.add('Jarak ke BTS cukup jauh (~${cell.timingAdvance! * 78}m). Dekati jendela atau area terbuka.');
    } else if (cell.distanceMeters != null && cell.distanceMeters! > 1200) {
      advice.add('Jarak ke BTS cukup jauh (${cell.distanceDisplay}). Dekati jendela atau lantai atas untuk sinyal lebih optimal.');
    }
    if (advice.isEmpty) {
      advice.add('Kualitas koneksi seluler stabil, tidak memerlukan tindakan khusus.');
    }

    return RfAnalysisReport(
      overallScore: finalScore,
      scoreGrade: grade,
      coverageRating: covRating,
      coverageExplanation: covExpl,
      interferenceRating: infRating,
      interferenceExplanation: infExpl,
      modulationCapability: modTier,
      distanceEstimate: distEst,
      verdictSummary: verdict.toString(),
      practicalAdvice: advice,
      bestNeighborComparison: neighborNote,
    );
  }
}
