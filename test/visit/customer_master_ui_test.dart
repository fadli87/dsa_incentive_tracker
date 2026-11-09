import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dsa_incentive_tracker/core/constants/visit_constants.dart';
import 'package:dsa_incentive_tracker/data/local/database_helper.dart';
import 'package:dsa_incentive_tracker/data/models/master_customer.dart';
import 'package:dsa_incentive_tracker/providers/customer_master_provider.dart';
import 'package:dsa_incentive_tracker/ui/screens/visit_form_screen.dart';

void main() {
  final db = DatabaseHelper.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db.clearInMemoryVisits();
  });

  group('Phase 10D — RVAI Suggestion Logic & Master Customer Form UI Tests', () {
    test(
      'computeRvaiSuggestions: hari ke-6 tidak muncul, hari ke-7 muncul, hari ke-37 tidak muncul, sudah ada visit rvai tidak muncul, tanggal kosong tidak muncul',
      () {
        final today = DateTime(2026, 11, 7);

        final customers = [
          // Hari ke-6 setelah install -> belum jatuh tempo (tidak muncul)
          MasterCustomer(
            customerId: '100006',
            installDate: today.subtract(const Duration(days: 6)),
            address: 'JL. HARI KE 6',
            syncedAt: '2026-11-07T00:00:00Z',
          ),
          // Hari ke-7 setelah install -> tepat jatuh tempo hari ini (muncul)
          MasterCustomer(
            customerId: '100007',
            installDate: today.subtract(const Duration(days: 7)),
            address: 'JL. HARI KE 7',
            syncedAt: '2026-11-07T00:00:00Z',
          ),
          // Hari ke-15 setelah install -> jatuh tempo 8 hari lalu (muncul & urut lebih atas)
          MasterCustomer(
            customerId: '100015',
            installDate: today.subtract(const Duration(days: 15)),
            address: 'JL. HARI KE 15',
            syncedAt: '2026-11-07T00:00:00Z',
          ),
          // Hari ke-37 setelah install -> melewati batas lookback 30 hari (tidak muncul)
          MasterCustomer(
            customerId: '100037',
            installDate: today.subtract(const Duration(days: 37)),
            address: 'JL. HARI KE 37',
            syncedAt: '2026-11-07T00:00:00Z',
          ),
          // Hari ke-10 setelah install tapi sudah ada visit rvai -> tidak muncul
          MasterCustomer(
            customerId: '100010',
            installDate: today.subtract(const Duration(days: 10)),
            address: 'JL. SUDAH RVAI',
            syncedAt: '2026-11-07T00:00:00Z',
          ),
          // Tanggal install kosong -> tidak muncul
          const MasterCustomer(
            customerId: '100000',
            installDate: null,
            address: 'JL. TANPA TANGGAL',
            syncedAt: '2026-11-07T00:00:00Z',
          ),
        ];

        final result = computeRvaiSuggestions(
          masterCustomers: customers,
          existingRvaiCustomerIds: {'100010'},
          today: today,
        );

        expect(result.map((e) => e.customer.customerId).toList(), [
          '100015', // Paling lama jatuh tempo (8 hari lalu) di urutan pertama
          '100007', // Jatuh tempo hari ini (0 hari lalu)
        ]);
        expect(result.first.daysPastDue, 8);
        expect(result.first.dueLabel, 'Jatuh tempo 8 hari lalu');
        expect(result.last.daysPastDue, 0);
        expect(result.last.dueLabel, 'Jatuh tempo hari ini');
      },
    );

    testWidgets(
      'Tombol Pilih dari Pelanggan Saya tersembunyi saat master lokal kosong dan petunjuk tampil',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: VisitFormScreen(initialDate: '2026-11-07'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('visit_pick_master_btn')), findsNothing);
        expect(find.byKey(const Key('visit_master_empty_hint')), findsOneWidget);
      },
    );

    testWidgets(
      'Pilih dari Pelanggan Saya membuka bottom sheet pencarian dan mengisi field form otomatis',
      (tester) async {
        await db.replaceMasterCustomersForOwner('', [
          MasterCustomer(
            customerId: '32018899',
            installDate: DateTime(2026, 10, 25),
            address: 'JL. DIPONEGORO NO 45 CILACAP',
            packageName: 'XL SATU FWA 50MBPS',
            latitude: -7.712345,
            longitude: 109.012345,
            salesName: 'BUDI SANTOSO',
            syncedAt: '2026-11-07T00:00:00Z',
          ),
        ]);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(masterSyncProvider.notifier).refreshLocalCount();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: VisitFormScreen(initialDate: '2026-11-07'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final pickBtn = find.byKey(const Key('visit_pick_master_btn'));
        expect(pickBtn, findsOneWidget);

        await tester.tap(pickBtn);
        await tester.pumpAndSettle();

        expect(find.text('Pilih dari Pelanggan Saya'), findsOneWidget);
        final itemTile = find.byKey(const Key('master_customer_item_32018899'));
        expect(itemTile, findsOneWidget);

        await tester.tap(itemTile);
        await tester.pumpAndSettle();

        final cidField = tester.widget<TextFormField>(
          find.byKey(const Key('visit_customer_id_field')),
        );
        final nameField = tester.widget<TextFormField>(
          find.byKey(const Key('visit_customer_name_field')),
        );
        final pkgField = tester.widget<TextFormField>(
          find.byKey(const Key('visit_package_field')),
        );
        final addrField = tester.widget<TextFormField>(
          find.byKey(const Key('visit_address_field')),
        );
        final latField = tester.widget<TextFormField>(
          find.byKey(const Key('visit_latitude_field')),
        );
        final lngField = tester.widget<TextFormField>(
          find.byKey(const Key('visit_longitude_field')),
        );

        expect(cidField.controller!.text, '32018899');
        expect(nameField.controller!.text, isEmpty); // KMZ tidak punya nama
        expect(pkgField.controller!.text, 'XL SATU FWA 50MBPS');
        expect(addrField.controller!.text, 'JL. DIPONEGORO NO 45 CILACAP');
        expect(latField.controller!.text, '-7.712345');
        expect(lngField.controller!.text, '109.012345');
      },
    );

    testWidgets(
      'Banner autofill muncul saat mengetik Customer ID >= 6 digit tanpa menimpa field sebelum dikonfirmasi',
      (tester) async {
        await db.replaceMasterCustomersForOwner('', [
          MasterCustomer(
            customerId: '99887766',
            installDate: DateTime(2026, 10, 28),
            address: 'JL. SOEKARNO HATTA CILACAP',
            packageName: 'XL SATU FWA 100MBPS',
            latitude: -7.680000,
            longitude: 109.050000,
            salesName: 'BUDI SANTOSO',
            syncedAt: '2026-11-07T00:00:00Z',
          ),
        ]);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(masterSyncProvider.notifier).refreshLocalCount();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: VisitFormScreen(initialDate: '2026-11-07'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Isi manual alamat terlebih dahulu
        await tester.enterText(
          find.byKey(const Key('visit_address_field')),
          'Alamat Manual Awal',
        );

        // Ketik Customer ID yang cocok di master
        await tester.enterText(
          find.byKey(const Key('visit_customer_id_field')),
          '99887766',
        );
        await tester.pumpAndSettle();

        // Banner autofill tampil, tetapi alamat manual belum ditimpa
        expect(find.byKey(const Key('visit_autofill_banner')), findsOneWidget);
        final addrBefore = tester
            .widget<TextFormField>(find.byKey(const Key('visit_address_field')))
            .controller!
            .text;
        expect(addrBefore, 'Alamat Manual Awal');

        // Tekan tombol "Isi Otomatis" pada banner -> barulah field terisi dari master
        await tester.tap(find.byKey(const Key('visit_autofill_apply_btn')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('visit_autofill_banner')), findsNothing);
        final addrAfter = tester
            .widget<TextFormField>(find.byKey(const Key('visit_address_field')))
            .controller!
            .text;
        expect(addrAfter, 'JL. SOEKARNO HATTA CILACAP');
      },
    );
  });
}
