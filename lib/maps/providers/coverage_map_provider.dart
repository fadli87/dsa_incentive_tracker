import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';
import '../services/geojson_service.dart';
import '../../network/providers/network_monitor_provider.dart';

class CoverageMapState {
  final List<DistrictInfo> districts;
  final DistrictInfo? selectedDistrict;
  final List<BtsTower> towers;
  final List<CoveragePolygonData> currentCoverages;
  final List<HomepassPoint> currentHomepass;
  final bool showCoverage;
  final bool showTowers;
  final bool showHomepass;
  final bool showInstalledSa;
  final String searchQuery;
  final bool isLoading;
  final BtsTower? matchedServingTower;
  final LatLng? userLocation;

  const CoverageMapState({
    this.districts = const [],
    this.selectedDistrict,
    this.towers = const [],
    this.currentCoverages = const [],
    this.currentHomepass = const [],
    this.showCoverage = true,
    this.showTowers = true,
    this.showHomepass = true,
    this.showInstalledSa = true,
    this.searchQuery = '',
    this.isLoading = false,
    this.matchedServingTower,
    this.userLocation,
  });

  CoverageMapState copyWith({
    List<DistrictInfo>? districts,
    DistrictInfo? selectedDistrict,
    List<BtsTower>? towers,
    List<CoveragePolygonData>? currentCoverages,
    List<HomepassPoint>? currentHomepass,
    bool? showCoverage,
    bool? showTowers,
    bool? showHomepass,
    bool? showInstalledSa,
    String? searchQuery,
    bool? isLoading,
    BtsTower? matchedServingTower,
    LatLng? userLocation,
  }) =>
      CoverageMapState(
        districts: districts ?? this.districts,
        selectedDistrict: selectedDistrict ?? this.selectedDistrict,
        towers: towers ?? this.towers,
        currentCoverages: currentCoverages ?? this.currentCoverages,
        currentHomepass: currentHomepass ?? this.currentHomepass,
        showCoverage: showCoverage ?? this.showCoverage,
        showTowers: showTowers ?? this.showTowers,
        showHomepass: showHomepass ?? this.showHomepass,
        showInstalledSa: showInstalledSa ?? this.showInstalledSa,
        searchQuery: searchQuery ?? this.searchQuery,
        isLoading: isLoading ?? this.isLoading,
        matchedServingTower: matchedServingTower ?? this.matchedServingTower,
        userLocation: userLocation ?? this.userLocation,
      );

  List<BtsTower> get filteredTowers {
    if (searchQuery.trim().isEmpty) return towers;
    final q = searchQuery.toLowerCase().trim();
    return towers.where((t) {
      return t.siteName.toLowerCase().contains(q) ||
          t.towerId.toLowerCase().contains(q) ||
          t.enodebId.toLowerCase().contains(q);
    }).toList();
  }

  List<HomepassPoint> get filteredHomepass {
    if (searchQuery.trim().isEmpty) return currentHomepass;
    final q = searchQuery.toLowerCase().trim();
    return currentHomepass.where((hp) {
      return hp.id.toLowerCase().contains(q) ||
          hp.village.toLowerCase().contains(q) ||
          hp.cluster.toLowerCase().contains(q);
    }).toList();
  }
}

class CoverageMapNotifier extends Notifier<CoverageMapState> {
  final GeoJsonService _geoService = GeoJsonService.instance;

  @override
  CoverageMapState build() {
    _initData();
    _listenToCellSignal();
    return const CoverageMapState(isLoading: true);
  }

  Future<void> _initData() async {
    final districts = await _geoService.loadDistricts();
    final towers = await _geoService.loadTowers();

    DistrictInfo? defaultDistrict;
    if (districts.isNotEmpty) {
      // Default: Cilacap Tengah
      defaultDistrict = districts.firstWhere(
        (d) => d.id == 'CILACAP_TENGAH',
        orElse: () => districts.first,
      );
    }

    List<CoveragePolygonData> initialCoverage = [];
    List<HomepassPoint> initialHomepass = [];
    if (defaultDistrict != null) {
      initialCoverage = await _geoService.loadDistrictCoverage(defaultDistrict.id);
      initialHomepass = await _geoService.loadDistrictHomepass(defaultDistrict.id);
    }

    state = state.copyWith(
      districts: districts,
      selectedDistrict: defaultDistrict,
      towers: towers,
      currentCoverages: initialCoverage,
      currentHomepass: initialHomepass,
      isLoading: false,
    );
  }

  void _listenToCellSignal() {
    ref.listen(cellSignalProvider, (prev, next) {
      final snapshot = next.value;
      _recalculateServingTower(state.userLocation, snapshot);
    });
  }

