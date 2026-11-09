import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:dsa_incentive_tracker/auth/models/member_status.dart';
import 'package:dsa_incentive_tracker/auth/models/team_member_item.dart';
import 'package:dsa_incentive_tracker/auth/providers/auth_providers.dart';
import 'package:dsa_incentive_tracker/auth/screens/super_admin_panel_screen.dart';
import 'package:dsa_incentive_tracker/data/models/master_customer.dart';
import 'package:dsa_incentive_tracker/data/services/customer_master_import_service.dart';
import 'package:dsa_incentive_tracker/providers/customer_master_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMasterImportGateway implements CustomerMasterImportRemoteGateway {
  final List<List<Map<String, dynamic>>> receivedBatches = [];
  final List<String> receivedBatchIds = [];
  final int? failOnBatchIndex;

  _FakeMasterImportGateway({this.failOnBatchIndex});

  @override
  Future<Map<String, dynamic>> callAdminImportCustomerMaster({
    required String batchId,
    required List<Map<String, dynamic>> rows,
  }) async {
    final currentIndex = receivedBatches.length;
    if (failOnBatchIndex != null && currentIndex == failOnBatchIndex) {
      throw Exception('SocketException: Failed host lookup');
    }
    receivedBatchIds.add(batchId);
    receivedBatches.add(rows);
    return <String, dynamic>{
      'inserted_count': rows.length - 1 >= 0 ? rows.length - 1 : 0,
      'updated_count': rows.isNotEmpty ? 1 : 0,
      'rejected_count': 0,
    };
  }
}

class _FakeTeamMembersNotifier extends TeamMembersNotifier {
  final List<TeamMemberItem> initialMembers;

  _FakeTeamMembersNotifier(this.initialMembers);

  @override
  Future<List<TeamMemberItem>> build() async => initialMembers;

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(initialMembers);
  }
}

