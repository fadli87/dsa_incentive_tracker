import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/supabase_client.dart';
import '../../core/config/supabase_config.dart';
import '../local/database_helper.dart';
import '../models/visit_activity.dart';

/// Abstraksi gateway remote untuk operasi tabel `public.visit_activities` di Supabase
/// agar `VisitSyncService` mudah di-inject dan di-fake pada unit test.
abstract class VisitRemoteGateway {
  String? get currentUserId;
  Future<void> upsertBatch(List<Map<String, dynamic>> payload);
  Future<List<Map<String, dynamic>>> fetchActiveOwnedVisits(
    String userId, {
    int fromIndex = 0,
    int toIndex = 499,
  });
}

/// Implementasi default `VisitRemoteGateway` menggunakan `SupabaseClient`
class SupabaseVisitRemoteGateway implements VisitRemoteGateway {
  final SupabaseClient? _injectedClient;

  const SupabaseVisitRemoteGateway([this._injectedClient]);

  SupabaseClient get _client => _injectedClient ?? AppSupabase.client;

  @override
  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsertBatch(List<Map<String, dynamic>> payload) async {
    await _client
        .from('visit_activities')
        .upsert(payload, onConflict: 'user_id,client_id')
        .timeout(const Duration(seconds: 10));
  }

  @override
  Future<List<Map<String, dynamic>>> fetchActiveOwnedVisits(
    String userId, {
    int fromIndex = 0,
    int toIndex = 499,
  }) async {
    final response = await _client
        .from('visit_activities')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .order('planned_date', ascending: false)
        .order('client_id', ascending: true)
        .range(fromIndex, toIndex)
        .timeout(const Duration(seconds: 10));

    return (response as List<dynamic>)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}

/// Hasil eksekusi sinkronisasi aktivitas visit
class VisitSyncResult {
  final int pushedCount;
  final int restoredCount;
  final bool skippedByGuard;
  final String? errorMessage;

