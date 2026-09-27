import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/drive_test_log.dart';
import '../services/drive_test_manager.dart';

// ============================================================================
// DriveTestManager singleton provider
// ============================================================================

final driveTestManagerProvider = Provider<DriveTestManager>((ref) {
  final manager = DriveTestManager();
  ref.onDispose(manager.dispose);
  return manager;
});

// ============================================================================
// Drive Test State
// ============================================================================

class DriveTestState {
  final bool isRunning;
  final DriveSession? currentSession;
  final int pointCount;
  final Duration elapsed;
  final Duration remainingBeforeAutoStop;
  final LogPoint? lastPoint;
  final List<LogPoint> recordedPoints;
  final List<DriveSession> sessionHistory;
  final bool isLoadingHistory;
  final String? exportedFilePath;
  final String? error;

  const DriveTestState({
    this.isRunning = false,
    this.currentSession,
    this.pointCount = 0,
    this.elapsed = Duration.zero,
    this.remainingBeforeAutoStop = const Duration(hours: 4),
    this.lastPoint,
    this.recordedPoints = const [],
    this.sessionHistory = const [],
    this.isLoadingHistory = false,
    this.exportedFilePath,
    this.error,
  });

  DriveTestState copyWith({
    bool? isRunning,
    DriveSession? currentSession,
    int? pointCount,
    Duration? elapsed,
    Duration? remainingBeforeAutoStop,
    LogPoint? lastPoint,
    List<LogPoint>? recordedPoints,
    List<DriveSession>? sessionHistory,
    bool? isLoadingHistory,
    String? exportedFilePath,
    String? error,
  }) =>
      DriveTestState(
        isRunning: isRunning ?? this.isRunning,
        currentSession: currentSession ?? this.currentSession,
        pointCount: pointCount ?? this.pointCount,
        elapsed: elapsed ?? this.elapsed,
        remainingBeforeAutoStop: remainingBeforeAutoStop ?? this.remainingBeforeAutoStop,
        lastPoint: lastPoint ?? this.lastPoint,
        recordedPoints: recordedPoints ?? this.recordedPoints,
        sessionHistory: sessionHistory ?? this.sessionHistory,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
        exportedFilePath: exportedFilePath,
        error: error,
      );
}

// ============================================================================
// DriveTest Notifier
// ============================================================================

class DriveTestNotifier extends Notifier<DriveTestState> {
  DriveTestManager get _manager => ref.watch(driveTestManagerProvider);
  StreamSubscription<DriveTestUpdate>? _sub;

  @override
  DriveTestState build() {
    ref.onDispose(() {
      _sub?.cancel();
    });

    _manager.initialize().then((_) {
      _sub = _manager.updateStream.listen(_onUpdate);
      _loadHistory();
    });

    return const DriveTestState();
  }

  void _onUpdate(DriveTestUpdate update) {
    final newPoints = update.lastPoint != null
        ? [...state.recordedPoints, update.lastPoint!]
        : state.recordedPoints;
    state = state.copyWith(
      isRunning: _manager.isRunning,
      currentSession: _manager.currentSession,
      pointCount: update.pointCount,
      elapsed: update.elapsed,
      remainingBeforeAutoStop: update.remainingBeforeAutoStop,
      lastPoint: update.lastPoint,
      recordedPoints: newPoints,
    );
  }

  Future<void> _loadHistory() async {
    state = state.copyWith(isLoadingHistory: true);
    try {
      final sessions = await _manager.getAllSessions();
      state = state.copyWith(sessionHistory: sessions, isLoadingHistory: false);
    } catch (_) {
      state = state.copyWith(isLoadingHistory: false);
    }
  }

  Future<void> startSession({String? name}) async {
    try {
      await _manager.startSession(name: name);
      state = state.copyWith(isRunning: true, recordedPoints: const [], error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> stopSession() async {
    await _manager.stopSession();
    await _loadHistory();
    state = state.copyWith(isRunning: false);
  }

  Future<void> exportCsv(int sessionId) async {
    try {
      final path = await _manager.exportToCsv(sessionId);
      state = state.copyWith(exportedFilePath: path);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> exportKml(int sessionId) async {
    try {
      final path = await _manager.exportToKml(sessionId);
      state = state.copyWith(exportedFilePath: path);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final driveTestNotifierProvider =
    NotifierProvider<DriveTestNotifier, DriveTestState>(
  DriveTestNotifier.new,
);

/// Provider untuk mengambil history titik log berdasarkan session ID.
final sessionPointsProvider =
    FutureProvider.family<List<LogPoint>, int>((ref, sessionId) async {
  final manager = ref.watch(driveTestManagerProvider);
  return manager.getSessionPoints(sessionId);
});
