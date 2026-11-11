import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dsa_incentive_tracker/data/models/customer_map_point.dart';
import 'package:dsa_incentive_tracker/data/local/database_helper.dart';
import 'package:dsa_incentive_tracker/data/services/customer_map_points_service.dart';
import 'package:dsa_incentive_tracker/maps/providers/coverage_map_provider.dart';
import 'package:dsa_incentive_tracker/maps/providers/customer_map_points_provider.dart';

// Fake remote gateway untuk pengujian pagination dan sinkronisasi tanpa jaringan
class FakeCustomerMapPointsGateway implements CustomerMapPointsRemoteGateway {
  final List<Map<String, dynamic>> rawData;
  bool shouldThrow = false;
  int fetchCallCount = 0;

  FakeCustomerMapPointsGateway(this.rawData);

  @override
  String? get currentUserId => 'test-user-123';

  @override
  Future<List<Map<String, dynamic>>> fetchCustomerMapPointsPage({
    required int fromIndex,
    required int toIndex,
  }) async {
    fetchCallCount++;
    if (shouldThrow) throw Exception('Network error');
    if (fromIndex >= rawData.length) return [];
    final end = (toIndex + 1 < rawData.length) ? toIndex + 1 : rawData.length;
    return rawData.sublist(fromIndex, end);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 13 - Pure Function installMonthBucket & Category Logic', () {
    test('installMonthBucket assigns correct buckets relative to reference now', () {
      final now = DateTime(2026, 11, 15, 12, 0);

      // 1. Bulan ini (November 2026) -> Merah
      final dThisMonth = DateTime(2026, 11, 2);
      expect(installMonthBucket(dThisMonth, now), InstallMonthCategory.thisMonth);
      expect(InstallMonthCategory.thisMonth.color, const Color(0xFFE53935));

      // 2. Bulan lalu (Oktober 2026) -> Biru Tua
      final dLastMonth = DateTime(2026, 10, 28);
      expect(installMonthBucket(dLastMonth, now), InstallMonthCategory.lastMonth);
      expect(InstallMonthCategory.lastMonth.color, const Color(0xFF1E3A8A));

      // 3. Dua bulan lalu (September 2026) -> Pink
      final dTwoMonths = DateTime(2026, 9, 10);
      expect(installMonthBucket(dTwoMonths, now), InstallMonthCategory.twoMonthsAgo);
      expect(InstallMonthCategory.twoMonthsAgo.color, const Color(0xFFEC407A));

      // 4. Tiga bulan lalu (Agustus 2026) -> Cokelat
      final dThreeMonths = DateTime(2026, 8, 5);
      expect(installMonthBucket(dThreeMonths, now), InstallMonthCategory.threeMonthsAgo);
      expect(InstallMonthCategory.threeMonthsAgo.color, const Color(0xFF6D4C41));

      // 5. Lebih lama (Juli 2026) -> Abu-abu
      final dOlder = DateTime(2026, 7, 20);
      expect(installMonthBucket(dOlder, now), InstallMonthCategory.older);
      expect(InstallMonthCategory.older.color, const Color(0xFF757575));

      // 6. Tanggal null -> Abu-abu
      expect(installMonthBucket(null, now), InstallMonthCategory.older);

      // 7. Masa depan (safety check) -> Bulan ini (0)
      final dFuture = DateTime(2026, 12, 1);
      expect(installMonthBucket(dFuture, now), InstallMonthCategory.thisMonth);
    });

    test('Year crossover calculates correct month delta (January vs December)', () {
      final nowJan2027 = DateTime(2027, 1, 15);

      final dDec2026 = DateTime(2026, 12, 20);
      expect(installMonthBucket(dDec2026, nowJan2027), InstallMonthCategory.lastMonth);

      final dNov2026 = DateTime(2026, 11, 10);
      expect(installMonthBucket(dNov2026, nowJan2027), InstallMonthCategory.twoMonthsAgo);

      final dOct2026 = DateTime(2026, 10, 5);
      expect(installMonthBucket(dOct2026, nowJan2027), InstallMonthCategory.threeMonthsAgo);
    });

    test('CustomerMapPoint model serialization & formatting', () {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final p = CustomerMapPoint(
        customerId: 'CUST-001',
        latitude: -7.7188,
        longitude: 109.0156,
        installDate: DateTime(2026, 10, 15),
        address: 'Jl. Jenderal Sudirman No. 10',
        packageName: 'XL SATU 50 Mbps',
        salesName: 'Budi Santoso',
        spvName: 'Ahmad Fauzi',
        tscName: 'TSC Cilacap',
        syncedAt: nowIso,
      );

      final map = p.toMap();
      expect(map['customer_id'], 'CUST-001');
      expect(map['latitude'], -7.7188);
      expect(map['longitude'], 109.0156);
      expect(map['install_date'], '2026-10-15');
      expect(map['address'], 'Jl. Jenderal Sudirman No. 10');
      expect(map['package_name'], 'XL SATU 50 Mbps');
      expect(map['sales_name'], 'Budi Santoso');
      expect(map['spv_name'], 'Ahmad Fauzi');
      expect(map['tsc_name'], 'TSC Cilacap');

      final fromMapPoint = CustomerMapPoint.fromMap(map);
      expect(fromMapPoint.customerId, p.customerId);
      expect(fromMapPoint.location, const LatLng(-7.7188, 109.0156));
      expect(fromMapPoint.installDateFormatted, contains('15/10/2026'));

      final json = {
        'customer_id': 'CUST-002',
        'latitude': -7.72,
        'longitude': 109.02,
        'install_date': '2026-11-01',
        'address': 'Jl. Ahmad Yani',
        'package_name': 'XL SATU 30 Mbps',
        'sales_name': 'Citra',
        'spv_name': 'Dewi',
        'tsc_name': 'TSC Kroya',
      };
      final fromJsonPoint = CustomerMapPoint.fromSupabaseJson(json);
      expect(fromJsonPoint.customerId, 'CUST-002');
      expect(fromJsonPoint.installDate, DateTime(2026, 11, 1));
    });
  });

  group('Phase 13 - SQLite v10 Migration and Local Persistence', () {
    test('DatabaseHelper upgrades to v10 and supports CustomerMapPoints CRUD', () async {
      final dbHelper = DatabaseHelper.instance;
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final points = [
        CustomerMapPoint(
          customerId: 'CUST-101',
          latitude: -7.70,
          longitude: 109.01,
          installDate: DateTime(2026, 11, 1),
          address: 'Alamat 101',
          packageName: 'Paket A',
          salesName: 'Sales A',
          spvName: 'SPV 1',
          tscName: 'TSC 1',
          syncedAt: nowIso,
        ),
        CustomerMapPoint(
          customerId: 'CUST-102',
          latitude: -7.71,
          longitude: 109.02,
          installDate: DateTime(2026, 10, 1),
          address: 'Alamat 102',
          packageName: 'Paket B',
          salesName: 'Sales B',
          spvName: 'SPV 2',
          tscName: 'TSC 2',
          syncedAt: nowIso,
        ),
      ];

      await dbHelper.replaceCustomerMapPoints(points);
      final count = await dbHelper.countCustomerMapPoints();
      expect(count, 2);

      final retrieved = await dbHelper.getAllCustomerMapPoints();
      expect(retrieved.length, 2);
      expect(retrieved.first.customerId, 'CUST-101');
      expect(retrieved.last.customerId, 'CUST-102');

      await dbHelper.clearAllCustomerMapPoints();
      final countAfterClear = await dbHelper.countCustomerMapPoints();
      expect(countAfterClear, 0);
    });
  });

  group('Phase 13 - CustomerMapPointsService and Pagination', () {
    test('Service paginates 1000 rows batches until exhaustion', () async {
      final dbHelper = DatabaseHelper.instance;
      await dbHelper.clearAllCustomerMapPoints();

      final mockData = List.generate(
        1500,
        (i) => {
          'customer_id': 'ID-$i',
          'latitude': -7.70 + (i * 0.0001),
          'longitude': 109.01 + (i * 0.0001),
          'install_date': '2026-10-01',
          'address': 'Alamat $i',
          'package_name': 'Paket $i',
          'sales_name': i % 2 == 0 ? 'SALES ALPHA' : 'SALES BETA',
          'spv_name': 'SPV UTAMA',
          'tsc_name': 'TSC CILACAP',
        },
      );

      final fakeGateway = FakeCustomerMapPointsGateway(mockData);
      final service = CustomerMapPointsService(
        databaseHelper: dbHelper,
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
      );

      final result = await service.syncAll(isApproved: true);
      expect(result.syncedCount, 1500);
      expect(result.hasError, isFalse);
      expect(fakeGateway.fetchCallCount, 2);

      final storedCount = await dbHelper.countCustomerMapPoints();
      expect(storedCount, 1500);

      await dbHelper.clearAllCustomerMapPoints();
    });

    test('Service silently handles network exceptions without crashing', () async {
      final dbHelper = DatabaseHelper.instance;
      final fakeGateway = FakeCustomerMapPointsGateway([])..shouldThrow = true;
      final service = CustomerMapPointsService(
        databaseHelper: dbHelper,
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
      );

      final result = await service.syncAll(isApproved: true);
      expect(result.hasError, isTrue);
      expect(result.syncedCount, 0);
    });
  });

  group('Phase 13 - Riverpod State & Filters', () {
    test('CoverageMapNotifier toggles showMasterCustomers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialState = container.read(coverageMapNotifierProvider);
      expect(initialState.showMasterCustomers, isTrue);

      container.read(coverageMapNotifierProvider.notifier).toggleMasterCustomers(false);
      expect(container.read(coverageMapNotifierProvider).showMasterCustomers, isFalse);

      container.read(coverageMapNotifierProvider.notifier).toggleMasterCustomers(true);
      expect(container.read(coverageMapNotifierProvider).showMasterCustomers, isTrue);
    });

    test('CustomerMapPointFilter filters by Sales, SPV, and Month Category', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(customerMapPointFilterProvider.notifier);
      expect(container.read(customerMapPointFilterProvider).hasActiveFilters, isFalse);

      notifier.setSales('Sales Alpha');
      expect(container.read(customerMapPointFilterProvider).salesName, 'Sales Alpha');
      expect(container.read(customerMapPointFilterProvider).hasActiveFilters, isTrue);

      notifier.setSpv('SPV Utama');
      expect(container.read(customerMapPointFilterProvider).spvName, 'SPV Utama');

      notifier.toggleCategory(InstallMonthCategory.thisMonth);
      expect(container.read(customerMapPointFilterProvider).selectedCategories.contains(InstallMonthCategory.thisMonth), isFalse);

      notifier.reset();
      expect(container.read(customerMapPointFilterProvider).salesName, isNull);
      expect(container.read(customerMapPointFilterProvider).spvName, isNull);
      expect(container.read(customerMapPointFilterProvider).selectedCategories.length, InstallMonthCategory.values.length);
    });
  });

  group('Phase 13 - SQL Migration and Schema Validation', () {
    test('Migration file exists and has correct table name and triggers', () {
      final migrationFile = File('supabase/migrations/2026-11-12_phase13_customer_map_points.sql');
      expect(migrationFile.existsSync(), isTrue, reason: 'Migration file must exist');

      final content = migrationFile.readAsStringSync().toLowerCase();
      expect(content, contains('create table if not exists public.customer_map_points'));
      expect(content, contains('enable row level security'));
      expect(content, contains('is_approved_member()'));
      expect(content, contains('can_view_all()'));
      expect(content, contains('trg_customer_map_point_upsert'));
      expect(content, contains('trg_customer_map_point_delete'));

      expect(content, isNot(contains('for insert to authenticated')));
      expect(content, isNot(contains('for update to authenticated')));
      expect(content, isNot(contains('for delete to authenticated')));
    });

    test('supabase/schema.sql includes phase 13 customer_map_points table', () {
      final schemaFile = File('supabase/schema.sql');
      expect(schemaFile.existsSync(), isTrue);

      final content = schemaFile.readAsStringSync().toLowerCase();
      expect(content, contains('create table if not exists public.customer_map_points'));
      expect(content, contains('trg_customer_map_point_upsert'));
    });
  });
}
