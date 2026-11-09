import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dsa_incentive_tracker/data/local/database_helper.dart';
import 'package:dsa_incentive_tracker/data/models/incentive_record.dart';
import 'package:dsa_incentive_tracker/data/models/sa_record.dart';
import 'package:dsa_incentive_tracker/data/services/backup_sync_service.dart';

class _FakeBackupRemoteGateway implements BackupRemoteGateway {
  @override
  String? currentUserId;

  bool shouldThrowOnUpsert = false;
  int upsertSaCallCount = 0;
  int upsertIncCallCount = 0;

  final List<String> saFetchRanges = [];
  final List<String> incFetchRanges = [];

  /// Key: `$userId::$clientId`
  final Map<String, Map<String, dynamic>> remoteSaStore = {};
  final Map<String, Map<String, dynamic>> remoteIncStore = {};

  /// Seeded rows for paginated restore testing
  final List<Map<String, dynamic>> seededSaRows = [];
  final List<Map<String, dynamic>> seededIncRows = [];

  _FakeBackupRemoteGateway({this.currentUserId = 'user-sales-01'});

  @override
  Future<void> upsertSaBatch(List<Map<String, dynamic>> payload) async {
    upsertSaCallCount++;
    if (shouldThrowOnUpsert) {
      throw Exception('Simulasi gangguan jaringan SA');
    }
    for (final row in payload) {
      final key = '${row['user_id']}::${row['client_id']}';
      remoteSaStore[key] = Map<String, dynamic>.from(row);
    }
  }

