import 'dart:io' show Platform, Directory;
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../../ai/models/coach_log_entry.dart';
import '../../auth/supabase_client.dart';
import '../models/customer_map_point.dart';
import '../models/incentive_record.dart';
import '../models/master_customer.dart';
import '../models/sa_record.dart';
import '../models/user_profile.dart';
import '../models/visit_activity.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  bool get _isInMemory {
    if (kIsWeb) return true;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  // In-memory storage fallback saat dijalankan di browser (Web) atau testing
  final List<IncentiveRecord> _webIncentives = [];
  final List<SaRecord> _webSaRecords = [];
  final List<CoachLogEntry> _webCoachLogs = [];
  final List<VisitActivity> _webVisits = [];
  final List<MasterCustomer> _webMasterCustomers = [];
  final List<CustomerMapPoint> _webCustomerMapPoints = [];
  UserProfile _webUserProfile = const UserProfile(
    name: '',
    salesCode: '',
    branch: 'XL SATU CILACAP',
    tsc: 'TSC PIPIN',
  );
  int _webIncentiveIdCounter = 1;
  int _webSaIdCounter = 1;
  int _webCoachLogIdCounter = 1;
  int _webVisitIdCounter = 1;

  DatabaseHelper._init();

  Future<Database?> get database async {
    if (_isInMemory) return null;
    if (_database != null) return _database!;
    _database = await _initDB('dsa_tracker_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
    }

    String dbFolder;
    if (!kIsWeb && Platform.isWindows) {
      final localAppData =
          Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          '';
      if (localAppData.isNotEmpty) {
        dbFolder = join(localAppData, 'DSAIncentiveTracker', 'databases');
      } else {
        dbFolder = await getDatabasesPath();
      }
    } else {
      dbFolder = await getDatabasesPath();
    }

    try {
      final dir = Directory(dbFolder);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
    } catch (_) {}

    final path = join(dbFolder, filePath);
    try {
      return await openDatabase(
        path,
        version: 10,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
        onOpen: _ensureVisitColumns,
      );
    } catch (e) {
      // Fallback path bila terjadi conflict locking dengan multiple instance
      if (!kIsWeb && Platform.isWindows) {
        final fallbackDir = Directory(
          join(Platform.environment['TEMP'] ?? '.', 'DSAIncentiveTracker'),
        );
        if (!fallbackDir.existsSync()) {
          fallbackDir.createSync(recursive: true);
        }
        return await openDatabase(
          join(fallbackDir.path, filePath),
          version: 10,
          onCreate: _createDB,
          onUpgrade: _onUpgrade,
          onOpen: _ensureVisitColumns,
        );
      }
      rethrow;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT,
        periode TEXT NOT NULL,
        period_month TEXT,
        position TEXT NOT NULL DEFAULT 'Elite',
        city TEXT NOT NULL DEFAULT 'KAB. CILACAP',
        basic_fee REAL NOT NULL DEFAULT 0.0,
        total_sa INTEGER NOT NULL,
        pm_base REAL NOT NULL,
        mult_rate REAL NOT NULL,
        mult_bonus REAL NOT NULL,
        prog_inc REAL NOT NULL,
        special_inc REAL NOT NULL,
        monthly_subtotal REAL NOT NULL DEFAULT 0.0,
        grand_total REAL NOT NULL,
        f0 INTEGER NOT NULL DEFAULT 0,
        f50 INTEGER NOT NULL DEFAULT 0,
        f100 INTEGER NOT NULL DEFAULT 0,
        f125 INTEGER NOT NULL DEFAULT 0,
        f200 INTEGER NOT NULL DEFAULT 0,
        fwa INTEGER NOT NULL DEFAULT 0,
        p35 INTEGER NOT NULL DEFAULT 0,
        p6 INTEGER NOT NULL DEFAULT 0,
        sync_state INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sa_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT,
        id_pelanggan TEXT NOT NULL,
        nama TEXT NOT NULL,
        no_hp_utama TEXT NOT NULL DEFAULT '',
        no_hp_alternatif TEXT NOT NULL DEFAULT '',
        alamat TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        paket TEXT NOT NULL,
        tanggal_pasang TEXT NOT NULL,
        sync_state INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        sales_code TEXT NOT NULL,
        branch TEXT NOT NULL DEFAULT 'XL SATU CILACAP',
        tsc TEXT NOT NULL DEFAULT 'TSC PIPIN'
      )
    ''');

    await db.execute('''
      CREATE TABLE coach_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ts INTEGER NOT NULL,
        query_norm TEXT NOT NULL,
        intent TEXT NOT NULL,
        score REAL NOT NULL,
        matched INTEGER NOT NULL,
        feedback INTEGER
      )
    ''');

    await _createVisitTable(db);
    await _createCustomerMasterLocalTable(db);
    await _createCustomerMapPointsLocalTable(db);
  }

  
  Future<void> _createCustomerMapPointsLocalTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_map_points_local (
        customer_id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        install_date TEXT,
        address TEXT NOT NULL DEFAULT '',
        package_name TEXT NOT NULL DEFAULT '',
        sales_name TEXT NOT NULL DEFAULT '',
        spv_name TEXT NOT NULL DEFAULT '',
        tsc_name TEXT NOT NULL DEFAULT '',
        synced_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS customer_map_points_local_sales_idx
        ON customer_map_points_local (sales_name)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS customer_map_points_local_install_idx
        ON customer_map_points_local (install_date)
    ''');
  }

  Future<void> _createCustomerMasterLocalTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_master_local (
        customer_id TEXT PRIMARY KEY,
        install_date TEXT,
        address TEXT NOT NULL DEFAULT '',
        package_name TEXT NOT NULL DEFAULT '',
        latitude REAL,
        longitude REAL,
        sales_name TEXT NOT NULL DEFAULT '',
        spv_name TEXT NOT NULL DEFAULT '',
        tsc_name TEXT NOT NULL DEFAULT '',
        owner_user_id TEXT NOT NULL DEFAULT '',
        synced_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS customer_master_local_owner_install_idx
        ON customer_master_local (owner_user_id, install_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS customer_master_local_owner_sales_idx
        ON customer_master_local (owner_user_id, sales_name)
    ''');
  }

  Future<void> _createVisitTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS visit_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL UNIQUE,
        owner_user_id TEXT NOT NULL DEFAULT '',
        customer_id TEXT NOT NULL,
        customer_name TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'belum',
        address TEXT NOT NULL DEFAULT '',
        package_name TEXT NOT NULL DEFAULT '',
        latitude REAL,
        longitude REAL,
        planned_date TEXT NOT NULL,
        visited_at TEXT,
        note TEXT NOT NULL DEFAULT '',
        form_submitted INTEGER NOT NULL DEFAULT 0,
        sync_state INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _ensureVisitColumns(db);
    await db.execute('''
      CREATE INDEX IF NOT EXISTS visit_activities_planned_date_idx
        ON visit_activities (planned_date)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS visit_activities_cat_status_idx
        ON visit_activities (category, status)
    ''');
  }

  Future<void> _ensureVisitColumns(Database db) async {
    try {
      await db.execute(
        "ALTER TABLE visit_activities ADD COLUMN owner_user_id TEXT NOT NULL DEFAULT ''",
      );
    } catch (_) {}
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
          "ALTER TABLE history ADD COLUMN position TEXT NOT NULL DEFAULT 'Elite'",
        );
        await db.execute(
          "ALTER TABLE history ADD COLUMN city TEXT NOT NULL DEFAULT 'KAB. CILACAP'",
        );
        await db.execute(
          "ALTER TABLE history ADD COLUMN basic_fee REAL NOT NULL DEFAULT 0.0",
        );
        await db.execute(
          "ALTER TABLE history ADD COLUMN monthly_subtotal REAL NOT NULL DEFAULT 0.0",
        );
      } catch (_) {}
    }
    if (oldVersion < 3) {
      for (final col in [
        'f0',
        'f50',
        'f100',
        'f125',
        'f200',
        'fwa',
        'p35',
        'p6',
      ]) {
        try {
          await db.execute(
            "ALTER TABLE history ADD COLUMN $col INTEGER NOT NULL DEFAULT 0",
          );
        } catch (_) {}
      }
    }
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_profile (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            sales_code TEXT NOT NULL,
            branch TEXT NOT NULL DEFAULT 'XL SATU CILACAP',
            tsc TEXT NOT NULL DEFAULT 'TSC PIPIN'
          )
        ''');
      } catch (_) {}

      // Migrasi sa_history untuk menghapus kolom no_ktp
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sa_history_temp (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_pelanggan TEXT NOT NULL,
            nama TEXT NOT NULL,
            alamat TEXT NOT NULL,
            paket TEXT NOT NULL,
            tanggal_pasang TEXT NOT NULL
          )
        ''');
        await db.execute('''
          INSERT OR IGNORE INTO sa_history_temp (id, id_pelanggan, nama, alamat, paket, tanggal_pasang)
          SELECT id, id_pelanggan, nama, alamat, paket, tanggal_pasang FROM sa_history
        ''');
        await db.execute('DROP TABLE IF EXISTS sa_history');
        await db.execute('ALTER TABLE sa_history_temp RENAME TO sa_history');
      } catch (_) {}
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
          "ALTER TABLE sa_history ADD COLUMN no_hp_utama TEXT NOT NULL DEFAULT ''",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE sa_history ADD COLUMN no_hp_alternatif TEXT NOT NULL DEFAULT ''",
        );
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE sa_history ADD COLUMN latitude REAL");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE sa_history ADD COLUMN longitude REAL");
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS coach_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts INTEGER NOT NULL,
            query_norm TEXT NOT NULL,
            intent TEXT NOT NULL,
            score REAL NOT NULL,
            matched INTEGER NOT NULL,
            feedback INTEGER
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await _createVisitTable(db);
      } catch (_) {}
    }
    if (oldVersion < 8) {
      try {
        await _createCustomerMasterLocalTable(db);
      } catch (_) {}
    }
    if (oldVersion < 9) {
      await _upgradeToV9(db);
    }
    if (oldVersion < 10) {
      try {
        await _createCustomerMapPointsLocalTable(db);
      } catch (_) {}
    }
  }

  Future<void> _upgradeToV9(Database db) async {
    const uuid = Uuid();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1. Tambah kolom pada history secara idempotent
    for (final colDef in [
      'client_id TEXT',
      'period_month TEXT',
      'sync_state INTEGER NOT NULL DEFAULT 0',
      'updated_at TEXT',
      'deleted INTEGER NOT NULL DEFAULT 0',
    ]) {
      try {
        await db.execute('ALTER TABLE history ADD COLUMN $colDef');
      } catch (_) {}
    }

    // 2. Tambah kolom pada sa_history secara idempotent
    for (final colDef in [
      'client_id TEXT',
      'sync_state INTEGER NOT NULL DEFAULT 0',
      'updated_at TEXT',
      'deleted INTEGER NOT NULL DEFAULT 0',
    ]) {
      try {
        await db.execute('ALTER TABLE sa_history ADD COLUMN $colDef');
      } catch (_) {}
    }

    // 3. Backfill baris lama di history tanpa menghapus atau mengubah kolom lain
    try {
      final histRows = await db.query(
        'history',
        columns: ['id', 'client_id', 'periode', 'period_month', 'updated_at'],
      );
      for (final row in histRows) {
        final id = row['id'];
        if (id == null) continue;
        final existingClientId = row['client_id']?.toString().trim() ?? '';
        final existingUpdated = row['updated_at']?.toString().trim() ?? '';
        final existingPeriodMonth =
            row['period_month']?.toString().trim() ?? '';
        final periodeStr = row['periode']?.toString() ?? '';

        if (existingClientId.isEmpty ||
            existingUpdated.isEmpty ||
            existingPeriodMonth.isEmpty) {
          final updates = <String, Object?>{};
          if (existingClientId.isEmpty) {
            updates['client_id'] = uuid.v4();
            updates['sync_state'] = 0;
          }
          if (existingUpdated.isEmpty) {
            updates['updated_at'] = nowIso;
          }
          if (existingPeriodMonth.isEmpty) {
            updates['period_month'] = tryParsePeriodMonth(periodeStr);
          }
          if (updates.isNotEmpty) {
            await db.update(
              'history',
              updates,
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }
    } catch (_) {}

    // 4. Backfill baris lama di sa_history tanpa menghapus atau mengubah kolom lain
    try {
      final saRows = await db.query(
        'sa_history',
        columns: ['id', 'client_id', 'updated_at'],
      );
      for (final row in saRows) {
        final id = row['id'];
        if (id == null) continue;
        final existingClientId = row['client_id']?.toString().trim() ?? '';
        final existingUpdated = row['updated_at']?.toString().trim() ?? '';
        if (existingClientId.isEmpty || existingUpdated.isEmpty) {
          final updates = <String, Object?>{};
          if (existingClientId.isEmpty) {
            updates['client_id'] = uuid.v4();
            updates['sync_state'] = 0;
          }
          if (existingUpdated.isEmpty) {
            updates['updated_at'] = nowIso;
          }
          await db.update(
            'sa_history',
            updates,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> runUpgradeForTest(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await _onUpgrade(db, oldVersion, newVersion);
  }

  // --- Incentive History CRUD ---
  Future<int> insertRecord(IncentiveRecord record) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final resolvedPeriodMonth =
        (record.periodMonth != null && record.periodMonth!.trim().isNotEmpty)
        ? record.periodMonth!.trim()
        : IncentiveRecord.currentMonthIso();
    final toSave = record.copyWith(
      periodMonth: resolvedPeriodMonth,
      syncState: 0,
      updatedAt: nowIso,
      deleted: false,
    );

    if (_isInMemory) {
      final id = _webIncentiveIdCounter++;
      final newRecord = toSave.copyWith(id: id);
      _webIncentives.insert(0, newRecord);
      return id;
    }
    final db = (await instance.database)!;
    final map = toSave.toMap()..remove('id');
    return await db.insert('history', map);
  }

  Future<int> updateRecord(IncentiveRecord record) async {
    if (record.id == null) return 0;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (_isInMemory) {
      final index = _webIncentives.indexWhere((r) => r.id == record.id);
      if (index == -1) return 0;
      final existing = _webIncentives[index];
      final updated = record.copyWith(
        clientId: record.clientId.isNotEmpty
            ? record.clientId
            : existing.clientId,
        periodMonth: (record.periodMonth != null &&
                record.periodMonth!.trim().isNotEmpty)
            ? record.periodMonth
            : (existing.periodMonth ?? tryParsePeriodMonth(record.periode)),
        syncState: 0,
        updatedAt: nowIso,
        deleted: false,
      );
      _webIncentives[index] = updated;
      return 1;
    }
    final db = (await instance.database)!;
    final existingRows = await db.query(
      'history',
      columns: ['client_id', 'period_month'],
      where: 'id = ?',
      whereArgs: [record.id],
      limit: 1,
    );
    final existingClientId = existingRows.isNotEmpty
        ? (existingRows.first['client_id']?.toString().trim() ?? '')
        : '';
    final existingPeriodMonth = existingRows.isNotEmpty
        ? (existingRows.first['period_month']?.toString().trim() ?? '')
        : '';

    final updated = record.copyWith(
      clientId: existingClientId.isNotEmpty
          ? existingClientId
          : record.clientId,
      periodMonth: (record.periodMonth != null &&
              record.periodMonth!.trim().isNotEmpty)
          ? record.periodMonth
          : (existingPeriodMonth.isNotEmpty
                ? existingPeriodMonth
                : tryParsePeriodMonth(record.periode)),
      syncState: 0,
      updatedAt: nowIso,
      deleted: false,
    );
    return await db.update(
      'history',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<List<IncentiveRecord>> getAllRecords() async {
    if (_isInMemory) {
      return List.unmodifiable(_webIncentives.where((r) => !r.deleted));
    }
    final db = (await instance.database)!;
    final result = await db.query(
      'history',
      where: 'deleted = 0',
      orderBy: 'id DESC',
    );
    return result.map((json) => IncentiveRecord.fromMap(json)).toList();
  }

  Future<int> deleteRecord(int id) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (_isInMemory) {
      final index = _webIncentives.indexWhere((r) => r.id == id);
      if (index == -1) return 0;
      _webIncentives[index] = _webIncentives[index].copyWith(
        deleted: true,
        syncState: 0,
        updatedAt: nowIso,
      );
      return 1;
    }
    final db = (await instance.database)!;
    return await db.update(
      'history',
      {'deleted': 1, 'sync_state': 0, 'updated_at': nowIso},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- SA Customer History CRUD (100% Offline Local Storage) ---
  Future<int> insertSaRecord(SaRecord record) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final toSave = record.copyWith(
      syncState: 0,
      updatedAt: nowIso,
      deleted: false,
    );

    if (_isInMemory) {
      final id = _webSaIdCounter++;
      final newRecord = toSave.copyWith(id: id);
      _webSaRecords.insert(0, newRecord);
      return id;
    }
    final db = (await instance.database)!;
    final map = toSave.toMap()..remove('id');
    return await db.insert('sa_history', map);
  }

  Future<List<SaRecord>> getAllSaRecords() async {
    if (_isInMemory) {
      return List.unmodifiable(_webSaRecords.where((r) => !r.deleted));
    }
    final db = (await instance.database)!;
    final result = await db.query(
      'sa_history',
      where: 'deleted = 0',
      orderBy: 'id DESC',
    );
    return result.map((json) => SaRecord.fromMap(json)).toList();
  }

  Future<int> updateSaRecord(SaRecord record) async {
    if (record.id == null) return 0;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (_isInMemory) {
      final index = _webSaRecords.indexWhere((r) => r.id == record.id);
      if (index == -1) return 0;
      final existing = _webSaRecords[index];
      _webSaRecords[index] = record.copyWith(
        clientId: existing.clientId.isNotEmpty
            ? existing.clientId
            : record.clientId,
        syncState: 0,
        updatedAt: nowIso,
        deleted: false,
      );
      return 1;
    }
    final db = (await instance.database)!;
    final existingRows = await db.query(
      'sa_history',
      columns: ['client_id'],
      where: 'id = ?',
      whereArgs: [record.id],
      limit: 1,
    );
    final existingClientId = existingRows.isNotEmpty
        ? (existingRows.first['client_id']?.toString().trim() ?? '')
        : '';
    final updated = record.copyWith(
      clientId: existingClientId.isNotEmpty
          ? existingClientId
          : record.clientId,
      syncState: 0,
      updatedAt: nowIso,
      deleted: false,
    );
    return await db.update(
      'sa_history',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteSaRecord(int id) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (_isInMemory) {
      final index = _webSaRecords.indexWhere((r) => r.id == id);
      if (index == -1) return 0;
      _webSaRecords[index] = _webSaRecords[index].copyWith(
        deleted: true,
        syncState: 0,
        updatedAt: nowIso,
      );
      return 1;
    }
    final db = (await instance.database)!;
    return await db.update(
      'sa_history',
      {'deleted': 1, 'sync_state': 0, 'updated_at': nowIso},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Backup Sync Helpers (Fase 11: sa_history & history) ---

  /// Mengambil semua baris `sa_history` yang belum tersinkron (`sync_state = 0`), termasuk yang `deleted = 1`.
  Future<List<SaRecord>> getPendingSaRecords() async {
    if (_isInMemory) {
      return _webSaRecords.where((r) => r.syncState == 0).toList();
    }
    final db = (await instance.database)!;
    final rows = await db.query(
      'sa_history',
      where: 'sync_state = 0',
      orderBy: 'id ASC',
    );
    return rows.map((m) => SaRecord.fromMap(m)).toList();
  }

  /// Mengambil semua baris `history` yang belum tersinkron (`sync_state = 0`), termasuk yang `deleted = 1`.
  Future<List<IncentiveRecord>> getPendingIncentiveRecords() async {
    if (_isInMemory) {
      return _webIncentives.where((r) => r.syncState == 0).toList();
    }
    final db = (await instance.database)!;
    final rows = await db.query(
      'history',
      where: 'sync_state = 0',
      orderBy: 'id ASC',
    );
    return rows.map((m) => IncentiveRecord.fromMap(m)).toList();
  }

  /// Menandai baris `sa_history` sebagai tersinkron (`sync_state = 1`).
  Future<void> markSaRecordsSynced(List<String> clientIds) async {
    if (clientIds.isEmpty) return;
    if (_isInMemory) {
      final idSet = clientIds.toSet();
      for (int i = 0; i < _webSaRecords.length; i++) {
        if (idSet.contains(_webSaRecords[i].clientId)) {
          _webSaRecords[i] = _webSaRecords[i].copyWith(syncState: 1);
        }
      }
      return;
    }
    final db = (await instance.database)!;
    final placeholders = List.filled(clientIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE sa_history SET sync_state = 1 WHERE client_id IN ($placeholders)',
      clientIds,
    );
  }

  /// Menandai baris `history` sebagai tersinkron (`sync_state = 1`).
  Future<void> markIncentiveRecordsSynced(List<String> clientIds) async {
    if (clientIds.isEmpty) return;
    if (_isInMemory) {
      final idSet = clientIds.toSet();
      for (int i = 0; i < _webIncentives.length; i++) {
        if (idSet.contains(_webIncentives[i].clientId)) {
          _webIncentives[i] = _webIncentives[i].copyWith(syncState: 1);
        }
      }
      return;
    }
    final db = (await instance.database)!;
    final placeholders = List.filled(clientIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE history SET sync_state = 1 WHERE client_id IN ($placeholders)',
      clientIds,
    );
  }

  /// Menyimpan hasil restore `sa_customers` dari Supabase ke `sa_history` lokal (`sync_state = 1`).
  Future<void> upsertSaRecordsFromRemote(List<SaRecord> records) async {
    if (records.isEmpty) return;
    if (_isInMemory) {
      for (final remote in records) {
        final synced = remote.copyWith(syncState: 1);
        final idx = _webSaRecords.indexWhere(
          (r) => r.clientId == synced.clientId,
        );
        if (idx != -1) {
          _webSaRecords[idx] = synced.copyWith(id: _webSaRecords[idx].id);
        } else {
          final id = _webSaIdCounter++;
          _webSaRecords.add(synced.copyWith(id: id));
        }
      }
      return;
    }
    final db = (await instance.database)!;
    await db.transaction((txn) async {
      for (final remote in records) {
        final synced = remote.copyWith(syncState: 1);
        final existing = await txn.query(
          'sa_history',
          columns: ['id'],
          where: 'client_id = ?',
          whereArgs: [synced.clientId],
          limit: 1,
        );
        final map = synced.toMap()..remove('id');
        if (existing.isNotEmpty) {
          await txn.update(
            'sa_history',
            map,
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        } else {
          await txn.insert('sa_history', map);
        }
      }
    });
  }

  /// Menyimpan hasil restore `incentive_records` dari Supabase ke `history` lokal (`sync_state = 1`).
  Future<void> upsertIncentiveRecordsFromRemote(
    List<IncentiveRecord> records,
  ) async {
    if (records.isEmpty) return;
    if (_isInMemory) {
      for (final remote in records) {
        final synced = remote.copyWith(syncState: 1);
        final idx = _webIncentives.indexWhere(
          (r) => r.clientId == synced.clientId,
        );
        if (idx != -1) {
          _webIncentives[idx] = synced.copyWith(id: _webIncentives[idx].id);
        } else {
          final id = _webIncentiveIdCounter++;
          _webIncentives.add(synced.copyWith(id: id));
        }
      }
      return;
    }
    final db = (await instance.database)!;
    await db.transaction((txn) async {
      for (final remote in records) {
        final synced = remote.copyWith(syncState: 1);
        final existing = await txn.query(
          'history',
          columns: ['id'],
          where: 'client_id = ?',
          whereArgs: [synced.clientId],
          limit: 1,
        );
        final map = synced.toMap()..remove('id');
        if (existing.isNotEmpty) {
          await txn.update(
            'history',
            map,
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        } else {
          await txn.insert('history', map);
        }
      }
    });
  }

  /// Menghitung total baris belum tersinkron (`sync_state = 0`) pada `sa_history` + `history`.
  Future<int> countPendingBackupItems() async {
    if (_isInMemory) {
      final saPending = _webSaRecords.where((r) => r.syncState == 0).length;
      final incPending = _webIncentives.where((r) => r.syncState == 0).length;
      return saPending + incPending;
    }
    final db = (await instance.database)!;
    final saRes = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM sa_history WHERE sync_state = 0',
    );
    final incRes = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM history WHERE sync_state = 0',
    );
    final saCnt = (saRes.first['cnt'] as num?)?.toInt() ?? 0;
    final incCnt = (incRes.first['cnt'] as num?)?.toInt() ?? 0;
    return saCnt + incCnt;
  }

  @visibleForTesting
  void clearInMemoryBackupData() {
    _webIncentives.clear();
    _webSaRecords.clear();
  }

  // --- User Profile (100% Offline Local Storage) ---
  Future<UserProfile> getUserProfile() async {
    if (_isInMemory) {
      return _webUserProfile;
    }
    final db = (await instance.database)!;
    final result = await db.query('user_profile', where: 'id = 1', limit: 1);
    if (result.isNotEmpty) {
      return UserProfile.fromMap(result.first);
    }
    return const UserProfile(
      name: '',
      salesCode: '',
      branch: 'XL SATU CILACAP',
      tsc: 'TSC PIPIN',
    );
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    if (_isInMemory) {
      _webUserProfile = profile;
      return;
    }
    final db = (await instance.database)!;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- Offline AI Coach Learning Log & Privacy Masking ---

  /// Masking privasi offline: Menghapus deretan angka >= 8 digit (nomor telepon / KTP)
  static String maskPrivacy(String text) {
    return text.replaceAll(RegExp(r'\b\d{8,}\b'), '***');
  }

  Future<int> insertCoachLog(CoachLogEntry entry) async {
    final maskedQuery = maskPrivacy(entry.queryNorm);
    final safeEntry = entry.copyWith(queryNorm: maskedQuery);

    if (_isInMemory) {
      final id = _webCoachLogIdCounter++;
      _webCoachLogs.insert(0, safeEntry.copyWith(id: id));
      return id;
    }
    final db = (await instance.database)!;
    return await db.insert('coach_log', safeEntry.toMap());
  }

  Future<int> updateCoachFeedback(int id, int feedback) async {
    if (_isInMemory) {
      final index = _webCoachLogs.indexWhere((e) => e.id == id);
      if (index != -1) {
        _webCoachLogs[index] = _webCoachLogs[index].copyWith(
          feedback: feedback,
        );
        return 1;
      }
      return 0;
    }
    final db = (await instance.database)!;
    return await db.update(
      'coach_log',
      {'feedback': feedback},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CoachLogEntry>> getRecentCoachLogs({int limit = 50}) async {
    if (_isInMemory) {
      return _webCoachLogs.take(limit).toList();
    }
    final db = (await instance.database)!;
    final result = await db.query(
      'coach_log',
      orderBy: 'ts DESC',
      limit: limit,
    );
    return result.map((m) => CoachLogEntry.fromMap(m)).toList();
  }

  Future<List<Map<String, dynamic>>> getTopUnknownQueries({
    int limit = 20,
  }) async {
    if (_isInMemory) {
      final unknowns = _webCoachLogs
          .where((e) => e.intent == 'unknown')
          .toList();
      final Map<String, int> counts = {};
      for (final u in unknowns) {
        counts[u.queryNorm] = (counts[u.queryNorm] ?? 0) + 1;
      }
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sorted
          .take(limit)
          .map((e) => {'query_norm': e.key, 'count': e.value})
          .toList();
    }
    final db = (await instance.database)!;
    final result = await db.rawQuery(
      '''
      SELECT query_norm, COUNT(*) as count
      FROM coach_log
      WHERE intent = 'unknown'
      GROUP BY query_norm
      ORDER BY count DESC
      LIMIT ?
    ''',
      [limit],
    );
    return result;
  }

  // --- Visit Activities CRUD (Offline-First + Sync Queue) ---

  /// Resolver opsional untuk pengujian unit agar `insertVisit` dapat mensimulasikan
  /// `auth.currentUser?.id` tanpa inisialisasi penuh `Supabase`.
  @visibleForTesting
  String? Function()? currentUserIdResolver;

  @visibleForTesting
  void clearInMemoryVisits() {
    _webVisits.clear();
    _webMasterCustomers.clear();
    _webCustomerMapPoints.clear();
    currentUserIdResolver = null;
  }

  /// Mengambil `ownerUserId` dari argumen eksplisit, `currentUserIdResolver` (saat test),
  /// atau `AppSupabase.client.auth.currentUser?.id` bila sesi tersedia; fallback `''` bila tanpa sesi.
  String resolveCurrentOwnerUserId([String? explicitOwnerId]) {
    final trimmedExplicit = explicitOwnerId?.trim() ?? '';
    if (trimmedExplicit.isNotEmpty) return trimmedExplicit;

    if (currentUserIdResolver != null) {
      final resolved = currentUserIdResolver!()?.trim() ?? '';
      if (resolved.isNotEmpty) return resolved;
    }

    if (AppSupabase.isInitialized) {
      try {
        final uid = AppSupabase.client.auth.currentUser?.id.trim() ?? '';
        if (uid.isNotEmpty) return uid;
      } catch (_) {}
    }
    return '';
  }

  /// Menghapus seluruh data lokal `visit_activities` (dipanggil saat logout
  /// agar data visit akun lama tidak tertinggal atau ter-push oleh akun lain).
  Future<void> clearAllLocalVisits() async {
    if (_isInMemory) {
      _webVisits.clear();
      return;
    }
    final db = await instance.database;
    if (db == null) return;
    await db.delete('visit_activities');
  }

  /// Mengisolasi data visit lokal untuk `userId` yang sedang aktif:
  /// 1. Menghapus baris milik akun lain (`owner_user_id != '' AND owner_user_id != userId`).
  /// 2. Mengikat baris yang dibuat saat offline/sebelum login (`owner_user_id = ''`) ke `userId`.
  Future<void> isolateVisitsForUser(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return;

    if (_isInMemory) {
      _webVisits.removeWhere(
        (v) => v.ownerUserId.isNotEmpty && v.ownerUserId != trimmed,
      );
      for (int i = 0; i < _webVisits.length; i++) {
        if (_webVisits[i].ownerUserId.isEmpty) {
          _webVisits[i] = _webVisits[i].copyWith(ownerUserId: trimmed);
        }
      }
      return;
    }

    final db = (await instance.database)!;
    await db.delete(
      'visit_activities',
      where: "owner_user_id != '' AND owner_user_id != ?",
      whereArgs: [trimmed],
    );
    await db.update('visit_activities', {
      'owner_user_id': trimmed,
    }, where: "owner_user_id = ''");
  }

  Future<int> insertVisit(VisitActivity visit) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final resolvedOwner = resolveCurrentOwnerUserId(visit.ownerUserId);
    final toSave = visit.copyWith(
      ownerUserId: resolvedOwner,
      syncState: 0,
      updatedAt: visit.updatedAt.isNotEmpty ? visit.updatedAt : nowIso,
      deleted: false,
    );

    if (_isInMemory) {
      final existingIdx = _webVisits.indexWhere(
        (v) => v.clientId == toSave.clientId,
      );
      if (existingIdx != -1) {
        final existingId = _webVisits[existingIdx].id;
        _webVisits[existingIdx] = toSave.copyWith(id: existingId);
        return existingId ?? 1;
      }
      final id = _webVisitIdCounter++;
      _webVisits.insert(0, toSave.copyWith(id: id));
      return id;
    }

    final db = (await instance.database)!;
    final map = toSave.toMap()..remove('id');
    return await db.insert(
      'visit_activities',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateVisit(VisitActivity visit) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final updated = visit.copyWith(syncState: 0, updatedAt: nowIso);

    if (_isInMemory) {
      final index = _webVisits.indexWhere(
        (v) =>
            (visit.id != null && v.id == visit.id) ||
            v.clientId == visit.clientId,
      );
      if (index == -1) return 0;
      _webVisits[index] = updated.copyWith(id: _webVisits[index].id);
      return 1;
    }

    final db = (await instance.database)!;
    final map = updated.toMap()..remove('id');
    if (visit.id != null) {
      return await db.update(
        'visit_activities',
        map,
        where: 'id = ?',
        whereArgs: [visit.id],
      );
    }
    return await db.update(
      'visit_activities',
      map,
      where: 'client_id = ?',
      whereArgs: [visit.clientId],
    );
  }

  Future<int> softDeleteVisit(int id) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    if (_isInMemory) {
      final index = _webVisits.indexWhere((v) => v.id == id);
      if (index == -1) return 0;
      _webVisits[index] = _webVisits[index].copyWith(
        deleted: true,
        syncState: 0,
        updatedAt: nowIso,
      );
      return 1;
    }

    final db = (await instance.database)!;
    return await db.update(
      'visit_activities',
      {'deleted': 1, 'sync_state': 0, 'updated_at': nowIso},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<VisitActivity>> getVisitsByDate(
    String plannedDate, {
    VisitCategory? category,
  }) async {
    if (_isInMemory) {
      return _webVisits.where((v) {
        if (v.deleted) return false;
        if (v.plannedDate != plannedDate) return false;
        if (category != null && v.category != category) return false;
        return true;
      }).toList();
    }

    final db = (await instance.database)!;
    final where = category == null
        ? 'deleted = 0 AND planned_date = ?'
        : 'deleted = 0 AND planned_date = ? AND category = ?';
    final whereArgs = category == null
        ? [plannedDate]
        : [plannedDate, category.toDbString()];
    final result = await db.query(
      'visit_activities',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
    return result.map((m) => VisitActivity.fromMap(m)).toList();
  }

  Future<List<VisitActivity>> getVisitsByRange(
    String fromDate,
    String toDate,
  ) async {
    if (_isInMemory) {
      return _webVisits.where((v) {
        if (v.deleted) return false;
        return v.plannedDate.compareTo(fromDate) >= 0 &&
            v.plannedDate.compareTo(toDate) <= 0;
      }).toList();
    }

    final db = (await instance.database)!;
    final result = await db.query(
      'visit_activities',
      where: 'deleted = 0 AND planned_date >= ? AND planned_date <= ?',
      whereArgs: [fromDate, toDate],
      orderBy: 'planned_date DESC, id DESC',
    );
    return result.map((m) => VisitActivity.fromMap(m)).toList();
  }

  Future<List<VisitActivity>> getPendingVisits({String? ownerUserId}) async {
    final owner = ownerUserId?.trim() ?? '';
    if (_isInMemory) {
      return _webVisits.where((v) {
        if (v.syncState != 0) return false;
        if (owner.isNotEmpty &&
            v.ownerUserId.isNotEmpty &&
            v.ownerUserId != owner) {
          return false;
        }
        return true;
      }).toList();
    }

    final db = (await instance.database)!;
    final where = owner.isEmpty
        ? 'sync_state = 0'
        : "sync_state = 0 AND (owner_user_id = ? OR owner_user_id = '')";
    final whereArgs = owner.isEmpty ? null : [owner];
    final result = await db.query(
      'visit_activities',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'updated_at ASC',
    );
    return result.map((m) => VisitActivity.fromMap(m)).toList();
  }

  /// Menandai baris sebagai tersinkron (`sync_state = 1`).
  /// Bila `expectedUpdatedAtByClientId` diberikan, hanya menandai baris yang `updated_at`-nya
  /// masih sama dengan versi yang baru saja dikirim (`WHERE client_id = ? AND updated_at = ?`),
  /// sehingga edit baru yang terjadi saat push berjalan tidak ikut ditandai synced.
  Future<void> markVisitsSynced(
    List<String> clientIds, {
    Map<String, String>? expectedUpdatedAtByClientId,
  }) async {
    if (clientIds.isEmpty) return;
    if (_isInMemory) {
      for (int i = 0; i < _webVisits.length; i++) {
        final v = _webVisits[i];
        if (!clientIds.contains(v.clientId)) continue;
        if (expectedUpdatedAtByClientId != null &&
            expectedUpdatedAtByClientId.containsKey(v.clientId)) {
          if (v.updatedAt == expectedUpdatedAtByClientId[v.clientId]) {
            _webVisits[i] = v.copyWith(syncState: 1);
          }
        } else {
          _webVisits[i] = v.copyWith(syncState: 1);
        }
      }
      return;
    }

    final db = (await instance.database)!;
    if (expectedUpdatedAtByClientId != null &&
        expectedUpdatedAtByClientId.isNotEmpty) {
      final batch = db.batch();
      for (final cid in clientIds) {
        final expectedUpdatedAt = expectedUpdatedAtByClientId[cid];
        if (expectedUpdatedAt != null) {
          batch.rawUpdate(
            'UPDATE visit_activities SET sync_state = 1 WHERE client_id = ? AND updated_at = ?',
            [cid, expectedUpdatedAt],
          );
        } else {
          batch.rawUpdate(
            'UPDATE visit_activities SET sync_state = 1 WHERE client_id = ?',
            [cid],
          );
        }
      }
      await batch.commit(noResult: true);
      return;
    }

    final placeholders = List.filled(clientIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE visit_activities SET sync_state = 1 WHERE client_id IN ($placeholders)',
      clientIds,
    );
  }

  Future<Map<VisitCategory, int>> visitCountsByCategory(
    String plannedDate,
  ) async {
    final counts = <VisitCategory, int>{
      VisitCategory.rvai: 0,
      VisitCategory.dismantle: 0,
      VisitCategory.unpaid: 0,
    };

    if (_isInMemory) {
      for (final v in _webVisits) {
        if (!v.deleted && v.plannedDate == plannedDate) {
          counts[v.category] = (counts[v.category] ?? 0) + 1;
        }
      }
      return counts;
    }

    final db = (await instance.database)!;
    final rows = await db.rawQuery(
      '''
      SELECT category, COUNT(*) as cnt
      FROM visit_activities
      WHERE deleted = 0 AND planned_date = ?
      GROUP BY category
    ''',
      [plannedDate],
    );

    for (final row in rows) {
      final cat = VisitCategory.fromString(row['category'] as String?);
      final cnt = (row['cnt'] as num?)?.toInt() ?? 0;
      counts[cat] = cnt;
    }
    return counts;
  }

  Future<bool> hasAnyLocalVisits({String? ownerUserId}) async {
    final owner = ownerUserId?.trim() ?? '';
    if (_isInMemory) {
      if (owner.isEmpty) return _webVisits.isNotEmpty;
      return _webVisits.any(
        (v) => v.ownerUserId.isEmpty || v.ownerUserId == owner,
      );
    }
    final db = (await instance.database)!;
    if (owner.isEmpty) {
      final rows = await db.rawQuery('SELECT 1 FROM visit_activities LIMIT 1');
      return rows.isNotEmpty;
    }
    final rows = await db.rawQuery(
      "SELECT 1 FROM visit_activities WHERE owner_user_id = ? OR owner_user_id = '' LIMIT 1",
      [owner],
    );
    return rows.isNotEmpty;
  }

  Future<void> upsertRestoredVisit(VisitActivity visit) async {
    final synced = visit.copyWith(syncState: 1, deleted: false);
    if (_isInMemory) {
      final idx = _webVisits.indexWhere((v) => v.clientId == synced.clientId);
      if (idx != -1) {
        _webVisits[idx] = synced.copyWith(id: _webVisits[idx].id);
      } else {
        _webVisits.add(synced.copyWith(id: _webVisitIdCounter++));
      }
      return;
    }

    final db = (await instance.database)!;
    final map = synced.toMap()..remove('id');
    await db.insert(
      'visit_activities',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Memperbarui status `form_submitted` dari server berdasarkan `client_id`
  /// **tanpa** menandai `sync_state = 0` (data berasal dari server).
  /// Bila status lokal masih `belum`, status diperbarui ke `serverStatus` (default `sudahVisit`),
  /// dan bila `visited_at` lokal masih kosong, diisi dengan `serverVisitedAt`.
  Future<bool> applyPulledFormStatus({
    required String clientId,
    VisitStatus? serverStatus,
    String? serverVisitedAt,
  }) async {
    final cid = clientId.trim();
    if (cid.isEmpty) return false;

    if (_isInMemory) {
      final idx = _webVisits.indexWhere((v) => v.clientId == cid);
      if (idx == -1) return false;
      final existing = _webVisits[idx];
      final newStatus = existing.status == VisitStatus.belum
          ? (serverStatus ?? VisitStatus.sudahVisit)
          : existing.status;
      final newVisitedAt =
          (existing.visitedAt == null || existing.visitedAt!.trim().isEmpty)
          ? serverVisitedAt
          : existing.visitedAt;

      _webVisits[idx] = existing.copyWith(
        formSubmitted: true,
        status: newStatus,
        visitedAt: newVisitedAt,
        // Penting: jangan ubah syncState menjadi 0!
      );
      return true;
    }

    final db = (await instance.database)!;
    final rows = await db.query(
      'visit_activities',
      where: 'client_id = ?',
      whereArgs: [cid],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final existing = VisitActivity.fromMap(rows.first);
    final newStatus = existing.status == VisitStatus.belum
        ? (serverStatus ?? VisitStatus.sudahVisit)
        : existing.status;
    final newVisitedAt =
        (existing.visitedAt == null || existing.visitedAt!.trim().isEmpty)
        ? serverVisitedAt
        : existing.visitedAt;

    await db.update(
      'visit_activities',
      {
        'form_submitted': 1,
        'status': newStatus.toDbString(),
        'visited_at': newVisitedAt,
      },
      where: 'client_id = ?',
      whereArgs: [cid],
    );
    return true;
  }

  /// Mengambil kumpulan `customer_id` yang sudah memiliki visit `rvai` aktif (`deleted = 0`).
  Future<Set<String>> getActiveRvaiCustomerIds({String? ownerUserId}) async {
    final owner = ownerUserId?.trim() ?? '';
    if (_isInMemory) {
      return _webVisits
          .where((v) {
            if (v.deleted) return false;
            if (v.category != VisitCategory.rvai) return false;
            if (owner.isNotEmpty &&
                v.ownerUserId.isNotEmpty &&
                v.ownerUserId != owner) {
              return false;
            }
            return true;
          })
          .map((v) => v.customerId.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    }

    final db = (await instance.database)!;
    final where = owner.isEmpty
        ? "deleted = 0 AND category = 'rvai'"
        : "deleted = 0 AND category = 'rvai' AND (owner_user_id = ? OR owner_user_id = '')";
    final rows = await db.query(
      'visit_activities',
      columns: ['customer_id'],
      where: where,
      whereArgs: owner.isEmpty ? null : [owner],
    );
    return rows
        .map((r) => (r['customer_id'] as String? ?? '').trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  // --- Customer Master Local Cache CRUD (SQLite v8) ---

  Future<void> clearAllMasterCustomers() async {
    if (_isInMemory) {
      _webMasterCustomers.clear();
      return;
    }
    final db = await instance.database;
    if (db == null) return;
    await db.delete('customer_master_local');
  }

  /// Mengganti seluruh isi `customer_master_local` milik `ownerUserId` secara atomik
  /// dalam satu transaksi (dan menghapus sisa data pemilik lain bila ada).
  Future<void> replaceMasterCustomersForOwner(
    String ownerUserId,
    List<MasterCustomer> customers,
  ) async {
    final owner = ownerUserId.trim();
    if (_isInMemory) {
      _webMasterCustomers.clear();
      for (final c in customers) {
        _webMasterCustomers.add(c.copyWith(ownerUserId: owner));
      }
      return;
    }

    final db = (await instance.database)!;
    await db.transaction((txn) async {
      await txn.delete('customer_master_local');
      if (customers.isNotEmpty) {
        final batch = txn.batch();
        for (final c in customers) {
          batch.insert(
            'customer_master_local',
            c.copyWith(ownerUserId: owner).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<int> countMasterCustomers({String? ownerUserId}) async {
    final owner = ownerUserId?.trim() ?? '';
    if (_isInMemory) {
      if (owner.isEmpty) return _webMasterCustomers.length;
      return _webMasterCustomers
          .where((c) => c.ownerUserId.isEmpty || c.ownerUserId == owner)
          .length;
    }

    final db = (await instance.database)!;
    final rows = owner.isEmpty
        ? await db.rawQuery('SELECT COUNT(*) as cnt FROM customer_master_local')
        : await db.rawQuery(
            "SELECT COUNT(*) as cnt FROM customer_master_local WHERE owner_user_id = ? OR owner_user_id = ''",
            [owner],
          );
    if (rows.isEmpty) return 0;
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<MasterCustomer?> getMasterCustomerById(
    String customerId, {
    String? ownerUserId,
  }) async {
    final cid = customerId.trim();
    if (cid.isEmpty) return null;
    final owner = ownerUserId?.trim() ?? '';

    if (_isInMemory) {
      for (final c in _webMasterCustomers) {
        if (c.customerId == cid) {
          if (owner.isEmpty ||
              c.ownerUserId.isEmpty ||
              c.ownerUserId == owner) {
            return c;
          }
        }
      }
      return null;
    }

    final db = (await instance.database)!;
    final where = owner.isEmpty
        ? 'customer_id = ?'
        : "customer_id = ? AND (owner_user_id = ? OR owner_user_id = '')";
    final whereArgs = owner.isEmpty ? [cid] : [cid, owner];
    final rows = await db.query(
      'customer_master_local',
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MasterCustomer.fromMap(rows.first);
  }

  /// Mencari pelanggan lokal berdasarkan `customer_id LIKE` atau `address LIKE`,
  /// diurutkan `install_date DESC, customer_id ASC`, dibatasi `limit` (default 50).
  Future<List<MasterCustomer>> searchMasterCustomers(
    String query, {
    String? ownerUserId,
    int limit = 50,
  }) async {
    final q = query.trim().toLowerCase();
    final owner = ownerUserId?.trim() ?? '';

    if (_isInMemory) {
      final filtered = _webMasterCustomers.where((c) {
        if (owner.isNotEmpty &&
            c.ownerUserId.isNotEmpty &&
            c.ownerUserId != owner) {
          return false;
        }
        if (q.isEmpty) return true;
        return c.customerId.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q) ||
            c.packageName.toLowerCase().contains(q) ||
            c.salesName.toLowerCase().contains(q);
      }).toList();

      filtered.sort((a, b) {
        final da = a.installDateString ?? '';
        final dbStr = b.installDateString ?? '';
        final cmp = dbStr.compareTo(da); // install_date DESC
        if (cmp != 0) return cmp;
        return a.customerId.compareTo(b.customerId);
      });
      return filtered.take(limit).toList();
    }

    final db = (await instance.database)!;
    final likeArg = '%${query.trim()}%';
    final String where;
    final List<Object?> whereArgs;

    if (q.isEmpty) {
      where = owner.isEmpty
          ? '1 = 1'
          : "(owner_user_id = ? OR owner_user_id = '')";
      whereArgs = owner.isEmpty ? [] : [owner];
    } else {
      where = owner.isEmpty
          ? '(customer_id LIKE ? OR address LIKE ?)'
          : "(owner_user_id = ? OR owner_user_id = '') AND (customer_id LIKE ? OR address LIKE ?)";
      whereArgs = owner.isEmpty
          ? [likeArg, likeArg]
          : [owner, likeArg, likeArg];
    }

    final rows = await db.query(
      'customer_master_local',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'install_date DESC, customer_id ASC',
      limit: limit,
    );
    return rows.map((r) => MasterCustomer.fromMap(r)).toList();
  }

  Future<List<MasterCustomer>> getAllMasterCustomers({
    String? ownerUserId,
  }) async {
    final owner = ownerUserId?.trim() ?? '';
    if (_isInMemory) {
      final list = _webMasterCustomers.where((c) {
        if (owner.isNotEmpty &&
            c.ownerUserId.isNotEmpty &&
            c.ownerUserId != owner) {
          return false;
        }
        return true;
      }).toList();
      list.sort((a, b) {
        final da = a.installDateString ?? '9999-99-99';
        final dbStr = b.installDateString ?? '9999-99-99';
        final cmp = da.compareTo(dbStr);
        if (cmp != 0) return cmp;
        return a.customerId.compareTo(b.customerId);
      });
      return list;
    }

    final db = (await instance.database)!;
    final where = owner.isEmpty
        ? null
        : "(owner_user_id = ? OR owner_user_id = '')";
    final rows = await db.query(
      'customer_master_local',
      where: where,
      whereArgs: owner.isEmpty ? null : [owner],
      orderBy: 'install_date ASC, customer_id ASC',
    );
    return rows.map((r) => MasterCustomer.fromMap(r)).toList();
  }

  // --- Customer Map Points Local Cache CRUD (SQLite v10, Phase 13) ---

  Future<void> clearAllCustomerMapPoints() async {
    if (_isInMemory) {
      _webCustomerMapPoints.clear();
      return;
    }
    final db = await instance.database;
    if (db == null) return;
    await db.delete('customer_map_points_local');
  }

  Future<void> replaceCustomerMapPoints(List<CustomerMapPoint> points) async {
    if (_isInMemory) {
      _webCustomerMapPoints.clear();
      _webCustomerMapPoints.addAll(points);
      return;
    }

    final db = (await instance.database)!;
    await db.transaction((txn) async {
      await txn.delete('customer_map_points_local');
      if (points.isNotEmpty) {
        final batch = txn.batch();
        for (final p in points) {
          batch.insert(
            'customer_map_points_local',
            p.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<int> countCustomerMapPoints() async {
    if (_isInMemory) {
      return _webCustomerMapPoints.length;
    }
    final db = (await instance.database)!;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM customer_map_points_local',
    );
    if (rows.isEmpty) return 0;
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<List<CustomerMapPoint>> getAllCustomerMapPoints() async {
    if (_isInMemory) {
      return List<CustomerMapPoint>.from(_webCustomerMapPoints);
    }
    final db = (await instance.database)!;
    final rows = await db.query(
      'customer_map_points_local',
      orderBy: 'customer_id ASC',
    );
    return rows.map((r) => CustomerMapPoint.fromMap(r)).toList();
  }
}
