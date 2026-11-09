import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dsa_incentive_tracker/data/local/database_helper.dart';
import 'package:dsa_incentive_tracker/data/models/master_customer.dart';
import 'package:dsa_incentive_tracker/data/services/customer_master_service.dart';
import 'package:dsa_incentive_tracker/ui/screens/claim_sales_name_screen.dart';

class FakeCustomerMasterGateway implements CustomerMasterRemoteGateway {
  @override
  String? currentUserId;

  List<Map<String, dynamic>> remoteCustomers;
  List<Map<String, dynamic>> salesNameOptions;
  String nextClaimResult;
  Map<String, dynamic>? masterStatusRow;
  List<Map<String, dynamic>> rvaiComplianceRows;
  final List<(int, int)> requestedRanges = [];

  FakeCustomerMasterGateway({
    this.currentUserId = 'user-sales-kclp-1',
    List<Map<String, dynamic>>? remoteCustomers,
    List<Map<String, dynamic>>? salesNameOptions,
    this.nextClaimResult = 'success',
    this.masterStatusRow,
    List<Map<String, dynamic>>? rvaiComplianceRows,
  }) : remoteCustomers = remoteCustomers ?? [],
       salesNameOptions = salesNameOptions ?? [],
       rvaiComplianceRows = rvaiComplianceRows ?? [];

  @override
  Future<List<Map<String, dynamic>>> fetchSalesNamesRpc() async {
    return salesNameOptions;
  }

  @override
  Future<String> claimSalesNameRpc(String salesName) async {
    return nextClaimResult;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCustomerMasterPage({
    required int fromIndex,
    required int toIndex,
  }) async {
    requestedRanges.add((fromIndex, toIndex));
    if (fromIndex >= remoteCustomers.length) return const [];
    final end = (toIndex + 1 < remoteCustomers.length)
        ? toIndex + 1
        : remoteCustomers.length;
    return remoteCustomers.sublist(fromIndex, end);
  }

  @override
  Future<Map<String, dynamic>?> fetchMasterStatusRpc() async {
    return masterStatusRow;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRvaiComplianceRpc({
    required String fromDate,
    required String toDate,
  }) async {
    return rvaiComplianceRows;
  }
}

void main() {
  final db = DatabaseHelper.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db.clearInMemoryVisits();
  });

