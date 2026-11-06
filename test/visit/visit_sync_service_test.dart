import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/data/local/database_helper.dart';
import 'package:dsa_incentive_tracker/data/models/visit_activity.dart';
import 'package:dsa_incentive_tracker/data/services/visit_sync_service.dart';

/// Fake implementasi `VisitRemoteGateway` dengan simulasi constraint `unique(user_id, client_id)`
class FakeVisitRemoteGateway implements VisitRemoteGateway {
  final String? activeUserId;
  bool shouldThrowOnUpsert;
  final Map<String, Map<String, dynamic>> remoteTable = {};

  FakeVisitRemoteGateway({
    this.activeUserId = 'user-sales-fiktif-1',
    this.shouldThrowOnUpsert = false,
  });

  @override
  String? get currentUserId => activeUserId;

  @override
  Future<void> upsertBatch(List<Map<String, dynamic>> payload) async {
    if (shouldThrowOnUpsert) {
      throw Exception('Simulasi kegagalan jaringan atau RLS revoked');
    }
    for (final row in payload) {
      final key = '${row['user_id']}__${row['client_id']}';
      remoteTable[key] = Map<String, dynamic>.from(row);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchActiveOwnedVisits(String userId) async {
    return remoteTable.values
        .where((row) => row['user_id'] == userId && row['deleted_at'] == null)
        .toList();
  }
}

void main() {
  final db = DatabaseHelper.instance;

  setUp(() {
    db.clearInMemoryVisits();
  });

  group('VisitSyncService Offline-First & Guard Tests', () {
    test('Guard tanpa konfigurasi Supabase atau belum approved berhenti diam-diam tanpa error', () async {
      await db.insertVisit(
        const VisitActivity(
          clientId: 'c-guard-1',
          customerId: '77880011',
          category: VisitCategory.rvai,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T02:00:00Z',
        ),
      );

      final fakeGateway = FakeVisitRemoteGateway();

      // 1. Supabase tidak dikonfigurasi
      final unconfiguredService = VisitSyncService(
        databaseHelper: db,
        remoteGateway: fakeGateway,
        isConfiguredOverride: false,
      );
      final res1 = await unconfiguredService.syncAll(isApproved: true);
      expect(res1.skippedByGuard, isTrue);
      expect(res1.hasError, isFalse);
      expect((await db.getPendingVisits()).length, 1);

      // 2. User belum approved
      final configuredService = VisitSyncService(
        databaseHelper: db,
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
      );
      final res2 = await configuredService.syncAll(isApproved: false);
      expect(res2.skippedByGuard, isTrue);
      expect((await db.getPendingVisits()).length, 1);
    });

    test('Push sukses menandai baris lokal menjadi synced (sync_state = 1)', () async {
      await db.insertVisit(
        const VisitActivity(
          clientId: 'c-push-1',
          customerId: '88001122',
          customerName: 'Pelanggan Fiktif A',
          category: VisitCategory.rvai,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T03:00:00Z',
        ),
      );
      await db.insertVisit(
        const VisitActivity(
          clientId: 'c-push-2',
          customerId: '88001123',
          customerName: 'Pelanggan Fiktif B',
          category: VisitCategory.unpaid,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T03:05:00Z',
        ),
      );

      final fakeGateway = FakeVisitRemoteGateway();
      final service = VisitSyncService(
        databaseHelper: db,
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
      );

      final res = await service.pushPendingVisits(isApproved: true);
      expect(res.hasError, isFalse);
      expect(res.pushedCount, 2);

      // Antrean pending lokal harus kosong setelah push sukses
      expect(await db.getPendingVisits(), isEmpty);
      expect(fakeGateway.remoteTable.length, 2);
    });

    test('Push gagal membiarkan data lokal tetap pending dan tidak menghapus data lokal', () async {
      await db.insertVisit(
        const VisitActivity(
          clientId: 'c-fail-1',
          customerId: '99001122',
          customerName: 'Pelanggan Offline Aman',
          category: VisitCategory.dismantle,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T04:00:00Z',
        ),
      );

      final fakeGateway = FakeVisitRemoteGateway(shouldThrowOnUpsert: true);
      final service = VisitSyncService(
        databaseHelper: db,
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
      );

      final res = await service.pushPendingVisits(isApproved: true);
      expect(res.hasError, isTrue);

      // Pastikan data lokal tetap utuh dan masih berstatus pending
      final pending = await db.getPendingVisits();
      expect(pending.length, 1);
      expect(pending.first.customerId, '99001122');

      final onDate = await db.getVisitsByDate('2026-11-06');
      expect(onDate.length, 1);
    });

    test('Upsert bersifat idempotent (kirim dua kali untuk client_id yang sama tidak menggandakan baris)', () async {
      final fakeGateway = FakeVisitRemoteGateway();
      final service = VisitSyncService(
        databaseHelper: db,
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
      );

      final visit = const VisitActivity(
        clientId: 'c-idem-1',
        customerId: '55667788',
        customerName: 'Pelanggan Idempotent',
        category: VisitCategory.rvai,
        status: VisitStatus.belum,
        plannedDate: '2026-11-06',
        updatedAt: '2026-11-06T05:00:00Z',
      );

      await db.insertVisit(visit);
      await service.pushPendingVisits(isApproved: true);
      expect(fakeGateway.remoteTable.length, 1);

      // Ubah status lokal (membuat sync_state = 0 kembali dengan client_id yang sama) lalu push kedua kali
      final saved = (await db.getVisitsByDate('2026-11-06')).first;
      await db.updateVisit(saved.copyWith(status: VisitStatus.sudahVisit));
      await service.pushPendingVisits(isApproved: true);

      // Tetap 1 baris di remote dan di lokal dengan status terbaru
      expect(fakeGateway.remoteTable.length, 1);
      expect(fakeGateway.remoteTable.values.first['status'], 'sudah_visit');
      expect((await db.getVisitsByDate('2026-11-06')).length, 1);
    });

    test('Restore saat tabel lokal kosong memulihkan baris aktif milik sendiri dengan sync_state = 1', () async {
      final fakeGateway = FakeVisitRemoteGateway(activeUserId: 'sales-restore-1');
      await fakeGateway.upsertBatch([
        {
          'user_id': 'sales-restore-1',
          'client_id': 'c-restored-1',
          'customer_id': '44332211',
          'customer_name': 'Pelanggan Pulih',
          'category': 'unpaid',
          'status': 'follow_up',
          'address': 'Jl. Ahmad Yani Cilacap',
          'package_name': 'FWA 100GB',
          'latitude': -7.71,
          'longitude': 109.01,
          'planned_date': '2026-11-06',
          'visited_at': null,
          'note': 'Janji bayar besok',
          'form_submitted': false,
          'updated_at': '2026-11-06T06:00:00Z',
          'deleted_at': null,
        },
      ]);

      final service = VisitSyncService(
        databaseHelper: db,
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
      );

      final res = await service.restoreIfLocalEmpty(isApproved: true);
      expect(res.restoredCount, 1);
      expect(await db.getPendingVisits(), isEmpty);

      final localList = await db.getVisitsByDate('2026-11-06');
      expect(localList.length, 1);
      expect(localList.first.customerId, '44332211');
      expect(localList.first.isSynced, isTrue);
    });
  });
}

