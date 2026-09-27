import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/cell_signal_info.dart';
import '../models/wifi_info.dart';
import '../models/lan_device.dart';
import '../models/ping_result.dart';
import '../models/speed_test_result.dart';
import '../services/telephony_bridge.dart';
import '../services/wifi_service.dart';
import '../services/lan_scanner.dart';
import '../services/network_tools.dart';
import '../services/speed_test_service.dart';

// ============================================================================
// Service providers
// ============================================================================

final telephonyBridgeProvider = Provider<TelephonyBridge>((_) => const TelephonyBridge());
final wifiServiceProvider = Provider<WifiService>((_) => const WifiService());
final lanScannerProvider = Provider<LanScanner>((_) => const LanScanner());
final networkToolsProvider = Provider<NetworkTools>((_) => const NetworkTools());
final speedTestServiceProvider = Provider<SpeedTestService>((_) => SpeedTestService.instance);

// ============================================================================
// Cellular Signal & SIM Slots — polling setiap 2 detik (G-NetTrack Live Monitor)
// ============================================================================

final simSlotsProvider = FutureProvider.autoDispose<List<SimSlotInfo>>((ref) async {
  final bridge = ref.watch(telephonyBridgeProvider);
  return bridge.getSimSlots();
});

class SelectedSlotNotifier extends Notifier<int> {
  @override
  int build() => 0; // 0 = SIM 1, 1 = SIM 2

  @override
  set state(int value) => super.state = value;

  void select(int slot) => state = slot;
}

final selectedSlotProvider =
    NotifierProvider<SelectedSlotNotifier, int>(
  SelectedSlotNotifier.new,
);

final cellSignalProvider = StreamProvider.autoDispose<TelephonySnapshot>((ref) async* {
  final bridge = ref.watch(telephonyBridgeProvider);
  final slotIndex = ref.watch(selectedSlotProvider);
  final simSlots = ref.watch(simSlotsProvider).value ?? [];
  final targetSlot = simSlots.where((s) => s.simSlotIndex == slotIndex).firstOrNull;
  final subId = targetSlot?.subscriptionId;

  var isDisposed = false;
  ref.onDispose(() => isDisposed = true);

  while (!isDisposed) {
    try {
      final snapshot = await bridge.getCellInfo(
        subscriptionId: subId,
        slotIndex: slotIndex,
      );
      if (isDisposed) break;
      yield snapshot;
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 2));
  }
});

// ============================================================================
// Live Throughput (Traffic Rate: DL & UL in kbps)
// ============================================================================

class LiveThroughput {
  final double dlKbps;
  final double ulKbps;
  const LiveThroughput({this.dlKbps = 0, this.ulKbps = 0});

  String get dlDisplay => '${dlKbps.toStringAsFixed(0)} kbps';
  String get ulDisplay => '${ulKbps.toStringAsFixed(0)} kbps';
}

final liveThroughputProvider = StreamProvider.autoDispose<LiveThroughput>((ref) async* {
  final bridge = ref.watch(telephonyBridgeProvider);
  var isDisposed = false;
  ref.onDispose(() => isDisposed = true);

  NetworkTrafficSnapshot? prev;
  DateTime? prevTime;

  while (!isDisposed) {
    await Future.delayed(const Duration(seconds: 2));
    if (isDisposed) break;
    try {
      final current = await bridge.getTrafficStats();
      final now = DateTime.now();

      if (prev != null && prevTime != null) {
        final elapsedSec = now.difference(prevTime).inMilliseconds / 1000.0;
        if (elapsedSec > 0.4) {
          final rxDiff = current.totalRxBytes - prev.totalRxBytes;
          final txDiff = current.totalTxBytes - prev.totalTxBytes;
          if (rxDiff >= 0 && txDiff >= 0) {
            final dlKbps = (rxDiff * 8.0) / (elapsedSec * 1000.0);
            final ulKbps = (txDiff * 8.0) / (elapsedSec * 1000.0);
            if (!isDisposed) {
              yield LiveThroughput(dlKbps: dlKbps, ulKbps: ulKbps);
            }
          }
        }
      }
      prev = current;
      prevTime = now;
    } catch (_) {}
  }
});

// ============================================================================
// Live GPS Location
// ============================================================================

class LiveGpsInfo {
  final double? latitude;
  final double? longitude;
  final double? altitudeM;
  final double? speedKmh;
  final double? headingDeg;
  final double? accuracyM;

  const LiveGpsInfo({
    this.latitude,
    this.longitude,
    this.altitudeM,
    this.speedKmh,
    this.headingDeg,
    this.accuracyM,
  });

  String get latitudeDisplay => latitude != null ? latitude!.toStringAsFixed(5) : '-';
  String get longitudeDisplay => longitude != null ? longitude!.toStringAsFixed(5) : '-';
  String get altitudeDisplay => altitudeM != null ? '${altitudeM!.round()}m' : '-';
  String get speedDisplay => speedKmh != null ? '${speedKmh!.round()} km/h' : '0 km/h';
  String get headingDisplay => headingDeg != null ? '${headingDeg!.round()}° N' : '0° N';
  String get accuracyDisplay => accuracyM != null ? '${accuracyM!.round()}m' : '-';
}

