import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/drive_test_log.dart';
import '../providers/drive_test_provider.dart';
import '../providers/network_monitor_provider.dart';

/// Sumber tile peta untuk GIS drive test visualizer.
enum DriveMapTileSource {
  googleRoadmap(
    label: 'Google Streets',
    urlTemplate: 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
    applyDarkFilter: false,
  ),
  googleHybrid(
    label: 'Google Satellite',
    urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
    applyDarkFilter: false,
  ),
  googleTerrain(
    label: 'Google Terrain',
    urlTemplate: 'https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}',
    applyDarkFilter: false,
  ),
  osm(
    label: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    applyDarkFilter: true,
  );

  final String label;
  final String urlTemplate;
  final bool applyDarkFilter;

  const DriveMapTileSource({
    required this.label,
    required this.urlTemplate,
    required this.applyDarkFilter,
  });
}

/// Widget Peta Drive Test Interaktif AURA.
/// Ported & upgraded dari standalone network_monitor (map_screen.dart):
/// - Mendukung multi-tile Google Satellite Hybrid, Google Streets, Terrain, OSM
/// - Jejak titik koordinat RSRP berwarna standar 3GPP (Hijau, Kuning, Merah)
/// - Tap Inspector: tap titik manapun untuk melihat parameter RF lengkap di lokasi tersebut
/// - GPS Accuracy circle & live device tracking
class DriveMapWidget extends ConsumerStatefulWidget {
  final List<LogPoint> points;
  final double height;
  final bool isFullScreen;

  const DriveMapWidget({
    super.key,
    required this.points,
    this.height = 360,
    this.isFullScreen = false,
  });

  @override
  ConsumerState<DriveMapWidget> createState() => _DriveMapWidgetState();
}

class _DriveMapWidgetState extends ConsumerState<DriveMapWidget> {
  final MapController _mapController = MapController();
  DriveMapTileSource _currentTileSource = DriveMapTileSource.googleHybrid;
  bool _darkFilterEnabled = false;
  LogPoint? _inspectedPoint;

  static const LatLng _defaultJakarta = LatLng(-6.2088, 106.8456);

