import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/customer_map_point.dart';
import '../../data/services/customer_map_points_service.dart';

/// Provider untuk instance `CustomerMapPointsService`.
final customerMapPointsServiceProvider =
    Provider<CustomerMapPointsService>((ref) {
      return CustomerMapPointsService();
    });

/// State untuk sinkronisasi titik pelanggan terpasang.
class CustomerMapPointsSyncState {
  final bool isSyncing;
  final int count;
  final DateTime? lastSyncTime;
  final String? errorMessage;
  final int revision;

  const CustomerMapPointsSyncState({
    this.isSyncing = false,
    this.count = 0,
    this.lastSyncTime,
    this.errorMessage,
    this.revision = 0,
  });

  CustomerMapPointsSyncState copyWith({
    bool? isSyncing,
    int? count,
    DateTime? lastSyncTime,
    String? errorMessage,
    bool clearError = false,
    int? revision,
  }) {
    return CustomerMapPointsSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      count: count ?? this.count,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      revision: revision ?? this.revision,
    );
  }

  bool get isLoading => isSyncing;
}

class CustomerMapPointsSyncNotifier
    extends StateNotifier<CustomerMapPointsSyncState> {
  final Ref _ref;
  final DatabaseHelper _db;

  CustomerMapPointsSyncNotifier(this._ref, [DatabaseHelper? db])
      : _db = db ?? DatabaseHelper.instance,
        super(const CustomerMapPointsSyncState()) {
    refreshCount();
  }

  Future<void> refreshCount() async {
    final count = await _db.countCustomerMapPoints();
    final service = _ref.read(customerMapPointsServiceProvider);
    final lastSync = await service.getLastSyncTime();
    if (!mounted) return;
    state = state.copyWith(
      count: count,
      lastSyncTime: lastSync,
      revision: state.revision + 1,
    );
  }

  /// Sinkronisasi manual ("Perbarui titik pelanggan").
  Future<CustomerMapPointsSyncResult> syncNow() async {
    final gateState = _ref.read(accessGateProvider);
    final isApproved = gateState == GateState.approved;
    final service = _ref.read(customerMapPointsServiceProvider);

    state = state.copyWith(isSyncing: true, clearError: true);
    final res = await service.syncAll(isApproved: isApproved);
    await refreshCount();
    if (mounted) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: res.hasError ? res.errorMessage : null,
      );
    }
    return res;
  }

  /// Sinkronisasi otomatis saat peta dibuka bila sudah > 24 jam atau data lokal kosong.
  Future<CustomerMapPointsSyncResult> syncIfNeeded() async {
    final gateState = _ref.read(accessGateProvider);
    final isApproved = gateState == GateState.approved;
    final service = _ref.read(customerMapPointsServiceProvider);

    state = state.copyWith(isSyncing: true, clearError: true);
    final res = await service.syncIfStale(isApproved: isApproved);
    await refreshCount();
    if (mounted) {
      state = state.copyWith(
        isSyncing: false,
        errorMessage: res.hasError ? res.errorMessage : null,
      );
    }
    return res;
  }

  Future<CustomerMapPointsSyncResult> syncAll({bool force = false}) {
    return force ? syncNow() : syncIfNeeded();
  }
}

/// Provider pengelola status sinkronisasi `customer_map_points`.
final customerMapPointsSyncProvider = StateNotifierProvider<
    CustomerMapPointsSyncNotifier, CustomerMapPointsSyncState>((ref) {
  return CustomerMapPointsSyncNotifier(ref);
});

/// Provider seluruh titik pelanggan terpasang dari database SQLite lokal.
final allCustomerMapPointsProvider =
    FutureProvider<List<CustomerMapPoint>>((ref) async {
  ref.watch(customerMapPointsSyncProvider.select((s) => s.revision));
  return DatabaseHelper.instance.getAllCustomerMapPoints();
});

/// State untuk filter layer Pelanggan Terpasang pada Peta Coverage.
class CustomerMapPointsFilterState {
  final String? selectedSales;
  final String? selectedSpv;
  final Set<InstallMonthCategory> enabledMonthCategories;

  const CustomerMapPointsFilterState({
    this.selectedSales,
    this.selectedSpv,
    this.enabledMonthCategories = const {
      InstallMonthCategory.thisMonth,
      InstallMonthCategory.lastMonth,
      InstallMonthCategory.twoMonthsAgo,
      InstallMonthCategory.threeMonthsAgo,
      InstallMonthCategory.older,
    },
  });

  CustomerMapPointsFilterState copyWith({
    String? selectedSales,
    bool clearSales = false,
    String? selectedSpv,
    bool clearSpv = false,
    Set<InstallMonthCategory>? enabledMonthCategories,
  }) {
    return CustomerMapPointsFilterState(
      selectedSales: clearSales ? null : (selectedSales ?? this.selectedSales),
      selectedSpv: clearSpv ? null : (selectedSpv ?? this.selectedSpv),
      enabledMonthCategories:
          enabledMonthCategories ?? this.enabledMonthCategories,
    );
  }