  void _recalculateServingTower([LatLng? userLoc, dynamic snapshot]) {
    final currentSnapshot = snapshot ?? ref.read(cellSignalProvider).value;
    final serving = currentSnapshot?.servingCell;
    final towers = state.towers;

    if (towers.isEmpty) return;

    if (serving == null || serving.cellType == 'UNKNOWN') {
      if (state.matchedServingTower != null) {
        state = state.copyWith(matchedServingTower: null);
      }
      return;
    }

    final effectiveUserLoc = userLoc ?? state.userLocation;
    final targetEnodebInt = serving.nodeId;
    final enodebId = targetEnodebInt?.toString().trim();

    BtsTower? match;

    // 1. Prioritas 1: Pencocokan eksak berbasis Node ID (eNodeB ID / gNodeB ID)
    if (targetEnodebInt != null && targetEnodebInt > 0 && enodebId != null && enodebId.isNotEmpty) {
      final candidates = towers.where((t) {
        final tEnbStr = t.enodebId.trim();
        final tEnbInt = int.tryParse(tEnbStr);
        if (tEnbInt != null && tEnbInt == targetEnodebInt) {
          return true;
        }
        if (tEnbStr.isNotEmpty && tEnbStr == enodebId) {
          return true;
        }
        if (t.towerId.trim().toUpperCase() == enodebId.toUpperCase()) {
          return true;
        }
        return false;
      }).toList();

      if (candidates.isNotEmpty) {
        if (candidates.length == 1) {
          match = candidates.first;
        } else if (effectiveUserLoc != null) {
          // Jika ada lebih dari 1 tower dengan eNodeB yang sama (multi-sektor / co-location),
          // pilih tower yang terdekat dengan posisi fisik user saat ini
          candidates.sort((a, b) {
            final dA = const Distance().as(LengthUnit.Meter, effectiveUserLoc, a.location);
            final dB = const Distance().as(LengthUnit.Meter, effectiveUserLoc, b.location);
            return dA.compareTo(dB);
          });
          match = candidates.first;
        } else {
          match = candidates.first;
        }
      }
    }

    // 2. Verifikasi Plausibilitas Jarak (Distance Sanity Check)
    // Jika match ditemukan via eNodeB ID namun jarak ke user > 35 KM (di luar jangkauan radio seluler),
    // cari tower terdekat dari lokasi user
    if (match != null && effectiveUserLoc != null) {
      final dMeters = const Distance().as(LengthUnit.Meter, effectiveUserLoc, match.location);
      if (dMeters > 35000.0) {
        double minDistance = 10000.0; // Radius 10 KM
        BtsTower? closerTower;
        for (final t in towers) {
          final d = const Distance().as(LengthUnit.Meter, effectiveUserLoc, t.location);
          if (d < minDistance) {
            minDistance = d;
            closerTower = t;
          }
        }
        if (closerTower != null) {
          match = closerTower;
        }
      }
    }

    // 3. Prioritas 2: Fallback ke Tower terdekat dari GPS user jika eNodeB ID tidak terdaftar
    if (match == null && effectiveUserLoc != null && serving.cellType != 'UNKNOWN') {
      double minDistance = 10000.0; // Radius maksimal 10 KM
      for (final t in towers) {
        final d = const Distance().as(LengthUnit.Meter, effectiveUserLoc, t.location);
        if (d < minDistance) {
          minDistance = d;
          match = t;
        }
      }
    }

    if (match != state.matchedServingTower) {
      state = state.copyWith(matchedServingTower: match);
    }
  }

  Future<void> selectDistrict(DistrictInfo district) async {
    if (state.selectedDistrict?.id == district.id) return;

    state = state.copyWith(selectedDistrict: district, isLoading: true);
    final coverage = await _geoService.loadDistrictCoverage(district.id);
    final homepass = await _geoService.loadDistrictHomepass(district.id);
    state = state.copyWith(
      currentCoverages: coverage,
      currentHomepass: homepass,
      isLoading: false,
    );
  }

  void toggleCoverage(bool value) {
    state = state.copyWith(showCoverage: value);
  }

  void toggleTowers(bool value) {
    state = state.copyWith(showTowers: value);
  }

  void toggleHomepass(bool value) {
    state = state.copyWith(showHomepass: value);
  }

  void toggleInstalledSa(bool value) {
    state = state.copyWith(showInstalledSa: value);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setUserLocation(LatLng location) {
    state = state.copyWith(userLocation: location);
    _recalculateServingTower(location);
  }
}

final coverageMapNotifierProvider =
    NotifierProvider<CoverageMapNotifier, CoverageMapState>(
  CoverageMapNotifier.new,
);
