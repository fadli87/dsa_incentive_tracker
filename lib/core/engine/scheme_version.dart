import '../../data/models/incentive_record.dart' show tryParsePeriodMonth;

/// Versi skema insentif DTD/DSA. Setiap versi berlaku untuk bulan performance
/// tertentu, sehingga riwayat lama tidak ikut berubah angkanya saat skema baru
/// dirilis.
enum SchemeVersion {
  sept2026,
  nov2026;

  /// Skema terbaru yang dikenal aplikasi (default kalkulator).
  static const SchemeVersion latest = SchemeVersion.nov2026;

  /// Skema untuk bulan performance [periodMonth] (`yyyy-MM-01`).
  /// Kosong/tidak dikenal memakai [latest].
  static SchemeVersion forPeriodMonth(String? periodMonth) {
    if (periodMonth == null || periodMonth.length < 7) return latest;
    return periodMonth.compareTo('2026-11') >= 0 ? nov2026 : sept2026;
  }

  /// Pakai [periodMonth] bila ada; bila tidak, parse teks [periode].
  static SchemeVersion forRecord({String? periodMonth, String? periode}) {
    final month = periodMonth ??
        (periode == null ? null : tryParsePeriodMonth(periode));
    return forPeriodMonth(month);
  }

  bool get isNov2026 => this == SchemeVersion.nov2026;

  /// Rate progresif per SA untuk AE OJT: tier 1-2, 3-4, 5-6, 7-9, >=10.
  List<double> get ojtTierRates => isNov2026
      ? const [60000.0, 90000.0, 150000.0, 180000.0, 200000.0]
      : const [80000.0, 100000.0, 130000.0, 150000.0, 200000.0];

  /// Batas bawah harga paket FTTH untuk bucket 100rb dan 125rb.
  int get ftth100Threshold => isNov2026 ? 290000 : 300000;
  int get ftth125Threshold => isNov2026 ? 390000 : 400000;

  /// Graduation Bonus SPV akselerasi Pro ke Elite (800rb). Dihapus mulai Nov 2026.
  bool get spvProToEliteAccelPaid => !isNov2026;

  /// Label singkat (ribuan rupiah) untuk UI.
  String get ftth50Range => isNov2026 ? '229–289' : '229–299';
  String get ftth100Range => isNov2026 ? '290–389' : '300–399';
  String get ftth125Range => '${ftth125Threshold ~/ 1000}–599';

  /// Label lengkap untuk tabel panduan.
  String get ftth50Full =>
      isNov2026 ? 'Rp 229.000 – Rp 289.999' : 'Rp 229.000 – Rp 299.999';
  String get ftth100Full =>
      isNov2026 ? 'Rp 290.000 – Rp 389.999' : 'Rp 300.000 – Rp 399.999';
  String get ftth125Full =>
      isNov2026 ? 'Rp 390.000 – Rp 599.999' : 'Rp 400.000 – Rp 599.999';
}
