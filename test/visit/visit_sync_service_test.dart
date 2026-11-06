import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/data/local/database_helper.dart';
import 'package:dsa_incentive_tracker/data/models/visit_activity.dart';
import 'package:dsa_incentive_tracker/data/services/visit_sync_service.dart';

/// Fake implementasi `VisitRemoteGateway` dengan simulasi constraint `unique(user_id, client_id)`,
/// penolakan baris tertentu (RLS/constraint), hook saat upsert berjalan, dan paginasi `.range()`.
class FakeVisitRemoteGateway implements VisitRemoteGateway {
  String? activeUserId;
  bool shouldThrowOnUpsert;
  final Set<String> failingClientIds;
  Future<void> Function()? onBeforeUpsertComplete;
  final Map<String, Map<String, dynamic>> remoteTable = {};

  FakeVisitRemoteGateway({
    this.activeUserId = 'user-sales-fiktif-1',
    this.shouldThrowOnUpsert = false,
    Set<String>? failingClientIds,
    this.onBeforeUpsertComplete,
  }) : failingClientIds = failingClientIds ?? {};

  @override
  String? get currentUserId => activeUserId;

  @override
  Future<void> upsertBatch(List<Map<String, dynamic>> payload) async {
    if (shouldThrowOnUpsert) {
      throw Exception('Simulasi kegagalan jaringan atau RLS revoked');
    }
    // Jika salah satu baris di dalam batch termasuk failingClientIds, gagalkan seluruh batch
    // (seperti perilaku transaksi PostgreSQL saat 1 baris melanggar constraint/RLS)
    for (final row in payload) {
      final cid = row['client_id'] as String?;
      if (cid != null && failingClientIds.contains(cid)) {
        throw Exception('RLS / constraint error pada baris $cid');
      }
    }

    if (onBeforeUpsertComplete != null) {
      await onBeforeUpsertComplete!();
    }

    for (final row in payload) {
      final key = '${row['user_id']}__${row['client_id']}';
      remoteTable[key] = Map<String, dynamic>.from(row);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchActiveOwnedVisits(
    String userId, {
    int fromIndex = 0,
    int toIndex = 499,
  }) async {
    final matching = remoteTable.values
        .where((row) => row['user_id'] == userId && row['deleted_at'] == null)
        .toList();
    if (fromIndex >= matching.length) return [];
    final end = (toIndex + 1 < matching.length) ? toIndex + 1 : matching.length;
    return matching.sublist(fromIndex, end);
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

    test('Restore saat tabel lokal kosong memulihkan baris aktif milik sendiri dengan paginasi .range()', () async {
      final fakeGateway = FakeVisitRemoteGateway(activeUserId: 'sales-restore-1');
      await fakeGateway.upsertBatch([
        for (int i = 1; i <= 5; i++)
          {
            'user_id': 'sales-restore-1',
            'client_id': 'c-restored-$i',
            'customer_id': '4433221$i',
            'customer_name': 'Pelanggan Pulih $i',
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
            'updated_at': '2026-11-06T06:0$i:00Z',
            'deleted_at': null,
          },
      ]);

      // Set restorePageSize = 2 agar teruji mengambil 3 halaman (2 + 2 + 1)
      final service = VisitSyncService(
        databaseHelper: db,
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
        restorePageSize: 2,
      );

      final res = await service.restoreIfLocalEmpty(isApproved: true);
      expect(res.restoredCount, 5);
      expect(await db.getPendingVisits(), isEmpty);

      final localList = await db.getVisitsByDate('2026-11-06');
      expect(localList.length, 5);
      expect(localList.every((v) => v.isSynced), isTrue);
    });

    test('Prioritas 3: Batch gagal jatuh ke pengiriman per-baris, menandai yang berhasil, dan lanjut ke batch berikutnya', () async {
      // Buat 55 baris (Batch 1: 50 baris, Batch 2: 5 baris).
      // Buat 1 baris di Batch 1 ('c-batch-bad') gagal.
      for (int i = 1; i <= 55; i++) {
        final cid = (i == 10) ? 'c-batch-bad' : 'c-batch-ok-$i';
        await db.insertVisit(
          VisitActivity(
            clientId: cid,
            customerId: '${100000 + i}',
            customerName: 'Target $i',
            category: VisitCategory.rvai,
            plannedDate: '2026-11-06',
            updatedAt: '2026-11-06T07:00:${(i % 60).toString().padLeft(2, '0')}Z',
          ),
        );
      }

      final fakeGateway = FakeVisitRemoteGateway(
        failingClientIds: {'c-batch-bad'},
      );
      final service = VisitSyncService(
        databaseHelper: db,
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
      );

      final res = await service.pushPendingVisits(isApproved: true);
      // 54 baris berhasil terkirim (49 di batch 1 + 5 di batch 2), hanya 1 yang gagal
      expect(res.pushedCount, 54);
      expect(res.hasError, isTrue);
      expect(res.errorMessage, contains('c-batch-bad'));

      final remainingPending = await db.getPendingVisits();
      expect(remainingPending.length, 1);
      expect(remainingPending.first.clientId, 'c-batch-bad');
      expect(fakeGateway.remoteTable.length, 54);
    });

    test('Prioritas 2: Edit baris saat push sedang berjalan TIDAK menandai versi baru sebagai synced', () async {
      await db.insertVisit(
        const VisitActivity(
          clientId: 'c-concurrent-1',
          customerId: '70008000',
          customerName: 'Pelanggan Diedit Saat Push',
          category: VisitCategory.rvai,
          status: VisitStatus.belum,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T08:00:00Z',
        ),
      );

      late FakeVisitRemoteGateway fakeGateway;
      fakeGateway = FakeVisitRemoteGateway(
        onBeforeUpsertComplete: () async {
          // Simulasikan sales mengedit baris lokal tepat ketika request upsert sedang terbang
          final currentLocal = (await db.getVisitsByDate('2026-11-06')).first;
          await db.updateVisit(
            currentLocal.copyWith(
              status: VisitStatus.sudahVisit,
              note: 'Diedit saat push berjalan',
            ),
          );
          // Hanya jalankan hook ini sekali
          fakeGateway.onBeforeUpsertComplete = null;
        },
      );

      final service = VisitSyncService(
        databaseHelper: db,
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
      );

      await service.pushPendingVisits(isApproved: true);

      // Karena updated_at di lokal sudah berubah saat push berlangsung,
      // baris versi baru TIDAK boleh ditandai sync_state = 1!
      final pendingAfterFirstPush = await db.getPendingVisits();
      expect(pendingAfterFirstPush.length, 1);
      expect(pendingAfterFirstPush.first.clientId, 'c-concurrent-1');
      expect(pendingAfterFirstPush.first.status, VisitStatus.sudahVisit);

      // Push berikutnya baru mengirim versi terbaru dan menandainya synced
      await service.pushPendingVisits(isApproved: true);
      expect(await db.getPendingVisits(), isEmpty);
      expect(
        fakeGateway.remoteTable['user-sales-fiktif-1__c-concurrent-1']?['status'],
        'sudah_visit',
      );
    });

    test('Prioritas 1: Pergantian akun mengisolasi data visit agar baris akun lama tidak di-push ke akun baru', () async {
      final gateway = FakeVisitRemoteGateway(activeUserId: 'user-lama');
      final service = VisitSyncService(
        databaseHelper: db,
        remoteGateway: gateway,
        isConfiguredOverride: true,
      );

      // 1. Akun lama menambah visit (namun gagal push karena offline)
      await db.insertVisit(
        const VisitActivity(
          clientId: 'c-milik-user-lama',
          ownerUserId: 'user-lama',
          customerId: '60001001',
          customerName: 'Target Akun Lama',
          category: VisitCategory.dismantle,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T09:00:00Z',
        ),
      );

      // 2. Akun berganti ke 'user-baru' di perangkat yang sama lalu menjalankan sync
      gateway.activeUserId = 'user-baru';
      final res = await service.pushPendingVisits(isApproved: true);

      // Baris milik 'user-lama' tidak boleh terkirim sebagai milik 'user-baru'
      expect(res.pushedCount, 0);
      expect(gateway.remoteTable.isEmpty, isTrue);
      expect(await db.getVisitsByDate('2026-11-06'), isEmpty);
    });

    test('Temuan B: Baris yang dibuat akun A otomatis terisi ownerUserId dari sesi saat insertVisit dan tidak pernah dikirim atas nama akun B walau signOut tidak dipanggil', () async {
      // 1. Sesi aktif adalah 'akun-A'
      db.currentUserIdResolver = () => 'akun-A';

      // Akun A membuat baris visit TANPA mengisi ownerUserId secara manual
      await db.insertVisit(
        const VisitActivity(
          clientId: 'c-dibuat-akun-a-offline',
          customerId: '91002003',
          customerName: 'Target Akun A Tanpa SignOut',
          category: VisitCategory.rvai,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T10:00:00Z',
        ),
      );

      // Pastikan ownerUserId langsung terisi 'akun-A' saat baris dibuat (sebelum sinkron pertama)
      final createdList = await db.getVisitsByDate('2026-11-06');
      expect(createdList.length, 1);
      expect(createdList.first.ownerUserId, 'akun-A');

      // 2. Sesi 'akun-A' berakhir tanpa lewat signOut (mis. token dicabut), lalu 'akun-B' login
      db.currentUserIdResolver = () => 'akun-B';
      final gatewayB = FakeVisitRemoteGateway(activeUserId: 'akun-B');
      final serviceB = VisitSyncService(
        databaseHelper: db,
        remoteGateway: gatewayB,
        isConfiguredOverride: true,
      );

      // 3. 'akun-B' menjalankan sinkronisasi
      final res = await serviceB.pushPendingVisits(isApproved: true);

      // Baris yang dibuat 'akun-A' TIDAK PERNAH dikirim atas nama 'akun-B'
      expect(res.pushedCount, 0);
      expect(gatewayB.remoteTable.isEmpty, isTrue);
      expect(await db.getPendingVisits(ownerUserId: 'akun-B'), isEmpty);

      // 4. Pastikan fallback '' tetap berjalan bila tidak ada sesi sama sekali
      db.currentUserIdResolver = () => null;
      await db.insertVisit(
        const VisitActivity(
          clientId: 'c-tanpa-sesi',
          customerId: '91002004',
          customerName: 'Target Offline Murni Tanpa Sesi',
          category: VisitCategory.unpaid,
          plannedDate: '2026-11-06',
          updatedAt: '2026-11-06T10:05:00Z',
        ),
      );
      final noSessionList = await db.getVisitsByDate('2026-11-06');
      expect(noSessionList.length, 1);
      expect(noSessionList.first.ownerUserId, '');
    });
  });
}