  @override
  Widget build(BuildContext context) {
    final driveState = ref.watch(driveTestNotifierProvider);
    final gpsInfo = ref.watch(liveGpsProvider).value;
    final lastPoint = driveState.lastPoint;

    // Hitung posisi saat ini
    final LatLng currentPosition = (lastPoint != null && lastPoint.latitude != 0)
        ? LatLng(lastPoint.latitude, lastPoint.longitude)
        : ((gpsInfo != null && gpsInfo.latitude != null)
            ? LatLng(gpsInfo.latitude!, gpsInfo.longitude!)
            : (widget.points.isNotEmpty
                ? LatLng(widget.points.last.latitude, widget.points.last.longitude)
                : _defaultJakarta));

    final mapWidget = Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: currentPosition,
            initialZoom: 16.5,
            minZoom: 3.0,
            maxZoom: 19.5,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom,
            ),
            onTap: (_, _) {
              if (_inspectedPoint != null) {
                setState(() => _inspectedPoint = null);
              }
            },
          ),
          children: [
            // 1. TILE LAYER
            TileLayer(
              key: ValueKey('${_currentTileSource.name}_$_darkFilterEnabled'),
              urlTemplate: _currentTileSource.urlTemplate,
              userAgentPackageName: 'com.aura.network',
              tileBuilder: _darkFilterEnabled
                  ? (context, tileWidget, tile) {
                      return ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          0.8, 0, 0, 0, 0,
                          0, 0.8, 0, 0, 0,
                          0, 0, 0.8, 0, 0,
                          0, 0, 0, 1.0, 0,
                        ]),
                        child: tileWidget,
                      );
                    }
                  : null,
            ),

            // 2. GPS ACCURACY RADIUS CIRCLE
            if (gpsInfo != null && gpsInfo.accuracyM != null && gpsInfo.accuracyM! > 0)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: currentPosition,
                    radius: gpsInfo.accuracyM!,
                    useRadiusInMeter: true,
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderColor: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

            // 3. LOG POINT MARKERS (RSRP Color-Coded)
            CircleLayer(
              circles: widget.points.map((p) {
                final isSelected = _inspectedPoint == p;
                final color = _signalColor(p.rsrpDbm);
                return CircleMarker(
                  point: LatLng(p.latitude, p.longitude),
                  radius: isSelected ? 9 : 6,
                  color: color.withValues(alpha: isSelected ? 0.95 : 0.8),
                  borderColor: isSelected ? Colors.white : color,
                  borderStrokeWidth: isSelected ? 2.5 : 1.0,
                  useRadiusInMeter: false,
                );
              }).toList(),
            ),

            // 4. CLICK DETECTORS FOR POINTS
            MarkerLayer(
              markers: widget.points.map((p) {
                return Marker(
                  point: LatLng(p.latitude, p.longitude),
                  width: 26,
                  height: 26,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() => _inspectedPoint = p);
                    },
                    child: const SizedBox.expand(),
                  ),
                );
              }).toList(),
            ),

            // 5. CURRENT DEVICE LOCATION PULSE MARKER
            MarkerLayer(
              markers: [
                Marker(
                  point: currentPosition,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF00E5FF), width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                          blurRadius: 10,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // ---------------------------------------------------------------------
        // FLOATING CONTROLS: Tile Switcher, Dark Filter, Recenter, Point Counter
        // ---------------------------------------------------------------------
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              // Tile Source Switcher Button
              _buildFloatingBtn(
                icon: Icons.layers_outlined,
                tooltip: 'Ganti Sumber Peta',
                onTap: _showTileSourceSheet,
              ),
              const SizedBox(height: 8),

              // Dark Filter Toggle Button
              _buildFloatingBtn(
                icon: _darkFilterEnabled ? Icons.dark_mode : Icons.light_mode_outlined,
                color: _darkFilterEnabled ? const Color(0xFF4FC3F7) : Colors.white70,
                tooltip: 'Filter Gelap (Dark Mode)',
                onTap: () {
                  setState(() => _darkFilterEnabled = !_darkFilterEnabled);
                },
              ),
              const SizedBox(height: 8),

              // Recenter Button
              _buildFloatingBtn(
                icon: Icons.my_location,
                tooltip: 'Pusatkan ke Lokasi Saya',
                onTap: () {
                  _mapController.move(currentPosition, 16.5);
                },
              ),
            ],
          ),
        ),

        // Point Counter Badge (Top-Left)
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, size: 13, color: Color(0xFF00E5FF)),
                const SizedBox(width: 4),
                Text(
                  '${widget.points.length} Titik Sinyal',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'RobotoMono',
                  ),
                ),
              ],
            ),
          ),
        ),

        // ---------------------------------------------------------------------
        // POINT INSPECTOR SHEET (Muncul saat titik di-tap)
        // ---------------------------------------------------------------------
        if (_inspectedPoint != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _buildPointInspectorSheet(_inspectedPoint!),
          )
        else
          // RSRP Legend (Bottom-Left)
          Positioned(
            left: 12,
            bottom: 12,
            child: _buildRsrpLegend(),
          ),
      ],
    );

    if (widget.isFullScreen) {
      return mapWidget;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFF10141D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: mapWidget,
      ),
    );
  }

  Widget _buildFloatingBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: color),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildRsrpLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _legendItem(const Color(0xFF4CAF50), '≥-85'),
          const SizedBox(width: 8),
          _legendItem(const Color(0xFF8BC34A), '-98'),
          const SizedBox(width: 8),
          _legendItem(const Color(0xFFFF9800), '-110'),
          const SizedBox(width: 8),
          _legendItem(const Color(0xFFF44336), '<-110'),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontFamily: 'RobotoMono'),
        ),
      ],
    );
  }

  Widget _buildPointInspectorSheet(LogPoint p) {
    final color = _signalColor(p.rsrpDbm);
    final timeStr =
        '${p.timestamp.hour.toString().padLeft(2, '0')}:${p.timestamp.minute.toString().padLeft(2, '0')}:${p.timestamp.second.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161C2C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0xDF000000), blurRadius: 14)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Detail Titik Sinyal • $timeStr',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 16, color: Colors.white60),
                onPressed: () => setState(() => _inspectedPoint = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _inspectorCell('RSRP', p.rsrpDbm != null ? '${p.rsrpDbm} dBm' : 'N/A', color),
              _inspectorCell('RSRQ', p.rsrqDb != null ? '${p.rsrqDb} dB' : 'N/A', Colors.white),
              _inspectorCell('SINR', p.sinrDb != null ? '${p.sinrDb} dB' : 'N/A', Colors.white),
              _inspectorCell('Speed', p.speedKmhDisplay, const Color(0xFF00E5FF)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _inspectorCell('Operator', p.operator_ ?? 'N/A', Colors.white70),
              _inspectorCell('Cell ID', p.cellIdDisplay, Colors.white70),
              _inspectorCell('PCI', p.pciDisplay, Colors.white70),
              _inspectorCell('Band', p.band ?? 'N/A', Colors.white70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inspectorCell(String label, String val, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
        const SizedBox(height: 1),
        Text(
          val,
          style: TextStyle(
            color: valColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            fontFamily: 'RobotoMono',
          ),
        ),
      ],
    );
  }

  void _showTileSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Tipe Peta (Tile Source)',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...DriveMapTileSource.values.map((src) {
                  final isSelected = _currentTileSource == src;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      src == DriveMapTileSource.googleHybrid
                          ? Icons.satellite_alt
                          : (src == DriveMapTileSource.googleTerrain
                              ? Icons.terrain
                              : Icons.map),
                      color: isSelected ? const Color(0xFF4FC3F7) : Colors.white70,
                    ),
                    title: Text(
                      src.label,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF4FC3F7) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF4FC3F7)) : null,
                    onTap: () {
                      setState(() => _currentTileSource = src);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _signalColor(int? rsrp) {
    if (rsrp == null) return Colors.grey;
    if (rsrp >= -85) return const Color(0xFF4CAF50);  // excellent: green
    if (rsrp >= -98) return const Color(0xFF8BC34A);  // good: light green
    if (rsrp >= -110) return const Color(0xFFFF9800); // fair: orange
    return const Color(0xFFF44336);                    // poor: red
  }
}