final liveGpsProvider = StreamProvider.autoDispose<LiveGpsInfo>((ref) async* {
  try {
    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    );
    await for (final pos in stream) {
      yield LiveGpsInfo(
        latitude: pos.latitude,
        longitude: pos.longitude,
        altitudeM: pos.altitude,
        speedKmh: pos.speed * 3.6,
        headingDeg: pos.heading,
        accuracyM: pos.accuracy,
      );
    }
  } catch (_) {
    yield const LiveGpsInfo();
  }
});

// ============================================================================
// Serving Cell Dwell Time & History Log (G-NetTrack Parity)
// ============================================================================

class CellHistoryEntry {
  final String time;
  final String event;
  final String areaCode;
  final String cellId;
  final String pci;
  final String arfcn;
  final String level;
  final String qual;
  final String type;
  final bool isServing;

  const CellHistoryEntry({
    required this.time,
    required this.event,
    required this.areaCode,
    required this.cellId,
    required this.pci,
    required this.arfcn,
    required this.level,
    required this.qual,
    required this.type,
    required this.isServing,
  });
}

class CellTrackerState {
  final int servingTimeSeconds;
  final int? lastCellId;
  final int? lastPci;
  final List<CellHistoryEntry> history;

  const CellTrackerState({
    this.servingTimeSeconds = 0,
    this.lastCellId,
    this.lastPci,
    this.history = const [],
  });

  String get servingTimeDisplay {
    if (servingTimeSeconds < 60) return '${servingTimeSeconds}s';
    final mins = servingTimeSeconds ~/ 60;
    final secs = servingTimeSeconds % 60;
    return '${mins}m ${secs}s';
  }
}

class CellTrackerNotifier extends Notifier<CellTrackerState> {
  Timer? _ticker;

  @override
  CellTrackerState build() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      state = CellTrackerState(
        servingTimeSeconds: state.servingTimeSeconds + 1,
        lastCellId: state.lastCellId,
        lastPci: state.lastPci,
        history: state.history,
      );
    });
    ref.onDispose(() => _ticker?.cancel());

    ref.listen<AsyncValue<TelephonySnapshot>>(cellSignalProvider, (prev, next) {
      next.whenData((snapshot) {
        updateCell(snapshot);
      });
    });

    return const CellTrackerState();
  }

  void updateCell(TelephonySnapshot snapshot) {
    final cell = snapshot.servingCell;
    if (cell == null) return;

    final isNewCell = state.lastCellId != null &&
        (state.lastCellId != cell.cellId || state.lastPci != cell.pci);
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final entry = CellHistoryEntry(
      time: timeStr,
      event: isNewCell ? 'HANDOVER' : 'SERVING',
      areaCode: cell.tacDisplay,
      cellId: cell.eNodeBCidDisplay,
      pci: cell.pciDisplay,
      arfcn: cell.arfcnDisplay,
      level: cell.primarySignalDbm != null ? '${cell.primarySignalDbm}' : '-',
      qual: cell.rsrq != null ? '${cell.rsrq}' : '-',
      type: cell.networkType,
      isServing: true,
    );

    // Filter duplicate serving events on the same second
    final updatedHistory = [entry, ...state.history].take(20).toList();

    state = CellTrackerState(
      servingTimeSeconds: isNewCell ? 0 : state.servingTimeSeconds,
      lastCellId: cell.cellId,
      lastPci: cell.pci,
      history: updatedHistory,
    );
  }
}

final cellTrackerProvider = NotifierProvider<CellTrackerNotifier, CellTrackerState>(
  CellTrackerNotifier.new,
);

// ============================================================================
// RF Analysis Provider (AURA Smart RF Analytics)
// ============================================================================

final rfAnalysisProvider = Provider.autoDispose<RfAnalysisReport>((ref) {
  final cellAsync = ref.watch(cellSignalProvider);
  return cellAsync.maybeWhen(
    data: (snapshot) => RfAnalyzer.evaluate(snapshot),
    orElse: () => const RfAnalysisReport(
      overallScore: 0,
      scoreGrade: 'N/A',
      coverageRating: 'Menunggu Data',
      coverageExplanation: 'Sedang membaca modem seluler...',
      interferenceRating: 'N/A',
      interferenceExplanation: 'Menunggu data...',
      modulationCapability: 'N/A',
      distanceEstimate: 'N/A',
      verdictSummary: 'Menghubungkan ke modem seluler...',
      practicalAdvice: [],
    ),
  );
});

// ============================================================================
// WiFi Info — polling setiap 5 detik
// ============================================================================

final wifiInfoProvider = StreamProvider.autoDispose<WifiInfo>((ref) {
  final service = ref.watch(wifiServiceProvider);
  return service.wifiInfoStream(interval: const Duration(seconds: 5));
});

