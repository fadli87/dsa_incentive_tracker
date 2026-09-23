# Instruksi Update: Fitur Edit Histori Insentif (DSA Tracker V2)

## Tujuan
Saat ini histori insentif yang sudah disimpan bersifat **read-only (fix)**. Update ini menambahkan
kemampuan **edit jumlah aktivasi** pada record histori yang sudah tersimpan. Semua nominal
(pmBase, multBonus, progInc, specialInc, monthlySubtotal, grandTotal) **WAJIB dihitung ulang
otomatis lewat `CalculatorEngine.calculateDetailed()`** — user hanya boleh mengubah angka jumlah
aktivasi per kategori (f0, f50, f100, f125, f200, fwa, p35, p6), tidak pernah nominal atau grand
total secara manual.

## Ringkasan Perubahan
1. `IncentiveRecord` — tambah 8 field input mentah + method `copyWith`
2. `DatabaseHelper` — migrasi DB ke versi 3 (tambah 8 kolom), tambah `updateRecord()`
3. `HistoryNotifier` (history_provider.dart) — tambah `updateRecord()`
4. `CalculatorScreen` — sertakan 8 field input mentah saat menyimpan record baru
5. `HistoryScreen` — tambah dialog Edit dengan rekalkulasi via engine, tombol Edit di dialog detail
6. (Opsional) Reuse `ResultCard` & `TierProductivityTable` untuk live preview di dialog edit

**Catatan penting:** Record histori yang SUDAH ADA sebelum update ini akan punya
`f0..p6 = 0` (default) karena data mentahnya memang tidak pernah tersimpan sebelumnya.
Jika record lama tersebut diedit, hasil rekalkulasi akan salah (jadi 0) karena tidak ada
data aktivasi mentah untuk dihitung ulang. Ini adalah keterbatasan yang tidak terhindarkan.
Fitur edit hanya akurat untuk record yang dibuat SETELAH update ini diterapkan.

---

## 1. `data/models/incentive_record.dart`

Tambahkan 8 field baru dan method `copyWith`. Field lama TIDAK berubah.

```dart
class IncentiveRecord {
  final int? id;
  final String periode;
  final String position;
  final String city;
  final double basicFee;
  final int totalSa;
  final double pmBase;
  final double multRate;
  final double multBonus;
  final double progInc;
  final double specialInc;
  final double monthlySubtotal;
  final double grandTotal;
  // --- Input mentah, disimpan supaya bisa direkalkulasi ulang saat edit ---
  final int f0;
  final int f50;
  final int f100;
  final int f125;
  final int f200;
  final int fwa;
  final int p35;
  final int p6;

  IncentiveRecord({
    this.id,
    required this.periode,
    this.position = 'Elite',
    this.city = 'KAB. CILACAP',
    this.basicFee = 0.0,
    required this.totalSa,
    required this.pmBase,
    required this.multRate,
    required this.multBonus,
    required this.progInc,
    required this.specialInc,
    double? monthlySubtotal,
    required this.grandTotal,
    this.f0 = 0,
    this.f50 = 0,
    this.f100 = 0,
    this.f125 = 0,
    this.f200 = 0,
    this.fwa = 0,
    this.p35 = 0,
    this.p6 = 0,
  }) : monthlySubtotal = monthlySubtotal ?? grandTotal;

  IncentiveRecord copyWith({
    int? id,
    String? periode,
    String? position,
    String? city,
    double? basicFee,
    int? totalSa,
    double? pmBase,
    double? multRate,
    double? multBonus,
    double? progInc,
    double? specialInc,
    double? monthlySubtotal,
    double? grandTotal,
    int? f0,
    int? f50,
    int? f100,
    int? f125,
    int? f200,
    int? fwa,
    int? p35,
    int? p6,
  }) {
    return IncentiveRecord(
      id: id ?? this.id,
      periode: periode ?? this.periode,
      position: position ?? this.position,
      city: city ?? this.city,
      basicFee: basicFee ?? this.basicFee,
      totalSa: totalSa ?? this.totalSa,
      pmBase: pmBase ?? this.pmBase,
      multRate: multRate ?? this.multRate,
      multBonus: multBonus ?? this.multBonus,
      progInc: progInc ?? this.progInc,
      specialInc: specialInc ?? this.specialInc,
      monthlySubtotal: monthlySubtotal ?? this.monthlySubtotal,
      grandTotal: grandTotal ?? this.grandTotal,
      f0: f0 ?? this.f0,
      f50: f50 ?? this.f50,
      f100: f100 ?? this.f100,
      f125: f125 ?? this.f125,
      f200: f200 ?? this.f200,
      fwa: fwa ?? this.fwa,
      p35: p35 ?? this.p35,
      p6: p6 ?? this.p6,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'periode': periode,
      'position': position,
      'city': city,
      'basic_fee': basicFee,
      'total_sa': totalSa,
      'pm_base': pmBase,
      'mult_rate': multRate,
      'mult_bonus': multBonus,
      'prog_inc': progInc,
      'special_inc': specialInc,
      'monthly_subtotal': monthlySubtotal,
      'grand_total': grandTotal,
      'f0': f0,
      'f50': f50,
      'f100': f100,
      'f125': f125,
      'f200': f200,
      'fwa': fwa,
      'p35': p35,
      'p6': p6,
    };
  }

  factory IncentiveRecord.fromMap(Map<String, dynamic> map) {
    final grandTotalVal = (map['grand_total'] as num).toDouble();
    return IncentiveRecord(
      id: map['id'] as int?,
      periode: map['periode'] as String,
      position: (map['position'] as String?) ?? 'Elite',
      city: (map['city'] as String?) ?? 'KAB. CILACAP',
      basicFee: (map['basic_fee'] as num?)?.toDouble() ?? 0.0,
      totalSa: map['total_sa'] as int,
      pmBase: (map['pm_base'] as num).toDouble(),
      multRate: (map['mult_rate'] as num).toDouble(),
      multBonus: (map['mult_bonus'] as num).toDouble(),
      progInc: (map['prog_inc'] as num).toDouble(),
      specialInc: (map['special_inc'] as num).toDouble(),
      monthlySubtotal:
          (map['monthly_subtotal'] as num?)?.toDouble() ?? grandTotalVal,
      grandTotal: grandTotalVal,
      f0: (map['f0'] as int?) ?? 0,
      f50: (map['f50'] as int?) ?? 0,
      f100: (map['f100'] as int?) ?? 0,
      f125: (map['f125'] as int?) ?? 0,
      f200: (map['f200'] as int?) ?? 0,
      fwa: (map['fwa'] as int?) ?? 0,
      p35: (map['p35'] as int?) ?? 0,
      p6: (map['p6'] as int?) ?? 0,
    );
  }
}
```

