import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../maps/models/cluster_map_models.dart';
import '../../maps/providers/cluster_maps_provider.dart';

enum ClusterTileSource {
  googleHybrid('Satelit Hybrid', 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'),
  googleSatellite('Satelit Murni', 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}'),
  osm('OpenStreetMap', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');

  final String label;
  final String url;
  const ClusterTileSource(this.label, this.url);
}

class ClusterMapViewerScreen extends ConsumerStatefulWidget {
  final ClusterMapItem cluster;

  const ClusterMapViewerScreen({
    super.key,
    required this.cluster,
  });

  @override
  ConsumerState<ClusterMapViewerScreen> createState() => _ClusterMapViewerScreenState();
}

class _ClusterMapViewerScreenState extends ConsumerState<ClusterMapViewerScreen> {
  final MapController _mapController = MapController();
  ClusterTileSource _tileSource = ClusterTileSource.googleHybrid;
  final Set<String> _hiddenLayers = <String>{};
  bool _didInitialFit = false;
  bool _isLocating = false;
  bool _isOpeningPdf = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _fitBounds(LatLngBounds bounds) {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(36.0),
      ),
    );
  }

  Future<void> _moveToMyLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin GPS tidak diberikan.')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final myPoint = LatLng(pos.latitude, pos.longitude);
      _mapController.move(myPoint, 17.5);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membaca lokasi GPS: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _onOpenPdfPressed() async {
    setState(() => _isOpeningPdf = true);
    final service = ref.read(clusterMapServiceProvider);
    try {
      final res = await service.openClusterPdf(widget.cluster);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka PDF: ${res.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningPdf = false);
    }
  }