// ============================================================================
// LAN Scan — on-demand (StateNotifier)
// ============================================================================

class LanScanState {
  final bool isScanning;
  final LanScanResult? result;
  final String? error;

  const LanScanState({
    this.isScanning = false,
    this.result,
    this.error,
  });

  LanScanState copyWith({bool? isScanning, LanScanResult? result, String? error}) =>
      LanScanState(
        isScanning: isScanning ?? this.isScanning,
        result: result ?? this.result,
        error: error ?? this.error,
      );
}

class LanScanNotifier extends Notifier<LanScanState> {
  LanScanner get _scanner => ref.watch(lanScannerProvider);

  @override
  LanScanState build() => const LanScanState();

  Future<void> startScan() async {
    if (state.isScanning) return;
    state = state.copyWith(isScanning: true, error: null);

    try {
      final result = await _scanner.scanLocalSubnet(
        onDeviceFound: (_) {
          // Re-emit state setiap device baru ditemukan (streaming)
          state = state.copyWith(isScanning: true);
        },
      );
      state = LanScanState(isScanning: false, result: result);
    } catch (e) {
      state = LanScanState(isScanning: false, error: e.toString());
    }
  }
}

final lanScanNotifierProvider =
    NotifierProvider<LanScanNotifier, LanScanState>(
  LanScanNotifier.new,
);

// ============================================================================
// Speed Test — on-demand (Notifier)
// ============================================================================

class SpeedTestState {
  final SpeedTestPhase phase;
  final double downloadMbps;
  final double uploadMbps;
  final int latencyMs;
  final double progress;
  final SpeedTestResult? result;
  final bool isFromCache;
  final String? error;

  const SpeedTestState({
    this.phase = SpeedTestPhase.idle,
    this.downloadMbps = 0,
    this.uploadMbps = 0,
    this.latencyMs = 0,
    this.progress = 0,
    this.result,
    this.isFromCache = false,
    this.error,
  });

  SpeedTestState copyWith({
    SpeedTestPhase? phase,
    double? downloadMbps,
    double? uploadMbps,
    int? latencyMs,
    double? progress,
    SpeedTestResult? result,
    bool? isFromCache,
    String? error,
  }) =>
      SpeedTestState(
        phase: phase ?? this.phase,
        downloadMbps: downloadMbps ?? this.downloadMbps,
        uploadMbps: uploadMbps ?? this.uploadMbps,
        latencyMs: latencyMs ?? this.latencyMs,
        progress: progress ?? this.progress,
        result: result ?? this.result,
        isFromCache: isFromCache ?? this.isFromCache,
        error: error,
      );
}

class SpeedTestNotifier extends Notifier<SpeedTestState> {
  SpeedTestService get _service => ref.watch(speedTestServiceProvider);
  StreamSubscription<SpeedTestProgress>? _sub;

  @override
  SpeedTestState build() {
    ref.onDispose(() {
      _sub?.cancel();
    });
    return const SpeedTestState();
  }

  Future<void> runTest({bool useCacheIfAvailable = false}) async {
    if (state.phase != SpeedTestPhase.idle && state.phase != SpeedTestPhase.done && state.phase != SpeedTestPhase.error) return;

    await _sub?.cancel();
    state = const SpeedTestState(phase: SpeedTestPhase.pinging);

    _sub = _service.runSpeedTest(useCacheIfAvailable: useCacheIfAvailable).listen(
      (progress) {
        state = state.copyWith(
          phase: progress.phase,
          progress: progress.progress,
          latencyMs: progress.latencyMs ?? state.latencyMs,
          downloadMbps: progress.phase == SpeedTestPhase.downloading
              ? progress.currentMbps
              : state.downloadMbps,
          uploadMbps: progress.phase == SpeedTestPhase.uploading
              ? progress.currentMbps
              : state.uploadMbps,
        );

        if (progress.phase == SpeedTestPhase.done) {
          final r = _service.lastResult;
          if (r != null) {
            state = state.copyWith(
              result: r,
              downloadMbps: r.downloadMbps,
              uploadMbps: r.uploadMbps,
              latencyMs: r.latencyMs,
              isFromCache: r.isFromCache,
            );
          }
        }
      },
      onError: (e) {
        state = state.copyWith(phase: SpeedTestPhase.error, error: e.toString());
      },
    );
  }
}

final speedTestNotifierProvider =
    NotifierProvider<SpeedTestNotifier, SpeedTestState>(
  SpeedTestNotifier.new,
);

// ============================================================================
// Network Tools — ping, DNS, traceroute (on-demand Future providers)
// ============================================================================

final pingProvider = FutureProvider.autoDispose.family<PingResult, String>((ref, host) async {
  return ref.watch(networkToolsProvider).pingHost(host);
});

final dnsLookupProvider = FutureProvider.autoDispose.family<DnsResult, String>((ref, domain) async {
  return ref.watch(networkToolsProvider).dnsLookup(domain);
});
