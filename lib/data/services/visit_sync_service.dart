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
  Future<List<Map<String, dynamic>>> fetchActiveOwnedVisits(String userId);
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
  Future<List<Map<String, dynamic>>> fetchActiveOwnedVisits(String userId) async {
    final response = await _client
        .from('visit_activities')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .order('planned_date', ascending: false)
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

  final DatabaseHelper _db;
  final VisitRemoteGateway _gateway;
  final bool? isConfiguredOverride;

  VisitSyncService({
    SupabaseClient? supabaseClient,
    VisitRemoteGateway? remoteGateway,
    DatabaseHelper? databaseHelper,
    this.isConfiguredOverride,
  })  : _db = databaseHelper ?? DatabaseHelper.instance,
        _gateway = remoteGateway ?? SupabaseVisitRemoteGateway(supabaseClient);

  bool get _isSupabaseConfigured =>
      isConfiguredOverride ?? (SupabaseConfig.isConfigured && AppSupabase.isInitialized);

  /// Guard wajib: berhenti diam-diam bila Supabase belum dikonfigurasi, belum login,
  /// atau status user bukan approved.
  bool _canSync({required bool isApproved}) {
    if (!_isSupabaseConfigured) return false;
    if (!isApproved) return false;
    final uid = _gateway.currentUserId;
    if (uid == null || uid.trim().isEmpty) return false;
    return true;
  }

  /// Push seluruh baris lokal yang masih `sync_state == 0` dalam batch maks 50.
  /// Soft delete dikirim sebagai `deleted_at`.
  /// Jika gagal karena jaringan atau RLS/revoked, data lokal TIDAK dihapus dan tetap pending.
  Future<VisitSyncResult> pushPendingVisits({required bool isApproved}) async {
    if (!_canSync(isApproved: isApproved)) {
      return const VisitSyncResult(skippedByGuard: true);
    }

    final userId = _gateway.currentUserId!;
    final pending = await _db.getPendingVisits();
    if (pending.isEmpty) {
      return const VisitSyncResult(pushedCount: 0);
    }

    int totalPushed = 0;
    try {
      for (int i = 0; i < pending.length; i += maxBatchSize) {
        final end = (i + maxBatchSize < pending.length)
            ? i + maxBatchSize
            : pending.length;
        final batch = pending.sublist(i, end);

        final payload = batch
            .map((v) => v.toSupabaseJson(userId: userId))
            .toList();

        await _gateway.upsertBatch(payload);

        final syncedClientIds = batch.map((v) => v.clientId).toList();
        await _db.markVisitsSynced(syncedClientIds);
        totalPushed += batch.length;
      }

      return VisitSyncResult(pushedCount: totalPushed);
    } catch (e) {
      debugPrint('VisitSyncService: pushPendingVisits error: $e');
      return VisitSyncResult(
        pushedCount: totalPushed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Restore: bila tabel lokal kosong (ganti HP / instal ulang) dan user approved,
  /// ambil baris milik sendiri (`user_id = auth.uid()`, `deleted_at is null`)
  /// dan simpan ke SQLite dengan `sync_state = 1`.
  Future<VisitSyncResult> restoreIfLocalEmpty({required bool isApproved}) async {
    if (!_canSync(isApproved: isApproved)) {
      return const VisitSyncResult(skippedByGuard: true);
    }

    final hasLocal = await _db.hasAnyLocalVisits();
    if (hasLocal) {
      return const VisitSyncResult(restoredCount: 0);
    }

    final userId = _gateway.currentUserId!;
    try {
      final remoteRows = await _gateway.fetchActiveOwnedVisits(userId);
      int restored = 0;
      for (final row in remoteRows) {
        final visit = VisitActivity.fromSupabaseJson(row);
        if (visit.clientId.isNotEmpty && !visit.deleted) {
          await _db.upsertRestoredVisit(visit);
          restored++;
        }
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