  void _showFeatureDetails(ClusterMapFeature feature) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final coord = feature.geometry.point ??
            (feature.geometry.points.isNotEmpty ? feature.geometry.points.first : null);

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: feature.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      feature.geometryType == ClusterGeometryType.point
                          ? Icons.location_on_rounded
                          : feature.geometryType == ClusterGeometryType.lineString
                              ? Icons.timeline_rounded
                              : Icons.layers_rounded,
                      color: feature.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          feature.geometryType == ClusterGeometryType.point
                              ? 'Titik ODP / Tiang'
                              : feature.geometryType == ClusterGeometryType.lineString
                                  ? 'Rute / Kabel Fiber'
                                  : 'Area / Boundary Cluster',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (feature.description != null && feature.description!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    feature.description!,
                    style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF334155)),
                  ),
                ),
              ],
              if (coord != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.my_location_rounded, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      '${coord.latitude.toStringAsFixed(6)}, ${coord.longitude.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Salin Koordinat'),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: '${coord.latitude},${coord.longitude}'),
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Koordinat berhasil disalin!')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF002B66),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.directions_rounded, size: 16),
                        label: const Text('Google Maps'),
                        onPressed: () async {
                          final uri = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=${coord.latitude},${coord.longitude}',
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final clusterDataAsync = ref.watch(clusterDataProvider(widget.cluster));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.cluster.clusterCode),
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // Pemilih Tile Provider
          PopupMenuButton<ClusterTileSource>(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Tipe Peta',
            initialValue: _tileSource,
            onSelected: (val) => setState(() => _tileSource = val),
            itemBuilder: (ctx) => ClusterTileSource.values.map((src) {
              return PopupMenuItem(
                value: src,
                child: Text(src.label),
              );
            }).toList(),
          ),
          // Tombol Buka PDF
          if (widget.cluster.pdfPath != null)
            IconButton(
              icon: _isOpeningPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Buka Desain PDF',
              onPressed: _isOpeningPdf ? null : _onOpenPdfPressed,
            ),
        ],
      ),
      body: clusterDataAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF002B66)),
              SizedBox(height: 16),
              Text(
                'Membaca peta cluster...',
                style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 14),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF002B66)),
                  onPressed: () => ref.invalidate(clusterDataProvider(widget.cluster)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (mapData) {
          if (mapData.isEmpty || mapData.bounds == null) {
            return const Center(
              child: Text('Cluster ini tidak memiliki data koordinat.'),
            );
          }

          // Auto-fit saat pertama kali load
          if (!_didInitialFit && mapData.bounds != null) {
            _didInitialFit = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitBounds(mapData.bounds!);
            });
          }

          // Siapkan layer-layer geometri
          final visibleLayers = mapData.layers
              .where((l) => !_hiddenLayers.contains(l.name))
              .toList();

          final polygons = <Polygon>[];
          final polylines = <Polyline>[];
          final markers = <Marker>[];

          for (final layer in visibleLayers) {
            for (final f in layer.features) {
              if (f.geometryType == ClusterGeometryType.polygon) {
                polygons.add(
                  Polygon(
                    points: f.geometry.points,
                    color: f.fillColor ?? f.color.withValues(alpha: 0.2),
                    borderColor: f.color,
                    borderStrokeWidth: f.strokeWidth,
                  ),
                );
              } else if (f.geometryType == ClusterGeometryType.lineString) {
                polylines.add(
                  Polyline(
                    points: f.geometry.points,
                    color: f.color,
                    strokeWidth: f.strokeWidth,
                  ),
                );
              } else if (f.geometryType == ClusterGeometryType.point && f.geometry.point != null) {
                markers.add(
                  Marker(
                    point: f.geometry.point!,
                    width: 32,
                    height: 32,
                    child: GestureDetector(
                      onTap: () => _showFeatureDetails(f),
                      child: Container(
                        decoration: BoxDecoration(
                          color: f.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(Icons.router_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                );
              }
            }
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: mapData.bounds!.center,
                  initialZoom: 15.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _tileSource.url,
                    userAgentPackageName: 'com.xlclp.dsaincentivetracker',
                  ),
                  if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
                  if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                  if (markers.isNotEmpty) MarkerLayer(markers: markers),
                ],
              ),

              // Filter Chips Layer (Folder) di bagian atas
              if (mapData.layers.length > 1)
                PositionBarLayerChips(
                  layers: mapData.layers,
                  hiddenLayers: _hiddenLayers,
                  onToggleLayer: (name) {
                    setState(() {
                      if (_hiddenLayers.contains(name)) {
                        _hiddenLayers.remove(name);
                      } else {
                        _hiddenLayers.add(name);
                      }
                    });
                  },
                ),

              // Floating Action Buttons (Fit Bounds & My Location)
              Positioned(
                right: 16,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'fab_fit_bounds',
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF002B66),
                      tooltip: 'Pusatkan ke Cluster',
                      onPressed: () {
                        if (mapData.bounds != null) {
                          _fitBounds(mapData.bounds!);
                        }
                      },
                      child: const Icon(Icons.crop_free_rounded),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: 'fab_my_location',
                      backgroundColor: const Color(0xFF002B66),
                      foregroundColor: Colors.white,
                      tooltip: 'Lokasi Saya',
                      onPressed: _isLocating ? null : _moveToMyLocation,
                      child: _isLocating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.my_location_rounded),
                    ),
                  ],
                ),
              ),

              // Info Bar bawah (Ringkasan Cluster)
              Positioned(
                left: 16,
                right: 80,
                bottom: 24,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.cluster.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${mapData.pointCount} Titik ODP • ${mapData.lineCount} Jalur Kabel • ${mapData.polygonCount} Boundary Area',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PositionBarLayerChips extends StatelessWidget {
  final List<ClusterMapLayer> layers;
  final Set<String> hiddenLayers;
  final ValueChanged<String> onToggleLayer;

  const PositionBarLayerChips({
    super.key,
    required this.layers,
    required this.hiddenLayers,
    required this.onToggleLayer,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 16,
      right: 16,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: layers.map((l) {
            final isVisible = !hiddenLayers.contains(l.name);
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                selected: isVisible,
                label: Text('${l.name} (${l.count})'),
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: isVisible ? FontWeight.bold : FontWeight.normal,
                  color: isVisible ? Colors.white : Colors.grey.shade700,
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                selectedColor: const Color(0xFF002B66),
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isVisible ? const Color(0xFF002B66) : Colors.grey.shade300,
                  ),
                ),
                onSelected: (_) => onToggleLayer(l.name),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
