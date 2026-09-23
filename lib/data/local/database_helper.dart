import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/incentive_record.dart';
import '../models/sa_record.dart';
import '../models/user_profile.dart';

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
  UserProfile _webUserProfile = const UserProfile(
    name: '',
    salesCode: '',
    branch: 'XL SATU CILACAP',
    tsc: 'TSC PIPIN',
  );
  int _webIncentiveIdCounter = 1;
  int _webSaIdCounter = 1;

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
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        periode TEXT NOT NULL,
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
        p6 INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sa_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_pelanggan TEXT NOT NULL,
        nama TEXT NOT NULL,
        no_hp_utama TEXT NOT NULL DEFAULT '',
        no_hp_alternatif TEXT NOT NULL DEFAULT '',
        alamat TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        paket TEXT NOT NULL,
        tanggal_pasang TEXT NOT NULL
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute(
            "ALTER TABLE history ADD COLUMN position TEXT NOT NULL DEFAULT 'Elite'");
        await db.execute(
            "ALTER TABLE history ADD COLUMN city TEXT NOT NULL DEFAULT 'KAB. CILACAP'");
        await db.execute(
            "ALTER TABLE history ADD COLUMN basic_fee REAL NOT NULL DEFAULT 0.0");
        await db.execute(
            "ALTER TABLE history ADD COLUMN monthly_subtotal REAL NOT NULL DEFAULT 0.0");
      } catch (_) {}
    }
    if (oldVersion < 3) {
      for (final col in ['f0', 'f50', 'f100', 'f125', 'f200', 'fwa', 'p35', 'p6']) {
        try {
          await db.execute(
              "ALTER TABLE history ADD COLUMN $col INTEGER NOT NULL DEFAULT 0");
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
            "ALTER TABLE sa_history ADD COLUMN no_hp_utama TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute(
            "ALTER TABLE sa_history ADD COLUMN no_hp_alternatif TEXT NOT NULL DEFAULT ''");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE sa_history ADD COLUMN latitude REAL");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE sa_history ADD COLUMN longitude REAL");
      } catch (_) {}
    }
  }

  // --- Incentive History CRUD ---
  Future<int> insertRecord(IncentiveRecord record) async {
    if (_isInMemory) {
      final id = _webIncentiveIdCounter++;
      final newRecord = IncentiveRecord(
        id: id,
        periode: record.periode,
        position: record.position,
        city: record.city,
        basicFee: record.basicFee,
        totalSa: record.totalSa,
        pmBase: record.pmBase,
        multRate: record.multRate,
        multBonus: record.multBonus,
        progInc: record.progInc,
        specialInc: record.specialInc,
        monthlySubtotal: record.monthlySubtotal,
        grandTotal: record.grandTotal,
        f0: record.f0,
        f50: record.f50,
        f100: record.f100,
        f125: record.f125,
        f200: record.f200,
        fwa: record.fwa,
        p35: record.p35,
        p6: record.p6,
      );
      _webIncentives.insert(0, newRecord);
      return id;
    }
    final db = (await instance.database)!;
    return await db.insert('history', record.toMap());
  }

  Future<int> updateRecord(IncentiveRecord record) async {
    if (record.id == null) return 0;
    if (_isInMemory) {
      final index = _webIncentives.indexWhere((r) => r.id == record.id);
      if (index == -1) return 0;
      _webIncentives[index] = record;
      return 1;
    }
    final db = (await instance.database)!;
    return await db.update(
      'history',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<List<IncentiveRecord>> getAllRecords() async {
    if (_isInMemory) {
      return List.unmodifiable(_webIncentives);
    }
    final db = (await instance.database)!;
    final result = await db.query('history', orderBy: 'id DESC');
    return result.map((json) => IncentiveRecord.fromMap(json)).toList();
  }

  Future<int> deleteRecord(int id) async {
    if (_isInMemory) {
      _webIncentives.removeWhere((r) => r.id == id);
      return 1;
    }
    final db = (await instance.database)!;
    return await db.delete('history', where: 'id = ?', whereArgs: [id]);
  }

  // --- SA Customer History CRUD (100% Offline Local Storage) ---
  Future<int> insertSaRecord(SaRecord record) async {
    if (_isInMemory) {
      final id = _webSaIdCounter++;
      final newRecord = SaRecord(
        id: id,
        idPelanggan: record.idPelanggan,
        nama: record.nama,
        noHpUtama: record.noHpUtama,
        noHpAlternatif: record.noHpAlternatif,
        alamat: record.alamat,
        latitude: record.latitude,
        longitude: record.longitude,
        paket: record.paket,
        tanggalPasang: record.tanggalPasang,
      );
      _webSaRecords.insert(0, newRecord);
      return id;
    }
    final db = (await instance.database)!;
    return await db.insert('sa_history', record.toMap());
  }

  Future<List<SaRecord>> getAllSaRecords() async {
    if (_isInMemory) {
      return List.unmodifiable(_webSaRecords);
    }
    final db = (await instance.database)!;
    final result = await db.query('sa_history', orderBy: 'id DESC');
    return result.map((json) => SaRecord.fromMap(json)).toList();
  }

  Future<int> deleteSaRecord(int id) async {
    if (_isInMemory) {
      _webSaRecords.removeWhere((r) => r.id == id);
      return 1;
    }
    final db = (await instance.database)!;
    return await db.delete('sa_history', where: 'id = ?', whereArgs: [id]);
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
}
