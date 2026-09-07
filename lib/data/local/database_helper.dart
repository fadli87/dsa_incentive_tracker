import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../models/incentive_record.dart';
import '../models/sa_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dsa_tracker_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
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
        grand_total REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sa_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_pelanggan TEXT NOT NULL,
        nama TEXT NOT NULL,
        no_ktp TEXT NOT NULL,
        alamat TEXT NOT NULL,
        paket TEXT NOT NULL,
        tanggal_pasang TEXT NOT NULL
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
  }

  // --- Incentive History CRUD ---
  Future<int> insertRecord(IncentiveRecord record) async {
    final db = await instance.database;
    return await db.insert('history', record.toMap());
  }

  Future<List<IncentiveRecord>> getAllRecords() async {
    final db = await instance.database;
    final result = await db.query('history', orderBy: 'id DESC');
    return result.map((json) => IncentiveRecord.fromMap(json)).toList();
  }

  Future<int> deleteRecord(int id) async {
    final db = await instance.database;
    return await db.delete('history', where: 'id = ?', whereArgs: [id]);
  }

  // --- SA Customer History CRUD ---
  Future<int> insertSaRecord(SaRecord record) async {
    final db = await instance.database;
    return await db.insert('sa_history', record.toMap());
  }

  Future<List<SaRecord>> getAllSaRecords() async {
    final db = await instance.database;
    final result = await db.query('sa_history', orderBy: 'id DESC');
    return result.map((json) => SaRecord.fromMap(json)).toList();
  }

  Future<int> deleteSaRecord(int id) async {
    final db = await instance.database;
    return await db.delete('sa_history', where: 'id = ?', whereArgs: [id]);
  }
}
