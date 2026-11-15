import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/supabase_client.dart';
import '../models/cluster_map_models.dart';
import 'kmz_parser_service.dart';

/// Exception spesifik untuk layanan Cluster Map
class ClusterMapServiceException implements Exception {
  final String message;
  const ClusterMapServiceException(this.message);

  @override
  String toString() => message;
}

/// Gateway abstrak untuk Supabase cluster maps agar mudah diuji (mock/fake)
abstract class ClusterMapRemoteGateway {
  Future<List<Map<String, dynamic>>> fetchRemoteClusterList();
  Future<Uint8List> downloadStorageFile(String bucket, String path);
}

class SupabaseClusterMapGateway implements ClusterMapRemoteGateway {
  final SupabaseClient? _client;
  const SupabaseClusterMapGateway([this._client]);

  SupabaseClient get client => _client ?? AppSupabase.client;

  @override
  Future<List<Map<String, dynamic>>> fetchRemoteClusterList() async {
    final res = await client
        .from('cluster_maps')
        .select()
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(res as List);
  }

  @override
  Future<Uint8List> downloadStorageFile(String bucket, String path) async {
    return await client.storage.from(bucket).download(path);
  }
}

/// Service pengelola data cluster maps: fetching, offline caching, dan parser invocation
class ClusterMapService {
  final ClusterMapRemoteGateway gateway;
  final Directory? injectedDir;

  ClusterMapService({
    ClusterMapRemoteGateway? gateway,
    this.injectedDir,
  }) : gateway = gateway ?? const SupabaseClusterMapGateway();

  /// Direktori lokal untuk menyimpan cache KMZ, PDF, dan list JSON
  Future<Directory> get _cacheDirectory async {
    if (injectedDir != null) return injectedDir!;
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocDir.path}/cluster_maps');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  File _getListCacheFile(Directory dir) => File('${dir.path}/clusters_list_cache.json');
  File _getKmzFile(Directory dir, String code) => File('${dir.path}/$code.kmz');
  File _getMetaFile(Directory dir, String code) => File('${dir.path}/$code.meta.json');
  File _getPdfFile(Directory dir, String code) => File('${dir.path}/$code.pdf');

  /// Ambil daftar cluster. Mengambil dari Supabase saat online dan meng-cache ke lokal.
  /// Jika offline, mengambil dari cache lokal terakhir.
  Future<List<ClusterMapItem>> fetchClusterList({bool forceRefresh = false}) async {
    final dir = await _cacheDirectory;
    final cacheFile = _getListCacheFile(dir);

    try {
      final rows = await gateway.fetchRemoteClusterList();
      final items = rows.map((r) => ClusterMapItem.fromJson(r)).toList();

      // Simpan ke cache lokal
      try {
        final jsonList = items.map((e) => e.toJson()).toList();
        await cacheFile.writeAsString(jsonEncode(jsonList));
      } catch (e) {
        debugPrint('[ClusterMapService] Gagal menulis list cache lokal: $e');
      }

      return items;
    } catch (e) {
      // Fallback offline: baca dari cache lokal
      if (cacheFile.existsSync()) {
        try {
          final content = await cacheFile.readAsString();
          final List decoded = jsonDecode(content);
          return decoded.map((r) => ClusterMapItem.fromJson(Map<String, dynamic>.from(r))).toList();
        } catch (_) {
          // Bila parse cache gagal, lempar exception
        }
      }

      throw const ClusterMapServiceException(
        'Tidak dapat memuat daftar cluster. Periksa koneksi internet Anda atau buka sekali saat online.',
      );
    }
  }

  /// Cek apakah cluster tertentu sudah diunduh di penyimpanan lokal
  Future<bool> isClusterDownloaded(String clusterCode) async {
    final dir = await _cacheDirectory;
    final file = _getKmzFile(dir, clusterCode.toUpperCase());
    return file.existsSync() && file.lengthSync() > 0;
  }

  /// Muat data peta cluster dari cache lokal atau unduh dari Supabase Storage.
  /// Menjamin bekerja mulus saat offline bila file sudah pernah diunduh.
  Future<ClusterMapData> loadClusterData(ClusterMapItem cluster) async {
    final dir = await _cacheDirectory;
    final code = cluster.clusterCode.toUpperCase();
    final kmzFile = _getKmzFile(dir, code);
    final metaFile = _getMetaFile(dir, code);

    bool needDownload = false;

    if (!kmzFile.existsSync() || kmzFile.lengthSync() == 0) {
      needDownload = true;
    } else {
      // Periksa apakah ada update versi
      if (metaFile.existsSync()) {
        try {
          final meta = jsonDecode(await metaFile.readAsString());
          final localUpdated = meta['updated_at']?.toString();
          if (localUpdated != null && localUpdated != cluster.updatedAt.toIso8601String()) {
            needDownload = true;
          }
        } catch (_) {
          // Abaikan error meta, gunakan file yang ada
        }
      }
    }

    if (needDownload) {
      try {
        final bytes = await gateway.downloadStorageFile('cluster-maps', cluster.kmzPath);
        await kmzFile.writeAsBytes(bytes);
        await metaFile.writeAsString(jsonEncode({
          'cluster_code': code,
          'updated_at': cluster.updatedAt.toIso8601String(),
          'kmz_size': bytes.length,
        }));
      } catch (e) {
        // Jika gagal download tetapi file lokal lama ada, pakai yang lama
        if (kmzFile.existsSync() && kmzFile.lengthSync() > 0) {
          debugPrint('[ClusterMapService] Gagal update KMZ, menggunakan cache lokal lama');
        } else {
          throw const ClusterMapServiceException(
            'Cluster ini belum diunduh. Buka sekali saat online untuk menyimpan ke memori offline.',
          );
        }
      }
    }

    // Baca bytes dari file lokal
    final Uint8List localBytes = await kmzFile.readAsBytes();
    return await KmzParserService.parseKmzInIsolate(localBytes);
  }

  /// Unduh file PDF dokumen cluster ke cache lokal dan buka menggunakan viewer bawaan
  Future<OpenResult> openClusterPdf(ClusterMapItem cluster) async {
    if (cluster.pdfPath == null || cluster.pdfPath!.isEmpty) {
      throw const ClusterMapServiceException('Dokumen PDF tidak tersedia untuk cluster ini.');
    }

    final dir = await _cacheDirectory;
    final code = cluster.clusterCode.toUpperCase();
    final pdfFile = _getPdfFile(dir, code);

    if (!pdfFile.existsSync() || pdfFile.lengthSync() == 0) {
      try {
        final bytes = await gateway.downloadStorageFile('cluster-maps', cluster.pdfPath!);
        await pdfFile.writeAsBytes(bytes);
      } catch (e) {
        throw const ClusterMapServiceException(
          'Gagal mengunduh dokumen PDF. Pastikan perangkat Anda terhubung ke internet.',
        );
      }
    }

    final result = await OpenFilex.open(pdfFile.path);
    return result;
  }

  /// Unduh semua cluster KMZ untuk persiapan sebelum turun ke lapangan
  Future<void> downloadAllClusters({
    void Function(int current, int total, String currentCluster)? onProgress,
  }) async {
    final list = await fetchClusterList();
    final total = list.length;

    for (int i = 0; i < total; i++) {
      final cluster = list[i];
      onProgress?.call(i + 1, total, cluster.name);
      try {
        await loadClusterData(cluster);
      } catch (e) {
        debugPrint('[ClusterMapService] Gagal mengunduh cluster ${cluster.clusterCode}: $e');
      }
    }
  }
}

