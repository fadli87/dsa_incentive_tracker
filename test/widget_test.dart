import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_incentive_tracker/main.dart';
import 'package:dsa_incentive_tracker/data/models/sa_record.dart';
import 'package:dsa_incentive_tracker/data/models/user_profile.dart';
import 'package:dsa_incentive_tracker/ui/screens/user_info_screen.dart';

void main() {
  testWidgets('App renders SplashScreen, Identity, and Navigates properly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi Splash Screen dan Copyright D'Azhars Studio
    expect(find.text('DSA XL SATU HANDBOOK'), findsOneWidget);
    expect(find.text("Copyright D'Azhars Studio"), findsOneWidget);
    expect(find.text('XL SATU CILACAP · TSC PIPIN'), findsOneWidget);

    // Transisi setelah splash timer (2600ms) + fade page route (600ms)
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pumpAndSettle();

    // Verifikasi Tab 1: Dashboard XLSMART
    expect(find.text('XLSMART'), findsOneWidget);
    expect(find.text('My Attendance'), findsOneWidget);
    expect(find.text('LEADS'), findsOneWidget);
    expect(find.text('My Sales'), findsOneWidget);

    // Tap on 'Kalkulator' tab
    await tester.tap(find.text('Kalkulator'));
    await tester.pumpAndSettle();
    expect(find.text('KALKULATOR INCENTIVE'), findsOneWidget);
    expect(find.text('WILAYAH'), findsOneWidget);
    expect(find.text('KAB. CILACAP'), findsOneWidget);

    // Tap on 'Paket Jualan' tab
    await tester.tap(find.text('Paket Jualan'));
    await tester.pumpAndSettle();
    expect(find.text('KATALOG PAKET JUALAN'), findsOneWidget);
    expect(find.text('1. Internet Only'), findsOneWidget);
    expect(find.text('2. FMC Kuota HP'), findsOneWidget);
    expect(find.text('Tactical FTTH 20 Mbps'), findsOneWidget);

    // Tap on 'Data SA' tab
    await tester.tap(find.text('Data SA'));
    await tester.pumpAndSettle();
    expect(find.text('DATA PELANGGAN (SA)'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);

    // Tap on 'Insentif' tab
    await tester.tap(find.text('Insentif'));
    await tester.pumpAndSettle();
    expect(find.text('Histori Pencapaian'), findsOneWidget);

    // Tap on 'Panduan' tab
    await tester.tap(find.text('Panduan'));
    await tester.pumpAndSettle();
    expect(find.text('PANDUAN & SKEMA INSENTIF'), findsOneWidget);

    // Verifikasi Tab AE dan SPV
    expect(find.text('Skema AE (Sales)'), findsOneWidget);
    expect(find.text('Skema SPV (Supervisor)'), findsOneWidget);

    // Tap on 'Skema SPV (Supervisor)' tab
    await tester.tap(find.text('Skema SPV (Supervisor)'));
    await tester.pumpAndSettle();
    expect(find.text('PANDUAN LENGKAP SKEMA SPV'), findsOneWidget);
    expect(find.text('1. Basic Fee Supervisor (Tetap Bulanan)'), findsOneWidget);
  });

  testWidgets('UserInfoScreen renders and allows input of Name and Sales Code',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: UserInfoScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('INFO PENGGUNA'), findsOneWidget);
    expect(find.text('DATA IDENTITAS SALES'), findsOneWidget);
    expect(find.text('Nama Lengkap Sales'), findsOneWidget);
    expect(find.text('Sales Code (Kode Sales)'), findsOneWidget);
    expect(find.text('Simpan Info Pengguna'), findsOneWidget);

    // Input data
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama Lengkap Sales'), 'Ahmad Sales');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Sales Code (Kode Sales)'), 'DSA777');
    await tester.pump();

    expect(find.text('Ahmad Sales'), findsAtLeastNWidgets(1));
    expect(find.text('CODE: DSA777'), findsOneWidget);
  });

  test('SaRecord model correctly excludes KTP', () {
    final record = SaRecord(
      idPelanggan: 'CIL-001',
      nama: 'Budi Santoso',
      alamat: 'Jl. Merdeka No. 10',
      paket: 'FTTH Reguler',
      tanggalPasang: '2026-09-23',
    );

    final map = record.toMap();
    expect(map.containsKey('no_ktp'), isFalse);
    expect(map['nama'], 'Budi Santoso');

    final parsed = SaRecord.fromMap(map);
    expect(parsed.nama, 'Budi Santoso');
    expect(parsed.idPelanggan, 'CIL-001');
  });

  test('UserProfile model handles branch and tsc defaults', () {
    const profile = UserProfile(
      name: 'Rudi',
      salesCode: 'DSA123',
    );
    expect(profile.branch, 'XL SATU CILACAP');
    expect(profile.tsc, 'TSC PIPIN');
    expect(profile.isConfigured, isTrue);
  });

  test('SaRecord handles phone numbers and map coordinates correctly', () {
    final record = SaRecord(
      idPelanggan: 'CIL-777',
      nama: 'Siti Rahma',
      noHpUtama: '081234567890',
      noHpAlternatif: '085711223344',
      alamat: 'Jl. Ahmad Yani No. 5 Cilacap',
      paket: 'FTTH Reguler',
      tanggalPasang: '2026-09-23',
      latitude: -7.7188,
      longitude: 109.0156,
    );

    expect(record.hasLocation, isTrue);
    expect(record.noHpUtama, '081234567890');
    expect(record.noHpAlternatif, '085711223344');

    final map = record.toMap();
    expect(map['no_hp_utama'], '081234567890');
    expect(map['no_hp_alternatif'], '085711223344');
    expect(map['latitude'], -7.7188);
    expect(map['longitude'], 109.0156);

    final restored = SaRecord.fromMap(map);
    expect(restored.nama, 'Siti Rahma');
    expect(restored.noHpUtama, '081234567890');
    expect(restored.noHpAlternatif, '085711223344');
    expect(restored.latitude, -7.7188);
    expect(restored.longitude, 109.0156);
    expect(restored.hasLocation, isTrue);
  });
}
