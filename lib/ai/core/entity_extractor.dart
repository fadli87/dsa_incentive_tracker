import '../../core/models/calculator_models.dart';

/// Hasil ekstraksi entitas terstruktur dari teks input pengguna
class ExtractedEntities {
  final Map<String, int> productCounts; // {'f0': 0, 'f50': 0, 'f100': 0, 'f125': 0, 'f200': 0, 'fwa': 0, 'p35': 0, 'p6': 0}
  final int? totalSa;
  final PositionType? position;
  final int? speedMbps;
  final int? budgetRupiah;
  final String? district;
  final String? segment; // 'rumah', 'kos', 'warkop', 'umkm', 'kantor'
  final String? objection; // 'mahal', 'sudah_ada_wifi', 'mikir', 'ribet', 'kontrak'
  final String? packageType; // 'ftth', 'fwa', 'fmc', 'pxgy', 'combo'

  const ExtractedEntities({
    this.productCounts = const {},
    this.totalSa,
    this.position,
    this.speedMbps,
    this.budgetRupiah,
    this.district,
    this.segment,
    this.objection,
    this.packageType,
  });

  bool get hasProductCounts => productCounts.values.any((c) => c > 0);

  ExtractedEntities copyWith({
    Map<String, int>? productCounts,
    int? totalSa,
    PositionType? position,
    int? speedMbps,
    int? budgetRupiah,
    String? district,
    String? segment,
    String? objection,
    String? packageType,
  }) {
    return ExtractedEntities(
      productCounts: productCounts ?? this.productCounts,
      totalSa: totalSa ?? this.totalSa,
      position: position ?? this.position,
      speedMbps: speedMbps ?? this.speedMbps,
      budgetRupiah: budgetRupiah ?? this.budgetRupiah,
      district: district ?? this.district,
      segment: segment ?? this.segment,
      objection: objection ?? this.objection,
      packageType: packageType ?? this.packageType,
    );
  }

  /// Gabungkan dengan entitas percakapan sebelumnya jika belum terisi
  ExtractedEntities mergeWithPrevious(ExtractedEntities? prev) {
    if (prev == null) return this;
    return ExtractedEntities(
      productCounts: hasProductCounts ? productCounts : prev.productCounts,
      totalSa: totalSa ?? prev.totalSa,
      position: position ?? prev.position,
      speedMbps: speedMbps ?? prev.speedMbps,
      budgetRupiah: budgetRupiah ?? prev.budgetRupiah,
      district: district ?? prev.district,
      segment: segment ?? prev.segment,
      objection: objection ?? prev.objection,
      packageType: packageType ?? prev.packageType,
    );
  }
}

/// Extractor entitas regex offline deterministik
class EntityExtractor {
  EntityExtractor._();

  static const List<String> _districts = [
    'adjpala', 'adireja', 'bantarsari', 'cilacap selatan', 'cilacap tengah',
    'cilacap utara', 'cimanggu', 'cipari', 'dayeuhluhur', 'gandrungmangu',
    'jeruklegi', 'kampung laut', 'karangpucung', 'kawunganten', 'kedungreja',
    'kesugihan', 'kroya', 'majenang', 'maos', 'nusawungu', 'patimuan',
    'sampang', 'sidareja', 'wanareja',
  ];

