import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:dsa_incentive_tracker/maps/models/cluster_map_models.dart';
import 'package:dsa_incentive_tracker/maps/providers/cluster_maps_provider.dart';
import 'package:dsa_incentive_tracker/ui/screens/cluster_map_list_screen.dart';
import 'package:dsa_incentive_tracker/ui/screens/cluster_map_viewer_screen.dart';

class _FakeClusterListNotifier extends ClusterListNotifier {
  final List<ClusterMapItem> initialItems;
  _FakeClusterListNotifier(this.initialItems);

  @override
  Future<List<ClusterMapItem>> build() async => initialItems;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleCluster1 = ClusterMapItem(
    clusterCode: 'XLCLP1947',
    name: 'CLUSTER INTAN RESIDENCE, KELURAHAN GUMILIR RW 17',
    kelurahan: 'GUMILIR',
    rw: '17',
    kmzPath: 'kmz/XLCLP1947.kmz',
    pdfPath: 'pdf/XLCLP1947.pdf',
    kmzSize: 1024 * 64,
    updatedAt: DateTime.utc(2026, 11, 15),
  );

  final sampleCluster2 = ClusterMapItem(
    clusterCode: 'XLCLP1161',
    name: 'PERUMAHAN TAMAN JUANDA',
    kelurahan: null,
    rw: null,
    kmzPath: 'kmz/XLCLP1161.kmz',
    pdfPath: null,
    kmzSize: 1024 * 128,
    updatedAt: DateTime.utc(2026, 11, 15),
  );

  group('Cluster Map UI Tests', () {
    testWidgets('ClusterMapListScreen menampilkan daftar cluster, search, dan badge status', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clusterListProvider.overrideWith(
              () => _FakeClusterListNotifier([sampleCluster1, sampleCluster2]),
            ),
            clusterOfflineStatusProvider('XLCLP1947').overrideWith((ref) => true),
            clusterOfflineStatusProvider('XLCLP1161').overrideWith((ref) => false),
          ],
          child: const MaterialApp(home: ClusterMapListScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi AppBar dan Search Bar
      expect(find.text('Peta Cluster (KMZ)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verifikasi item cluster
      expect(find.text('CLUSTER INTAN RESIDENCE, KELURAHAN GUMILIR RW 17'), findsOneWidget);
      expect(find.text('PERUMAHAN TAMAN JUANDA'), findsOneWidget);

      // Verifikasi status Offline vs Online
      expect(find.text('Offline'), findsOneWidget);
      expect(find.text('Online'), findsOneWidget);

      // Verifikasi badge PDF ada di cluster 1
      expect(find.text('PDF'), findsOneWidget);

      // Uji pencarian realtime
      await tester.enterText(find.byType(TextField), 'TAMAN');
      await tester.pumpAndSettle();

      expect(find.text('PERUMAHAN TAMAN JUANDA'), findsOneWidget);
      expect(find.text('CLUSTER INTAN RESIDENCE, KELURAHAN GUMILIR RW 17'), findsNothing);
    });

    testWidgets('ClusterMapViewerScreen menampilkan chip layer, info bar, dan tombol navigasi', (tester) async {
      final sampleMapData = ClusterMapData(
        layers: [
          ClusterMapLayer(
            name: 'ODP',
            features: [
              ClusterMapFeature(
                name: 'ODP-01',
                description: 'Kapasitas 8 Port',
                geometry: ClusterGeometry.point(const LatLng(-7.65, 109.01)),
                color: Colors.red,
              ),
            ],
          ),
          ClusterMapLayer(
            name: 'Kabel',
            features: [
              ClusterMapFeature(
                name: 'Kabel 24C',
                geometry: ClusterGeometry.lineString([
                  const LatLng(-7.65, 109.01),
                  const LatLng(-7.655, 109.015),
                ]),
                color: Colors.blue,
              ),
            ],
          ),
        ],
        bounds: LatLngBounds.fromPoints([
          const LatLng(-7.66, 109.00),
          const LatLng(-7.64, 109.02),
        ]),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clusterDataProvider(sampleCluster1).overrideWith((ref) => sampleMapData),
          ],
          child: MaterialApp(
            home: ClusterMapViewerScreen(cluster: sampleCluster1),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi AppBar
      expect(find.text('XLCLP1947'), findsOneWidget);

      // Verifikasi Chips Layer (Folder)
      expect(find.text('ODP (1)'), findsOneWidget);
      expect(find.text('Kabel (1)'), findsOneWidget);

      // Verifikasi Floating Action Buttons
      expect(find.byIcon(Icons.crop_free_rounded), findsOneWidget);
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_rounded), findsOneWidget);

      // Verifikasi Info Bar
      expect(find.text('CLUSTER INTAN RESIDENCE, KELURAHAN GUMILIR RW 17'), findsOneWidget);
      expect(find.textContaining('1 Titik ODP • 1 Jalur Kabel'), findsOneWidget);
    });
  });
}