---

## 2. `data/local/database_helper.dart`

### 2a. Naikkan versi database

Ubah:
```dart
return await openDatabase(
  path,
  version: 2,
  onCreate: _createDB,
  onUpgrade: _onUpgrade,
);
```
Jadi:
```dart
return await openDatabase(
  path,
  version: 3,
  onCreate: _createDB,
  onUpgrade: _onUpgrade,
);
```

### 2b. Tambah 8 kolom baru di `_createDB` (tabel `history`)

Ganti CREATE TABLE history dengan:
```dart
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
```
(Tabel `sa_history` tidak berubah.)

### 2c. Update `_onUpgrade` — tambah migrasi versi 3

```dart
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
}
```

### 2d. Update `insertRecord` (bagian `kIsWeb`) — sertakan field mentah

Cari blok `if (kIsWeb) { ... }` di dalam `insertRecord`, tambahkan 8 field ke constructor
`IncentiveRecord(...)` di dalamnya:
```dart
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
```

### 2e. Tambah method `updateRecord` (setelah `insertRecord`)

```dart
Future<int> updateRecord(IncentiveRecord record) async {
  if (record.id == null) return 0;
  if (kIsWeb) {
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
```

---

## 3. `providers/history_provider.dart`

Tambah method `updateRecord` di `HistoryNotifier`:

```dart
Future<void> updateRecord(IncentiveRecord record) async {
  state = const AsyncValue.loading();
  state = await AsyncValue.guard(() async {
    await DatabaseHelper.instance.updateRecord(record);
    return await DatabaseHelper.instance.getAllRecords();
  });
}
```

---

## 4. `ui/screens/calculator_screen.dart`

Di `onPressed` tombol "Simpan Histori Pencapaian", tambahkan 8 field input mentah
ke constructor `IncentiveRecord(...)`:

```dart
final record = IncentiveRecord(
  periode: DateFormat('MMM yyyy').format(DateTime.now()),
  position: result.position.label,
  city: result.city,
  basicFee: result.basicFee,
  totalSa: result.totalSa,
  pmBase: result.pmBase,
  multRate: result.multRate,
  multBonus: result.multBonus,
  progInc: result.progInc,
  specialInc: result.specialInc,
  monthlySubtotal: result.monthlySubtotal,
  grandTotal: result.grandTotal,
  f0: int.tryParse(_controllers['f0']!.text) ?? 0,
  f50: int.tryParse(_controllers['f50']!.text) ?? 0,
  f100: int.tryParse(_controllers['f100']!.text) ?? 0,
  f125: int.tryParse(_controllers['f125']!.text) ?? 0,
  f200: int.tryParse(_controllers['f200']!.text) ?? 0,
  fwa: int.tryParse(_controllers['fwa']!.text) ?? 0,
  p35: int.tryParse(_controllers['p35']!.text) ?? 0,
  p6: int.tryParse(_controllers['p6']!.text) ?? 0,
);
```

---

## 5. `ui/screens/history_screen.dart`

### 5a. Tambah import

```dart
import '../../core/engine/calculator_engine.dart';
import '../../core/models/calculator_models.dart';
```

### 5b. Tambah helper untuk konversi label posisi ke enum

```dart
PositionType _positionFromLabel(String label) {
  return PositionType.values.firstWhere(
    (p) => p.label == label,
    orElse: () => PositionType.elite,
  );
}
```

### 5c. Ubah `_showDetailDialog` menerima `WidgetRef ref`, tambahkan tombol Edit

Ubah signature:
```dart
void _showDetailDialog(BuildContext context, WidgetRef ref, IncentiveRecord r) {
```

Tambahkan tombol Edit di `actions`, sebelum tombol "Tutup":
```dart
actions: [
  TextButton.icon(
    onPressed: () {
      Navigator.of(ctx).pop();
      _showEditDialog(context, ref, r);
    },
    icon: const Icon(Icons.edit, size: 16),
    label: const Text('Edit'),
  ),
  TextButton(
    onPressed: () => Navigator.of(ctx).pop(),
    child: const Text('Tutup'),
  ),
],
```

### 5d. Update pemanggilan `_showDetailDialog` di `ListTile.onTap`

```dart
onTap: () => _showDetailDialog(context, ref, r),
```

### 5e. Tambah method `_showEditDialog` (method baru)

```dart
void _showEditDialog(BuildContext context, WidgetRef ref, IncentiveRecord r) {
  final ctrls = {
    'f0': TextEditingController(text: r.f0.toString()),
    'f50': TextEditingController(text: r.f50.toString()),
    'f100': TextEditingController(text: r.f100.toString()),
    'f125': TextEditingController(text: r.f125.toString()),
    'f200': TextEditingController(text: r.f200.toString()),
    'fwa': TextEditingController(text: r.fwa.toString()),
    'p35': TextEditingController(text: r.p35.toString()),
    'p6': TextEditingController(text: r.p6.toString()),
  };
  final labels = {
    'f0': 'FTTH < 229',
    'f50': 'FTTH 229–299',
    'f100': 'FTTH 300–399',
    'f125': 'FTTH 400–599',
    'f200': 'FTTH ≥ 600',
    'fwa': 'FWA ≥ 219',
    'p35': 'PXGY 3–5 Bln',
    'p6': 'PXGY ≥ 6 Bln',
  };

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('Edit Jumlah Aktivasi — ${r.periode}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ctrls.entries
              .map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: TextField(
                      controller: e.value,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: labels[e.key],
                        isDense: true,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF002B66),
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final newResult = CalculatorEngine.calculateDetailed(
              position: _positionFromLabel(r.position),
              city: r.city,
              f0: int.tryParse(ctrls['f0']!.text) ?? 0,
              f50: int.tryParse(ctrls['f50']!.text) ?? 0,
              f100: int.tryParse(ctrls['f100']!.text) ?? 0,
              f125: int.tryParse(ctrls['f125']!.text) ?? 0,
              f200: int.tryParse(ctrls['f200']!.text) ?? 0,
              fwa: int.tryParse(ctrls['fwa']!.text) ?? 0,
              p35: int.tryParse(ctrls['p35']!.text) ?? 0,
              p6: int.tryParse(ctrls['p6']!.text) ?? 0,
            );

            final updated = r.copyWith(
              totalSa: newResult.totalSa,
              pmBase: newResult.pmBase,
              multRate: newResult.multRate,
              multBonus: newResult.multBonus,
              progInc: newResult.progInc,
              specialInc: newResult.specialInc,
              monthlySubtotal: newResult.monthlySubtotal,
              grandTotal: newResult.grandTotal,
              f0: int.tryParse(ctrls['f0']!.text) ?? 0,
              f50: int.tryParse(ctrls['f50']!.text) ?? 0,
              f100: int.tryParse(ctrls['f100']!.text) ?? 0,
              f125: int.tryParse(ctrls['f125']!.text) ?? 0,
              f200: int.tryParse(ctrls['f200']!.text) ?? 0,
              fwa: int.tryParse(ctrls['fwa']!.text) ?? 0,
              p35: int.tryParse(ctrls['p35']!.text) ?? 0,
              p6: int.tryParse(ctrls['p6']!.text) ?? 0,
            );

            await ref.read(historyProvider.notifier).updateRecord(updated);
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Histori diperbarui & dihitung ulang!')),
              );
            }
          },
          child: const Text('Simpan & Hitung Ulang'),
        ),
      ],
    ),
  );
}
```