  const VisitSyncResult({
    this.pushedCount = 0,
    this.restoredCount = 0,
    this.skippedByGuard = false,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
}

/// Service sinkronisasi offline-first untuk Aktivitas Harian Visit
class VisitSyncService {
  static const int maxBatchSize = 50;
  static const int defaultRestorePageSize = 500;

  final DatabaseHelper _db;
  final VisitRemoteGateway _gateway;
  final bool? isConfiguredOverride;
  final int restorePageSize;

  VisitSyncService({
    SupabaseClient? supabaseClient,
    VisitRemoteGateway? remoteGateway,
    DatabaseHelper? databaseHelper,
    this.isConfiguredOverride,
    this.restorePageSize = defaultRestorePageSize,
  })  : _db = databaseHelper ?? DatabaseHelper.instance,
        _gateway = remoteGateway ?? SupabaseVisitRemoteGateway(supabaseClient);

  bool get _isSupabaseConfigured =>
      isConfiguredOverride ?? (SupabaseConfig.isConfigured && AppSupabase.isInitialized);

  /// Mengembalikan ID user yang sedang login dari gateway (atau null bila belum login).
  String? get currentAuthUserId => _gateway.currentUserId;

  /// Guard wajib: berhenti diam-diam bila Supabase belum dikonfigurasi, belum login,
  /// atau status user bukan approved.
  bool _canSync({required bool isApproved}) {
    if (!_isSupabaseConfigured) return false;
    if (!isApproved) return false;
    final uid = _gateway.currentUserId;
    if (uid == null || uid.trim().isEmpty) return false;
    return true;
  }

  /// Push seluruh baris lokal milik `auth.uid()` yang masih `sync_state == 0` dalam batch maks 50.
  /// - Mengisolasi baris per akun (`isolateVisitsForUser`) agar baris akun lain tidak pernah ikut terkirim.
  /// - Menandai sinkron hanya bila `updated_at` masih sama dengan versi yang dikirim (`WHERE client_id = ? AND updated_at = ?`).
  /// - Bila satu batch gagal, mencoba ulang baris satu per satu di batch tersebut, menandai yang berhasil,
  ///   mencatat yang gagal, lalu lanjut ke batch berikutnya.
  Future<VisitSyncResult> pushPendingVisits({required bool isApproved}) async {
    if (!_canSync(isApproved: isApproved)) {
      return const VisitSyncResult(skippedByGuard: true);
    }

    final userId = _gateway.currentUserId!;
    await _db.isolateVisitsForUser(userId);
    final pending = await _db.getPendingVisits(ownerUserId: userId);
    if (pending.isEmpty) {
      return const VisitSyncResult(pushedCount: 0);
    }

    int totalPushed = 0;
    final List<String> errors = [];

    for (int i = 0; i < pending.length; i += maxBatchSize) {
      final end = (i + maxBatchSize < pending.length)
          ? i + maxBatchSize
          : pending.length;
      final batch = pending.sublist(i, end);

      final payload = batch
          .map((v) => v.toSupabaseJson(userId: userId))
          .toList();

      try {
        await _gateway.upsertBatch(payload);
        final syncedClientIds = batch.map((v) => v.clientId).toList();
        final expectedUpdatedAt = <String, String>{
          for (final v in batch) v.clientId: v.updatedAt,
        };
        await _db.markVisitsSynced(
          syncedClientIds,
          expectedUpdatedAtByClientId: expectedUpdatedAt,
        );
        totalPushed += batch.length;
      } catch (batchErr) {
        debugPrint(
          'VisitSyncService: batch upsert failed ($batchErr), retrying per-row...',
        );
        // Fallback: kirim ulang satu per satu agar 1 baris gagal tidak memblokir baris lain
        for (final visit in batch) {
          try {
            await _gateway.upsertBatch([visit.toSupabaseJson(userId: userId)]);
            await _db.markVisitsSynced(
              [visit.clientId],
              expectedUpdatedAtByClientId: {visit.clientId: visit.updatedAt},
            );
            totalPushed++;
          } catch (rowErr) {
            debugPrint(
              'VisitSyncService: push row ${visit.clientId} error: $rowErr',
            );
            errors.add('${visit.clientId}: $rowErr');
          }
        }
      }
    }

    return VisitSyncResult(
      pushedCount: totalPushed,
      errorMessage: errors.isEmpty ? null : errors.join('; '),
    );
  }

  /// Restore: bila tabel lokal untuk user aktif kosong (ganti HP / instal ulang) dan user approved,
  /// ambil baris milik sendiri (`user_id = auth.uid()`, `deleted_at is null`) secara berhalaman
  /// menggunakan `.range()` sampai halaman terakhir < `restorePageSize`, lalu simpan ke SQLite
  /// dengan `sync_state = 1` dan `owner_user_id = userId`.
  Future<VisitSyncResult> restoreIfLocalEmpty({required bool isApproved}) async {
    if (!_canSync(isApproved: isApproved)) {
      return const VisitSyncResult(skippedByGuard: true);
    }

    final userId = _gateway.currentUserId!;
    await _db.isolateVisitsForUser(userId);
    final hasLocal = await _db.hasAnyLocalVisits(ownerUserId: userId);
    if (hasLocal) {
      return const VisitSyncResult(restoredCount: 0);
    }

    try {
      int restored = 0;
      int page = 0;
      while (true) {
        final fromIdx = page * restorePageSize;
        final toIdx = fromIdx + restorePageSize - 1;
        final remoteRows = await _gateway.fetchActiveOwnedVisits(
          userId,
          fromIndex: fromIdx,
          toIndex: toIdx,
        );

        for (final row in remoteRows) {
          final visit = VisitActivity.fromSupabaseJson(row).copyWith(
            ownerUserId: userId,
          );
          if (visit.clientId.isNotEmpty && !visit.deleted) {
            await _db.upsertRestoredVisit(visit);
            restored++;
          }
        }

        if (remoteRows.length < restorePageSize) {
          break;
        }
        page++;
      }
      return VisitSyncResult(restoredCount: restored);
    } catch (e) {
      debugPrint('VisitSyncService: restoreIfLocalEmpty error: $e');
      return VisitSyncResult(errorMessage: e.toString());
    }
  }

  /// Jalankan Restore (bila lokal kosong) diikuti Push antrean pending.
  Future<VisitSyncResult> syncAll({required bool isApproved}) async {
    if (!_canSync(isApproved: isApproved)) {
      return const VisitSyncResult(skippedByGuard: true);
    }

    final restoreRes = await restoreIfLocalEmpty(isApproved: isApproved);
    final pushRes = await pushPendingVisits(isApproved: isApproved);

    return VisitSyncResult(
      pushedCount: pushRes.pushedCount,
      restoredCount: restoreRes.restoredCount,
      errorMessage: pushRes.errorMessage ?? restoreRes.errorMessage,
    );
  }
}
