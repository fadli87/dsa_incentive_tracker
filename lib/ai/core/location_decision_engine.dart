import 'dart:math' as math;
import '../../core/catalog/package_catalog.dart';
import '../../maps/models/map_models.dart';
import '../../network/models/cell_signal_info.dart';
import '../models/quick_action.dart';

enum LocationDecisionType {
  ftthRecommended,
  fwaRecommended,
  fwaWeakSignal,
  outOfCoverage,
}

class LocationDecisionCard {
  final LocationDecisionType decisionType;
  final String title;
  final String description;
  final double? actualDistanceMeters;
  final HomepassPoint? nearestPoint;
  final List<CatalogPackage> recommendedPackages;
  final String recommendedScript;
  final List<QuickAction> actions;
  final bool isExistingCustomer;
  final bool isNonPriority;

  const LocationDecisionCard({
    required this.decisionType,
    required this.title,
    required this.description,
    this.actualDistanceMeters,
    this.nearestPoint,
    required this.recommendedPackages,
    required this.recommendedScript,
    required this.actions,
    this.isExistingCustomer = false,
    this.isNonPriority = false,
  });
}

/// Pure function engine untuk menentukan rekomendasi paket berdasarkan lokasi GPS,
/// titik homepass terdekat, dan evaluasi sinyal seluler (RF).
class LocationDecisionEngine {
  LocationDecisionEngine._();

  static const double defaultRadiusMeters = 100.0;
  static const int fwaReadyScoreThreshold = 60;

  /// Hitung jarak akurat antara 2 titik koordinat (Haversine Formula dalam meter)
  static double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // Meter
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  /// Evaluasi lokasi murni (Pure Function)
  static LocationDecisionCard evaluateLocation({
    required double userLat,
    required double userLng,
    required List<HomepassPoint> homepassList,
    TelephonySnapshot? currentRfSignal,
    double radiusMeters = defaultRadiusMeters,
  }) {
    if (homepassList.isEmpty) {
      return _buildOutOfCoverageCard(null, null);
    }

    // Hitung jarak ke setiap homepass
    final List<({HomepassPoint point, double distance})> withDistance = [];
    for (final hp in homepassList) {
      final dist = calculateDistanceMeters(userLat, userLng, hp.latitude, hp.longitude);
      withDistance.add((point: hp, distance: dist));
    }
    withDistance.sort((a, b) => a.distance.compareTo(b.distance));

    // Cari titik FTTH terdekat & FWA terdekat
    final ftthMatches = withDistance.where((e) => e.point.displayTechnologyLabel == 'FTTH').toList();
    final fwaMatches = withDistance.where((e) => e.point.displayTechnologyLabel.startsWith('FWA')).toList();

    final nearestOverall = withDistance.first;
    final nearestFtth = ftthMatches.isNotEmpty ? ftthMatches.first : null;
    final nearestFwa = fwaMatches.isNotEmpty ? fwaMatches.first : null;

    // 1. Gating FTTH dalam radius R
    if (nearestFtth != null && nearestFtth.distance <= radiusMeters) {
      return _buildFtthCard(nearestFtth.point, nearestFtth.distance);
    }

    // 2. Gating FWA dalam radius R
    if (nearestFwa != null && nearestFwa.distance <= radiusMeters) {
      int? rfScore;
      if (currentRfSignal != null) {
        rfScore = RfAnalyzer.evaluate(currentRfSignal).overallScore;
      }

      final isRfGood = rfScore == null || rfScore >= fwaReadyScoreThreshold;

      if (isRfGood) {
        return _buildFwaCard(nearestFwa.point, nearestFwa.distance, rfScore);
      } else {
        return _buildFwaWeakSignalCard(nearestFwa.point, nearestFwa.distance, rfScore);
      }
    }

    // 3. Di luar radius R
    return _buildOutOfCoverageCard(nearestOverall.point, nearestOverall.distance);
  }

  static LocationDecisionCard _buildFtthCard(HomepassPoint point, double distance) {
    final ftthPackages = PackageCatalog.getFtthPackages().take(3).toList();
    final hero = PackageCatalog.findById('ftth-hero-250-mbps') ?? ftthPackages.first;

    final sbDesc = StringBuffer();
    sbDesc.writeln('Lokasi berada dalam jangkauan kabel optik FTTH (jarak ${distance.toStringAsFixed(0)} m ke homepass ${point.id}).');
    if (point.isExistingCustomer) {
      sbDesc.writeln('⚠️ **Perhatian:** Titik terdata sebagai Existing FTTH Customer. Tawarkan upgrade paket atau verifikasi kepemilikan.');
    } else if (point.isNonPriority) {
      sbDesc.writeln('ℹ️ Titik non-prioritas, pastikan ketersediaan port ODP tiang saat survei.');
    }

    final script = 'Selamat pagi/siang Bapak/Ibu, perumahan Anda sudah tercover jaringan internet fiber optik XL SATU FIBER dengan tiang ODP terdekat hanya ${distance.toStringAsFixed(0)} meter. Kami menyediakan paket ${hero.title} ${hero.speedMbps} Mbps promo gratis biaya pasang + kuota HP sekeluarga. Boleh saya bantu proses pendaftarannya?';

    return LocationDecisionCard(
      decisionType: LocationDecisionType.ftthRecommended,
      title: '✅ Direkomendasikan: XL SATU FTTH (Kabel Optik)',
      description: sbDesc.toString().trim(),
      actualDistanceMeters: distance,
      nearestPoint: point,
      recommendedPackages: ftthPackages,
      recommendedScript: script,
      isExistingCustomer: point.isExistingCustomer,
      isNonPriority: point.isNonPriority,
      actions: [
        const QuickAction(
          label: 'Daftar Paket FTTH',
          intent: 'package_list',
          args: {'type': 'ftth'},
        ),
        const QuickAction(
          label: 'Draf Pesan WhatsApp',
          intent: 'wa_draft',
        ),
        QuickAction.nav(
          label: 'Buka Peta Cakupan',
          destination: CoachDestination.coverageMap,
        ),
      ],
    );
  }

