/// Centralized Application Constants & Versioning Information.
class AppConstants {
  AppConstants._();

  static const String appName = 'DSA XL Satu Handbook';
  static const String appVersion = 'v1.1.0';
  static const String appVersionDisplay = 'Ver.1.1.0';

  static const List<String> _indonesianMonths = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  /// Label periode aktif otomatis (misal: "Oktober 2026", "November 2026", dst.)
  /// Mengikuti bulan dan tahun berjalan saat aplikasi digunakan.
  static String get effectiveDate {
    final now = DateTime.now();
    return '${_indonesianMonths[now.month - 1]} ${now.year}';
  }

  static const String copyrightStudio = "Copyright D'Azhars Studio";
  static const String copyrightSubtext =
      "Creative Tech Agency · All Rights Reserved • Ver.1.1.0";
  static const String branchOfficial = 'XL SATU CILACAP · TSC PIPIN';
}