Uint8List _buildSampleKmlBytes({
  String cityCode = 'KCLP',
  String customerId = '88001234',
  String installDate = '2026-09-15 10:22:00',
  String address = 'JL. MERDEKA   NO. 10  CILACAP',
  String productName = 'XL SATU   FIBER 50MBPS',
  String lat = '-7.7186',
  String lon = '109.0154',
  String coordTag = '109.0200,-7.7200,0',
  String salesName = '  budi   santoso ',
  String spvName = ' eko   yunianto ',
  String tscName = ' pipien   malviana ',
  bool includeSensitiveColumns = true,
}) {
  final sensitiveRows = includeSensitiveColumns
      ? '''
<tr><td>Serial Number (Wifi/ONT/SIM CARD 1)</td><td>SN-ONT-SECRET-9999</td></tr>
<tr><td>WO ID</td><td>WO-SECRET-111</td></tr>
<tr><td>SO Number</td><td>SO-SECRET-222</td></tr>
<tr><td>Create Time</td><td>2026-09-14 08:00:00</td></tr>
<tr><td>Close Time</td><td>2026-09-15 12:00:00</td></tr>
'''
      : '';

  final xml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <name>$customerId</name>
      <description><![CDATA[
        <table>
          <tr><td>Customer ID</td><td>$customerId</td></tr>
          <tr><td>City Code Homepass</td><td>$cityCode</td></tr>
          <tr><td>Install Date</td><td>$installDate</td></tr>
          <tr><td>Homepass Address</td><td>$address</td></tr>
          <tr><td>Product Name</td><td>$productName</td></tr>
          <tr><td>Latitude</td><td>$lat</td></tr>
          <tr><td>Longitude</td><td>$lon</td></tr>
          <tr><td>Sales Name</td><td>$salesName</td></tr>
          <tr><td>SPV Name</td><td>$spvName</td></tr>
          <tr><td>TSC Name</td><td>$tscName</td></tr>
          $sensitiveRows
        </table>
      ]]></description>
      <Point>
        <coordinates>$coordTag</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>''';
  return Uint8List.fromList(utf8.encode(xml));
}

void main() {
  group('Fase 12 — CustomerMasterImportService (Parser & Whitelist)', () {
    test(
      'Whitelist ketat: kolom sensitif (Serial Number, WO ID, SO Number, Create/Close Time) dibuang dan toJson() hanya berisi 10 kunci',
      () {
        final kmlBytes = _buildSampleKmlBytes(includeSensitiveColumns: true);
        final res = parseKmlBytes(kmlBytes, batchId: '2026-11-10_0900');

        expect(res.records.length, 1);
        final json = res.records.first.toJson();

        expect(
          json.keys.toSet(),
          equals({
            'customer_id',
            'city_code',
            'install_date',
            'address',
            'package_name',
            'latitude',
            'longitude',
            'sales_name',
            'spv_name',
            'tsc_name',
          }),
        );
        final serialized = jsonEncode(json);
        expect(serialized.contains('SN-ONT-SECRET-9999'), isFalse);
        expect(serialized.contains('WO-SECRET-111'), isFalse);
        expect(serialized.contains('SO-SECRET-222'), isFalse);
      },
    );

    test(
      'Filter City Code Homepass == KCLP (case-insensitive), lewati Customer ID kosong, dan normalisasi nama',
      () {
        final xml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <description><![CDATA[
        <table>
          <tr><td>Customer ID</td><td>88001</td></tr>
          <tr><td>City Code Homepass</td><td>kclp</td></tr>
          <tr><td>Install Date</td><td>2026-08-01</td></tr>
          <tr><td>Sales Name</td><td>  andi   wijaya  </td></tr>
          <tr><td>SPV Name</td><td>  eko   yunianto </td></tr>
          <tr><td>TSC Name</td><td> pipien  malviana </td></tr>
        </table>
      ]]></description>
    </Placemark>
    <Placemark>
      <description><![CDATA[
        <table>
          <tr><td>Customer ID</td><td>88002</td></tr>
          <tr><td>City Code Homepass</td><td>PWKT</td></tr>
          <tr><td>Install Date</td><td>2026-08-02</td></tr>
        </table>
      ]]></description>
    </Placemark>
    <Placemark>
      <description><![CDATA[
        <table>
          <tr><td>Customer ID</td><td>   </td></tr>
          <tr><td>City Code Homepass</td><td>KCLP</td></tr>
        </table>
      ]]></description>
    </Placemark>
  </Document>
</kml>''';
        final res = parseKmlBytes(Uint8List.fromList(utf8.encode(xml)));

        expect(res.stats.totalPlacemarks, 3);
        expect(res.stats.cityMatched, 2); // 2 KCLP, tapi 1 kosong Customer ID
        expect(res.stats.validUnique, 1);

        final rec = res.records.single;
        expect(rec.customerId, '88001');
        expect(rec.cityCode, 'KCLP');
        expect(rec.salesName, 'ANDI WIJAYA');
        expect(rec.spvName, 'EKO YUNIANTO');
        expect(rec.tscName, 'PIPIEN MALVIANA');
      },
    );

    test(
      'Install Date tidak valid menjadi null; koordinat 0 atau di luar rentang memakai fallback <coordinates> atau menjadi null',
      () {
        // Kasus 1: lat/lon di tabel = 0, fallback <coordinates> valid
        final kmlFallback = _buildSampleKmlBytes(
          customerId: '88010',
          installDate: '2026-02-30', // tanggal kalender tidak valid
          lat: '0',
          lon: '0',
          coordTag: '109.0555,-7.6543,0',
        );
        final resFallback = parseKmlBytes(kmlFallback);
        final r1 = resFallback.records.single;
        expect(r1.installDate, isNull);
        expect(r1.latitude, closeTo(-7.6543, 0.0001));
        expect(r1.longitude, closeTo(109.0555, 0.0001));
        expect(resFallback.stats.missingInstallDate, 1);
        expect(resFallback.stats.missingCoords, 0);

        // Kasus 2: lat/lon di luar rentang (-95, 200) dan fallback <coordinates> juga 0,0 -> null
        final kmlNullCoord = _buildSampleKmlBytes(
          customerId: '88011',
          installDate: 'bukan-tanggal',
          lat: '-95.0',
          lon: '200.0',
          coordTag: '0,0,0',
        );
        final resNull = parseKmlBytes(kmlNullCoord);
        final r2 = resNull.records.single;
        expect(r2.installDate, isNull);
        expect(r2.latitude, isNull);
        expect(r2.longitude, isNull);
        expect(resNull.stats.missingCoords, 1);
      },
    );

    test(
      'Duplikat Customer ID memilih baris dengan install_date yang lebih baru',
      () {
        final xml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <Placemark>
      <description><![CDATA[
        <table>
          <tr><td>Customer ID</td><td>88999</td></tr>
          <tr><td>City Code Homepass</td><td>KCLP</td></tr>
          <tr><td>Install Date</td><td>2026-05-10</td></tr>
          <tr><td>Homepass Address</td><td>ALAMAT LAMA</td></tr>
        </table>
      ]]></description>
    </Placemark>
    <Placemark>
      <description><![CDATA[
        <table>
          <tr><td>Customer ID</td><td>88999</td></tr>
          <tr><td>City Code Homepass</td><td>KCLP</td></tr>
          <tr><td>Install Date</td><td>2026-09-22</td></tr>
          <tr><td>Homepass Address</td><td>ALAMAT BARU</td></tr>
        </table>
      ]]></description>
    </Placemark>
    <Placemark>
      <description><![CDATA[
        <table>
          <tr><td>Customer ID</td><td>88999</td></tr>
          <tr><td>City Code Homepass</td><td>KCLP</td></tr>
          <tr><td>Install Date</td><td>2026-07-01</td></tr>
          <tr><td>Homepass Address</td><td>ALAMAT TENGAH</td></tr>
        </table>
      ]]></description>
    </Placemark>
  </Document>
</kml>''';
        final res = parseKmlBytes(Uint8List.fromList(utf8.encode(xml)));
        expect(res.stats.validUnique, 1);
        expect(res.stats.duplicates, 2);
        expect(res.records.single.installDate, '2026-09-22');
        expect(res.records.single.address, 'ALAMAT BARU');
      },
    );

    test(
      'Ekstraksi KMZ (ZIP di memori) berhasil membaca doc.kml dan ZIP tanpa .kml melempar pesan ramah',
      () async {
        final kmlBytes = _buildSampleKmlBytes(customerId: '88777');
        final archiveWithKml = Archive()
          ..addFile(ArchiveFile('doc.kml', kmlBytes.length, kmlBytes));
        final kmzBytes = Uint8List.fromList(
          ZipEncoder().encode(archiveWithKml),
        );

        final extracted = extractKmlFromKmz(kmzBytes);
        final parsed = parseKmlBytes(extracted);
        expect(parsed.records.single.customerId, '88777');

        // Uji juga via isolate CustomerMasterImportService.parseFileBytesInIsolate
        final service = CustomerMasterImportService(
          remoteGateway: _FakeMasterImportGateway(),
        );
        final isolateRes = await service.parseFileBytesInIsolate(kmzBytes);
        expect(isolateRes.records.single.customerId, '88777');

        // ZIP tanpa file .kml -> lempar "File KMZ tidak berisi dokumen KML"
        final dummyBytes = utf8.encode('hello world');
        final archiveWithoutKml = Archive()
          ..addFile(ArchiveFile('readme.txt', dummyBytes.length, dummyBytes));
        final badKmz = Uint8List.fromList(
          ZipEncoder().encode(archiveWithoutKml),
        );

        expect(
          () => extractKmlFromKmz(badKmz),
          throwsA(
            isA<MasterImportException>().having(
              (e) => e.message,
              'message',
              contains('File KMZ tidak berisi dokumen KML'),
            ),
          ),
        );
      },
    );
  });

  group('Fase 12 — Pembagian Batch & Penanganan Gagal Tengah Jalan', () {
    List<MasterImportRecord> generateRecords(int count) {
      return List.generate(
        count,
        (i) => MasterImportRecord(
          customerId: '88${i.toString().padLeft(5, '0')}',
          cityCode: 'KCLP',
          installDate: '2026-10-01',
          address: 'ALAMAT $i',
          packageName: 'XL SATU',
          latitude: -7.71,
          longitude: 109.01,
          salesName: 'BUDI SANTOSO',
          spvName: 'EKO YUNIANTO',
          tscName: 'PIPIEN MALVIANA',
        ),
      );
    }

    test('1.203 baris dibagi menjadi 3 panggilan RPC (500, 500, 203)', () async {
      final fakeGateway = _FakeMasterImportGateway();
      final service = CustomerMasterImportService(remoteGateway: fakeGateway);
      final records = generateRecords(1203);
      final progressLog = <(int, int)>[];

      final res = await service.importRecords(
        records,
        '2026-11-10_1000',
        onProgress: (done, total) => progressLog.add((done, total)),
      );

      expect(fakeGateway.receivedBatches.length, 3);
      expect(fakeGateway.receivedBatches[0].length, 500);
      expect(fakeGateway.receivedBatches[1].length, 500);
      expect(fakeGateway.receivedBatches[2].length, 203);
      expect(res.totalSent, 1203);
      expect(
        progressLog,
        equals([(0, 1203), (500, 1203), (1000, 1203), (1203, 1203)]),
      );
    });

    test(
      'Gagal di batch ke-2 langsung berhenti dan melaporkan "500 dari 1203 baris tersimpan"',
      () async {
        final fakeGateway = _FakeMasterImportGateway(failOnBatchIndex: 1);
        final service = CustomerMasterImportService(remoteGateway: fakeGateway);
        final records = generateRecords(1203);

        await expectLater(
          () => service.importRecords(records, '2026-11-10_1005'),
          throwsA(
            isA<MasterImportBatchException>()
                .having((e) => e.savedCount, 'savedCount', 500)
                .having((e) => e.totalCount, 'totalCount', 1203)
                .having(
                  (e) => e.message,
                  'message',
                  contains('500 dari 1203 baris tersimpan'),
                ),
          ),
        );
        // Batch ke-3 tidak pernah dipanggil karena berhenti di batch ke-2 (index 1)
        expect(fakeGateway.receivedBatches.length, 1);
      },
    );
  });

  group('Fase 12 — UI SuperAdminPanelScreen (Visibilitas Role & Dialog Pratinjau)', () {
    Widget buildTestSuperAdminApp({
      required TeamRole role,
      PickMasterImportBytesCallback? pickCallback,
      CustomerMasterImportRemoteGateway? importGateway,
    }) {
      final fakeGateway = importGateway ?? _FakeMasterImportGateway();
      return ProviderScope(
        overrides: [
          currentRoleProvider.overrideWithValue(role),
          canEditRolesProvider.overrideWithValue(role == TeamRole.superadmin),
          teamMembersProvider.overrideWith(
            () => _FakeTeamMembersNotifier([
              TeamMemberItem(
                userId: 'u-1',
                email: 'owner@example.com',
                name: 'Owner Test',
                status: MemberStatus.approved,
                role: role,
              ),
            ]),
          ),
          masterStatusSummaryProvider.overrideWith(
            (ref) async => MasterStatusSummary(
              total: 100,
              lastImport: DateTime.utc(2026, 11, 1),
              lastBatch: '2026-11-01',
              withSales: 98,
            ),
          ),
          unmatchedFormResponsesProvider.overrideWith((ref) async => const []),
          customerMasterImportServiceProvider.overrideWithValue(
            CustomerMasterImportService(
              remoteGateway: fakeGateway,
              useIsolate: false,
            ),
          ),
          if (pickCallback != null)
            pickMasterImportBytesProvider.overrideWithValue(pickCallback),
        ],
        child: const MaterialApp(home: SuperAdminPanelScreen()),
      );
    }

    testWidgets(
      'Tombol "Impor dari KMZ/KML" tersembunyi untuk admin, spv, tsc, member dan hanya muncul untuk superadmin',
      (tester) async {
        for (final nonSuperRole in [
          TeamRole.admin,
          TeamRole.spv,
          TeamRole.tsc,
          TeamRole.member,
        ]) {
          await tester.pumpWidget(buildTestSuperAdminApp(role: nonSuperRole));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('btn_import_customer_master_kmz')),
            findsNothing,
            reason: 'Role ${nonSuperRole.name} tidak boleh melihat tombol impor',
          );
        }

        await tester.pumpWidget(
          buildTestSuperAdminApp(role: TeamRole.superadmin),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('btn_import_customer_master_kmz')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Dialog pratinjau menampilkan angka statistik saja (tanpa bocor alamat/nama) dan menonaktifkan Impor Sekarang bila validUnique == 0',
      (tester) async {
        // Kasus A: validUnique == 0 (kota bukan KCLP)
        final nonKclpKml = _buildSampleKmlBytes(
          cityCode: 'PWKT',
          customerId: '99001',
          address: 'ALAMAT RAHASIA JANGAN TAMPIL',
          salesName: 'NAMA SALES RAHASIA',
        );

        await tester.pumpWidget(
          buildTestSuperAdminApp(
            role: TeamRole.superadmin,
            pickCallback: () async => nonKclpKml,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('btn_import_customer_master_kmz')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('master_import_preview_dialog')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('master_import_empty_warning')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Tidak ada baris KCLP yang valid'),
          findsOneWidget,
        );
        // Pastikan tidak ada data pribadi yang ditampilkan di dialog pratinjau
        expect(find.textContaining('ALAMAT RAHASIA'), findsNothing);
        expect(find.textContaining('NAMA SALES RAHASIA'), findsNothing);

        final confirmBtn = tester.widget<ElevatedButton>(
          find.byKey(const Key('btn_confirm_master_import')),
        );
        expect(confirmBtn.onPressed, isNull);

        await tester.tap(find.byKey(const Key('btn_cancel_master_import')));
        await tester.pumpAndSettle();

        // Kasus B: validUnique == 1 -> tombol Impor Sekarang aktif & mengirim ke RPC
        final validKml = _buildSampleKmlBytes(
          cityCode: 'KCLP',
          customerId: '8800999',
          address: 'JL. RAHASIA PELANGGAN NO 99',
          salesName: 'BUDI RAHASIA',
          tscName: 'PIPIEN MALVIANA',
        );
        final fakeGateway = _FakeMasterImportGateway();

        await tester.pumpWidget(
          buildTestSuperAdminApp(
            role: TeamRole.superadmin,
            pickCallback: () async => validKml,
            importGateway: fakeGateway,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('btn_import_customer_master_kmz')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('master_import_preview_dialog')),
          findsOneWidget,
        );
        // Alamat dan nama sales tidak bocor di layar pratinjau
        expect(find.textContaining('JL. RAHASIA PELANGGAN'), findsNothing);
        expect(find.textContaining('BUDI RAHASIA'), findsNothing);
        // Statistik TSC muncul
        expect(find.textContaining('PIPIEN MALVIANA'), findsOneWidget);

        await tester.tap(find.byKey(const Key('btn_confirm_master_import')));
        await tester.pumpAndSettle();

        expect(fakeGateway.receivedBatches.length, 1);
        expect(
          find.byKey(const Key('master_import_result_dialog')),
          findsOneWidget,
        );
        expect(
          find.text('Baru: 0, Diperbarui: 1, Ditolak: 0'),
          findsOneWidget,
        );
      },
    );
  });

  group('Fase 12 — Validasi Berkas SQL Migrasi & Schema', () {
    test(
      'Migrasi 2026-11-10_phase12_import_customer_master.sql dan schema.sql memuat admin_import_customer_master dengan guard is_superadmin_exact()',
      () {
        final migrationFile = File(
          'supabase/migrations/2026-11-10_phase12_import_customer_master.sql',
        );
        final schemaFile = File('supabase/schema.sql');

        expect(migrationFile.existsSync(), isTrue);
        expect(schemaFile.existsSync(), isTrue);

        final migrationSql = migrationFile.readAsStringSync();
        final schemaSql = schemaFile.readAsStringSync();

        for (final sql in [migrationSql, schemaSql]) {
          expect(sql, contains('public.admin_import_customer_master'));
          expect(sql, contains('public.is_superadmin_exact()'));
          expect(sql, contains('v_total > 500'));
          expect(sql, contains('batch_too_large'));
          expect(sql, contains('on conflict (customer_id) do update set'));
        }
      },
    );
  });
}