  static LocationDecisionCard _buildFwaCard(HomepassPoint point, double distance, int? rfScore) {
    final fwaPackages = PackageCatalog.getFwaPackages();
    final hero = PackageCatalog.findById('fwa-hero-100-mbps') ?? fwaPackages.first;

    final script = 'Selamat pagi/siang Bapak/Ibu, lokasi rumah Anda sangat cocok menggunakan XL SATU FWA Nirkabel (${hero.title}) kecepatan 100 Mbps Plug & Play tanpa tarik kabel tiang. Pemasangan cepat langsung aktif hari ini. Boleh saya bantu pasangkan?';

    return LocationDecisionCard(
      decisionType: LocationDecisionType.fwaRecommended,
      title: '✅ Direkomendasikan: XL SATU FWA (Nirkabel)',
      description: 'Homepass FWA terdeteksi pada jarak ${distance.toStringAsFixed(0)} m (ID: ${point.id}) dengan kualitas sinyal seluler prima (${rfScore ?? "Baik"}/100).',
      actualDistanceMeters: distance,
      nearestPoint: point,
      recommendedPackages: fwaPackages,
      recommendedScript: script,
      actions: [
        const QuickAction(
          label: 'Daftar Paket FWA',
          intent: 'package_list',
          args: {'type': 'fwa'},
        ),
        const QuickAction(
          label: 'Script Closing FWA',
          intent: 'script_get',
          args: {'type': 'fwa'},
        ),
        const QuickAction(
          label: 'Rekomendasi Paket Sinyal',
          intent: 'rf_analyze',
        ),
      ],
    );
  }

  static LocationDecisionCard _buildFwaWeakSignalCard(HomepassPoint point, double distance, int? rfScore) {
    final fwaPackages = PackageCatalog.getFwaPackages();

    return LocationDecisionCard(
      decisionType: LocationDecisionType.fwaWeakSignal,
      title: '⚠️ FWA Tercover tapi Sinyal Kurang Optimal',
      description: 'Homepass FWA berada dalam radius ${distance.toStringAsFixed(0)} m, namun skor kualitas sinyal seluler saat ini $rfScore/100 (< 60). Disarankan tes posisi router outdoor atau periksa tiang ODP fiber terdekat.',
      actualDistanceMeters: distance,
      nearestPoint: point,
      recommendedPackages: fwaPackages,
      recommendedScript: 'Untuk memastikan koneksi maksimal di lokasi ini, kami sarankan pemasangan CPE router di area outdoor atau lantai atas.',
      actions: [
        const QuickAction(
          label: 'Rekomendasi Paket Sinyal',
          intent: 'rf_analyze',
        ),
        const QuickAction(
          label: 'Daftar Paket FTTH',
          intent: 'package_list',
          args: {'type': 'ftth'},
        ),
      ],
    );
  }

  static LocationDecisionCard _buildOutOfCoverageCard(HomepassPoint? nearestPoint, double? distance) {
    final distText = distance != null
        ? (distance > 1000 ? '${(distance / 1000).toStringAsFixed(1)} km' : '${distance.toStringAsFixed(0)} m')
        : 'tidak terdeteksi';

    return LocationDecisionCard(
      decisionType: LocationDecisionType.outOfCoverage,
      title: '📍 Di Luar Radius Homepass (Cek Manual)',
      description: 'Tidak ada titik homepass resmi dalam radius 100 m. Titik jaringan terdekat berjarak $distText. Silakan cek tiang fisik di sekitar lokasi atau gunakan FWA Outdoor jika sinyal 4G/5G mencukupi.',
      actualDistanceMeters: distance,
      nearestPoint: nearestPoint,
      recommendedPackages: PackageCatalog.getFwaPackages(),
      recommendedScript: 'Izin cek tiang kabel terdekat atau ukur sinyal 4G/5G di lokasi rumah Anda.',
      actions: [
        const QuickAction(
          label: 'Rekomendasi Paket Sinyal',
          intent: 'rf_analyze',
        ),
        QuickAction.nav(
          label: 'Buka Peta Cakupan',
          destination: CoachDestination.coverageMap,
        ),
      ],
    );
  }
}
