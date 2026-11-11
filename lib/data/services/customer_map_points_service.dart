import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/supabase_client.dart';
import '../../core/config/supabase_config.dart';
import '../local/database_helper.dart';
import '../models/customer_map_point.dart';

/// Hasil operasi sinkronisasi `customer_map_points` ke `customer_map_points_local`.
class CustomerMapPointsSyncResult {
  final int syncedCount;
  final int pagesFetched;
  final bool skippedByGuard;
  final bool hasError;
  final String? errorMessage;

  const CustomerMapPointsSyncResult({
    this.syncedCount = 0,
    this.pagesFetched = 0,
    this.skippedByGuard = false,
    this.hasError = false,
    this.errorMessage,
  });
}

/// Gateway remote untuk `CustomerMapPointsService` agar mudah di-mock dalam pengujian.
abstract class CustomerMapPointsRemoteGateway {
  String? get currentUserId;

  Future<List<Map<String, dynamic>>> fetchCustomerMapPointsPage({
    required int fromIndex,
    required int toIndex,
  });
}

class SupabaseCustomerMapPointsGateway
    implements CustomerMapPointsRemoteGateway {
  static const Duration timeout = Duration(seconds: 15);
  final SupabaseClient? _injectedClient;

  const SupabaseCustomerMapPointsGateway([this._injectedClient]);

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
  Future<List<Map<String, dynamic>>> fetchCustomerMapPointsPage({
    required int fromIndex,
    required int toIndex,
  }) async {
    final res = await _client
        .from('customer_map_points')
        .select(
          'customer_id, latitude, longitude, install_date, address, package_name, sales_name, spv_name, tsc_name',
        )
        .order('customer_id', ascending: true)
        .range(fromIndex, toIndex)
        .timeout(timeout);

    return (res as List<dynamic>)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

/// Layanan sinkronisasi titik pelanggan terpasang dari Supabase ke SQLite lokal.
class CustomerMapPointsService {
  static const int pageSize = 1000;
  static const Duration autoSyncInterval = Duration(hours: 24);
  static const String lastSyncPrefKey = 'customer_map_points_last_sync';

  final DatabaseHelper _db;
  final CustomerMapPointsRemoteGateway _gateway;
  final bool? _isConfiguredOverride;

  CustomerMapPointsService({
    DatabaseHelper? databaseHelper,
    CustomerMapPointsRemoteGateway? remoteGateway,
    this._isConfiguredOverride,
  })  : _db = databaseHelper ?? DatabaseHelper.instance,
        _gateway = remoteGateway ?? const SupabaseCustomerMapPointsGateway();

  bool get _isConfigured =>
      _isConfiguredOverride ??
      (SupabaseConfig.isConfigured && AppSupabase.isInitialized);

  String? get currentAuthUserId => _gateway.currentUserId;

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(lastSyncPrefKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> _saveLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastSyncPrefKey, time.toUtc().toIso8601String());
  }

  Future<bool> shouldAutoSync({DateTime? now}) async {
    final last = await getLastSyncTime();
    if (last == null) return true;
    final current = now ?? DateTime.now().toUtc();
    return current.difference(last) >= autoSyncInterval;
  }

  /// Sinkronisasi penuh secara atomik (unduh per 1.000 baris, ganti seluruh isi lokal).
  Future<CustomerMapPointsSyncResult> syncAll({
    required bool isApproved,
    int pageLimit = pageSize,
  }) async {
    if (!_isConfigured || !isApproved) {
      return const CustomerMapPointsSyncResult(skippedByGuard: true);
    }

    final userId = _gateway.currentUserId?.trim() ?? '';
    if (userId.isEmpty) {
      return const CustomerMapPointsSyncResult(skippedByGuard: true);
    }

    try {
      final List<CustomerMapPoint> allPoints = [];
      int offset = 0;
      int pages = 0;
      final nowIso = DateTime.now().toUtc().toIso8601String();

      while (true) {
        final rows = await _gateway.fetchCustomerMapPointsPage(
          fromIndex: offset,
          toIndex: offset + pageLimit - 1,
        );
        pages++;
        for (final row in rows) {
          final parsed = CustomerMapPoint.fromSupabaseJson(
            row,
            syncedAt: nowIso,
          );
          if (parsed.customerId.isNotEmpty &&
              parsed.latitude != 0.0 &&
              parsed.longitude != 0.0) {
            allPoints.add(parsed);
          }
        }
        if (rows.length < pageLimit) {
          break;
        }
        offset += pageLimit;
      }

      await _db.replaceCustomerMapPoints(allPoints);
      await _saveLastSyncTime(DateTime.now().toUtc());

      return CustomerMapPointsSyncResult(
        syncedCount: allPoints.length,
        pagesFetched: pages,
      );
    } catch (e) {
      debugPrint('CustomerMapPointsService.syncAll error: $e');
      return CustomerMapPointsSyncResult(hasError: true, errorMessage: '$e');
    }
  }

  /// Menjalankan sinkronisasi otomatis bila data lokal kosong atau sudah > 24 jam.
  Future<CustomerMapPointsSyncResult> syncIfStale({
    required bool isApproved,
  }) async {
    if (!_isConfigured || !isApproved) {
      return const CustomerMapPointsSyncResult(skippedByGuard: true);
    }
    final localCount = await _db.countCustomerMapPoints();
    final stale = await shouldAutoSync();
    if (localCount > 0 && !stale) {
      return CustomerMapPointsSyncResult(syncedCount: localCount);
    }
    return syncAll(isApproved: isApproved);
  }

  /// Menghapus seluruh titik lokal dan preferensi waktu sinkron.
  Future<void> clearLocalPoints() async {
    await _db.clearAllCustomerMapPoints();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(lastSyncPrefKey);
  }
}
