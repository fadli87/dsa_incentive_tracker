import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/utils/launcher_helper.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/visit_activity.dart';
import '../../providers/visit_provider.dart';
import 'visit_form_screen.dart';

/// Konfigurasi tile peta yang sama persis dengan `coverage_map_screen.dart`
enum VisitMapTileType {
  googleHybrid('Google Satellite', 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'),
  googleStreets('Google Streets', 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'),
  osm('OpenStreetMap', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');

  final String label;
  final String url;
  const VisitMapTileType(this.label, this.url);
}

class VisitMapScreen extends ConsumerStatefulWidget {
  final String? initialDate;

  const VisitMapScreen({
    super.key,
    this.initialDate,
  });

  @override
  ConsumerState<VisitMapScreen> createState() => _VisitMapScreenState();
}

class _VisitMapScreenState extends ConsumerState<VisitMapScreen> {
  static const LatLng _defaultCenter = LatLng(-7.7188, 109.0156); // Cilacap
  final MapController _mapController = MapController();

  VisitMapTileType _currentTile = VisitMapTileType.googleHybrid;
  bool _showRvai = true;
  bool _showDismantle = true;
  bool _showUnpaid = true;

  List<VisitActivity> _visitsOnDate = [];
  bool _isLoading = true;

  String get _activeDate =>
      widget.initialDate ?? ref.read(visitSelectedDateProvider);

  @override
  void initState() {
    super.initState();
    _loadDateVisits();
  }

  Future<void> _loadDateVisits() async {
    setState(() => _isLoading = true);
    final list = await DatabaseHelper.instance.getVisitsByDate(_activeDate);
    if (!mounted) return;
    setState(() {
      _visitsOnDate = list;
      _isLoading = false;
    });
  }

  Color _categoryColor(VisitCategory cat) {
    switch (cat) {
      case VisitCategory.rvai:
        return Colors.green.shade700;
      case VisitCategory.dismantle:
        return Colors.red.shade700;
      case VisitCategory.unpaid:
        return Colors.amber.shade700;
    }
  }

  void _showMarkerSummary(VisitActivity visit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final color = _categoryColor(visit.category);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      visit.category.displayLabel,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF002B66).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      visit.status.displayLabel,
                      style: const TextStyle(
                        color: Color(0xFF002B66),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${visit.customerId}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF002B66),
                ),
              ),
              if (visit.customerName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  visit.customerName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
              if (visit.address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  visit.address,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                ),
              ],
              if (visit.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Catatan: ${visit.note}',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Ubah'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VisitFormScreen(initialVisit: visit),
                          ),
                        );
                        if (changed == true) {
                          await _loadDateVisits();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF002B66),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('Navigasi'),
                      onPressed: visit.hasLocation
                          ? () {
                              Navigator.pop(ctx);
                              LauncherHelper.openGoogleMaps(
                                visit.latitude!,
                                visit.longitude!,
                              );
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleVisits = _visitsOnDate.where((v) {
      if (!v.hasLocation) return false;
      return switch (v.category) {
        VisitCategory.rvai => _showRvai,
        VisitCategory.dismantle => _showDismantle,
        VisitCategory.unpaid => _showUnpaid,
      };
    }).toList();

    final initialCenter = visibleVisits.isNotEmpty
        ? LatLng(visibleVisits.first.latitude!, visibleVisits.first.longitude!)
        : _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF002B66),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PETA VISIT HARIAN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Tanggal: $_activeDate (${visibleVisits.length} titik)',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<VisitMapTileType>(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Pilih Jenis Peta',
            onSelected: (t) => setState(() => _currentTile = t),
            itemBuilder: (_) => VisitMapTileType.values
                .map(
                  (t) => PopupMenuItem(
                    value: t,
                    child: Text(
                      t.label,
                      style: TextStyle(
                        fontWeight: _currentTile == t
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Toggle 3 Layer lewat FilterChip
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('RVAI (Hijau)'),
                    selected: _showRvai,
                    selectedColor: Colors.green.shade100,
                    checkmarkColor: Colors.green.shade800,
                    onSelected: (v) => setState(() => _showRvai = v),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Dismantle (Merah)'),
                    selected: _showDismantle,
                    selectedColor: Colors.red.shade100,
                    checkmarkColor: Colors.red.shade800,
                    onSelected: (v) => setState(() => _showDismantle = v),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Unpaid (Kuning)'),
                    selected: _showUnpaid,
                    selectedColor: Colors.amber.shade100,
                    checkmarkColor: Colors.amber.shade900,
                    onSelected: (v) => setState(() => _showUnpaid = v),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: initialCenter,
                      initialZoom: 13.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _currentTile.url,
                        userAgentPackageName: 'com.dsa.incentive.tracker',
                      ),
                      MarkerLayer(
                        markers: visibleVisits.map((visit) {
                          final color = _categoryColor(visit.category);
                          return Marker(
                            point: LatLng(visit.latitude!, visit.longitude!),
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () => _showMarkerSummary(visit),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
