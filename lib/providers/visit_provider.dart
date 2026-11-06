import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../data/local/database_helper.dart';
import '../data/models/visit_activity.dart';

/// Helper format tanggal yyyy-MM-dd
String formatVisitDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

/// Provider tanggal terpilih untuk layar Aktivitas Harian (default: hari ini)
final visitSelectedDateProvider = StateProvider<String>((ref) {
  return formatVisitDate(DateTime.now());
});

/// Provider filter kategori terpilih (`null` = Semua)
final visitSelectedCategoryProvider = StateProvider<VisitCategory?>((ref) {
  return null;
});

/// AsyncNotifier utama untuk daftar Aktivitas Harian Visit
class VisitNotifier extends AsyncNotifier<List<VisitActivity>> {
  static const Uuid _uuid = Uuid();

  @override
  Future<List<VisitActivity>> build() async {
    final selectedDate = ref.watch(visitSelectedDateProvider);
    final selectedCategory = ref.watch(visitSelectedCategoryProvider);
    return await DatabaseHelper.instance.getVisitsByDate(
      selectedDate,
      category: selectedCategory,
    );
  }

  Future<List<VisitActivity>> _fetchCurrent() async {
    final selectedDate = ref.read(visitSelectedDateProvider);
    final selectedCategory = ref.read(visitSelectedCategoryProvider);
    return await DatabaseHelper.instance.getVisitsByDate(
      selectedDate,
      category: selectedCategory,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchCurrent);
  }

  Future<void> addVisit(VisitActivity visit) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      final record = visit.copyWith(
        clientId: visit.clientId.trim().isEmpty ? _uuid.v4() : visit.clientId,
        updatedAt: nowIso,
        syncState: 0,
        deleted: false,
      );
      await DatabaseHelper.instance.insertVisit(record);
      return await _fetchCurrent();
    });
  }

  Future<void> updateVisit(VisitActivity visit) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.updateVisit(visit);
      return await _fetchCurrent();
    });
  }

  Future<void> deleteVisit(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.softDeleteVisit(id);
      return await _fetchCurrent();
    });
  }

  /// Cek apakah kombinasi Customer ID + Kategori + Tanggal sudah ada (untuk peringatan non-blocking)
  Future<bool> hasDuplicate({
    required String customerId,
    required VisitCategory category,
    required String plannedDate,
    int? excludeId,
  }) async {
    final visitsOnDate = await DatabaseHelper.instance.getVisitsByDate(
      plannedDate,
      category: category,
    );
    final normalizedId = customerId.trim().toLowerCase();
    return visitsOnDate.any((v) =>
        v.id != excludeId &&
        v.customerId.trim().toLowerCase() == normalizedId);
  }
}

final visitProvider =
    AsyncNotifierProvider<VisitNotifier, List<VisitActivity>>(
  () => VisitNotifier(),
);

/// Provider hitungan per kategori pada tanggal terpilih
final visitCountsByCategoryProvider =
    FutureProvider<Map<VisitCategory, int>>((ref) async {
  // Watch visitProvider agar hitungan ikut ter-refresh saat ada tambah/ubah/hapus
  ref.watch(visitProvider);
  final selectedDate = ref.watch(visitSelectedDateProvider);
  return await DatabaseHelper.instance.visitCountsByCategory(selectedDate);
});

/// Provider jumlah aktivitas yang belum tersinkron ke Supabase (sync_state == 0)
final pendingVisitCountProvider = FutureProvider<int>((ref) async {
  ref.watch(visitProvider);
  final pending = await DatabaseHelper.instance.getPendingVisits();
  return pending.length;
});
