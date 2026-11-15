import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../maps/models/cluster_map_models.dart';
import '../../maps/providers/cluster_maps_provider.dart';
import 'cluster_map_viewer_screen.dart';

class ClusterMapListScreen extends ConsumerStatefulWidget {
  const ClusterMapListScreen({super.key});

  @override
  ConsumerState<ClusterMapListScreen> createState() => _ClusterMapListScreenState();
}

class _ClusterMapListScreenState extends ConsumerState<ClusterMapListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isDownloadingAll = false;
  int _downloadCurrent = 0;
  int _downloadTotal = 0;
  String _downloadingClusterName = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onDownloadAllPressed(List<ClusterMapItem> clusters) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unduh Semua Peta Cluster?'),
        content: Text(
          'Aplikasi akan mengunduh ${clusters.length} peta cluster agar dapat dibuka di lapangan tanpa sinyal internet.\n\nPastikan Anda terhubung ke jaringan internet yang stabil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF002B66)),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Mulai Unduh'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isDownloadingAll = true;
      _downloadCurrent = 0;
      _downloadTotal = clusters.length;
    });

    final service = ref.read(clusterMapServiceProvider);

    try {
      await service.downloadAllClusters(
        onProgress: (current, total, name) {
          if (mounted) {
            setState(() {
              _downloadCurrent = current;
              _downloadTotal = total;
              _downloadingClusterName = name;
            });
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua peta cluster berhasil diunduh ke penyimpanan offline.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        ref.invalidate(clusterListProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Proses unduh terhenti: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingAll = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clusterListAsync = ref.watch(clusterListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Peta Cluster (KMZ)'),
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Daftar',
            onPressed: () => ref.read(clusterListProvider.notifier).refresh(),
          ),
          clusterListAsync.maybeWhen(
            data: (clusters) => clusters.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.download_for_offline_rounded),
                    tooltip: 'Unduh Semua Cluster',
                    onPressed: _isDownloadingAll ? null : () => _onDownloadAllPressed(clusters),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner Progress Unduh Semua
          if (_isDownloadingAll)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFFEFF6FF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF002B66)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mengunduh offline ($_downloadCurrent/$_downloadTotal): $_downloadingClusterName',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF002B66)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _downloadTotal > 0 ? _downloadCurrent / _downloadTotal : null,
                    backgroundColor: const Color(0xFFDBEAFE),
                    color: const Color(0xFF2563EB),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ),
            ),

          // Kolom Pencarian
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari cluster, kelurahan, RW, atau kode XLCLP...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF002B66)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF002B66), width: 1.5),
                ),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),

          // Daftar Cluster
          Expanded(
            child: clusterListAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF002B66)),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 54, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        err.toString(),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF002B66)),
                        onPressed: () => ref.read(clusterListProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (clusters) {
                final filtered = clusters.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  final matchName = c.name.toLowerCase().contains(_searchQuery);
                  final matchCode = c.clusterCode.toLowerCase().contains(_searchQuery);
                  final matchKel = c.kelurahan?.toLowerCase().contains(_searchQuery) ?? false;
                  final matchRw = c.rw?.toLowerCase().contains(_searchQuery) ?? false;
                  return matchName || matchCode || matchKel || matchRw;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Tidak ada cluster yang cocok dengan "$_searchQuery"'
                                : 'Belum ada data cluster di server.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.read(clusterListProvider.notifier).refresh(),
                  color: const Color(0xFF002B66),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return _buildClusterCard(item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClusterCard(ClusterMapItem cluster) {
    final offlineAsync = ref.watch(clusterOfflineStatusProvider(cluster.clusterCode));
    final isDownloaded = offlineAsync.maybeWhen(
      data: (val) => val,
      orElse: () => false,
    );

    String sizeLabel = '';
    if (cluster.kmzSize != null && cluster.kmzSize! > 0) {
      if (cluster.kmzSize! > 1024 * 1024) {
        sizeLabel = '${(cluster.kmzSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        sizeLabel = '${(cluster.kmzSize! / 1024).toStringAsFixed(0)} KB';
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClusterMapViewerScreen(cluster: cluster),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ikon Kode Cluster
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF002B66).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share_location_rounded, color: Color(0xFF002B66), size: 24),
              ),
              const SizedBox(width: 12),

              // Detail Teks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cluster.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cluster.displaySubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (sizeLabel.isNotEmpty || cluster.pdfPath != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (sizeLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                sizeLabel,
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                              ),
                            ),
                          if (cluster.pdfPath != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.picture_as_pdf_rounded, size: 10, color: Color(0xFFDC2626)),
                                  SizedBox(width: 2),
                                  Text(
                                    'PDF',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Status Offline Badge
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDownloaded ? Icons.check_circle_rounded : Icons.cloud_download_outlined,
                    color: isDownloaded ? const Color(0xFF16A34A) : Colors.grey.shade400,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDownloaded ? 'Offline' : 'Online',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isDownloaded ? const Color(0xFF16A34A) : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