  String? get salesName => selectedSales;
  String? get spvName => selectedSpv;
  Set<InstallMonthCategory> get selectedCategories => enabledMonthCategories;
  bool get hasActiveFilters =>
      selectedSales != null ||
      selectedSpv != null ||
      enabledMonthCategories.length < InstallMonthCategory.values.length;
}

class CustomerMapPointsFilterNotifier
    extends StateNotifier<CustomerMapPointsFilterState> {
  CustomerMapPointsFilterNotifier()
      : super(const CustomerMapPointsFilterState());

  void setSales(String? sales) {
    final trimmed = sales?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == 'SEMUA') {
      state = state.copyWith(clearSales: true);
    } else {
      state = state.copyWith(selectedSales: trimmed);
    }
  }

  void setSpv(String? spv) {
    final trimmed = spv?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == 'SEMUA') {
      state = state.copyWith(clearSpv: true);
    } else {
      state = state.copyWith(selectedSpv: trimmed);
    }
  }

  void toggleMonthCategory(InstallMonthCategory category) {
    final current = Set<InstallMonthCategory>.from(state.enabledMonthCategories);
    if (current.contains(category)) {
      current.remove(category);
    } else {
      current.add(category);
    }
    state = state.copyWith(enabledMonthCategories: current);
  }

  void toggleCategory(InstallMonthCategory category) => toggleMonthCategory(category);

  void resetFilters() {
    state = const CustomerMapPointsFilterState();
  }

  void reset() => resetFilters();
}

final customerMapPointsFilterProvider = StateNotifierProvider<
    CustomerMapPointsFilterNotifier, CustomerMapPointsFilterState>((ref) {
  return CustomerMapPointsFilterNotifier();
});

/// Daftar nama sales unik dari titik pelanggan terpasang lokal (untuk dropdown filter).
final uniqueMasterSalesNamesProvider = Provider<List<String>>((ref) {
  final pointsAsync = ref.watch(allCustomerMapPointsProvider);
  return pointsAsync.maybeWhen(
    data: (points) {
      final names = points
          .map((p) => p.salesName.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return names;
    },
    orElse: () => const [],
  );
});

/// Daftar nama SPV unik dari titik pelanggan terpasang lokal (untuk dropdown filter).
final uniqueMasterSpvNamesProvider = Provider<List<String>>((ref) {
  final pointsAsync = ref.watch(allCustomerMapPointsProvider);
  return pointsAsync.maybeWhen(
    data: (points) {
      final names = points
          .map((p) => p.spvName.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return names;
    },
    orElse: () => const [],
  );
});

/// Hitungan titik per kategori bulan untuk legenda Peta Coverage.
final customerMapPointsMonthCountsProvider =
    Provider<Map<InstallMonthCategory, int>>((ref) {
  final pointsAsync = ref.watch(allCustomerMapPointsProvider);
  final filter = ref.watch(customerMapPointsFilterProvider);
  final now = DateTime.now();

  return pointsAsync.maybeWhen(
    data: (points) {
      final counts = <InstallMonthCategory, int>{
        for (final cat in InstallMonthCategory.values) cat: 0,
      };

      for (final p in points) {
        // Hormati filter Sales & SPV saat menghitung statistik legenda bulan
        if (filter.selectedSales != null &&
            p.salesName != filter.selectedSales) {
          continue;
        }
        if (filter.selectedSpv != null && p.spvName != filter.selectedSpv) {
          continue;
        }
        final cat = p.getMonthCategory(now);
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
      return counts;
    },
    orElse: () => {for (final cat in InstallMonthCategory.values) cat: 0},
  );
});

/// Titik pelanggan terpasang yang telah disaring berdasarkan filter sales, SPV, dan kategori bulan.
final filteredCustomerMapPointsProvider = Provider<List<CustomerMapPoint>>((
  ref,
) {
  final pointsAsync = ref.watch(allCustomerMapPointsProvider);
  final filter = ref.watch(customerMapPointsFilterProvider);
  final now = DateTime.now();

  return pointsAsync.maybeWhen(
    data: (points) {
      return points.where((p) {
        if (filter.selectedSales != null &&
            p.salesName != filter.selectedSales) {
          return false;
        }
        if (filter.selectedSpv != null && p.spvName != filter.selectedSpv) {
          return false;
        }
        final cat = p.getMonthCategory(now);
        if (!filter.enabledMonthCategories.contains(cat)) {
          return false;
        }
        return true;
      }).toList();
    },
    orElse: () => const [],
  );
});

// Ergonomic aliases
final customerMapPointFilterProvider = customerMapPointsFilterProvider;
final customerMapPointSalesListProvider = uniqueMasterSalesNamesProvider;
final customerMapPointSpvListProvider = uniqueMasterSpvNamesProvider;
final customerMapPointMonthCountsProvider = customerMapPointsMonthCountsProvider;
