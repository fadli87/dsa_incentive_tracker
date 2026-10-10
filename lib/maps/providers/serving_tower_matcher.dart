import 'package:latlong2/latlong.dart';
import '../models/map_models.dart';
import '../../network/models/cell_signal_info.dart';

enum ServingMatchSource {
  none,
  enodebExact,
  nearestEstimate,
}

class ServingTowerMatchResult {
  final BtsTower? tower;
  final ServingMatchSource source;
  final double? distanceMeters;
  final bool distanceAnomaly; // eNodeB matched but distance > 15 km

  const ServingTowerMatchResult({
    this.tower,
    this.source = ServingMatchSource.none,
    this.distanceMeters,
    this.distanceAnomaly = false,
  });

  static const empty = ServingTowerMatchResult();
}

class ServingTowerMatcher {
  /// Maximum plausible radio link distance for eNodeB match (15 KM)
  static const double maxEnodebDistanceMeters = 15000.0;

  /// Pure matcher function
  static ServingTowerMatchResult match({
    required List<BtsTower> towers,
    CellData? servingCell,
    LatLng? userLocation,
  }) {
    if (towers.isEmpty || servingCell == null) {
      return ServingTowerMatchResult.empty;
    }

    final cellType = servingCell.cellType.toUpperCase();
    if (cellType == 'UNKNOWN') {
      return ServingTowerMatchResult.empty;
    }

    // Rule 2: eNodeB exact match HANYA valid untuk LTE (4G)
    if (cellType == 'LTE') {
      final targetEnodebInt = servingCell.nodeId;
      final enodebId = targetEnodebInt?.toString().trim();

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
          BtsTower candidateTower;
          if (candidates.length == 1) {
            candidateTower = candidates.first;
          } else if (userLocation != null) {
            candidates.sort((a, b) {
              final dA = const Distance().as(LengthUnit.Meter, userLocation, a.location);
              final dB = const Distance().as(LengthUnit.Meter, userLocation, b.location);
              return dA.compareTo(dB);
            });
            candidateTower = candidates.first;
          } else {
            candidateTower = candidates.first;
          }

          // Rule 3: Distance sanity check
          if (userLocation != null) {
            final dMeters = const Distance().as(LengthUnit.Meter, userLocation, candidateTower.location);
            if (dMeters <= maxEnodebDistanceMeters) {
              return ServingTowerMatchResult(
                tower: candidateTower,
                source: ServingMatchSource.enodebExact,
                distanceMeters: dMeters,
                distanceAnomaly: false,
              );
            } else {
              // Distance > 15 km: radio anomaly / unmapped eNodeB. Fallback to nearest estimate if available
              final nearest = _findNearestTower(towers, userLocation, maxDistanceMeters: 10000.0);
              if (nearest != null) {
                final nDist = const Distance().as(LengthUnit.Meter, userLocation, nearest.location);
                return ServingTowerMatchResult(
                  tower: nearest,
                  source: ServingMatchSource.nearestEstimate,
                  distanceMeters: nDist,
                  distanceAnomaly: true,
                );
              }
              // Jika tidak ada tower < 10km, tetap kembalikan candidate dengan flag distanceAnomaly = true
              return ServingTowerMatchResult(
                tower: candidateTower,
                source: ServingMatchSource.enodebExact,
                distanceMeters: dMeters,
                distanceAnomaly: true,
              );
            }
          } else {
            return ServingTowerMatchResult(
              tower: candidateTower,
              source: ServingMatchSource.enodebExact,
              distanceMeters: null,
              distanceAnomaly: false,
            );
          }
        }
      }
    }

    // Fallback: Untuk non-LTE (GSM/WCDMA/NR) atau jika eNodeB LTE tidak ditemukan di database
    if (userLocation != null) {
      final nearest = _findNearestTower(towers, userLocation, maxDistanceMeters: 10000.0);
      if (nearest != null) {
        final nDist = const Distance().as(LengthUnit.Meter, userLocation, nearest.location);
        return ServingTowerMatchResult(
          tower: nearest,
          source: ServingMatchSource.nearestEstimate,
          distanceMeters: nDist,
          distanceAnomaly: false,
        );
      }
    }

    return ServingTowerMatchResult.empty;
  }

  static BtsTower? _findNearestTower(
    List<BtsTower> towers,
    LatLng userLocation, {
    required double maxDistanceMeters,
  }) {
    double minDistance = maxDistanceMeters;
    BtsTower? closest;
    for (final t in towers) {
      final d = const Distance().as(LengthUnit.Meter, userLocation, t.location);
      if (d < minDistance) {
        minDistance = d;
        closest = t;
      }
    }
    return closest;
  }
}
