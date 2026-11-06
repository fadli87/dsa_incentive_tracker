import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/core/config/visit_form_config.dart';
import 'package:dsa_incentive_tracker/data/local/database_helper.dart';
import 'package:dsa_incentive_tracker/data/models/visit_activity.dart';
import 'package:dsa_incentive_tracker/providers/visit_provider.dart';
import 'package:dsa_incentive_tracker/ui/screens/visit_daily_screen.dart';
import 'package:dsa_incentive_tracker/ui/screens/visit_form_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DatabaseHelper.instance.clearInMemoryVisits();
  });

  group('VisitFormConfig Prefill URL Unit Tests', () {
    test('URL kosong mengembalikan null', () {
      final url = VisitFormConfig.buildPrefillUrl(
        customerId: '32001234',
        category: VisitCategory.rvai,
        overrideFormUrl: '',
        overrideCustomerEntry: 'entry.111',
        overrideCategoryEntry: 'entry.222',
      );
      expect(url, isNull);
    });

    test('Membentuk URL prefill dengan encoding dan label kategori yang tepat', () {
      const dummyBaseUrl = 'https://docs.google.com/forms/d/e/FAKE_FORM_ID/viewform';
      const custEntry = 'entry.10001';
      const catEntry = 'entry.20002';

      // 1. RVAI -> VISIT RVAI
      final rvaiUrl = VisitFormConfig.buildPrefillUrl(
        customerId: '32009988',
        category: VisitCategory.rvai,
        overrideFormUrl: dummyBaseUrl,
        overrideCustomerEntry: custEntry,
        overrideCategoryEntry: catEntry,
      );
      expect(
        rvaiUrl,
        '$dummyBaseUrl?usp=pp_url&entry.10001=32009988&entry.20002=${Uri.encodeQueryComponent("VISIT RVAI")}',
      );

      // 2. Dismantle -> DISMANTLE
      final dismantleUrl = VisitFormConfig.buildPrefillUrl(
        customerId: '32009989',
        category: VisitCategory.dismantle,
        overrideFormUrl: dummyBaseUrl,
        overrideCustomerEntry: custEntry,
        overrideCategoryEntry: catEntry,
      );
      expect(
        dismantleUrl,
        '$dummyBaseUrl?usp=pp_url&entry.10001=32009989&entry.20002=DISMANTLE',
      );

      // 3. Unpaid -> UNPAID
      final unpaidUrl = VisitFormConfig.buildPrefillUrl(
        customerId: '32009990',
        category: VisitCategory.unpaid,
        overrideFormUrl: dummyBaseUrl,
        overrideCustomerEntry: custEntry,
        overrideCategoryEntry: catEntry,
      );
      expect(
        unpaidUrl,
        '$dummyBaseUrl?usp=pp_url&entry.10001=32009990&entry.20002=UNPAID',
      );
    });
  });

  group('VisitFormScreen & VisitDailyScreen Widget Tests', () {
    testWidgets('Validasi VisitFormScreen: Customer ID kosong, kategori kosong, dan lat/lng di luar rentang', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VisitFormScreen(initialDate: '2026-11-06'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll ke tombol simpan lalu tap tanpa mengisi field
      final saveBtn = find.byKey(const Key('visit_save_btn'));
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Customer ID wajib diisi'), findsOneWidget);
      expect(find.text('Kategori visit wajib dipilih'), findsOneWidget);

      // Isi Customer ID dengan huruf (bukan angka) dan lat/lng di luar rentang
      await tester.enterText(find.byKey(const Key('visit_customer_id_field')), 'ABC-123');
      await tester.enterText(find.byKey(const Key('visit_latitude_field')), '-95.5');
      await tester.enterText(find.byKey(const Key('visit_longitude_field')), '190.2');

      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.text('Customer ID hanya boleh berisi angka'), findsOneWidget);
      expect(find.text('Latitude harus berada di rentang -90 hingga 90'), findsOneWidget);
      expect(find.text('Longitude harus berada di rentang -180 hingga 180'), findsOneWidget);
    });

    testWidgets('VisitDailyScreen memfilter kategori dengan benar dan menonaktifkan tombol Google Form saat URL kosong', (tester) async {
      const testDate = '2026-11-06';
      await DatabaseHelper.instance.insertVisit(
        const VisitActivity(
          clientId: 'c-rvai-1',
          customerId: '11110001',
          customerName: 'Pelanggan RVAI Fiktif',
          category: VisitCategory.rvai,
          plannedDate: testDate,
          updatedAt: '2026-11-06T01:00:00Z',
        ),
      );
      await DatabaseHelper.instance.insertVisit(
        const VisitActivity(
          clientId: 'c-dismantle-1',
          customerId: '22220002',
          customerName: 'Pelanggan Dismantle Fiktif',
          category: VisitCategory.dismantle,
          plannedDate: testDate,
          updatedAt: '2026-11-06T01:05:00Z',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitSelectedDateProvider.overrideWith((ref) => testDate),
          ],
          child: const MaterialApp(
            home: VisitDailyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Awalnya filter Semua menampilkan kedua kartu
      expect(find.textContaining('11110001'), findsOneWidget);
      expect(find.textContaining('22220002'), findsOneWidget);

      // Tap chip filter RVAI -> hanya tampil RVAI
      await tester.tap(find.byKey(const Key('filter_chip_rvai')));
      await tester.pumpAndSettle();

      expect(find.textContaining('11110001'), findsOneWidget);
      expect(find.textContaining('22220002'), findsNothing);

      // Tap kartu RVAI untuk membuka bottom sheet detail
      await tester.tap(find.textContaining('11110001'));
      await tester.pumpAndSettle();

      // Pastikan tombol Isi Google Form tampil tetapi nonaktif (karena VISIT_FORM_URL kosong saat test)
      final formBtnFinder = find.byKey(const Key('visit_open_google_form_btn'));
      expect(formBtnFinder, findsOneWidget);
      final formBtnWidget = tester.widget<ElevatedButton>(formBtnFinder);
      expect(formBtnWidget.onPressed, isNull);
      expect(
        find.textContaining('Link Google Form belum dikonfigurasi'),
        findsOneWidget,
      );
    });
  });
}

