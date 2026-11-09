import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/supabase_client.dart';
import '../../core/config/supabase_config.dart';
import '../local/database_helper.dart';
import '../models/master_customer.dart';

/// Baris rekap kepatuhan RVAI per sales dari RPC `get_rvai_compliance`.
class RvaiComplianceRow {
  final String salesName;
  final String spvName;
  final String tscName;
  final int dueTotal;
  final int visitedTotal;

  const RvaiComplianceRow({
    required this.salesName,
    this.spvName = '',
    this.tscName = '',
    required this.dueTotal,
    required this.visitedTotal,
  });

  int get pendingTotal => (dueTotal - visitedTotal).clamp(0, dueTotal);

  double get complianceRate => dueTotal == 0 ? 1.0 : visitedTotal / dueTotal;

  factory RvaiComplianceRow.fromJson(Map<String, dynamic> json) {
    return RvaiComplianceRow(
      salesName: (json['sales_name'] as String? ?? '').trim(),
      spvName: (json['spv_name'] as String? ?? '').trim(),
      tscName: (json['tsc_name'] as String? ?? '').trim(),
      dueTotal: (json['due_total'] as num?)?.toInt() ?? 0,
      visitedTotal: (json['visited_total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Hasil operasi sinkronisasi `customer_master` ke `customer_master_local`.
class CustomerMasterSyncResult {
  final int syncedCount;
  final int pagesFetched;
  final bool skippedByGuard;
  final bool hasError;
  final String? errorMessage;

  const CustomerMasterSyncResult({
    this.syncedCount = 0,
    this.pagesFetched = 0,
    this.skippedByGuard = false,
    this.hasError = false,
    this.errorMessage,
  });
}

/// Abstraksi gateway remote untuk `CustomerMasterService` agar mudah di-fake dalam unit test.
abstract class CustomerMasterRemoteGateway {
  String? get currentUserId;

  Future<List<Map<String, dynamic>>> fetchSalesNamesRpc();

  Future<String> claimSalesNameRpc(String salesName);

  Future<List<Map<String, dynamic>>> fetchCustomerMasterPage({
    required int fromIndex,
    required int toIndex,
  });

  Future<Map<String, dynamic>?> fetchMasterStatusRpc();

  Future<List<Map<String, dynamic>>> fetchRvaiComplianceRpc({
    required String fromDate,
    required String toDate,
  });
}

/// Implementasi gateway ke Supabase menggunakan `SupabaseClient`.
class SupabaseCustomerMasterGateway implements CustomerMasterRemoteGateway {
  static const Duration timeout = Duration(seconds: 12);
  final SupabaseClient? _injectedClient;

  const SupabaseCustomerMasterGateway([this._injectedClient]);

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
  Future<List<Map<String, dynamic>>> fetchSalesNamesRpc() async {
    final res = await _client.rpc('list_master_sales_names').timeout(timeout);
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  @override
  Future<String> claimSalesNameRpc(String salesName) async {
    final res = await _client
        .rpc('claim_sales_name', params: {'p_sales_name': salesName.trim()})
        .timeout(timeout);
    return res?.toString() ?? 'error';
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCustomerMasterPage({
    required int fromIndex,
    required int toIndex,
  }) async {
    final res = await _client
        .from('customer_master')
        .select(
          'customer_id, install_date, address, package_name, latitude, longitude, sales_name, spv_name, tsc_name',
        )
        .order('customer_id', ascending: true)
        .range(fromIndex, toIndex)
        .timeout(timeout);

    return (res as List<dynamic>)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchMasterStatusRpc() async {
    final res = await _client.rpc('get_master_status').timeout(timeout);
    if (res is List && res.isNotEmpty && res.first is Map) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRvaiComplianceRpc({
    required String fromDate,
    required String toDate,
  }) async {
    final res = await _client
        .rpc(
          'get_rvai_compliance',
          params: {'from_date': fromDate, 'to_date': toDate},
        )
        .timeout(timeout);
    if (res is List) {
      return res
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }
}

/// Service untuk sinkronisasi Master Pelanggan KCLP, klaim nama sales, dan status master.
class CustomerMasterService {
  static const int pageSize = 1000;
  static const Duration autoSyncInterval = Duration(hours: 12);
  static const String lastSyncPrefPrefix = 'customer_master_last_sync_';

  static const Set<String> validClaimStatuses = {
    'success',
    'unauthorized',
    'invalid_name',
    'not_found',
    'already_claimed',
    'already_set',
    'error',
  };

  final DatabaseHelper _db;
  final CustomerMasterRemoteGateway _gateway;
  final bool? isConfiguredOverride;

  CustomerMasterService({
    DatabaseHelper? databaseHelper,
    SupabaseClient? supabaseClient,
    CustomerMasterRemoteGateway? remoteGateway,
    this.isConfiguredOverride,
  }) : _db = databaseHelper ?? DatabaseHelper.instance,
       _gateway =
           remoteGateway ?? SupabaseCustomerMasterGateway(supabaseClient);

  bool get _isConfigured {
    if (isConfiguredOverride != null) return isConfiguredOverride!;
    return SupabaseConfig.isConfigured && AppSupabase.isInitialized;
  }

  String? get currentAuthUserId {
    if (!_isConfigured) return null;
    final uid = _gateway.currentUserId?.trim() ?? '';
    return uid.isEmpty ? null : uid;
  }

  /// Normalisasi status hasil RPC `claim_sales_name`.
  static String parseClaimStatus(dynamic rawStatus) {
    if (rawStatus == null) return 'error';
    final normalized = rawStatus.toString().trim().toLowerCase();
    if (validClaimStatuses.contains(normalized)) {
      return normalized;
    }
    return 'error';
  }

  /// Mengambil daftar nama sales unik dari `customer_master` via RPC `list_master_sales_names`.
  Future<List<MasterSalesNameOption>> fetchSalesNames() async {
    if (!_isConfigured) return const [];
    try {
      final rows = await _gateway.fetchSalesNamesRpc();
      return rows
          .map((r) => MasterSalesNameOption.fromJson(r))
          .where((o) => o.salesName.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('CustomerMasterService.fetchSalesNames error: $e');
      return const [];
    }
  }

  /// Mengklaim nama sales untuk akun sendiri sekali saja via RPC `claim_sales_name`.
  /// Mengembalikan salah satu: `success|unauthorized|invalid_name|not_found|already_claimed|already_set|error`.
  Future<String> claimSalesName(String name) async {
    if (!_isConfigured) return 'error';
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'invalid_name';
    try {
      final raw = await _gateway.claimSalesNameRpc(trimmed);
      return parseClaimStatus(raw);
    } catch (e) {
      debugPrint('CustomerMasterService.claimSalesName error: $e');
      return 'error';
    }
  }

  Future<DateTime?> getLastSyncTime(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString('$lastSyncPrefPrefix$userId');
      if (iso == null || iso.isEmpty) return null;
      return DateTime.tryParse(iso);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveLastSyncTime(String userId, DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$lastSyncPrefPrefix$userId',
        time.toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  Future<bool> shouldAutoSync(String userId, {DateTime? now}) async {
    final last = await getLastSyncTime(userId);
    if (last == null) return true;
    final current = now ?? DateTime.now().toUtc();
    return current.difference(last.toUtc()) >= autoSyncInterval;
  }

  /// Mengunduh baris `customer_master` yang diizinkan RLS secara berhalaman (1000 baris per halaman)
  /// menggunakan `.range()`, lalu mengganti isi `customer_master_local` milik `owner_user_id`
  /// secara atomik dalam satu transaksi.
  /// Berhenti diam-diam bila `!SupabaseConfig.isConfigured`, belum login, atau status bukan approved.
  Future<CustomerMasterSyncResult> syncMyCustomers({
    bool isApproved = true,
    int pageLimit = pageSize,
  }) async {
    if (!_isConfigured || !isApproved) {
      return const CustomerMasterSyncResult(skippedByGuard: true);
    }

    final userId = _gateway.currentUserId?.trim() ?? '';
    if (userId.isEmpty) {
      return const CustomerMasterSyncResult(skippedByGuard: true);
    }

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final allCustomers = <MasterCustomer>[];
      int offset = 0;
      int pages = 0;

      while (true) {
        final rows = await _gateway.fetchCustomerMasterPage(
          fromIndex: offset,
          toIndex: offset + pageLimit - 1,
        );
        pages++;
        for (final row in rows) {
          final parsed = MasterCustomer.fromSupabaseJson(
            row,
            ownerUserId: userId,
            syncedAt: nowIso,
          );
          if (parsed.customerId.isNotEmpty) {
            allCustomers.add(parsed);
          }
        }
        if (rows.length < pageLimit) {
          break;
        }
        offset += pageLimit;
      }

      await _db.replaceMasterCustomersForOwner(userId, allCustomers);
      await _saveLastSyncTime(userId, DateTime.now().toUtc());

      return CustomerMasterSyncResult(
        syncedCount: allCustomers.length,
        pagesFetched: pages,
      );
    } catch (e) {
      debugPrint('CustomerMasterService.syncMyCustomers error: $e');
      return CustomerMasterSyncResult(hasError: true, errorMessage: '$e');
    }
  }

  /// Menjalankan sinkronisasi otomatis bila sudah melewati interval 12 jam sejak sync terakhir.
  Future<CustomerMasterSyncResult> syncIfStale({
    required bool isApproved,
  }) async {
    if (!_isConfigured || !isApproved) {
      return const CustomerMasterSyncResult(skippedByGuard: true);
    }
    final userId = _gateway.currentUserId?.trim() ?? '';
    if (userId.isEmpty) {
      return const CustomerMasterSyncResult(skippedByGuard: true);
    }
    final localCount = await _db.countMasterCustomers(ownerUserId: userId);
    final stale = await shouldAutoSync(userId);
    if (localCount > 0 && !stale) {
      return CustomerMasterSyncResult(syncedCount: localCount);
    }
    return syncMyCustomers(isApproved: isApproved);
  }

  /// Mengambil status impor terakhir untuk Panel SuperAdmin (`get_master_status`).
  Future<MasterStatusSummary?> fetchMasterStatus() async {
    if (!_isConfigured) return null;
    try {
      final map = await _gateway.fetchMasterStatusRpc();
      if (map == null) return null;
      return MasterStatusSummary.fromJson(map);
    } catch (e) {
      debugPrint('CustomerMasterService.fetchMasterStatus error: $e');
      return null;
    }
  }

  /// Mengambil ringkasan kepatuhan RVAI per sales untuk layar Rekap Tim (`get_rvai_compliance`).
  Future<List<RvaiComplianceRow>> fetchRvaiCompliance({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    if (!_isConfigured) return const [];
    try {
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final rows = await _gateway.fetchRvaiComplianceRpc(
        fromDate: fmt(fromDate),
        toDate: fmt(toDate),
      );
      return rows.map((r) => RvaiComplianceRow.fromJson(r)).toList();
    } catch (e) {
      debugPrint('CustomerMasterService.fetchRvaiCompliance error: $e');
      return const [];
    }
  }
}