  group('CustomerMasterService Sync, Pagination, Claim, & Search Tests', () {
    test(
      'Guard tanpa konfigurasi Supabase atau belum approved berhenti diam-diam tanpa melempar error',
      () async {
        final fakeGateway = FakeCustomerMasterGateway(
          remoteCustomers: [
            {
              'customer_id': '100001',
              'install_date': '2026-10-01',
              'address': 'JL. DIPONEGORO CILACAP',
              'package_name': 'XL SATU FWA',
              'sales_name': 'BUDI SANTOSO',
            },
          ],
        );

        final unconfigured = CustomerMasterService(
          databaseHelper: db,
          remoteGateway: fakeGateway,
          isConfiguredOverride: false,
        );
        final res1 = await unconfigured.syncMyCustomers(isApproved: true);
        expect(res1.skippedByGuard, isTrue);
        expect(res1.hasError, isFalse);
        expect(await db.countMasterCustomers(), 0);
        expect(await unconfigured.fetchSalesNames(), isEmpty);
        expect(await unconfigured.claimSalesName('BUDI SANTOSO'), 'error');

        final unapproved = CustomerMasterService(
          databaseHelper: db,
          remoteGateway: fakeGateway,
          isConfiguredOverride: true,
        );
        final res2 = await unapproved.syncMyCustomers(isApproved: false);
        expect(res2.skippedByGuard, isTrue);
        expect(await db.countMasterCustomers(), 0);
      },
    );

    test(
      'Paginasi syncMyCustomers: 2.300 baris diunduh dalam 3 halaman (1000 per halaman) dan seluruhnya tersimpan',
      () async {
        final rows = List.generate(2300, (idx) {
          final cid = (1000000 + idx).toString();
          final day = ((idx % 28) + 1).toString().padLeft(2, '0');
          return <String, dynamic>{
            'customer_id': cid,
            'install_date': '2026-09-$day',
            'address': 'JL. CILACAP BLOK $idx',
            'package_name': 'XL SATU FWA 50MBPS',
            'latitude': -7.70 - (idx * 0.00001),
            'longitude': 109.01 + (idx * 0.00001),
            'sales_name': 'BUDI SANTOSO',
            'spv_name': 'EKO YUNIANTO',
            'tsc_name': 'PIPIEN MALVIANA',
          };
        });

        final fakeGateway = FakeCustomerMasterGateway(
          currentUserId: 'user-sales-2300',
          remoteCustomers: rows,
        );
        final service = CustomerMasterService(
          databaseHelper: db,
          remoteGateway: fakeGateway,
          isConfiguredOverride: true,
        );

        final result = await service.syncMyCustomers(isApproved: true);
        expect(result.hasError, isFalse);
        expect(result.skippedByGuard, isFalse);
        expect(result.pagesFetched, 3);
        expect(result.syncedCount, 2300);
        expect(fakeGateway.requestedRanges, [
          (0, 999),
          (1000, 1999),
          (2000, 2999),
        ]);

        final savedCount = await db.countMasterCustomers(
          ownerUserId: 'user-sales-2300',
        );
        expect(savedCount, 2300);

        final first = await db.getMasterCustomerById(
          '1000000',
          ownerUserId: 'user-sales-2300',
        );
        final last = await db.getMasterCustomerById(
          '1002299',
          ownerUserId: 'user-sales-2300',
        );
        expect(first, isNotNull);
        expect(last, isNotNull);
        expect(last!.address, 'JL. CILACAP BLOK 2299');
      },
    );

    test(
      'Parse status klaim nama sales dan aturan wajib klaim (SPV/TSC/Admin/Superadmin tidak wajib klaim)',
      () async {
        for (final status in [
          'success',
          'unauthorized',
          'invalid_name',
          'not_found',
          'already_claimed',
          'already_set',
          'error',
        ]) {
          expect(CustomerMasterService.parseClaimStatus(status), status);
          expect(
            CustomerMasterService.parseClaimStatus(status.toUpperCase()),
            status,
          );
        }
        expect(CustomerMasterService.parseClaimStatus('status_aneh'), 'error');
        expect(CustomerMasterService.parseClaimStatus(null), 'error');

        expect(
          ClaimSalesNameScreen.messageForClaimStatus('already_claimed'),
          contains('sudah dipakai akun lain'),
        );

        // Sales biasa (canViewAll == false) tanpa sales_name wajib klaim bila master tersedia
        expect(
          ClaimSalesNameScreen.shouldPromptClaim(
            isApproved: true,
            canViewAll: false,
            currentSalesName: null,
            hasMasterOptions: true,
          ),
          isTrue,
        );
        // Sales yang sudah klaim tidak diminta lagi
        expect(
          ClaimSalesNameScreen.shouldPromptClaim(
            isApproved: true,
            canViewAll: false,
            currentSalesName: 'BUDI SANTOSO',
            hasMasterOptions: true,
          ),
          isFalse,
        );
        // SPV/TSC/Admin/Superadmin (canViewAll == true) tidak wajib klaim
        expect(
          ClaimSalesNameScreen.shouldPromptClaim(
            isApproved: true,
            canViewAll: true,
            currentSalesName: null,
            hasMasterOptions: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'Pencarian lokal: cari customer_id atau alamat, urut install_date DESC, dan dibatasi maks 50 hasil',
      () async {
        final customers = List.generate(65, (i) {
          final day = ((i % 28) + 1).toString().padLeft(2, '0');
          return MasterCustomer(
            customerId: '8800${i.toString().padLeft(3, '0')}',
            installDate: DateTime(2026, 9, int.parse(day)),
            address: i.isEven
                ? 'JL. AHMAD YANI NO $i CILACAP SELATAN'
                : 'JL. GATOT SUBROTO NO $i SIDAREJA',
            packageName: 'XL SATU FWA',
            salesName: 'BUDI SANTOSO',
            ownerUserId: 'u-search',
            syncedAt: '2026-11-07T00:00:00Z',
          );
        });

        await db.replaceMasterCustomersForOwner('u-search', customers);

        // Tanpa kata kunci -> dibatasi 50 baris dan urut install_date DESC
        final top50 = await db.searchMasterCustomers(
          '',
          ownerUserId: 'u-search',
        );
        expect(top50.length, 50);
        expect(top50.first.installDateString, '2026-09-28');

        // Cari berdasarkan bagian alamat
        final sidareja = await db.searchMasterCustomers(
          'SIDAREJA',
          ownerUserId: 'u-search',
        );
        expect(sidareja, isNotEmpty);
        expect(
          sidareja.every((c) => c.address.contains('SIDAREJA')),
          isTrue,
        );

        // Cari berdasarkan Customer ID spesifik
        final byCid = await db.searchMasterCustomers(
          '8800012',
          ownerUserId: 'u-search',
        );
        expect(byCid.length, 1);
        expect(byCid.first.customerId, '8800012');
      },
    );

    test(
      'MasterStatusSummary mendeteksi impor usang (> 35 hari) dan RvaiComplianceRow menghitung persentase',
      () async {
        final fakeGateway = FakeCustomerMasterGateway(
          masterStatusRow: {
            'total': 1250,
            'last_import': '2026-09-27T08:00:00Z',
            'last_batch': '2026-09-27',
            'with_sales': 1230,
          },
          rvaiComplianceRows: [
            {
              'sales_name': 'BUDI SANTOSO',
              'spv_name': 'EKO YUNIANTO',
              'tsc_name': 'PIPIEN MALVIANA',
              'due_total': 10,
              'visited_total': 8,
            },
          ],
        );

        final service = CustomerMasterService(
          databaseHelper: db,
          remoteGateway: fakeGateway,
          isConfiguredOverride: true,
        );

        final status = await service.fetchMasterStatus();
        expect(status, isNotNull);
        expect(status!.total, 1250);
        expect(status.withoutSales, 20);
        expect(
          status.isImportStale(now: DateTime.utc(2026, 11, 7)),
          isTrue, // > 35 hari sejak 27 Sep
        );
        expect(
          status.isImportStale(now: DateTime.utc(2026, 10, 15)),
          isFalse,
        );

        final compliance = await service.fetchRvaiCompliance(
          fromDate: DateTime(2026, 10, 1),
          toDate: DateTime(2026, 11, 7),
        );
        expect(compliance.length, 1);
        expect(compliance.first.salesName, 'BUDI SANTOSO');
        expect(compliance.first.dueTotal, 10);
        expect(compliance.first.visitedTotal, 8);
        expect(compliance.first.pendingTotal, 2);
        expect(compliance.first.complianceRate, closeTo(0.8, 0.001));
      },
    );
  });
}

