import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cluster_map_models.dart';
import '../services/cluster_map_service.dart';

/// Provider instance ClusterMapService
final clusterMapServiceProvider = Provider<ClusterMapService>((ref) {
  return ClusterMapService();
});

/// StateNotifier untuk memuat dan merefresh daftar cluster
class ClusterListNotifier extends AsyncNotifier<List<ClusterMapItem>> {
  @override
  Future<List<ClusterMapItem>> build() async {
    final service = ref.watch(clusterMapServiceProvider);
    return service.fetchClusterList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(clusterMapServiceProvider);
      return service.fetchClusterList(forceRefresh: true);
    });
  }
}

/// Provider daftar katalog cluster
final clusterListProvider =
    AsyncNotifierProvider<ClusterListNotifier, List<ClusterMapItem>>(() {
  return ClusterListNotifier();
});

/// Provider status apakah suatu cluster sudah di-cache secara offline
final clusterOfflineStatusProvider =
    FutureProvider.family<bool, String>((ref, clusterCode) async {
  final service = ref.watch(clusterMapServiceProvider);
  return service.isClusterDownloaded(clusterCode);
});

/// Provider data peta cluster (ClusterMapData) hasil load dan parse
final clusterDataProvider =
    FutureProvider.family<ClusterMapData, ClusterMapItem>((ref, cluster) async {
  final service = ref.watch(clusterMapServiceProvider);
  return service.loadClusterData(cluster);
});
