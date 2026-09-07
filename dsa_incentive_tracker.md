# Blueprint: DSA Incentive Tracker (XL SMART Sep 2026)

## 1. Instruksi untuk AI Agent (agy)
Anda adalah ahli *developer* Flutter. Tolong buat proyek Flutter baru dan *generate* semua file di bawah ini sesuai dengan struktur direktori dan kode yang telah disediakan. Aplikasi ini berfungsi sebagai kalkulator *offline-first* untuk menghitung insentif sales dengan skema berjenjang dan menyimpan historinya menggunakan SQLite dan Riverpod.

## 2. Dependencies (`pubspec.yaml`)
Tambahkan dependensi berikut ke dalam `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  sqflite: ^2.3.0
  path: ^1.9.0
  path_provider: ^2.1.2
  fl_chart: ^0.66.0
  intl: ^0.19.0
  
  lib/
├── main.dart
├── core/
│   └── engine/
│       └── calculator_engine.dart
├── data/
│   ├── models/
│   │   └── incentive_record.dart
│   └── local/
│       └── database_helper.dart
├── providers/
│   ├── calculator_provider.dart
│   └── history_provider.dart
└── ui/
    ├── screens/
    │   ├── main_navigation.dart
    │   ├── calculator_screen.dart
    │   └── history_screen.dart
    └── widgets/
        └── result_card.dart

lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/screens/main_navigation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSA Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF002B66)),
        useMaterial3: true,
      ),
      home: const MainNavigation(),
    );
  }
}		
	

lib/data/models/incentive_record.dart

class IncentiveRecord {
  final int? id;
  final String periode;
  final int totalSa;
  final double pmBase;
  final double multRate;
  final double multBonus;
  final double progInc;
  final double specialInc;
  final double grandTotal;

  IncentiveRecord({
    this.id, required this.periode, required this.totalSa,
    required this.pmBase, required this.multRate, required this.multBonus,
    required this.progInc, required this.specialInc, required this.grandTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, 'periode': periode, 'total_sa': totalSa,
      'pm_base': pmBase, 'mult_rate': multRate, 'mult_bonus': multBonus,
      'prog_inc': progInc, 'special_inc': specialInc, 'grand_total': grandTotal,
    };
  }

  factory IncentiveRecord.fromMap(Map<String, dynamic> map) {
    return IncentiveRecord(
      id: map['id'], periode: map['periode'], totalSa: map['total_sa'],
      pmBase: map['pm_base'], multRate: map['mult_rate'],
      multBonus: map['mult_bonus'], progInc: map['prog_inc'],
      specialInc: map['special_inc'], grandTotal: map['grand_total'],
    );
  }
}


lib/core/engine/calculator_engine.dart	

class CalculatorEngine {
  static Map<String, dynamic> calculate({
    required int f0, required int f50, required int f100,
    required int f125, required int f200, required int fwa,
    required int p35, required int p6,
  }) {
    int totalSa = f0 + f50 + f100 + f125 + f200 + fwa + p35 + p6;
    
    double pmBase = (f50 * 50000) + (f100 * 100000) + (f125 * 125000) +
                    (f200 * 200000) + (fwa * 50000) + (p35 * 125000) + (p6 * 150000);
                    
    double specialInc = (p35 * 125000) + (p6 * 150000);
    
    int b1 = totalSa.clamp(0, 6);
    int b2 = (totalSa - 6).clamp(0, 3);
    int b3 = (totalSa - 9).clamp(0, 4);
    int b4 = (totalSa - 13).clamp(0, 16);
    int b5 = (totalSa - 29).clamp(0, 10);
    int b6 = (totalSa - 39).clamp(0, 10);
    int b7 = (totalSa - 49) > 0 ? (totalSa - 49) : 0;
    
    double progInc = (b1 * 80000) + (b2 * 150000) + (b3 * 175000) +
                     (b4 * 200000) + (b5 * 225000) + (b6 * 250000) + (b7 * 275000);
                     
    double multRate = 0.0;
    if (totalSa >= 50) multRate = 4.65;
    else if (totalSa >= 40) multRate = 4.50;
    else if (totalSa >= 30) multRate = 4.25;
    else if (totalSa >= 14) multRate = 4.00;
    else if (totalSa >= 10) multRate = 2.00;
    else if (totalSa >= 7) multRate = 1.50;
    
    double multBonus = multRate * pmBase;
    double grandTotal = progInc + pmBase + multBonus + specialInc;
    
    return {
      'totalSa': totalSa, 'pmBase': pmBase, 'multRate': multRate,
      'multBonus': multBonus, 'progInc': progInc, 
      'specialInc': specialInc, 'grandTotal': grandTotal
    };
  }
}

lib/data/local/database_helper.dart


import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/incentive_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dsa_incentive.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        periode TEXT NOT NULL,
        total_sa INTEGER NOT NULL,
        pm_base REAL NOT NULL,
        mult_rate REAL NOT NULL,
        mult_bonus REAL NOT NULL,
        prog_inc REAL NOT NULL,
        special_inc REAL NOT NULL,
        grand_total REAL NOT NULL
      )
    ''');
  }

  Future<int> insertRecord(IncentiveRecord record) async {
    final db = await instance.database;
    return await db.insert('history', record.toMap());
  }

  Future<List<IncentiveRecord>> getAllRecords() async {
    final db = await instance.database;
    final result = await db.query('history', orderBy: 'id DESC');
    return result.map((json) => IncentiveRecord.fromMap(json)).toList();
  }
}


lib/providers/calculator_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/engine/calculator_engine.dart';

class CalculatorState {
  final int f0, f50, f100, f125, f200, fwa, p35, p6;
  final Map<String, dynamic> results;

  CalculatorState({
    this.f0 = 0, this.f50 = 0, this.f100 = 0, this.f125 = 0, 
    this.f200 = 0, this.fwa = 0, this.p35 = 0, this.p6 = 0,
    required this.results,
  });

  CalculatorState copyWith({
    int? f0, int? f50, int? f100, int? f125, 
    int? f200, int? fwa, int? p35, int? p6,
  }) {
    int newF0 = f0 ?? this.f0; int newF50 = f50 ?? this.f50;
    int newF100 = f100 ?? this.f100; int newF125 = f125 ?? this.f125;
    int newF200 = f200 ?? this.f200; int newFwa = fwa ?? this.fwa;
    int newP35 = p35 ?? this.p35; int newP6 = p6 ?? this.p6;

    final newResults = CalculatorEngine.calculate(
      f0: newF0, f50: newF50, f100: newF100, f125: newF125,
      f200: newF200, fwa: newFwa, p35: newP35, p6: newP6,
    );

    return CalculatorState(
      f0: newF0, f50: newF50, f100: newF100, f125: newF125,
      f200: newF200, fwa: newFwa, p35: newP35, p6: newP6,
      results: newResults,
    );
  }
}

class CalculatorNotifier extends Notifier<CalculatorState> {
  @override
  CalculatorState build() {
    return CalculatorState(
      results: CalculatorEngine.calculate(
        f0: 0, f50: 0, f100: 0, f125: 0, f200: 0, fwa: 0, p35: 0, p6: 0
      )
    );
  }

  void updateField(String field, int value) {
    switch (field) {
      case 'f0': state = state.copyWith(f0: value); break;
      case 'f50': state = state.copyWith(f50: value); break;
      case 'f100': state = state.copyWith(f100: value); break;
      case 'f125': state = state.copyWith(f125: value); break;
      case 'f200': state = state.copyWith(f200: value); break;
      case 'fwa': state = state.copyWith(fwa: value); break;
      case 'p35': state = state.copyWith(p35: value); break;
      case 'p6': state = state.copyWith(p6: value); break;
    }
  }
  
  void reset() {
    state = CalculatorState(
      results: CalculatorEngine.calculate(
        f0: 0, f50: 0, f100: 0, f125: 0, f200: 0, fwa: 0, p35: 0, p6: 0
      )
    );
  }
}

final calculatorProvider = NotifierProvider<CalculatorNotifier, CalculatorState>(() => CalculatorNotifier());


lib/providers/history_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/database_helper.dart';
import '../data/models/incentive_record.dart';

class HistoryNotifier extends AsyncNotifier<List<IncentiveRecord>> {
  @override
  Future<List<IncentiveRecord>> build() async {
    return await DatabaseHelper.instance.getAllRecords();
  }

  Future<void> addRecord(IncentiveRecord record) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await DatabaseHelper.instance.insertRecord(record);
      return await DatabaseHelper.instance.getAllRecords();
    });
  }
}

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<IncentiveRecord>>(() => HistoryNotifier());


lib/ui/widgets/result_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ResultCard extends StatelessWidget {
  final Map<String, dynamic> results;
  const ResultCard({super.key, required this.results});

  String _fmt(dynamic val) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(val);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildRow('Total SA', '${results['totalSa']} Unit', isBold: true),
            const Divider(),
            _buildRow('Progresif SA', _fmt(results['progInc'])),
            _buildRow('Product Mix Base', _fmt(results['pmBase'])),
            _buildRow('Booster (${results['multRate']}x)', _fmt(results['multBonus'])),
            _buildRow('Special PXGY', _fmt(results['specialInc'])),
            const Divider(thickness: 2),
            _buildRow('ESTIMASI TOTAL', _fmt(results['grandTotal']), isBold: true, color: Colors.red.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isBold ? 16 : 14, color: color)),
        ],
      ),
    );
  }
}


lib/ui/screens/calculator_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/calculator_provider.dart';
import '../../providers/history_provider.dart';
import '../../data/models/incentive_record.dart';
import '../widgets/result_card.dart';

class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorProvider);
    final notifier = ref.read(calculatorProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Kalkulator Insentif')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Input Pencapaian Paket:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _buildInput('FTTH < 229rb (Inc: 0)', 'f0', state.f0, notifier),
          _buildInput('FTTH 229rb-299rb (Inc: 50k)', 'f50', state.f50, notifier),
          _buildInput('FTTH 300rb-399rb (Inc: 100k)', 'f100', state.f100, notifier),
          _buildInput('FTTH 400rb-599rb (Inc: 125k)', 'f125', state.f125, notifier),
          _buildInput('FTTH >= 600rb (Inc: 200k)', 'f200', state.f200, notifier),
          _buildInput('FWA >= 219rb (Inc: 50k)', 'fwa', state.fwa, notifier),
          _buildInput('PXGY 3-5 Bln (PM 125k+Spc 125k)', 'p35', state.p35, notifier),
          _buildInput('PXGY >= 6 Bln (PM 150k+Spc 150k)', 'p6', state.p6, notifier),
          const SizedBox(height: 20),
          ResultCard(results: state.results),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              if (state.results['totalSa'] == 0) return;
              final record = IncentiveRecord(
                periode: DateFormat('MMM yyyy').format(DateTime.now()),
                totalSa: state.results['totalSa'],
                pmBase: state.results['pmBase'],
                multRate: state.results['multRate'],
                multBonus: state.results['multBonus'],
                progInc: state.results['progInc'],
                specialInc: state.results['specialInc'],
                grandTotal: state.results['grandTotal'],
              );
              await ref.read(historyProvider.notifier).addRecord(record);
              notifier.reset();
              if(context.mounted){
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan!')));
              }
            },
            child: const Text('Simpan Histori Pencapaian'),
          )
        ],
      ),
    );
  }

  Widget _buildInput(String label, String fieldKey, int val, CalculatorNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            flex: 1,
            child: TextFormField(
              initialValue: val == 0 ? '' : val.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true, contentPadding: EdgeInsets.all(8), border: OutlineInputBorder()
              ),
              onChanged: (v) => notifier.updateField(fieldKey, int.tryParse(v) ?? 0),
            ),
          )
        ],
      ),
    );
  }
}

lib/ui/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/history_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Histori Pencapaian')),
      body: historyState.when(
        data: (records) {
          if (records.isEmpty) {
            return const Center(child: Text('Belum ada data histori.'));
          }
          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final r = records[index];
              final fmtTotal = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(r.grandTotal);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(r.periode, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Total SA: ${r.totalSa} \vert{} Booster:${r.multRate}x'),
                  trailing: Text(fmtTotal, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}


lib/ui/screens/main_navigation.dart

import 'package:flutter/material.dart';
import 'calculator_screen.dart';
import 'history_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [CalculatorScreen(), HistoryScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'Kalkulator'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Histori'),
        ],
      ),
    );
  }
}