  static ExtractedEntities extract(String normalizedQuery, {ExtractedEntities? previous}) {
    final text = ' $normalizedQuery ';

    // 1. Ekstraksi Posisi
    PositionType? position;
    if (RegExp(r'\b(ojt|training|magang)\b').hasMatch(text)) {
      position = PositionType.ojt;
    } else if (RegExp(r'\b(pro)\b').hasMatch(text)) {
      position = PositionType.pro;
    } else if (RegExp(r'\b(elite)\b').hasMatch(text)) {
      position = PositionType.elite;
    } else if (RegExp(r'\b(spv|supervisor)\b').hasMatch(text)) {
      position = PositionType.spv;
    }

    // 2. Ekstraksi Kecepatan (Mbps / Gbps)
    int? speedMbps;
    final gbMatch = RegExp(r'(\d+)\s*(?:gb|giga|gbps)\b').firstMatch(text);
    if (gbMatch != null) {
      speedMbps = int.parse(gbMatch.group(1)!) * 1000;
    } else {
      final mbMatch = RegExp(r'(\d+)\s*(?:mbps|mb|mega)\b').firstMatch(text);
      if (mbMatch != null) {
        speedMbps = int.parse(mbMatch.group(1)!);
      }
    }

    // 3. Ekstraksi Budget Uang (Rupiah)
    int? budgetRupiah;
    final jtMatch = RegExp(r'(\d+(?:\.\d+)?)\s*juta\b').firstMatch(text);
    if (jtMatch != null) {
      final val = double.tryParse(jtMatch.group(1)!);
      if (val != null) budgetRupiah = (val * 1000000).round();
    } else {
      final rbMatch = RegExp(r'(\d+(?:\.\d+)?)\s*ribu\b').firstMatch(text);
      if (rbMatch != null) {
        final val = double.tryParse(rbMatch.group(1)!);
        if (val != null) budgetRupiah = (val * 1000).round();
      } else {
        final rpMatch = RegExp(r'rp\s*(\d{4,9})\b').firstMatch(text);
        if (rpMatch != null) {
          budgetRupiah = int.tryParse(rpMatch.group(1)!);
        }
      }
    }

    // 4. Ekstraksi Wilayah / Kecamatan (Fuzzy match sederhana)
    String? district;
    for (final d in _districts) {
      if (text.contains(d)) {
        district = d;
        break;
      }
    }

    // 5. Ekstraksi Segmen Pelanggan
    String? segment;
    if (RegExp(r'\b(kos|kost|kosan|anak kos)\b').hasMatch(text)) {
      segment = 'kos';
    } else if (RegExp(r'\b(warkop|warung|cafe|kafe)\b').hasMatch(text)) {
      segment = 'warkop';
    } else if (RegExp(r'\b(umkm|toko|usaha|bisnis|kantor mini)\b').hasMatch(text)) {
      segment = 'umkm';
    } else if (RegExp(r'\b(kantor|enterprise|perusahaan)\b').hasMatch(text)) {
      segment = 'kantor';
    } else if (RegExp(r'\b(rumah|keluarga|rumahan|warga)\b').hasMatch(text)) {
      segment = 'rumah';
    }

    // 6. Ekstraksi Keberatan / Objection
    String? objection;
    if (RegExp(r'\b(mahal|kemahalan|mahalan|harga tinggi|anggaran)\b').hasMatch(text)) {
      objection = 'mahal';
    } else if (RegExp(r'\b(sudah ada wifi|ada wifi|punya wifi|pake indihome|pake provider lain|wifi lain)\b').hasMatch(text)) {
      objection = 'sudah_ada_wifi';
    } else if (RegExp(r'\b(mikir|ragu|tanya suami|tanya istri|nanti dulu|belum butuh)\b').hasMatch(text)) {
      objection = 'mikir';
    } else if (RegExp(r'\b(ribet|tarik kabel|bor|rusak dinding|instalasi)\b').hasMatch(text)) {
      objection = 'ribet';
    } else if (RegExp(r'\b(kontrak|pinalti|terikat|12 bulan|lama)\b').hasMatch(text)) {
      objection = 'kontrak';
    }

    // 7. Ekstraksi Tipe Paket
    String? packageType;
    if (RegExp(r'\b(fwa|wireless|router 5g|odu)\b').hasMatch(text)) {
      packageType = 'fwa';
    } else if (RegExp(r'\b(ftth|fiber|kabel optik)\b').hasMatch(text)) {
      packageType = 'ftth';
    } else if (RegExp(r'\b(fmc|kuota hp|bundling)\b').hasMatch(text)) {
      packageType = 'fmc';
    } else if (RegExp(r'\b(pxgy|advance|bayar di muka|pay x)\b').hasMatch(text)) {
      packageType = 'pxgy';
    } else if (RegExp(r'\b(combo|tv|siaran tv)\b').hasMatch(text)) {
      packageType = 'combo';
    }

    // 8. Ekstraksi Rincian Produk & Total SA
    final Map<String, int> productCounts = {
      'f0': 0,
      'f50': 0,
      'f100': 0,
      'f125': 0,
      'f200': 0,
      'fwa': 0,
      'p35': 0,
      'p6': 0,
    };

    // Regex per bucket produk
    final fwaM = RegExp(r'(\d+)\s*(?:fwa)\b').firstMatch(text);
    if (fwaM != null) productCounts['fwa'] = int.parse(fwaM.group(1)!);

    final f0M = RegExp(r'(\d+)\s*(?:f0|ftth\s*20)\b').firstMatch(text);
    if (f0M != null) productCounts['f0'] = int.parse(f0M.group(1)!);

    final f50M = RegExp(r'(\d+)\s*(?:f50|ftth\s*229|ftth\s*250|ftth\s*300|ftth\s*400)\b').firstMatch(text);
    if (f50M != null) productCounts['f50'] = int.parse(f50M.group(1)!);

    final f100M = RegExp(r'(\d+)\s*(?:f100|ftth\s*500)\b').firstMatch(text);
    if (f100M != null) productCounts['f100'] = int.parse(f100M.group(1)!);

    final f125M = RegExp(r'(\d+)\s*(?:f125)\b').firstMatch(text);
    if (f125M != null) productCounts['f125'] = int.parse(f125M.group(1)!);

    final f200M = RegExp(r'(\d+)\s*(?:f200|ftth\s*1\s*gb)\b').firstMatch(text);
    if (f200M != null) productCounts['f200'] = int.parse(f200M.group(1)!);

    final p35M = RegExp(r'(\d+)\s*(?:p35|pxgy\s*3|pxgy\s*4|advance\s*3|advance\s*4)\b').firstMatch(text);
    if (p35M != null) productCounts['p35'] = int.parse(p35M.group(1)!);

    final p6M = RegExp(r'(\d+)\s*(?:p6|pxgy\s*6|advance\s*6)\b').firstMatch(text);
    if (p6M != null) productCounts['p6'] = int.parse(p6M.group(1)!);

    // Total SA umum (misal: "15 sa", "30 sa")
    int? totalSa;
    final saMatch = RegExp(r'(\d+)\s*(?:sa|aktivasi|closing|spk)\b').firstMatch(text);
    if (saMatch != null) {
      totalSa = int.parse(saMatch.group(1)!);
    } else {
      final sumCounts = productCounts.values.reduce((a, b) => a + b);
      if (sumCounts > 0) {
        totalSa = sumCounts;
      }
    }

    final extracted = ExtractedEntities(
      productCounts: productCounts,
      totalSa: totalSa,
      position: position,
      speedMbps: speedMbps,
      budgetRupiah: budgetRupiah,
      district: district,
      segment: segment,
      objection: objection,
      packageType: packageType,
    );

    return previous != null ? extracted.mergeWithPrevious(previous) : extracted;
  }
}
