# Dokumentasi Lengkap Skema Perhitungan Insentif DSA (November 2026)

Dokumen ini memuat arsitektur logika, rumus, struktur kode, dan perbandingan perubahan skema insentif DTD/DSA (XL SATU Cilacap · TSC Pipin) yang diimplementasikan pada aplikasi **DSA XL Satu Handbook (Ver. 1.2.5+)**.

---

## Daftar Isi
1. [Arsitektur Versi Skema (`SchemeVersion`)](#1-arsitektur-versi-skema-schemeversion)
2. [Ambang Batas Paket FTTH & FWA](#2-ambang-batas-paket-ftth--fwa)
3. [Perhitungan AE OJT (Skema Baru)](#3-perhitungan-ae-ojt-skema-baru)
4. [Perhitungan AE Pro & AE Elite](#4-perhitungan-ae-pro--ae-elite)
5. [Perhitungan Insentif SPV (Supervisor)](#5-perhitungan-insentif-spv-supervisor)
6. [Kompilasi File Source Code Terkait](#6-kompilasi-file-source-code-terkait)

---

## 1. Arsitektur Versi Skema (`SchemeVersion`)

**Lokasi File:** [`lib/core/engine/scheme_version.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/core/engine/scheme_version.dart)

### Tujuan Desain
Aplikasi menghitung ulang riwayat transaksi dari input mentah aktivasi (`f0`, `f50`, `f100`, `f125`, `f200`, `fwa`, `p35`, `p6`). Tanpa pemisahan versi, pengeditan catatan lama (September/Oktober 2026) akan merusak angka nominal yang sudah dibayarkan. Oleh karena itu, dibuat `enum SchemeVersion` yang mengisolasi aturan berdasarkan periode performance record:

```dart
enum SchemeVersion {
  sept2026,
  nov2026;

  /// Default kalkulator selalu menggunakan skema terbaru
  static const SchemeVersion latest = SchemeVersion.nov2026;

  /// Penentuan otomatis berdasarkan bulan performance ('yyyy-MM-01')
  static SchemeVersion forPeriodMonth(String? periodMonth) {
    if (periodMonth == null || periodMonth.length < 7) return latest;
    return periodMonth.compareTo('2026-11') >= 0 ? nov2026 : sept2026;
  }

  /// Helper untuk record histori
  static SchemeVersion forRecord({String? periodMonth, String? periode}) {
    final month = periodMonth ??
        (periode == null ? null : tryParsePeriodMonth(periode));
    return forPeriodMonth(month);
  }

  bool get isNov2026 => this == SchemeVersion.nov2026;

  /// Tarif Progresif OJT per SA: tier 1-2, 3-4, 5-6, 7-9, >=10
  List<double> get ojtTierRates => isNov2026
      ? const [60000.0, 90000.0, 150000.0, 180000.0, 200000.0]
      : const [80000.0, 100000.0, 130000.0, 150000.0, 200000.0];

  /// Batas bawah harga paket FTTH untuk bucket 100rb dan 125rb
  int get ftth100Threshold => isNov2026 ? 290000 : 300000;
  int get ftth125Threshold => isNov2026 ? 390000 : 400000;

  /// Graduation Bonus SPV akselerasi Pro ke Elite (800rb) dinonaktifkan mulai Nov 2026
  bool get spvProToEliteAccelPaid => !isNov2026;

  /// Label singkat untuk antarmuka pengguna
  String get ftth50Range => isNov2026 ? '229–289' : '229–299';
  String get ftth100Range => isNov2026 ? '290–389' : '300–399';
  String get ftth125Range => '${ftth125Threshold ~/ 1000}–599';
}
```

---

## 2. Ambang Batas Paket FTTH & FWA

**Lokasi File:** [`lib/core/engine/incentive_bucket.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/core/engine/incentive_bucket.dart)

### A. Perubahan Ambang Batas FTTH (Product Mix Regular)
Insentif dasar per SA untuk FTTH tetap Rp 0 / Rp 50.000 / Rp 100.000 / Rp 125.000 / Rp 200.000, namun batas bawah harga paket digeser ke bawah per 1 November 2026:

| Bucket | September / Oktober 2026 | November 2026 | Insentif / SA | Dampak Penjualan |
|---|---|---|---|---|
| **f0** | `< Rp 229.000` | `< Rp 229.000` | Rp 0 | Paket di bawah 229k |
| **f50** | `Rp 229.000 – Rp 299.999` | `Rp 229.000 – Rp 289.999` | Rp 50.000 | - |
| **f100** | `Rp 300.000 – Rp 399.999` | `Rp 290.000 – Rp 389.999` | Rp 100.000 | **Paket 299k naik ke insentif Rp 100k!** |
| **f125** | `Rp 400.000 – Rp 599.999` | `Rp 390.000 – Rp 599.999` | Rp 125.000 | **Paket 399k naik ke insentif Rp 125k!** |
| **f200** | `≥ Rp 600.000` | `≥ Rp 600.000` | Rp 200.000 | Paket High ARPU / Bisnis |

### B. Pengenalan Paket FWA Baru (Termasuk Rp 220.890)
Harga paket FWA di lapangan adalah Rp 199.000 (sebelum PPN) atau **Rp 220.890 (setelah PPN 11%)**.
Logika engine dirancang fleksibel agar mendukung input nett maupun gross:

```dart
// 2. FWA (Fixed Wireless Access) - Termasuk paket Rp 199.000 nett / Rp 220.890 gross
if (typeLower.contains('fwa') || titleLower.contains('fwa')) {
  if (pkg.price >= 199000) {
    return fwa; // Sah mendapatkan bonus FWA +Rp 50.000/aktivasi
  }
  return f0;
}
```

- **Label UI:** `FWA ≥ 219k / 220.890 (+Rp 50.000/aktivasi)`
- **Bonus:** `+Rp 50.000` per aktivasi.

---

## 3. Perhitungan AE OJT (Skema Baru)

**Lokasi File:** [`lib/core/engine/calculator_engine.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/core/engine/calculator_engine.dart) (Metode `calculateDetailed`)

### Komponen Insentif AE OJT:
$$\text{Total Insentif OJT} = \text{Insentif Progresif SA} + \text{Lump Sum Bonus OJT} + \text{Bonus FWA & PXGY}$$
$$\text{Total Take Home Pay} = \text{Basic Fee (Rp 1.900.000)} + \text{Total Insentif OJT}$$

### A. Tabel Progresif OJT per SA
Setiap SA dihitung secara bertingkat (bracket):

| Tier SA | Batas Bracket | Sept / Okt 2026 | **November 2026** |
|---|---|---|---|
| Tier 1 | 1 – 2 SA | Rp 80.000 | **Rp 60.000** |
| Tier 2 | 3 – 4 SA | Rp 100.000 | **Rp 90.000** |
| Tier 3 | 5 – 6 SA | Rp 130.000 | **Rp 150.000** |
| Tier 4 | 7 – 9 SA | Rp 150.000 | **Rp 180.000** |
| Tier 5 | ≥ 10 SA | Rp 200.000 | **Rp 200.000** |

```dart
final ojtRates = scheme.ojtTierRates; // [60k, 90k, 150k, 180k, 200k]
final int b1 = totalSa.clamp(0, 2);              // tier 1-2
final int b2 = (totalSa - 2).clamp(0, 2);          // tier 3-4
final int b3 = (totalSa - 4).clamp(0, 2);          // tier 5-6
final int b4 = (totalSa - 6).clamp(0, 3);          // tier 7-9
final int b5 = (totalSa - 9) > 0 ? (totalSa - 9) : 0; // tier >=10

progInc = (b1 * ojtRates[0]) +
    (b2 * ojtRates[1]) +
    (b3 * ojtRates[2]) +
    (b4 * ojtRates[3]) +
    (b5 * ojtRates[4]);
```

### B. Lump Sum Bonus OJT
- Capai minimal **3 SA**: Mendapat **Rp 325.000**
- Capai minimal **7 SA**: Mendapat **Rp 600.000** (menggantikan Rp 325.000)

```dart
if (totalSa >= 7) {
  lumpSumBonus = 600000.0;
} else if (totalSa >= 3) {
  lumpSumBonus = 325000.0;
}
```

> **Catatan:** OJT **tidak** memiliki Multiplier terhadap Product Mix.

---

## 4. Perhitungan AE Pro & AE Elite

### Komponen Penghasilan:
1. **Basic Fee:**
   - AE Pro: Rp 2.600.000
   - AE Elite: Rp 2.773.184 (UMK Cilacap)
2. **Product Mix (FTTH, FWA, PXGY):**
   - Subtotal Product Mix dihitung dari total aktivasi per bucket harga.
3. **Multiplier Product Mix:**
   - `< 10 SA`: Multiplier = `0%` (Rp 0)
   - `10 – 14 SA`: Multiplier = `100%` (1.0x)
   - `15 – 19 SA`: Multiplier = `120%` (1.2x)
   - `20 – 29 SA`: Multiplier = `150%` (1.5x)
   - `≥ 30 SA`: Multiplier = `200%` (2.0x)
4. **Special Incentive PXGY (Pay X Get Y):**
   - Jika leads berasal dari DTD (`leadsFromDtd = true`):
     - `p35` (PXGY 3–5 Bulan): Tambahan **+Rp 125.000 / SA**
     - `p6` (PXGY ≥ 6 Bulan): Tambahan **+Rp 150.000 / SA**
5. **Tier Progresif SA Pro/Elite:**
   - 1 – 6 SA: Rp 80.000 / SA
   - 7 – 9 SA: Rp 150.000 / SA
   - 10 – 13 SA: Rp 175.000 / SA
   - 14 – 29 SA: Rp 200.000 / SA
   - 30 – 39 SA: Rp 225.000 / SA
   - 40 – 49 SA: Rp 250.000 / SA
   - ≥ 50 SA: Rp 275.000 / SA
6. **Survival Rate Pelanggan:**
   - **M3 (Ambang batas 90%):** Jika lolos gate: $\text{Pelanggan Aktif} \times \text{Rp } 100.000$
   - **M5 (Ambang batas 80%):** Jika lolos gate: $\text{Pelanggan Aktif} \times \text{Rp } 80.000$
7. **Quarterly Bonus Kuartalan (M3 Survival ≥ 90%):**
   - 30 – 44 SA: Rp 2.000.000
   - 45 – 59 SA: Rp 15.000.000
   - ≥ 60 SA: Rp 20.000.000 (+Rp 10.000 per SA di atas 60)

---

## 5. Perhitungan Insentif SPV (Supervisor)

**Lokasi File:** [`lib/core/engine/calculator_engine.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/core/engine/calculator_engine.dart) (Metode `calculateSpvDetailed`)

### Komponen Penghasilan SPV:
1. **Basic Fee SPV:** Rp 4.500.000
2. **Productivity Mix Tim Lapangan:**
   - **Regular (ARPU < 279k):**
     - 11 – 40 SA: Rp 20.000 / SA
     - 41 – 60 SA: Rp 25.000 / SA
     - 61 – 100 SA: Rp 35.000 / SA
     - ≥ 101 SA: Rp 60.000 / SA
   - **PXGY & High ARPU (≥ 279k):**
     - 1 – 10 SA: Rp 20.000 / SA
     - 11 – 40 SA: Rp 30.000 / SA
     - 41 – 60 SA: Rp 35.000 / SA
     - 61 – 100 SA: Rp 40.000 / SA
     - ≥ 101 SA: Rp 80.000 / SA
3. **Participation Bonus:**
   - Dihitung dari rasio agen yang aktif menghasilkan SA terhadap total agen aktif:
     - 50.5% – 60.4%: Multiplier 0.60
     - 60.5% – 70.4%: Multiplier 0.75
     - 70.5% – 80.4%: Multiplier 1.00
     - ≥ 80.5%: Multiplier 1.25
   - *Catatan:* SPV baru (MOB ≤ 3 bulan) bebas evaluasi partisipasi (Multiplier 1.0).
4. **KPI Bonus Multiplier:**
   - Dievaluasi berdasarkan jumlah agen aktif dan rasio OJT dalam tim:
     - 5 agen: 0.50 – 0.55
     - 6 agen: 0.55 – 0.60
     - 7 agen: 0.75 – 1.00
     - ≥ 8 agen: 1.05 – 1.20
5. **Survival Rate SPV (M3 & M5):**
   - **M3 (Gate 90%):** $\text{Pelanggan Aktif} \times \text{Rp } 25.000 + \text{Lump Sum Rp } 2.000.000$
   - **M5 (Gate 80%):** $\text{Pelanggan Aktif} \times \text{Rp } 25.000 + \text{Lump Sum Rp } 2.000.000$
6. **Graduation Bonus (Perubahan November 2026):**
   ```dart
   final double totalGraduation = (ojtToProNormal * 500000.0) +
       (ojtToProAccel * 700000.0) +
       (proToEliteNormal * 600000.0) +
       (scheme.spvProToEliteAccelPaid ? proToEliteAccel * 800000.0 : 0.0);
   ```
   - OJT ➔ Pro (Normal): Rp 500.000
   - OJT ➔ Pro (Akselerasi): Rp 700.000
   - Pro ➔ Elite (Normal): Rp 600.000
   - **Pro ➔ Elite (Akselerasi):** **Rp 0 / Ditiadakan per November 2026** *(sesuai slide DTD Nov 2026)*.
7. **Monthly Performance Bonus (Lump Sum Tim):**
   - 160 – 199 SA: Rp 2.500.000
   - 200 – 249 SA: Rp 3.500.000
   - ≥ 250 SA: Rp 5.000.000
8. **Quarterly Bonus Tim SPV (M3 Survival ≥ 90%):**
   - Mulai 50 SA (Rp 1.500.000) hingga ≥ 500 SA (Rp 12.000.000 + Rp 30.000/SA di atas 500).

---

## 6. Kompilasi File Source Code Terkait

| Modul | File Source Code | Deskripsi |
|---|---|---|
| **Versioning Engine** | [`lib/core/engine/scheme_version.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/core/engine/scheme_version.dart) | Isolasi skema historis Sept 2026 vs Nov 2026 |
| **Kalkulator Inti** | [`lib/core/engine/calculator_engine.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/core/engine/calculator_engine.dart) | Rumus perhitungan OJT, Pro, Elite, dan SPV |
| **Bucket & Paket** | [`lib/core/engine/incentive_bucket.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/core/engine/incentive_bucket.dart) | Ambang batas paket FTTH dan FWA (Rp 220.890) |
| **Katalog Paket** | [`lib/core/catalog/package_catalog.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/core/catalog/package_catalog.dart) | Daftar harga resmi paket XL Satu |
| **UI Kalkulator** | [`lib/ui/screens/calculator_screen.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/ui/screens/calculator_screen.dart) | Tampilan input aktivasi dan rincian insentif |
| **UI Kalkulator SPV** | [`lib/ui/widgets/spv_calculator_view.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/ui/widgets/spv_calculator_view.dart) | Tampilan simulator target dan komisi supervisor |
| **Panduan Skema** | [`lib/ui/screens/guide_screen.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/ui/screens/guide_screen.dart) | Tabel panduan resmi di menu Handbook aplikasi |
| **Pengujian Unit** | [`test/calculator_engine_test.dart`](file:///l:/dev_app/dsa_incentive_tracker/test/calculator_engine_test.dart) | Verifikasi 265 test cases skema Sept & Nov 2026 |

---
*Dokumentasi ini disusun secara otomatis dan selaras 100% dengan implementasi kode pada commit `6e17172` (v1.2.5).*