  @override
  Future<void> upsertIncentiveBatch(List<Map<String, dynamic>> payload) async {
    upsertIncCallCount++;
    if (shouldThrowOnUpsert) {
      throw Exception('Simulasi gangguan jaringan Insentif');
    }
    for (final row in payload) {
      final key = '${row['user_id']}::${row['client_id']}';
      remoteIncStore[key] = Map<String, dynamic>.from(row);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwnSaPage({
    required String userId,
    required int from,
    required int to,
  }) async {
    saFetchRanges.add('$from..$to');
    final source = seededSaRows.isNotEmpty
        ? seededSaRows
        : remoteSaStore.values
              .where((r) => r['user_id'] == userId && r['deleted_at'] == null)
              .toList();
    if (from >= source.length) return const [];
    final end = (to + 1 < source.length) ? to + 1 : source.length;
    return source.sublist(from, end);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwnIncentivePage({
    required String userId,
    required int from,
    required int to,
  }) async {
    incFetchRanges.add('$from..$to');
    final source = seededIncRows.isNotEmpty
        ? seededIncRows
        : remoteIncStore.values
              .where((r) => r['user_id'] == userId && r['deleted_at'] == null)
              .toList();
    if (from >= source.length) return const [];
    final end = (to + 1 < source.length) ? to + 1 : source.length;
    return source.sublist(from, end);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 11C — BackupSyncService & Persetujuan Sales Tests', () {
    final db = DatabaseHelper.instance;
    late _FakeBackupRemoteGateway fakeGateway;
    late BackupSyncService syncService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db.clearInMemoryVisits();
      db.clearInMemoryBackupData();
      fakeGateway = _FakeBackupRemoteGateway(currentUserId: 'user-sales-01');
      syncService = BackupSyncService(
        databaseHelper: db,
        remoteGateway: fakeGateway,
        isConfiguredOverride: true,
      );
    });

    test('Tidak ada pengiriman apa pun sebelum persetujuan diberikan (unset atau declined)', () async {
      await db.insertSaRecord(
        SaRecord(
          idPelanggan: '80001001',
          nama: 'Pelanggan Fiktif 1',
          noHpUtama: '08000000001',
          alamat: 'Jl. Fiktif 1',
          paket: 'FTTH 50 Mbps',
          tanggalPasang: '2026-11-09',
        ),
      );
      await db.insertRecord(
        IncentiveRecord(
          periode: 'Nov 2026',
          totalSa: 10,
          pmBase: 1000000,
          multRate: 2.0,
          multBonus: 2000000,
          progInc: 750000,
          specialInc: 0,
          grandTotal: 4250000,
        ),
      );

      // 1. Status masih unset -> pushPending harus di-skip
      final resUnset = await syncService.pushPending(isMemberApproved: true);
      expect(resUnset.skippedByGuard, isTrue);
      expect(fakeGateway.upsertSaCallCount, 0);
      expect(fakeGateway.upsertIncCallCount, 0);
      expect(await db.countPendingBackupItems(), 2);

      // 2. Sales menekan "Nanti" (declined) -> pushPending tetap di-skip
      final now = DateTime.utc(2026, 11, 9, 8, 0);
      await syncService.setConsentDeclined(now);
      final resDeclined = await syncService.pushPending(isMemberApproved: true);
      expect(resDeclined.skippedByGuard, isTrue);
      expect(fakeGateway.upsertSaCallCount, 0);
      expect(fakeGateway.upsertIncCallCount, 0);

      // 3. Masa tunda "Nanti" 7 hari: H+3 belum ditanya lagi, H+7 baru ditanya lagi
      expect(
        await syncService.shouldPromptConsent(
          hasLocalData: true,
          now: now.add(const Duration(days: 3)),
        ),
        isFalse,
      );
      expect(
        await syncService.shouldPromptConsent(
          hasLocalData: true,
          now: now.add(const Duration(days: 7)),
        ),
        isTrue,
      );
    });

    test('Guard tanpa konfigurasi Supabase tidak melempar error dan tidak mengirim data', () async {
      await syncService.setConsentGranted();
      await db.insertSaRecord(
        SaRecord(
          idPelanggan: '80001002',
          nama: 'Pelanggan Fiktif 2',
          noHpUtama: '08000000002',
          alamat: 'Jl. Fiktif 2',
          paket: 'FWA 100 Mbps',
          tanggalPasang: '2026-11-09',
        ),
      );

      final unconfiguredService = BackupSyncService(
        databaseHelper: db,
        remoteGateway: fakeGateway,
        isConfiguredOverride: false,
      );
      final res = await unconfiguredService.syncAll(isMemberApproved: true);
      expect(res.skippedByGuard, isTrue);
      expect(res.hasError, isFalse);
      expect(fakeGateway.upsertSaCallCount, 0);
    });

    test('Push sukses menandai synced, gagal biarkan pending, upsert idempoten, dan soft delete dikirim sebagai deleted_at', () async {
      await syncService.setConsentGranted();

      final saId = await db.insertSaRecord(
        SaRecord(
          clientId: 'cid-sa-1',
          idPelanggan: '80002001',
          nama: 'Pelanggan Fiktif A',
          noHpUtama: '08000000011',
          alamat: 'Jl. Fiktif A',
          paket: 'FTTH 100 Mbps',
          tanggalPasang: '2026-11-09',
        ),
      );
      await db.insertRecord(
        IncentiveRecord(
          clientId: 'cid-inc-1',
          periode: 'Nov 2026',
          totalSa: 14,
          pmBase: 1400000,
          multRate: 4.0,
          multBonus: 5600000,
          progInc: 1000000,
          specialInc: 0,
          grandTotal: 9000000,
        ),
      );

      // 1. Simulasi gagal jaringan -> harus tetap pending (sync_state = 0)
      fakeGateway.shouldThrowOnUpsert = true;
      final failRes = await syncService.pushPending(isMemberApproved: true);
      expect(failRes.hasError, isTrue);
      expect(await db.countPendingBackupItems(), 2);

      // 2. Jaringan pulih -> push sukses -> sync_state = 1
      fakeGateway.shouldThrowOnUpsert = false;
      final okRes = await syncService.pushPending(isMemberApproved: true);
      expect(okRes.hasError, isFalse);
      expect(okRes.pushedSaCount, 1);
      expect(okRes.pushedIncentiveCount, 1);
      expect(await db.countPendingBackupItems(), 0);
      expect(fakeGateway.remoteSaStore.length, 1);
      expect(fakeGateway.remoteIncStore.length, 1);
      expect(await syncService.getLastSyncAt(), isNotNull);

      // 3. Upsert idempoten: bila diedit dan di-push lagi, tidak menggandakan baris di server
      final existingSa = (await db.getAllSaRecords()).first;
      await db.updateSaRecord(existingSa.copyWith(alamat: 'Jl. Fiktif A Baru'));
      await syncService.pushPending(isMemberApproved: true);
      expect(fakeGateway.remoteSaStore.length, 1);
      expect(
        fakeGateway.remoteSaStore['user-sales-01::cid-sa-1']?['alamat'],
        'Jl. Fiktif A Baru',
      );

      // 4. Soft delete dikirim sebagai deleted_at
      await db.deleteSaRecord(saId);
      expect(await db.getAllSaRecords(), isEmpty);
      expect(await db.countPendingBackupItems(), 1);

      final delPushRes = await syncService.pushPending(isMemberApproved: true);
      expect(delPushRes.pushedSaCount, 1);
      expect(await db.countPendingBackupItems(), 0);
      expect(
        fakeGateway.remoteSaStore['user-sales-01::cid-sa-1']?['deleted_at'],
        isNotNull,
      );
    });

    test('Restore berhalaman: 2.300 baris diunduh dalam 3 halaman (1000, 1000, 300) dengan sync_state = 1', () async {
      await syncService.setConsentGranted();

      for (int i = 1; i <= 2300; i++) {
        fakeGateway.seededSaRows.add({
          'user_id': 'user-sales-01',
          'client_id': 'cid-restore-$i',
          'id_pelanggan': '9000$i',
          'nama': 'Pelanggan Restore $i',
          'no_hp_utama': '08000000000',
          'no_hp_alternatif': '',
          'alamat': 'Alamat Fiktif $i',
          'paket': 'FTTH',
          'tanggal_pasang': '2026-11-01',
          'updated_at': '2026-11-09T01:00:00Z',
          'deleted_at': null,
        });
      }

      final restoreRes = await syncService.restoreIfLocalEmpty(
        isMemberApproved: true,
      );
      expect(restoreRes.hasError, isFalse);
      expect(restoreRes.restoredSaCount, 2300);
      expect(
        fakeGateway.saFetchRanges,
        equals(['0..999', '1000..1999', '2000..2999']),
      );

      final localSa = await db.getAllSaRecords();
      expect(localSa.length, 2300);
      // Semua baris hasil restore sudah berstatus sync_state = 1 (tidak antre push lagi)
      expect(await db.getPendingSaRecords(), isEmpty);
    });
  });
}
