import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/supabase_client.dart';
import '../../core/config/supabase_config.dart';
import '../local/database_helper.dart';
import '../models/visit_activity.dart';
import '../models/visit_form_response.dart';

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

  /// Mengambil baris milik sendiri (`user_id = userId`) yang `form_submitted = true`
  /// dan `updated_at > sinceIso` (atau semua bila `sinceIso == null`).
  Future<List<Map<String, dynamic>>> fetchSubmittedOwnedVisits(
    String userId, {
    String? sinceIso,
  }) async => const [];

  /// Mengambil jawaban Google Form untuk satu visit berdasarkan `client_id` + `user_id`
  /// atau `remote_visit_id` lewat RPC `get_form_response_for_visit`.
  Future<Map<String, dynamic>?> fetchFormResponseForVisit({
    required String clientId,
    String? ownerUserId,
    String? remoteVisitId,
  }) async => null;
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

  @override
  Future<List<Map<String, dynamic>>> fetchSubmittedOwnedVisits(
    String userId, {
    String? sinceIso,
  }) async {
    var query = _client
        .from('visit_activities')
        .select('client_id, status, visited_at, form_submitted, updated_at')
        .eq('user_id', userId)
        .eq('form_submitted', true)
        .isFilter('deleted_at', null);

    if (sinceIso != null && sinceIso.trim().isNotEmpty) {
      query = query.gt('updated_at', sinceIso.trim());
    }

    final response = await query
        .order('updated_at', ascending: true)
        .limit(500)
        .timeout(const Duration(seconds: 10));

    return (response as List<dynamic>)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchFormResponseForVisit({
    required String clientId,
    String? ownerUserId,
    String? remoteVisitId,
  }) async {
    String? visitUuid = remoteVisitId?.trim();
    if (visitUuid == null || visitUuid.isEmpty) {
      final uid = (ownerUserId?.trim().isNotEmpty == true)
          ? ownerUserId!.trim()
          : (currentUserId ?? '');
      var q = _client
          .from('visit_activities')
          .select('id')
          .eq('client_id', clientId.trim());
      if (uid.isNotEmpty) {
        q = q.eq('user_id', uid);
      }
      final rows = await q.limit(1).timeout(const Duration(seconds: 10));
      if (rows.isNotEmpty) {
        visitUuid = rows.first['id']?.toString();
      }
    }

    if (visitUuid == null || visitUuid.isEmpty) return null;

    final res = await _client
        .rpc('get_form_response_for_visit', params: {'p_visit_id': visitUuid})
        .timeout(const Duration(seconds: 10));
    if (res is List && res.isNotEmpty && res.first is Map) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return null;
  }
}

/// Hasil eksekusi sinkronisasi aktivitas visit
class VisitSyncResult {
  final int pulledFormCount;
  final int pushedCount;
  final int restoredCount;
  final bool skippedByGuard;
  final String? errorMessage;

  const VisitSyncResult({
    this.pulledFormCount = 0,
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
  static const String lastFormPullPrefPrefix = 'visit_form_status_last_pull_';

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

  Future<String?> _getLastFormPullIso(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$lastFormPullPrefPrefix$userId');
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLastFormPullIso(String userId, String iso) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$lastFormPullPrefPrefix$userId', iso);
    } catch (_) {}
  }

  /// Fase 9D: Menarik status `form_submitted = true` milik sendiri dari server yang `updated_at`
  /// lebih baru dari penanda tarik terakhir, lalu memperbarui baris lokal yang cocok berdasarkan
  /// `client_id` **tanpa** menandai `sync_state = 0`.
  Future<VisitSyncResult> pullFormStatus({required bool isApproved}) async {
    if (!_canSync(isApproved: isApproved)) {
      return const VisitSyncResult(skippedByGuard: true);
    }

    final userId = _gateway.currentUserId!;
    try {
      final sinceIso = await _getLastFormPullIso(userId);
      final rows = await _gateway.fetchSubmittedOwnedVisits(
        userId,
        sinceIso: sinceIso,
      );
      if (rows.isEmpty) {
        return const VisitSyncResult(pulledFormCount: 0);
      }

      int updatedLocal = 0;
      String? newestUpdatedAt = sinceIso;

      for (final row in rows) {
        final cid = (row['client_id'] as String? ?? '').trim();
        if (cid.isEmpty) continue;

        final serverStatus = VisitStatus.fromString(row['status'] as String?);
        final serverVisitedAt = row['visited_at'] as String?;
        final rowUpdatedAt = row['updated_at'] as String?;

        final applied = await _db.applyPulledFormStatus(
          clientId: cid,
          serverStatus: serverStatus,
          serverVisitedAt: serverVisitedAt,
        );
        if (applied) {
          updatedLocal++;
        }

        if (rowUpdatedAt != null && rowUpdatedAt.trim().isNotEmpty) {
          if (newestUpdatedAt == null ||
              rowUpdatedAt.compareTo(newestUpdatedAt) > 0) {
            newestUpdatedAt = rowUpdatedAt;
          }
        }
      }

      if (newestUpdatedAt != null && newestUpdatedAt.isNotEmpty) {
        await _saveLastFormPullIso(userId, newestUpdatedAt);
      }

      return VisitSyncResult(pulledFormCount: updatedLocal);
    } catch (e) {
      debugPrint('VisitSyncService.pullFormStatus error: $e');
      return VisitSyncResult(errorMessage: e.toString());
    }
  }

  /// Mengambil jawaban Google Form untuk satu visit via RPC `get_form_response_for_visit`.
  Future<VisitFormResponse?> fetchFormResponseForVisit({
    required String clientId,
    String? ownerUserId,
    String? remoteVisitId,
  }) async {
    if (!_isSupabaseConfigured) return null;
    try {
      final map = await _gateway.fetchFormResponseForVisit(
        clientId: clientId,
        ownerUserId: ownerUserId,
        remoteVisitId: remoteVisitId,
      );
      if (map == null) return null;
      return VisitFormResponse.fromJson(map);
    } catch (e) {
      debugPrint('VisitSyncService.fetchFormResponseForVisit error: $e');
      return null;
    }
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

  /// Jalankan Restore (bila lokal kosong), lalu **Tarik (`pullFormStatus`) dulu baru Dorong (`pushPendingVisits`)**
  /// agar status Form dari server tidak tertimpa oleh antrean lokal.
  Future<VisitSyncResult> syncAll({required bool isApproved}) async {
    if (!_canSync(isApproved: isApproved)) {
      return const VisitSyncResult(skippedByGuard: true);
    }

    final restoreRes = await restoreIfLocalEmpty(isApproved: isApproved);
    final pullRes = await pullFormStatus(isApproved: isApproved);
    final pushRes = await pushPendingVisits(isApproved: isApproved);

    return VisitSyncResult(
      pulledFormCount: pullRes.pulledFormCount,
      pushedCount: pushRes.pushedCount,
      restoredCount: restoreRes.restoredCount,
      errorMessage:
          pushRes.errorMessage ?? pullRes.errorMessage ?? restoreRes.errorMessage,
    );
  }
}
