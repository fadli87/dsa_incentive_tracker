import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/data/models/visit_activity.dart';
import 'package:dsa_incentive_tracker/data/services/visit_csv_export_service.dart';

void main() {
  group('VisitCsvExportService (Fase 7 — Ekspor Google My Maps)', () {
    test('Baris tanpa koordinat dilewati dan hanya baris berkoordinat yang masuk CSV', () {
      final visits = [
        VisitActivity(
          clientId: 'csv-1',
          customerId: '32001001',
          customerName: 'Pelanggan Dengan Koordinat',
          category: VisitCategory.rvai,
          address: 'Jl. Gatot Subroto No. 1',
          latitude: -7.7279,
          longitude: 109.0079,
          plannedDate: '2026-11-06',
          status: VisitStatus.sudahVisit,
          updatedAt: '2026-11-06T08:00:00Z',
        ),
        VisitActivity(
          clientId: 'csv-2',
          customerId: '32001002',
          customerName: 'Pelanggan Tanpa Koordinat',
          category: VisitCategory.rvai,
          address: 'Jl. Tanpa Titik',
          latitude: null,
          longitude: null,
          plannedDate: '2026-11-06',
          status: VisitStatus.belum,
          updatedAt: '2026-11-06T08:00:00Z',
        ),
      ];

      final csv = VisitCsvExportService.buildCsvContent(visits);
      expect(
        csv,
        contains('Customer ID,Nama,Latitude,Longitude,Kategori,Status,Alamat'),
      );
      expect(csv, contains('32001001,Pelanggan Dengan Koordinat,-7.727900,109.007900,RVAI,Sudah Visit,Jl. Gatot Subroto No. 1'));
      expect(csv, isNot(contains('32001002')));
      expect(csv, isNot(contains('Pelanggan Tanpa Koordinat')));
    });

    test('Escape koma dan tanda kutip ganda (RFC-4180) pada Nama dan Alamat', () {
      final visits = [
        VisitActivity(
          clientId: 'csv-escape-1',
          customerId: '32002001',
          customerName: 'Toko "Maju, Jaya"',
          category: VisitCategory.dismantle,
          address: 'Jl. Ahmad Yani No. 5, Blok "B", Cilacap',
          latitude: -7.712345,
          longitude: 109.012345,
          plannedDate: '2026-11-06',
          status: VisitStatus.followUp,
          updatedAt: '2026-11-06T08:00:00Z',
        ),
      ];

      final csv = VisitCsvExportService.buildCsvContent(visits);
      // Tanda kutip ganda di-escape menjadi "" dan field yang mengandung koma dibungkus "..."
      expect(csv, contains('"Toko ""Maju, Jaya"""'));
      expect(csv, contains('"Jl. Ahmad Yani No. 5, Blok ""B"", Cilacap"'));
    });

    test('buildCsvPerCategory memisahkan satu CSV per kategori yang memiliki koordinat', () {
      final visits = [
        VisitActivity(
          clientId: 'cat-1',
          customerId: '32003001',
          customerName: 'Target RVAI',
          category: VisitCategory.rvai,
          latitude: -7.70,
          longitude: 109.00,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T08:00:00Z',
        ),
        VisitActivity(
          clientId: 'cat-2',
          customerId: '32003002',
          customerName: 'Target Unpaid',
          category: VisitCategory.unpaid,
          latitude: -7.71,
          longitude: 109.01,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T08:00:00Z',
        ),
        VisitActivity(
          clientId: 'cat-3',
          customerId: '32003003',
          customerName: 'Target Dismantle Tanpa Koordinat',
          category: VisitCategory.dismantle,
          latitude: null,
          longitude: null,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T08:00:00Z',
        ),
      ];

      final map = VisitCsvExportService.buildCsvPerCategory(visits);
      expect(map.keys, containsAll([VisitCategory.rvai, VisitCategory.unpaid]));
      expect(map.containsKey(VisitCategory.dismantle), isFalse);
      expect(map[VisitCategory.rvai], contains('32003001'));
      expect(map[VisitCategory.unpaid], contains('32003002'));
    });
  });
}
