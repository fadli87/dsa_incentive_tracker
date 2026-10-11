import '../catalog/package_catalog.dart';

/// Helper mapping paket katalog ke kode bucket insentif di CalculatorEngine:
/// `f0`, `f50`, `f100`, `f125`, `f200`, `fwa`, `p35`, `p6`.
class IncentiveBucket {
  IncentiveBucket._();

  static const String f0 = 'f0';
  static const String f50 = 'f50';
  static const String f100 = 'f100';
  static const String f125 = 'f125';
  static const String f200 = 'f200';
  static const String fwa = 'fwa';
  static const String p35 = 'p35';
  static const String p6 = 'p6';

  /// Menentukan kode bucket insentif berdasarkan properti paket katalog
  static String? forPackage(CatalogPackage pkg) {
    final typeLower = pkg.type.toLowerCase();
    final titleLower = pkg.title.toLowerCase();

    // 1. Advance Payment / PXGY
    if (pkg.tab == 3 || typeLower.contains('bayar')) {
      if (titleLower.contains('6 bulan') || titleLower.contains('12 bulan')) {
        return p6;
      }
      return p35; // Default advance (3-4 bulan)
    }

    // 2. FWA (Fixed Wireless Access)
    if (typeLower.contains('fwa') || titleLower.contains('fwa')) {
      if (pkg.price >= 219000) {
        return fwa;
      }
      return f0;
    }

    // 3. FTTH, FMC, Combo TV berdasarkan ambang harga bulanan
    final price = pkg.price;
    if (price >= 600000) {
      return f200;
    } else if (price >= 400000) {
      return f125;
    } else if (price >= 300000) {
      return f100;
    } else if (price >= 229000) {
      return f50;
    } else {
      return f0;
    }
  }

  /// Komisi dasar (Product Mix Base) per aktivasi untuk masing-masing bucket
  static double getBaseCommission(String bucketCode) {
    switch (bucketCode) {
      case f50:
      case fwa:
        return 50000.0;
      case f100:
        return 100000.0;
      case f125:
      case p35:
        return 125000.0;
      case f200:
      case p6:
        return 200000.0; // p6 specialInc di engine bernilai 150.000 (pmBase 150k), f200 pmBase 200k
      case f0:
      default:
        return 0.0;
    }
  }

  /// Label tampilan UI untuk kode bucket
  static String getLabel(String bucketCode) {
    switch (bucketCode) {
      case f0:
        return 'FTTH < 229K (Rp 0)';
      case f50:
        return 'FTTH 229K–299K (Rp 50K)';
      case f100:
        return 'FTTH 300K–399K (Rp 100K)';
      case f125:
        return 'FTTH 400K–599K (Rp 125K)';
      case f200:
        return 'FTTH ≥ 600K (Rp 200K)';
      case fwa:
        return 'FWA ≥ 219K (+Rp 50K)';
      case p35:
        return 'PXGY 3–5 Bulan (Rp 125K)';
      case p6:
        return 'PXGY ≥ 6 Bulan (Rp 150K)';
      default:
        return bucketCode.toUpperCase();
    }
  }

  /// Keterangan ringkas bucket untuk penjelasan coach
  static String getBucketName(String bucketCode) {
    switch (bucketCode) {
      case f0:
        return 'FTTH < Rp 229.000';
      case f50:
        return 'FTTH Rp 229.000 – Rp 299.000';
      case f100:
        return 'FTTH Rp 300.000 – Rp 399.000';
      case f125:
        return 'FTTH Rp 400.000 – Rp 599.000';
      case f200:
        return 'FTTH ≥ Rp 600.000';
      case fwa:
        return 'FWA Outdoor/Indoor';
      case p35:
        return 'PXGY 3–5 Bulan';
      case p6:
        return 'PXGY ≥ 6 Bulan';
      default:
        return bucketCode;
    }
  }
}
