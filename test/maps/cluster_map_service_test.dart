import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/maps/models/cluster_map_models.dart';
import 'package:dsa_incentive_tracker/maps/services/cluster_map_service.dart';

Uint8List _createDummyKmz(String featureName, double lat, double lon) {
  final kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Placemark>
    <name>$featureName</name>
    <Point><coordinates>$lon,$lat,0</coordinates></Point>
  </Placemark>
</kml>''';
  final archive = Archive();
  final kmlBytes = utf8.encode(kml);
  archive.addFile(ArchiveFile('doc.kml', kmlBytes.length, kmlBytes));
  final zipBytes = ZipEncoder().encode(archive);
  return Uint8List.fromList(zipBytes);
}

class _FakeClusterGateway implements ClusterMapRemoteGateway {
  bool shouldFail = false;
  final List<Map<String, dynamic>> clusterRows;
  final Map<String, Uint8List> storageFiles;
  int downloadCallCount = 0;

  _FakeClusterGateway({
    required this.clusterRows,
    required this.storageFiles,
  });

  @override
  Future<List<Map<String, dynamic>>> fetchRemoteClusterList() async {
    if (shouldFail) {
      throw const SocketException('No internet connection');
    }
    return clusterRows;
  }

  @override
  Future<Uint8List> downloadStorageFile(String bucket, String path) async {
    if (shouldFail) {
      throw const SocketException('No internet connection');
    }
    downloadCallCount++;
    final bytes = storageFiles['$bucket/$path'] ?? storageFiles[path];
    if (bytes == null) {
      throw Exception('File not found in storage: $bucket/$path');
    }
    return bytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late _FakeClusterGateway fakeGateway;
  late ClusterMapService service;

  final sampleDate = DateTime.utc(2026, 11, 15, 8, 0, 0);

  final sampleCluster1 = ClusterMapItem(
    clusterCode: 'XLCLP1947',
    name: 'CLUSTER INTAN RESIDENCE, KELURAHAN GUMILIR RW 17',
    kelurahan: 'GUMILIR',
    rw: '17',
    kmzPath: 'kmz/XLCLP1947.kmz',
    pdfPath: 'pdf/XLCLP1947.pdf',
    kmzSize: 1024,
    updatedAt: sampleDate,
  );

  final sampleCluster2 = ClusterMapItem(
    clusterCode: 'XLCLP1161',
    name: 'PERUMAHAN TAMAN JUANDA',
    kelurahan: null,
    rw: null,
    kmzPath: 'kmz/XLCLP1161.kmz',
    pdfPath: null,
    kmzSize: 2048,
    updatedAt: sampleDate,
  );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cluster_test_');

    final kmzBytes1 = _createDummyKmz('ODP INTAN 01', -7.6543, 109.0123);
    final kmzBytes2 = _createDummyKmz('ODP JUANDA 01', -7.6600, 109.0200);

    fakeGateway = _FakeClusterGateway(
      clusterRows: [sampleCluster1.toJson(), sampleCluster2.toJson()],
      storageFiles: {
        'cluster-maps/kmz/XLCLP1947.kmz': kmzBytes1,
        'cluster-maps/kmz/XLCLP1161.kmz': kmzBytes2,
      },
    );

    service = ClusterMapService(
      gateway: fakeGateway,
      injectedDir: tempDir,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ClusterMapService Tests — Offline Caching & Sync', () {
    test('fetchClusterList: Mengambil online dan menyimpan cache lokal', () async {
      final list = await service.fetchClusterList();
      expect(list.length, 2);
      expect(list[0].clusterCode, 'XLCLP1947');
      expect(list[1].clusterCode, 'XLCLP1161');

      // Pastikan cache file dibuat
      final cacheFile = File('${tempDir.path}/clusters_list_cache.json');
      expect(cacheFile.existsSync(), isTrue);
    });

    test('fetchClusterList: Fallback ke cache lokal saat offline', () async {
      // 1. Fetch online dulu agar cache terisi
      await service.fetchClusterList();

      // 2. Putus koneksi (simulasi offline di lapangan)
      fakeGateway.shouldFail = true;

      // 3. Fetch ulang, harus tetap berhasil membaca dari cache
      final offlineList = await service.fetchClusterList();
      expect(offlineList.length, 2);
      expect(offlineList[0].clusterCode, 'XLCLP1947');
      expect(offlineList[1].clusterCode, 'XLCLP1161');
    });

    test('fetchClusterList: Melempar pesan ramah bila offline dan belum ada cache sama sekali', () async {
      fakeGateway.shouldFail = true;
      expect(
        () => service.fetchClusterList(),
        throwsA(isA<ClusterMapServiceException>().having(
          (e) => e.message,
          'message',
          contains('buka sekali saat online'),
        )),
      );
    });

    test('loadClusterData: Unduh pertama kali, pakai cache lokal di pemanggilan berikutnya', () async {
      expect(await service.isClusterDownloaded('XLCLP1947'), isFalse);

      // Unduh pertama kali
      final mapData = await service.loadClusterData(sampleCluster1);
      expect(mapData.isEmpty, isFalse);
      expect(mapData.layers.first.features.first.name, 'ODP INTAN 01');
      expect(fakeGateway.downloadCallCount, 1);
      expect(await service.isClusterDownloaded('XLCLP1947'), isTrue);

      // Pemanggilan kedua (tanpa perubahan versi): tidak mendownload ulang
      final cachedData = await service.loadClusterData(sampleCluster1);
      expect(cachedData.layers.first.features.first.name, 'ODP INTAN 01');
      expect(fakeGateway.downloadCallCount, 1); // Tetap 1!
    });

    test('loadClusterData: Berhasil dibuka saat offline bila sudah pernah diunduh', () async {
      // 1. Unduh saat online
      await service.loadClusterData(sampleCluster1);
      expect(fakeGateway.downloadCallCount, 1);

      // 2. Offline di lapangan
      fakeGateway.shouldFail = true;

      // 3. Buka lagi, harus tetap berhasil tanpa error
      final offlineData = await service.loadClusterData(sampleCluster1);
      expect(offlineData.isEmpty, isFalse);
      expect(offlineData.layers.first.features.first.name, 'ODP INTAN 01');
      expect(fakeGateway.downloadCallCount, 1); // Tidak ada panggilan jaringan baru
    });

    test('loadClusterData: Melempar pesan ramah saat offline dan cluster belum pernah diunduh', () async {
      // Offline langsung tanpa unduh
      fakeGateway.shouldFail = true;

      expect(
        () => service.loadClusterData(sampleCluster1),
        throwsA(isA<ClusterMapServiceException>().having(
          (e) => e.message,
          'message',
          contains('Cluster ini belum diunduh. Buka sekali saat online'),
        )),
      );
    });
  });
}
