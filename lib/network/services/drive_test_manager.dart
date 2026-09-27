import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:csv/csv.dart';
import '../models/drive_test_log.dart';
import 'telephony_bridge.dart';

const _kMaxSessionDuration = Duration(hours: 4);
const _kDefaultSamplingInterval = Duration(seconds: 3);

/// Manages a drive test session: logging cellular signal + GPS to SQLite,
/// with auto-stop, CSV export, and KML export.
class DriveTestManager {
  final TelephonyBridge _telephonyBridge;

  DriveSession? _currentSession;
  Timer? _loggingTimer;
  Timer? _autoStopTimer;
  int _pointCount = 0;
  bool _isRunning = false;
  LogPoint? _lastPoint;
  Database? _db;

  final _updateController = StreamController<DriveTestUpdate>.broadcast();
  Stream<DriveTestUpdate> get updateStream => _updateController.stream;

  DriveTestManager({TelephonyBridge? telephonyBridge})
      : _telephonyBridge = telephonyBridge ?? const TelephonyBridge();

  bool get isRunning => _isRunning;
  DriveSession? get currentSession => _currentSession;
  int get pointCount => _pointCount;
  LogPoint? get lastPoint => _lastPoint;

  Future<void> initialize() async {
    await _initDb();
  }

  Future<void> _initDb() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'aura_drive_test.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            started_at INTEGER NOT NULL,
            ended_at INTEGER,
            point_count INTEGER DEFAULT 0,
            is_auto_stopped INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS log_points (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER NOT NULL,
            timestamp INTEGER NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            altitude_m REAL,
            accuracy_m REAL,
            speed_ms REAL,
            network_type TEXT NOT NULL,
            band TEXT,
            rsrp_dbm INTEGER,
            rsrq_db INTEGER,
            sinr_db INTEGER,
            rssi_dbm INTEGER,
            cell_id INTEGER,
            pci INTEGER,
            operator TEXT,
            download_mbps REAL,
            upload_mbps REAL,
            ping_ms INTEGER,
            FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  Future<void> startSession({
    String? name,
    Duration samplingInterval = _kDefaultSamplingInterval,
    Duration maxDuration = _kMaxSessionDuration,
  }) async {
    if (_isRunning) return;

    await _initDb();
    final now = DateTime.now();
    final sessionName = name ?? 'Session ${now.toLocal().toString().substring(0, 16)}';

    final id = await _db!.insert('sessions', {
      'name': sessionName,
      'started_at': now.millisecondsSinceEpoch,
      'point_count': 0,
      'is_auto_stopped': 0,
    });

    _currentSession = DriveSession(
      id: id,
      name: sessionName,
      startedAt: now,
    );
    _pointCount = 0;
    _isRunning = true;

    _autoStopTimer = Timer(maxDuration, () async {
      await stopSession(isAutoStopped: true);
    });

    _loggingTimer = Timer.periodic(samplingInterval, (_) => _logSinglePoint());

    _updateController.add(DriveTestUpdate(
      lastPoint: null,
      pointCount: 0,
      elapsed: Duration.zero,
      remainingBeforeAutoStop: maxDuration,
    ));
  }

  Future<void> stopSession({bool isAutoStopped = false}) async {
    if (!_isRunning) return;

    _loggingTimer?.cancel();
    _loggingTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;

    final endedAt = DateTime.now();
    if (_currentSession?.id != null && _db != null) {
      await _db!.update(
        'sessions',
        {
          'ended_at': endedAt.millisecondsSinceEpoch,
          'point_count': _pointCount,
          'is_auto_stopped': isAutoStopped ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [_currentSession!.id],
      );
    }

    _isRunning = false;
    _updateController.add(DriveTestUpdate(
      lastPoint: _lastPoint,
      pointCount: _pointCount,
      elapsed: _currentSession != null ? endedAt.difference(_currentSession!.startedAt) : Duration.zero,
      remainingBeforeAutoStop: Duration.zero,
    ));
  }

  Future<void> _logSinglePoint() async {
    if (!_isRunning || _currentSession?.id == null || _db == null) return;

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 2),
          ),
        );
      } catch (_) {}

      if (position == null) return;

      final snapshot = await _telephonyBridge.getCellInfo();
      final cell = snapshot.servingCell;

      final point = LogPoint(
        sessionId: _currentSession!.id!,
        timestamp: DateTime.now(),
        latitude: position.latitude,
        longitude: position.longitude,
        altitudeM: position.altitude,
        accuracyM: position.accuracy,
        speedMs: position.speed,
        networkType: snapshot.networkType,
        operator_: snapshot.operatorDisplayName,
        cellId: cell?.cellId,
        pci: cell?.pci,
        band: cell?.bandShortCode,
        rsrpDbm: cell?.rsrp ?? cell?.ssRsrp,
        rsrqDb: cell?.rsrq ?? cell?.ssRsrq,
        sinrDb: cell?.sinr ?? cell?.ssSinr,
        rssiDbm: cell?.rssi ?? cell?.dbm,
      );

      await _db!.insert('log_points', point.toMap());

      _pointCount++;
      _lastPoint = point;

      final now = DateTime.now();
      final elapsed = now.difference(_currentSession!.startedAt);
      final remaining = _kMaxSessionDuration - elapsed;

      _updateController.add(DriveTestUpdate(
        lastPoint: point,
        pointCount: _pointCount,
        elapsed: elapsed,
        remainingBeforeAutoStop: remaining.isNegative ? Duration.zero : remaining,
      ));
    } catch (e) {
      if (kDebugMode) print('Error logging drive test point: $e');
    }
  }

  Future<List<DriveSession>> getAllSessions() async {
    await _initDb();
    final rows = await _db!.query('sessions', orderBy: 'started_at DESC');
    return rows.map((r) => DriveSession.fromMap(r)).toList();
  }

  Future<List<LogPoint>> getSessionPoints(int sessionId) async {
    await _initDb();
    final rows = await _db!.query(
      'log_points',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return rows.map((r) => LogPoint.fromMap(r)).toList();
  }

  Future<String> exportToCsv(int sessionId) async {
    final points = await getSessionPoints(sessionId);
    final headers = LogPoint.csvHeaders;
    final rows = <List<dynamic>>[headers];

    for (final p in points) {
      rows.add(p.toCsvRow());
    }

    final csvString = const ListToCsvConverter().convert(rows);
    final dbPath = await getDatabasesPath();
    final file = File(p.join(dbPath, 'drive_test_$sessionId.csv'));
    await file.writeAsString(csvString);
    return file.path;
  }

  Future<String> exportToKml(int sessionId) async {
    final points = await getSessionPoints(sessionId);
    final buf = StringBuffer();
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<kml xmlns="http://www.opengis.net/kml/2.2">');
    buf.writeln('  <Document>');
    buf.writeln('    <name>Drive Test Session $sessionId</name>');

    for (final p in points) {
      buf.writeln('    <Placemark>');
      buf.writeln('      <name>${p.networkType} | RSRP: ${p.rsrpDbm ?? "-"} dBm</name>');
      buf.writeln('      <Point>');
      buf.writeln('        <coordinates>${p.longitude},${p.latitude}</coordinates>');
      buf.writeln('      </Point>');
      buf.writeln('    </Placemark>');
    }

    buf.writeln('  </Document>');
    buf.writeln('</kml>');

    final dbPath = await getDatabasesPath();
    final file = File(p.join(dbPath, 'drive_test_$sessionId.kml'));
    await file.writeAsString(buf.toString());
    return file.path;
  }

  void dispose() {
    _loggingTimer?.cancel();
    _autoStopTimer?.cancel();
    _updateController.close();
  }
}
