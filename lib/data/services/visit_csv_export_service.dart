import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../models/visit_activity.dart';

/// Service ekspor CSV per kategori untuk di-import ke layer Google My Maps
class VisitCsvExportService {
  static const List<String> headers = [
    'Customer ID',
    'Nama',
    'Latitude',
    'Longitude',
    'Kategori',
    'Status',
    'Alamat',
  ];

  /// Membentuk konten CSV untuk daftar visit tertentu.
  /// Baris tanpa koordinat (`!v.hasLocation`) otomatis dilewati karena Google My Maps
  /// membutuhkan titik Latitude & Longitude.
  static String buildCsvContent(List<VisitActivity> visits) {
    final validVisits = visits.where((v) => v.hasLocation).toList();
    final rows = <List<dynamic>>[
      headers,
      ...validVisits.map(
        (v) => [
          v.customerId,
          v.customerName,
          v.latitude!.toStringAsFixed(6),
          v.longitude!.toStringAsFixed(6),
          v.category.displayLabel,
          v.status.displayLabel,
          v.address,
        ],
      ),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Menghasilkan map `VisitCategory -> String (CSV)` untuk setiap kategori
  /// yang memiliki minimal 1 target berkoordinat.
  static Map<VisitCategory, String> buildCsvPerCategory(
    List<VisitActivity> allVisits,
  ) {
    final result = <VisitCategory, String>{};
    for (final category in VisitCategory.values) {
      final catVisits = allVisits
          .where((v) => v.category == category && v.hasLocation)
          .toList();
      if (catVisits.isEmpty) continue;
      result[category] = buildCsvContent(catVisits);
    }
    return result;
  }

  /// Membagikan satu file CSV per kategori menggunakan `SharePlus`.
  /// Mengembalikan jumlah file kategori yang berhasil diekspor (0 bila tidak ada baris berkoordinat).
  static Future<int> shareCategoryCsvFiles({
    required List<VisitActivity> visits,
    required String dateStr,
    SharePlus? sharePlusInstance,
  }) async {
    final csvByCat = buildCsvPerCategory(visits);
    if (csvByCat.isEmpty) {
      return 0;
    }

    final files = <XFile>[];
    final fileNames = <String>[];

    csvByCat.forEach((cat, csvContent) {
      final fileName = 'visit_${cat.toDbString()}_$dateStr.csv';
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      files.add(
        XFile.fromData(
          bytes,
          mimeType: 'text/csv',
          name: fileName,
        ),
      );
      fileNames.add(fileName);
    });

    final sharePlus = sharePlusInstance ?? SharePlus.instance;
    await sharePlus.share(
      ShareParams(
        files: files,
        fileNameOverrides: fileNames,
        subject: 'Ekspor Visit My Maps ($dateStr)',
        text:
            'Ekspor CSV Aktivitas Visit ($dateStr) per kategori untuk Google My Maps.',
      ),
    );

    return files.length;
  }
}

