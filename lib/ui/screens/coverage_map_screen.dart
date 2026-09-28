import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../maps/models/map_models.dart';
import '../../maps/providers/coverage_map_provider.dart';
import '../../maps/widgets/map_inspector_sheet.dart';
import '../../maps/widgets/location_search_sheet.dart';
import '../../providers/sa_provider.dart';
import '../../ai/widgets/ai_coach_chat_sheet.dart';
import '../../network/providers/network_monitor_provider.dart';

enum MapTileType {
  googleHybrid('Google Satellite', 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'),
  googleStreets('Google Streets', 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}'),
  osm('OpenStreetMap', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');

  final String label;
  final String url;
  const MapTileType(this.label, this.url);
}

class CoverageMapScreen extends ConsumerStatefulWidget {
  const CoverageMapScreen({super.key});

  @override
  ConsumerState<CoverageMapScreen> createState() => _CoverageMapScreenState();
}

class _CoverageMapScreenState extends ConsumerState<CoverageMapScreen> {
  final MapController _mapController = MapController();
  MapTileType _currentTile = MapTileType.googleHybrid;
  bool _isLocating = false;
  LatLng? _userPosition;
  LatLng? _searchedPin;
  String? _searchedRawSource;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userPosition = latLng;
        _isLocating = false;
      });
      ref.read(coverageMapNotifierProvider.notifier).setUserLocation(latLng);
      _mapController.move(latLng, 15.0);
    } catch (_) {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _openLocationSearch() async {
    final result = await LocationSearchSheet.show(context);
    if (result != null) {
      setState(() {
        _searchedPin = result.point;
        _searchedRawSource = result.rawSource;
      });
      _mapController.move(result.point, 16.0);

      // Otomatis buka inspector untuk titik yang dicari
      if (mounted) {
        final mapState = ref.read(coverageMapNotifierProvider);

        // Cari tower terdekat
        BtsTower? nearestTower;
        double minTowerDist = 500.0;
        for (final tower in mapState.filteredTowers) {
          final d = const Distance().as(LengthUnit.Meter, result.point, tower.location);
          if (d < minTowerDist) {
            minTowerDist = d;
            nearestTower = tower;
          }
        }

        // Cari homepass terdekat
        HomepassPoint? nearestHp;
        double minHpDist = 150.0;
        for (final hp in mapState.filteredHomepass) {
          final d = const Distance().as(LengthUnit.Meter, result.point, hp.location);
          if (d < minHpDist) {
            minHpDist = d;
            nearestHp = hp;
          }
        }

        double? distFromUser;
        if (_userPosition != null) {
          distFromUser = const Distance().as(LengthUnit.Meter, _userPosition!, result.point);
        }

        MapInspectorSheet.show(
          context,
          tower: nearestTower,
          homepass: nearestHp,
          point: result.point,
          districtName: mapState.selectedDistrict?.name,
          distanceMeters: distFromUser,
          searchSource: result.rawSource,
        );
      }
    }
  }

  void _showLayersBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final mapState = ref.watch(coverageMapNotifierProvider);
            final mapNotifier = ref.read(coverageMapNotifierProvider.notifier);

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.layers_rounded, color: Color(0xFF002B66)),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Pengaturan Layer Peta',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    // 1. Toggle Homepass
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFB8C00).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.home_work_rounded, color: Color(0xFFFB8C00)),
                      ),
                      title: const Text('Homepass Target Bangunan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: Text('${mapState.currentHomepass.length} titik target prospek di ${mapState.selectedDistrict?.name ?? "Cilacap"}', style: const TextStyle(fontSize: 11.5)),
                      value: mapState.showHomepass,
                      activeThumbColor: const Color(0xFFFB8C00),
                      activeTrackColor: const Color(0xFFFB8C00).withValues(alpha: 0.3),
                      onChanged: (val) => mapNotifier.toggleHomepass(val),
                    ),
                    // 2. Toggle Coverage
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B0FF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.public_rounded, color: Color(0xFF00B0FF)),
                      ),
                      title: const Text('Area Coverage FWA / FTTH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: const Text('Poligon area coverage mulus per kecamatan', style: TextStyle(fontSize: 11.5)),
                      value: mapState.showCoverage,
                      activeThumbColor: const Color(0xFF00B0FF),
                      activeTrackColor: const Color(0xFF00B0FF).withValues(alpha: 0.3),
                      onChanged: (val) => mapNotifier.toggleCoverage(val),
                    ),
                    // 3. Toggle Towers
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F9D58).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cell_tower_rounded, color: Color(0xFF0F9D58)),
                      ),
                      title: const Text('380 Tower BTS XL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: const Text('Posisi BTS, eNodeB ID & warna asli KMZ', style: TextStyle(fontSize: 11.5)),
                      value: mapState.showTowers,
                      activeThumbColor: const Color(0xFF0F9D58),
                      activeTrackColor: const Color(0xFF0F9D58).withValues(alpha: 0.3),
                      onChanged: (val) => mapNotifier.toggleTowers(val),
                    ),
                    // 4. Toggle Installed SA
                    SwitchListTile(
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00897B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF00897B)),
                      ),
                      title: const Text('Pelanggan SA Terpasang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: const Text('Titik pelanggan SA tersimpan di database', style: TextStyle(fontSize: 11.5)),
                      value: mapState.showInstalledSa,
                      activeThumbColor: const Color(0xFF00897B),
                      activeTrackColor: const Color(0xFF00897B).withValues(alpha: 0.3),
                      onChanged: (val) => mapNotifier.toggleInstalledSa(val),
                    ),
                    const Divider(height: 24),
                    // Legend Warna Target Homepass & Tower
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Text(
                        'Legenda Warna Homepass & Tower',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Column(
                        children: [
                          _buildLegendRow(const Color(0xFF9C27B0), 'Ungu - Existing Homeconnect', 'Pelanggan aktif XL Satu yang sudah terpasang'),
                          const SizedBox(height: 6),
                          _buildLegendRow(const Color(0xFFFB8C00), 'Orange - Prospek Prioritas (P3 / A / B)', 'Target utama yang belum dikunjungi / prospek tinggi'),
                          const SizedBox(height: 6),
                          _buildLegendRow(const Color(0xFF43A047), 'Hijau - Prospek Reguler (P4 / C / D)', 'Target reguler / telah dikunjungi'),
                          const SizedBox(height: 6),
                          _buildLegendRow(const Color(0xFF00E5FF), '📡 Cyan - Serving BTS Tower', 'Tower yang sedang melayani perangkat sales'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mapState = ref.watch(coverageMapNotifierProvider);
    final mapNotifier = ref.read(coverageMapNotifierProvider.notifier);
    final saListAsync = ref.watch(saProvider);
    final installedSaList = saListAsync.value ?? [];

    final cellSignalAsync = ref.watch(cellSignalProvider);
    final servingCell = cellSignalAsync.value?.servingCell;

    final center = _searchedPin ??
        _userPosition ??
        (mapState.selectedDistrict != null
            ? mapState.selectedDistrict!.center
            : const LatLng(-7.7188, 109.0156)); // Default Cilacap

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Peta Coverage & BTS XL',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          // Tombol Cari Koordinat / ShareLoc WA
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Input Lat/Long / ShareLoc WA',
            onPressed: _openLocationSearch,
          ),
          // Tombol Pengaturan Layer
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Pilih Layer Peta',
            onPressed: () => _showLayersBottomSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined, color: Color(0xFF6366F1)),
            tooltip: 'Tanya AI Coach',
            onPressed: () => AiCoachChatSheet.show(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // 1. Peta FlutterMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13.5,
              onTap: (tapPosition, point) {
                // 1. Deteksi klik terdekat ke Homepass titik target (radius 35 meter)
                if (mapState.showHomepass && mapState.filteredHomepass.isNotEmpty) {
                  HomepassPoint? closestHp;
                  double minHpDist = 35.0;
                  for (final hp in mapState.filteredHomepass) {
                    final d = const Distance().as(LengthUnit.Meter, point, hp.location);
                    if (d < minHpDist) {
                      minHpDist = d;
                      closestHp = hp;
                    }
                  }
                  if (closestHp != null) {
                    double? distFromUser;
                    if (_userPosition != null) {
                      distFromUser = const Distance().as(
                        LengthUnit.Meter,
                        _userPosition!,
                        closestHp.location,
                      );
                    }
                    MapInspectorSheet.show(
                      context,
                      homepass: closestHp,
                      point: closestHp.location,
                      districtName: mapState.selectedDistrict?.name,
                      distanceMeters: distFromUser,
                    );
                    return;
                  }
                }

                // 2. Deteksi klik terdekat ke Tower BTS (radius 80 meter)
                if (mapState.showTowers && mapState.filteredTowers.isNotEmpty) {
                  BtsTower? closestTower;
                  double minTowerDist = 80.0;
                  for (final tower in mapState.filteredTowers) {
                    final d = const Distance().as(LengthUnit.Meter, point, tower.location);
                    if (d < minTowerDist) {
                      minTowerDist = d;
                      closestTower = tower;
                    }
                  }
                  if (closestTower != null) {
                    double? distFromUser;
                    if (_userPosition != null) {
                      distFromUser = const Distance().as(
                        LengthUnit.Meter,
                        _userPosition!,
                        closestTower.location,
                      );
                    }
                    MapInspectorSheet.show(
                      context,
                      tower: closestTower,
                      point: closestTower.location,
                      districtName: mapState.selectedDistrict?.name,
                      distanceMeters: distFromUser,
                    );
                    return;
                  }
                }

                // 3. Fallback inspector lokasi umum
                MapInspectorSheet.show(
                  context,
                  point: point,
                  districtName: mapState.selectedDistrict?.name,
                );
              },
            ),
            children: [
              // Tile Layer
              TileLayer(
                urlTemplate: _currentTile.url,
                userAgentPackageName: 'com.dsa.incentive.tracker',
              ),

              // Coverage Polygons Layer (Dissolved / Smooth Area)
              if (mapState.showCoverage && mapState.currentCoverages.isNotEmpty)
                PolygonLayer(
                  polygons: mapState.currentCoverages.expand((cov) {
                    return cov.rings.map((ring) {
                      return Polygon(
                        points: ring,
                        color: cov.fillColor,
                        borderColor: cov.borderColor,
                        borderStrokeWidth: 1.5,
                      );
                    });
                  }).toList(),
                ),

              // Serving BTS Tower Connecting Beam Polyline (Garis Sinyal Laser dari HP Sales ke Tower)
              if (_userPosition != null && mapState.matchedServingTower != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_userPosition!, mapState.matchedServingTower!.location],
                      color: const Color(0xFF00E5FF),
                      strokeWidth: 3.5,
                      borderColor: const Color(0xFF002B66).withValues(alpha: 0.7),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              // Serving BTS Tower Radar Pulsing Rings Layer
              if (mapState.matchedServingTower != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: mapState.matchedServingTower!.location,
                      radius: 38,
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.18),
                      borderColor: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                      borderStrokeWidth: 2.0,
                    ),
                    CircleMarker(
                      point: mapState.matchedServingTower!.location,
                      radius: 18,
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.38),
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              // Homepass Target Bangunan Circle Layer (Ultra Fast Canvas Rendering 60FPS)
              if (mapState.showHomepass && mapState.filteredHomepass.isNotEmpty)
                CircleLayer(
                  circles: mapState.filteredHomepass.map((hp) {
                    return CircleMarker(
                      point: hp.location,
                      radius: 4.5,
                      color: hp.categoryColor,
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.0,
                    );
                  }).toList(),
                ),

              // 380 Titik Tower BTS XL Marker Layer (Warna Asli KMZ & Highlight Serving Tower)
              if (mapState.showTowers)
                MarkerLayer(
                  markers: mapState.filteredTowers.map((tower) {
                    final isMatched = mapState.matchedServingTower?.towerId == tower.towerId ||
                        (mapState.matchedServingTower?.enodebId.isNotEmpty == true &&
                            mapState.matchedServingTower?.enodebId == tower.enodebId);

                    return Marker(
                      point: tower.location,
                      width: isMatched ? 48 : 30,
                      height: isMatched ? 48 : 30,
                      child: GestureDetector(
                        onTap: () {
                          double? dist;
                          if (_userPosition != null) {
                            dist = const Distance().as(
                              LengthUnit.Meter,
                              _userPosition!,
                              tower.location,
                            );
                          }
                          MapInspectorSheet.show(
                            context,
                            tower: tower,
                            point: tower.location,
                            districtName: mapState.selectedDistrict?.name,
                            distanceMeters: dist,
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: isMatched ? 40 : 30,
                              height: isMatched ? 40 : 30,
                              decoration: BoxDecoration(
                                color: isMatched
                                    ? const Color(0xFF00E5FF)
                                    : tower.markerColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: isMatched ? 2.5 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isMatched ? const Color(0xAA00E5FF) : Colors.black26,
                                    blurRadius: isMatched ? 12 : 4,
                                    spreadRadius: isMatched ? 3 : 0,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.cell_tower_rounded,
                                color: isMatched ? const Color(0xFF002B66) : Colors.white,
                                size: isMatched ? 22 : 15,
                              ),
                            ),
                            if (isMatched)
                              Positioned(
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF002B66),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF00E5FF), width: 1),
                                  ),
                                  child: const Text(
                                    'SERVING',
                                    style: TextStyle(
                                      color: Color(0xFF00E5FF),
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Pelanggan SA Terpasang Layer
              if (mapState.showInstalledSa)
                MarkerLayer(
                  markers: installedSaList
                      .where((sa) => sa.hasLocation)
                      .map((sa) {
                    final pt = LatLng(sa.latitude!, sa.longitude!);
                    return Marker(
                      point: pt,
                      width: 26,
                      height: 26,
                      child: GestureDetector(
                        onTap: () {
                          MapInspectorSheet.show(
                            context,
                            point: pt,
                            districtName: sa.alamat,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF00897B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.person_pin_circle_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

              // Pin Hasil Pencarian ShareLoc / Koordinat
              if (_searchedPin != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _searchedPin!,
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () {
                          double? dist;
                          if (_userPosition != null) {
                            dist = const Distance().as(LengthUnit.Meter, _userPosition!, _searchedPin!);
                          }
                          MapInspectorSheet.show(
                            context,
                            point: _searchedPin!,
                            districtName: mapState.selectedDistrict?.name,
                            distanceMeters: dist,
                            searchSource: _searchedRawSource,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x666366F1),
                                blurRadius: 10,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.share_location_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              // Live User GPS Location Marker
              if (_userPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userPosition!,
                      width: 26,
                      height: 26,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2979FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2979FF).withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.my_location_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. Header District Selector, Search Bar & Quick Toggles + Serving BTS Live HUD
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Baris 1: Selector Kecamatan & Tombol Search
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.map_outlined, color: Color(0xFF002B66), size: 18),
                        const SizedBox(width: 6),
                        // Dropdown Kecamatan
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<DistrictInfo>(
                              value: mapState.selectedDistrict,
                              isExpanded: true,
                              hint: const Text('Pilih Kecamatan', style: TextStyle(fontSize: 12.5)),
                              icon: const Icon(Icons.arrow_drop_down_rounded),
                              items: mapState.districts.map((d) {
                                return DropdownMenuItem<DistrictInfo>(
                                  value: d,
                                  child: Text(
                                    d.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (d) {
                                if (d != null) {
                                  mapNotifier.selectDistrict(d);
                                  _mapController.move(d.center, 13.5);
                                }
                              },
                            ),
                          ),
                        ),
                        if (mapState.isLoading)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF002B66)),
                            tooltip: 'Cari Lat/Long atau ShareLoc',
                            onPressed: _openLocationSearch,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Baris 2: Floating Quick Switch Bar (Overflow Safe)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Toggle Switch Homepass
                      Flexible(
                        child: InkWell(
                          onTap: () => mapNotifier.toggleHomepass(!mapState.showHomepass),
                          borderRadius: BorderRadius.circular(16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.home_work_rounded,
                                size: 15,
                                color: mapState.showHomepass
                                    ? const Color(0xFFFB8C00)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  'Homepass',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: mapState.showHomepass
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Transform.scale(
                                scale: 0.65,
                                child: Switch(
                                  value: mapState.showHomepass,
                                  activeThumbColor: const Color(0xFFFB8C00),
                                  activeTrackColor: const Color(0xFFFB8C00).withValues(alpha: 0.3),
                                  onChanged: (val) => mapNotifier.toggleHomepass(val),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 16, color: Colors.grey.withValues(alpha: 0.3)),
                      // Toggle Switch Coverage
                      Flexible(
                        child: InkWell(
                          onTap: () => mapNotifier.toggleCoverage(!mapState.showCoverage),
                          borderRadius: BorderRadius.circular(16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.public_rounded,
                                size: 15,
                                color: mapState.showCoverage
                                    ? const Color(0xFF00B0FF)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  'Coverage',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: mapState.showCoverage
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : Colors.grey,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Transform.scale(
                                scale: 0.65,
                                child: Switch(
                                  value: mapState.showCoverage,
                                  activeThumbColor: const Color(0xFF00B0FF),
                                  activeTrackColor: const Color(0xFF00B0FF).withValues(alpha: 0.3),
                                  onChanged: (val) => mapNotifier.toggleCoverage(val),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Baris 3: Floating Serving Tower Live HUD Bar
                if (mapState.matchedServingTower != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: () {
                        _mapController.move(mapState.matchedServingTower!.location, 16.0);
                        double? dist;
                        if (_userPosition != null) {
                          dist = const Distance().as(
                            LengthUnit.Meter,
                            _userPosition!,
                            mapState.matchedServingTower!.location,
                          );
                        }
                        MapInspectorSheet.show(
                          context,
                          tower: mapState.matchedServingTower,
                          point: mapState.matchedServingTower!.location,
                          districtName: mapState.selectedDistrict?.name,
                          distanceMeters: dist,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF002B66), Color(0xFF0D47A1)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x5500E5FF),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E5FF),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.cell_tower_rounded,
                                color: Color(0xFF002B66),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00E5FF),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          'SERVING BTS',
                                          style: TextStyle(
                                            color: Color(0xFF002B66),
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          mapState.matchedServingTower!.siteName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'eNodeB: ${mapState.matchedServingTower!.enodebId} · ID: ${mapState.matchedServingTower!.towerId}'
                                    '${_userPosition != null ? " · Jarak: ${(const Distance().as(LengthUnit.Meter, _userPosition!, mapState.matchedServingTower!.location)).toStringAsFixed(0)}m" : ""}'
                                    '${servingCell?.rsrp != null ? " · ${servingCell!.rsrp} dBm" : ""}',
                                    style: const TextStyle(
                                      color: Color(0xFFE0F7FA),
                                      fontSize: 10,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.center_focus_strong_rounded,
                              color: Color(0xFF00E5FF),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. Map Tile Switcher & Interactive Layer Filter Chips
          Positioned(
            bottom: 20,
            left: 10,
            right: 68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Switch Tile Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<MapTileType>(
                      value: _currentTile,
                      isDense: true,
                      icon: const Icon(Icons.layers_rounded, size: 16),
                      items: MapTileType.values.map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _currentTile = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Interactive Layer Chips
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildInteractiveChip(
                      label: '380 BTS',
                      color: const Color(0xFF0F9D58),
                      isActive: mapState.showTowers,
                      isDark: isDark,
                      onTap: () => mapNotifier.toggleTowers(!mapState.showTowers),
                    ),
                    _buildInteractiveChip(
                      label: 'Coverage',
                      color: const Color(0xFF00B0FF),
                      isActive: mapState.showCoverage,
                      isDark: isDark,
                      onTap: () => mapNotifier.toggleCoverage(!mapState.showCoverage),
                    ),
                    _buildInteractiveChip(
                      label: 'HP (${mapState.currentHomepass.length})',
                      color: const Color(0xFFFB8C00),
                      isActive: mapState.showHomepass,
                      isDark: isDark,
                      onTap: () => mapNotifier.toggleHomepass(!mapState.showHomepass),
                    ),
                    _buildInteractiveChip(
                      label: 'SA',
                      color: const Color(0xFF00897B),
                      isActive: mapState.showInstalledSa,
                      isDark: isDark,
                      onTap: () => mapNotifier.toggleInstalledSa(!mapState.showInstalledSa),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Floating Actions: Cari ShareLoc, GPS, AI Coach, dan Fokus Tower Melayani
          Positioned(
            bottom: 20,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mapState.matchedServingTower != null) ...[
                  FloatingActionButton.small(
                    heroTag: 'focus_serving_tower_fab',
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: const Color(0xFF002B66),
                    tooltip: 'Fokus Tower Melayani',
                    onPressed: () {
                      _mapController.move(mapState.matchedServingTower!.location, 16.0);
                      double? dist;
                      if (_userPosition != null) {
                        dist = const Distance().as(
                          LengthUnit.Meter,
                          _userPosition!,
                          mapState.matchedServingTower!.location,
                        );
                      }
                      MapInspectorSheet.show(
                        context,
                        tower: mapState.matchedServingTower,
                        point: mapState.matchedServingTower!.location,
                        districtName: mapState.selectedDistrict?.name,
                        distanceMeters: dist,
                      );
                    },
                    child: const Icon(Icons.cell_tower_rounded, size: 18),
                  ),
                  const SizedBox(height: 8),
                ],
                FloatingActionButton.small(
                  heroTag: 'search_sharloc_fab',
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  tooltip: 'Cari Lat/Long / ShareLoc',
                  onPressed: _openLocationSearch,
                  child: const Icon(Icons.share_location_rounded, size: 17),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'recenter_gps',
                  backgroundColor: const Color(0xFF002B66),
                  foregroundColor: Colors.white,
                  tooltip: 'Lokasi Saya',
                  onPressed: _fetchCurrentLocation,
                  child: _isLocating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 17),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'tanya_ai_map',
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  tooltip: 'Tanya AI Coach',
                  onPressed: () => AiCoachChatSheet.show(context),
                  child: const Icon(Icons.psychology_outlined, size: 17),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveChip({
    required String label,
    required Color color,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF1E293B) : Colors.white)
              : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.6) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color : Colors.grey.withValues(alpha: 0.3),
            width: isActive ? 1.4 : 0.8,
          ),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive ? color : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white38 : Colors.black38),
                decoration: isActive ? null : TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
