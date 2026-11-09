import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/supabase_client.dart';
import '../../core/config/supabase_config.dart';
import '../local/database_helper.dart';
import '../models/incentive_record.dart';
import '../models/sa_record.dart';

/// Status persetujuan pencadangan online (`backup_consent_v1`).
enum BackupConsentStatus {
  unset('unset'),
  granted('granted'),
  declined('declined');

  final String value;
  const BackupConsentStatus(this.value);

  static BackupConsentStatus fromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'granted':
        return BackupConsentStatus.granted;
      case 'declined':
        return BackupConsentStatus.declined;
      default:
        return BackupConsentStatus.unset;
    }
  }
}

/// Hasil eksekusi operasi sinkronisasi cadangan Data SA & Riwayat Insentif.
class BackupSyncResult {
  final int pushedSaCount;
  final int pushedIncentiveCount;
  final int restoredSaCount;
  final int restoredIncentiveCount;
  final bool skippedByGuard;
  final bool hasError;
  final String? errorCode;

  const BackupSyncResult({
    this.pushedSaCount = 0,
    this.pushedIncentiveCount = 0,
    this.restoredSaCount = 0,
    this.restoredIncentiveCount = 0,
    this.skippedByGuard = false,
    this.hasError = false,
    this.errorCode,
  });
}

/// Abstraksi gateway Supabase untuk `sa_customers` dan `incentive_records`
/// agar dapat diuji 100% offline dengan fake gateway di unit test.
abstract class BackupRemoteGateway {
  String? get currentUserId;

  Future<void> upsertSaBatch(List<Map<String, dynamic>> payload);

  Future<void> upsertIncentiveBatch(List<Map<String, dynamic>> payload);

  Future<List<Map<String, dynamic>>> fetchOwnSaPage({
    required String userId,
    required int from,
    required int to,
  });

  Future<List<Map<String, dynamic>>> fetchOwnIncentivePage({
    required String userId,
    required int from,
    required int to,
  });
}

/// Implementasi produksi [BackupRemoteGateway] menggunakan [SupabaseClient].
class SupabaseBackupRemoteGateway implements BackupRemoteGateway {
  final SupabaseClient? _injectedClient;

  const SupabaseBackupRemoteGateway([this._injectedClient]);

  SupabaseClient get _client => _injectedClient ?? AppSupabase.client;

