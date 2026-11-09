import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers/auth_providers.dart';
import '../core/constants/visit_constants.dart';
import '../data/local/database_helper.dart';
import '../data/models/master_customer.dart';
import '../data/services/customer_master_import_service.dart';
import '../data/services/customer_master_service.dart';
import 'visit_provider.dart';

/// Provider untuk instance `CustomerMasterService`.
final customerMasterServiceProvider = Provider<CustomerMasterService>((ref) {
  return CustomerMasterService();
});

/// Provider untuk instance `CustomerMasterImportService` (Khusus SuperAdmin).
final customerMasterImportServiceProvider =
    Provider<CustomerMasterImportService>((ref) {
      return CustomerMasterImportService();
    });

/// Callback pemilih file KMZ/KML yang hanya mengembalikan bytes di memori
/// (tidak pernah menyalin/menyimpan file ke disk aplikasi).
/// Dapat di-override pada widget test.
typedef PickMasterImportBytesCallback = Future<Uint8List?> Function();

final pickMasterImportBytesProvider = Provider<PickMasterImportBytesCallback>((
  ref,
) {
  return () async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['kmz', 'kml'],
    );
    if (picked == null) return null;
    return picked.readAsBytes();
  };
});

/// Provider untuk membaca `sales_name` milik akun yang sedang aktif.
final mySalesNameProvider = Provider<String?>((ref) {
  final gateState = ref.watch(accessGateProvider);
  if (gateState != GateState.approved) return null;
  return ref.watch(accessGateProvider.notifier).currentSalesName;
});

/// State sinkronisasi Master Pelanggan lokal.
class MasterSyncState {
  final bool isSyncing;
  final int localCount;
  final DateTime? lastSyncTime;
  final String? lastError;
  final int revision;

  const MasterSyncState({
    this.isSyncing = false,
    this.localCount = 0,
    this.lastSyncTime,
    this.lastError,
    this.revision = 0,
  });

  MasterSyncState copyWith({
    bool? isSyncing,
    int? localCount,
    DateTime? lastSyncTime,
    String? lastError,
    bool clearError = false,
    int? revision,
  }) {
    return MasterSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      localCount: localCount ?? this.localCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: clearError ? null : (lastError ?? this.lastError),
      revision: revision ?? this.revision,
    );
  }
}

class MasterSyncNotifier extends StateNotifier<MasterSyncState> {
  final Ref _ref;
  final DatabaseHelper _db;

  MasterSyncNotifier(this._ref, [DatabaseHelper? db])
    : _db = db ?? DatabaseHelper.instance,
      super(const MasterSyncState()) {
    refreshLocalCount();
  }

  Future<void> refreshLocalCount() async {
    final service = _ref.read(customerMasterServiceProvider);
    final ownerId = service.currentAuthUserId;
    final count = await _db.countMasterCustomers(ownerUserId: ownerId);
    DateTime? lastSync;
    if (ownerId != null) {
      lastSync = await service.getLastSyncTime(ownerId);
    }
    if (!mounted) return;
    state = state.copyWith(
      localCount: count,
      lastSyncTime: lastSync,
      revision: state.revision + 1,
    );
  }

  /// Sinkronisasi manual ("Perbarui Data Pelanggan") atau paksa unduh ulang.
  Future<CustomerMasterSyncResult> syncNow() async {
    final gateState = _ref.read(accessGateProvider);
    final isApproved = gateState == GateState.approved;
    final service = _ref.read(customerMasterServiceProvider);

    state = state.copyWith(isSyncing: true, clearError: true);
    final res = await service.syncMyCustomers(isApproved: isApproved);
    await refreshLocalCount();
    if (mounted) {
      state = state.copyWith(
        isSyncing: false,
        lastError: res.hasError ? res.errorMessage : null,
      );
    }
    return res;
  }

  /// Sinkronisasi otomatis saat app dibuka/resume bila sudah >12 jam.
  Future<CustomerMasterSyncResult> syncIfNeeded() async {
    final gateState = _ref.read(accessGateProvider);
    final isApproved = gateState == GateState.approved;
    final service = _ref.read(customerMasterServiceProvider);

    state = state.copyWith(isSyncing: true, clearError: true);
    final res = await service.syncIfStale(isApproved: isApproved);
    await refreshLocalCount();
    if (mounted) {
      state = state.copyWith(
        isSyncing: false,
        lastError: res.hasError ? res.errorMessage : null,
      );
    }
    return res;
  }
}

/// Provider utama untuk mengelola sinkronisasi `customer_master_local`.
final masterSyncProvider =
    StateNotifierProvider<MasterSyncNotifier, MasterSyncState>((ref) {
      return MasterSyncNotifier(ref);
    });

/// Pencarian lokal di `customer_master_local` (`customer_id LIKE` atau `address LIKE`, maks 50, urut `install_date DESC`).
final masterSearchProvider =
    FutureProvider.family<List<MasterCustomer>, String>((ref, query) async {
      ref.watch(masterSyncProvider.select((s) => s.revision));
      final service = ref.watch(customerMasterServiceProvider);
      final ownerId = service.currentAuthUserId;
      return DatabaseHelper.instance.searchMasterCustomers(
        query,
        ownerUserId: ownerId,
        limit: 50,
      );
    });

/// Mengambil satu pelanggan berdasarkan `customer_id` dari master lokal.
final masterCustomerByIdProvider =
    FutureProvider.family<MasterCustomer?, String>((ref, customerId) async {
      ref.watch(masterSyncProvider.select((s) => s.revision));
      final trimmed = customerId.trim();
      if (trimmed.isEmpty) return null;
      final service = ref.watch(customerMasterServiceProvider);
      final ownerId = service.currentAuthUserId;
      return DatabaseHelper.instance.getMasterCustomerById(
        trimmed,
        ownerUserId: ownerId,
      );
    });

/// Provider daftar saran RVAI berdasarkan data `customer_master_local` dan `visit_activities`.
final rvaiSuggestionsProvider = FutureProvider<List<RvaiSuggestionItem>>((
  ref,
) async {
  ref.watch(masterSyncProvider.select((s) => s.revision));
  // Ikut merespons perubahan daftar visit lokal
  ref.watch(visitProvider);

  final service = ref.watch(customerMasterServiceProvider);
  final ownerId = service.currentAuthUserId;
  final db = DatabaseHelper.instance;

  final allMaster = await db.getAllMasterCustomers(ownerUserId: ownerId);
  if (allMaster.isEmpty) return const [];

  final existingRvaiIds = await db.getActiveRvaiCustomerIds(
    ownerUserId: ownerId,
  );
  return computeRvaiSuggestions(
    masterCustomers: allMaster,
    existingRvaiCustomerIds: existingRvaiIds,
    today: DateTime.now(),
  );
});

/// Provider status impor Master Pelanggan untuk Panel SuperAdmin (`get_master_status`).
final masterStatusSummaryProvider = FutureProvider<MasterStatusSummary?>((
  ref,
) async {
  final service = ref.watch(customerMasterServiceProvider);
  return service.fetchMasterStatus();
});