**Catatan path import:** sesuaikan `core/engine/calculator_engine.dart` dengan lokasi file
sebenarnya di project (berdasarkan file yang di-upload, path-nya adalah
`core/engine/calculator_engine.dart`, bukan `core/logic/`).

---

## 6. (Opsional) Live Preview di Dialog Edit menggunakan `ResultCard` & `TierProductivityTable`

Karena `ResultCard` menerima parameter `calculationResult` (`CalculationResult?`) dan
`TierProductivityTable` menerima `result` (`CalculationResult`) — keduanya **sudah reusable**
tanpa modifikasi apa pun. Untuk live preview saat user mengubah angka di dialog edit:

1. Ubah `_showEditDialog` menjadi `StatefulBuilder` (bukan `showDialog` biasa) agar bisa
   `setState` untuk trigger rebuild preview setiap kali input berubah.
2. Setiap `onChanged` di `TextField`, panggil `CalculatorEngine.calculateDetailed(...)` dengan
   nilai controller saat ini, simpan ke variabel state lokal `_previewResult`.
3. Render `ResultCard(calculationResult: _previewResult, results: const {})` dan/atau
   `TierProductivityTable(result: _previewResult)` di bawah form input, di dalam
   `SingleChildScrollView` yang sama, sebelum tombol aksi.
4. Ini murni penambahan visual — logika update tetap sama seperti section 5e di atas.

Contoh kerangka (ganti bagian `content` di dialog edit section 5e):

```dart
content: StatefulBuilder(
  builder: (ctx, setDialogState) {
    CalculationResult buildPreview() {
      return CalculatorEngine.calculateDetailed(
        position: _positionFromLabel(r.position),
        city: r.city,
        f0: int.tryParse(ctrls['f0']!.text) ?? 0,
        f50: int.tryParse(ctrls['f50']!.text) ?? 0,
        f100: int.tryParse(ctrls['f100']!.text) ?? 0,
        f125: int.tryParse(ctrls['f125']!.text) ?? 0,
        f200: int.tryParse(ctrls['f200']!.text) ?? 0,
        fwa: int.tryParse(ctrls['fwa']!.text) ?? 0,
        p35: int.tryParse(ctrls['p35']!.text) ?? 0,
        p6: int.tryParse(ctrls['p6']!.text) ?? 0,
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...ctrls.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextField(
                  controller: e.value,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: labels[e.key],
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              )),
          const SizedBox(height: 12),
          ResultCard(calculationResult: buildPreview(), results: const {}),
        ],
      ),
    );
  },
),
```

Bagian `actions` (tombol Simpan) tetap sama seperti section 5e, hanya perlu memanggil
`CalculatorEngine.calculateDetailed(...)` sekali lagi dengan nilai final saat tombol ditekan
(sudah ada di kode section 5e).

---

## Checklist Testing Setelah Implementasi

- [ ] Buka app baru (fresh install / hapus data lama) → simpan record baru → cek 8 kolom
      f0-p6 tersimpan dengan benar di DB (bisa cek via `getAllRecords()` debug print)
- [ ] Buka detail record baru → tombol Edit muncul → ubah salah satu angka aktivasi →
      Simpan → cek grandTotal berubah sesuai rumus, bukan angka lama
- [ ] Edit record OJT vs Pro/Elite → pastikan `_positionFromLabel` mengembalikan enum yang
      benar dan hasil sesuai skema masing-masing posisi
- [ ] Edit record lama (sebelum update, f0-p6 = 0) → verifikasi muncul hasil 0/salah,
      pastikan tidak crash, hanya hasilnya memang tidak akurat (expected limitation)
- [ ] Coba app versi lama upgrade ke versi baru (jangan uninstall dulu) → pastikan
      `_onUpgrade` migrasi jalan tanpa error/crash (kolom baru bertambah dengan default 0)