  @override
  String? get currentUserId {
    if (_injectedClient == null && !AppSupabase.isInitialized) return null;
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> upsertSaBatch(List<Map<String, dynamic>> payload) async {
    await _client
        .from('sa_customers')
        .upsert(payload, onConflict: 'user_id,client_id')
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<void> upsertIncentiveBatch(List<Map<String, dynamic>> payload) async {
    await _client
        .from('incentive_records')
        .upsert(payload, onConflict: 'user_id,client_id')
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwnSaPage({
    required String userId,
    required int from,
    required int to,
  }) async {
    final res = await _client
        .from('sa_customers')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false)
        .range(from, to)
        .timeout(const Duration(seconds: 20));
    return (res as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchOwnIncentivePage({
    required String userId,
    required int from,
    required int to,
  }) async {
    final res = await _client
        .from('incentive_records')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false)
        .range(from, to)
        .timeout(const Duration(seconds: 20));
    return (res as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

/// Layanan sinkronisasi cadangan online Data SA (`sa_history` ➔ `public.sa_customers`)
/// dan Riwayat Insentif (`history` ➔ `public.incentive_records`).
///
/// Mematuhi aturan keras Fase 11:
/// - Tidak mengirim apa pun sebelum sales menyetujui (`backup_consent_v1 == 'granted'`).
/// - Tidak pernah mencatat isi data pelanggan (nama, nomor HP, alamat) ke log.
/// - Push dalam batch maks 50 baris secara idempoten (`onConflict: 'user_id,client_id'`).
/// - Restore berhalaman 1000 baris bila tabel lokal kosong.
class BackupSyncService {
  static const String prefConsentKey = 'backup_consent_v1';
  static const String prefDeclinedAtKey = 'backup_consent_declined_at';
  static const String prefLastSyncAtKey = 'backup_last_sync_at';

  static const int maxPushBatchSize = 50;
  static const int restorePageSize = 1000;
  static const Duration rePromptCooldown = Duration(days: 7);

  final DatabaseHelper _db;
  final BackupRemoteGateway _gateway;
  final bool? isConfiguredOverride;

  bool _isSyncing = false;

  BackupSyncService({
    DatabaseHelper? databaseHelper,
    SupabaseClient? supabaseClient,
    BackupRemoteGateway? remoteGateway,
    this.isConfiguredOverride,
  }) : _db = databaseHelper ?? DatabaseHelper.instance,
       _gateway = remoteGateway ?? SupabaseBackupRemoteGateway(supabaseClient);

  bool get isConfigured {
    if (isConfiguredOverride != null) return isConfiguredOverride!;
    return SupabaseConfig.isConfigured && AppSupabase.isInitialized;
  }

  bool get _isConfigured => isConfigured;

  String? get currentAuthUserId {
    if (!_isConfigured) return null;
    final uid = _gateway.currentUserId?.trim() ?? '';
    return uid.isEmpty ? null : uid;
  }

  /// Membaca status persetujuan cadangan dari `SharedPreferences`.
  Future<BackupConsentStatus> getConsentStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return BackupConsentStatus.fromString(prefs.getString(prefConsentKey));
    } catch (_) {
      return BackupConsentStatus.unset;
    }
  }

  /// Menyimpan persetujuan `granted` ketika sales menekan tombol **Sinkronkan** atau mengaktifkan saklar.
  Future<void> setConsentGranted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefConsentKey, BackupConsentStatus.granted.value);
    await prefs.remove(prefDeclinedAtKey);
  }

  /// Menyimpan status `declined` ketika sales menekan **Nanti** atau mematikan saklar.
  Future<void> setConsentDeclined([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final ts = (now ?? DateTime.now()).toUtc().toIso8601String();
    await prefs.setString(prefConsentKey, BackupConsentStatus.declined.value);
    await prefs.setString(prefDeclinedAtKey, ts);
  }

  /// Menentukan apakah dialog persetujuan perlu ditampilkan:
  /// - Hanya bila ada data lokal (`hasLocalData == true`), dan
  /// - Status masih `unset`, ATAU `declined` sudah melewati masa tunda 7 hari.
  Future<bool> shouldPromptConsent({
    required bool hasLocalData,
    DateTime? now,
  }) async {
    if (!hasLocalData) return false;
    final status = await getConsentStatus();
    if (status == BackupConsentStatus.granted) return false;
    if (status == BackupConsentStatus.unset) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawDeclined = prefs.getString(prefDeclinedAtKey);
      if (rawDeclined == null || rawDeclined.trim().isEmpty) return true;
      final declinedAt = DateTime.tryParse(rawDeclined.trim());
      if (declinedAt == null) return true;
      final current = (now ?? DateTime.now()).toUtc();
      return current.difference(declinedAt.toUtc()) >= rePromptCooldown;
    } catch (_) {
      return false;
    }
  }

  /// Membaca waktu sinkronisasi terakhir dari `SharedPreferences`.
  Future<DateTime?> getLastSyncAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefLastSyncAtKey);
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _recordLastSyncNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        prefLastSyncAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  /// Push seluruh baris `sync_state = 0` dari `sa_history` dan `history` ke Supabase
  /// dalam batch maks 50 baris.
  ///
  /// Berhenti diam-diam bila belum dikonfigurasi, belum login, bukan `approved`,
  /// atau persetujuan belum `granted`.
  Future<BackupSyncResult> pushPending({
    required bool isMemberApproved,
  }) async {
    final uid = currentAuthUserId;
    if (!_isConfigured || uid == null || !isMemberApproved) {
      return const BackupSyncResult(skippedByGuard: true);
    }

    final consent = await getConsentStatus();
    if (consent != BackupConsentStatus.granted) {
      return const BackupSyncResult(skippedByGuard: true);
    }

    if (_isSyncing) {
      return const BackupSyncResult(skippedByGuard: true);
    }

    _isSyncing = true;
    int pushedSa = 0;
    int pushedInc = 0;

    try {
      // 1. Push pending Data SA dalam batch 50
      final pendingSa = await _db.getPendingSaRecords();
      for (int i = 0; i < pendingSa.length; i += maxPushBatchSize) {
        final end = (i + maxPushBatchSize < pendingSa.length)
            ? i + maxPushBatchSize
            : pendingSa.length;
        final chunk = pendingSa.sublist(i, end);
        final payload = chunk
            .map((r) => r.toSupabaseJson(userId: uid))
            .toList();

        await _gateway.upsertSaBatch(payload);
        final syncedIds = chunk.map((r) => r.clientId).toList();
        await _db.markSaRecordsSynced(syncedIds);
        pushedSa += chunk.length;
      }

      // 2. Push pending Riwayat Insentif dalam batch 50
      final pendingInc = await _db.getPendingIncentiveRecords();
      for (int i = 0; i < pendingInc.length; i += maxPushBatchSize) {
        final end = (i + maxPushBatchSize < pendingInc.length)
            ? i + maxPushBatchSize
            : pendingInc.length;
        final chunk = pendingInc.sublist(i, end);
        final payload = chunk
            .map((r) => r.toSupabaseJson(userId: uid))
            .toList();

        await _gateway.upsertIncentiveBatch(payload);
        final syncedIds = chunk.map((r) => r.clientId).toList();
        await _db.markIncentiveRecordsSynced(syncedIds);
        pushedInc += chunk.length;
      }

      await _recordLastSyncNow();
      return BackupSyncResult(
        pushedSaCount: pushedSa,
        pushedIncentiveCount: pushedInc,
      );
    } catch (_) {
      // Jangan pernah mencatat isi data pelanggan di log.
      debugPrint('BackupSyncService: pushPending gagal (kode jaringan/RLS).');
      return BackupSyncResult(
        pushedSaCount: pushedSa,
        pushedIncentiveCount: pushedInc,
        hasError: true,
        errorCode: 'push_failed',
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Memulihkan (restore) data milik sendiri dari Supabase apabila tabel lokal kosong
  /// (misal saat ganti HP atau instal ulang) dan sales telah menyetujui pencadangan.
  Future<BackupSyncResult> restoreIfLocalEmpty({
    required bool isMemberApproved,
  }) async {
    final uid = currentAuthUserId;
    if (!_isConfigured || uid == null || !isMemberApproved) {
      return const BackupSyncResult(skippedByGuard: true);
    }

    final consent = await getConsentStatus();
    if (consent != BackupConsentStatus.granted) {
      return const BackupSyncResult(skippedByGuard: true);
    }

    int restoredSa = 0;
    int restoredInc = 0;

    try {
      // 1. Restore sa_customers bila sa_history lokal kosong
      final existingSa = await _db.getAllSaRecords();
      if (existingSa.isEmpty) {
        final allSa = <SaRecord>[];
        int offset = 0;
        while (true) {
          final page = await _gateway.fetchOwnSaPage(
            userId: uid,
            from: offset,
            to: offset + restorePageSize - 1,
          );
          if (page.isEmpty) break;
          allSa.addAll(page.map((m) => SaRecord.fromSupabaseJson(m)));
          if (page.length < restorePageSize) break;
          offset += restorePageSize;
        }
        if (allSa.isNotEmpty) {
          await _db.upsertSaRecordsFromRemote(allSa);
          restoredSa = allSa.length;
        }
      }

      // 2. Restore incentive_records bila history lokal kosong
      final existingInc = await _db.getAllRecords();
      if (existingInc.isEmpty) {
        final allInc = <IncentiveRecord>[];
        int offset = 0;
        while (true) {
          final page = await _gateway.fetchOwnIncentivePage(
            userId: uid,
            from: offset,
            to: offset + restorePageSize - 1,
          );
          if (page.isEmpty) break;
          allInc.addAll(page.map((m) => IncentiveRecord.fromSupabaseJson(m)));
          if (page.length < restorePageSize) break;
          offset += restorePageSize;
        }
        if (allInc.isNotEmpty) {
          await _db.upsertIncentiveRecordsFromRemote(allInc);
          restoredInc = allInc.length;
        }
      }

      if (restoredSa > 0 || restoredInc > 0) {
        await _recordLastSyncNow();
      }

      return BackupSyncResult(
        restoredSaCount: restoredSa,
        restoredIncentiveCount: restoredInc,
      );
    } catch (_) {
      debugPrint('BackupSyncService: restoreIfLocalEmpty gagal.');
      return BackupSyncResult(
        restoredSaCount: restoredSa,
        restoredIncentiveCount: restoredInc,
        hasError: true,
        errorCode: 'restore_failed',
      );
    }
  }

  /// Menjalankan restore (bila tabel lokal kosong) lalu push antrean pending.
  Future<BackupSyncResult> syncAll({required bool isMemberApproved}) async {
    final restoreRes = await restoreIfLocalEmpty(
      isMemberApproved: isMemberApproved,
    );
    final pushRes = await pushPending(isMemberApproved: isMemberApproved);
    return BackupSyncResult(
      pushedSaCount: pushRes.pushedSaCount,
      pushedIncentiveCount: pushRes.pushedIncentiveCount,
      restoredSaCount: restoreRes.restoredSaCount,
      restoredIncentiveCount: restoreRes.restoredIncentiveCount,
      skippedByGuard: restoreRes.skippedByGuard && pushRes.skippedByGuard,
      hasError: restoreRes.hasError || pushRes.hasError,
      errorCode: pushRes.errorCode ?? restoreRes.errorCode,
    );
  }
}
