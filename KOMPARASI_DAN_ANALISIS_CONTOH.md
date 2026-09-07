# Analisis Komparasi: Versi Saat Ini vs Referensi Contoh

Dokumen ini menyajikan perbandingan mendalam antara **Aplikasi DSA Incentive Tracker yang telah kita buat di Flutter** dengan **Aplikasi Web Referensi pada folder `Contoh/`** (berdasarkan 6 screenshot acuan: *SR CENTRAL KALIMANTAN KALKULATOR INCENTIVE*).

---

## 1. Ringkasan Eksekutif

| Aspek | Aplikasi Saat Ini (`lib/`) | Referensi Web (`Contoh/`) | Rekomendasi Integrasi |
| :--- | :--- | :--- | :--- |
| **Pilihan Posisi** | Tunggal (Flat), tidak ada pilihan role | 4 Role: `OJT`, `Pro`, `Elite`, `SPV` | **Sangat Direkomendasikan** untuk ditambahkan sebagai tab pilihan di bagian atas |
| **Wilayah & Basic Fee** | Belum ada | Dropdown Wilayah/Kabupaten + Otomatisasi Basic Fee | **Direkomendasikan** agar komponen gaji pokok masuk dalam estimasi bulanan |
| **Kategori Produk** | Skema FTTH lama (<229k s/d ≥600k) | Skema Produk A, B, C, D, E | **Perlu Penyesuaian** menyesuaikan skema pricing terbaru |
| **Bonus FWA / PXGY** | Diinput bercampur dengan FTTH | Dipisah berdasarkan speed (50, 100, 200 Mbps) | **Direkomendasikan** dipisah ke section tersendiri |
| **Komponen Tambahan** | Hanya Progresif, PM Base, Booster, PXGY | Net Add, Quarter Bonus, Survival Rate, Booster | **Direkomendasikan** sebagai section input modular/collapsible |
| **Tabel Rincian Tier** | Belum ada (hanya ringkasan total) | Tabel Tier Produktivitas lengkap per tier | **Sangat Bagus untuk UI/UX** transparansi hitungan |
| **Format Ringkasan** | 1 Card Sederhana | Modular: Bulanan, Survival, Quarter, Net Add, Grand Total | **Sangat Direkomendasikan** untuk tampilan modern & profesional |
| **Database & Histori** | Sudah ada SQLite & History SA | Hanya kalkulator kalkulasi statis | **Pertahankan keunggulan kita** (fitur offline-first & database) |

---

## 2. Analisis Rinci Tiap Komponen

### A. Posisi / Role & Basic Fee
- **Versi Saat Ini**:
  - Semua perhitungan dianggap sama dan tidak memperhitungkan gaji pokok (*Basic Fee*).
- **Referensi `Contoh`**:
  - Terdapat 4 tab posisi:
    1. **OJT (On Job Training)**
    2. **Pro (Professional)**
    3. **Elite (Elite Agent)**
    4. **SPV (Supervisor)**
  - Terdapat dropdown **Wilayah (Kota/Kabupaten)** (contoh: *KAB. CILACAP*).
  - Setiap posisi di wilayah tertentu memiliki **Basic Fee** (misal Elite di Kab. Cilacap = `Rp 2.773.184`). Basic Fee ini langsung menjadi komponen dasar penghasilan bulanan.

---

### B. Input Produk Aktivasi & Bonus FWA
- **Versi Saat Ini**:
  - FTTH < 229rb (Insentif: 0)
  - FTTH 229rb–299rb (Insentif: 50.000)
  - FTTH 300rb–399rb (Insentif: 100.000)
  - FTTH 400rb–599rb (Insentif: 125.000)
  - FTTH ≥ 600rb (Insentif: 200.000)
  - FWA ≥ 219rb (Insentif: 50.000)
  - PXGY 3–5 Bulan (PM 125.000 + Special 125.000)
  - PXGY ≥ 6 Bulan (PM 150.000 + Special 150.000)

- **Referensi `Contoh`**:
  - **Produk Aktivasi**:
    - **Product A**: Basic price < 229 (`Rp 0` / aktivasi)
    - **Product B**: 229–278 (`Rp 50.000` / aktivasi)
    - **Product C**: 279–349 (`Rp 100.000` / aktivasi)
    - **Product D**: 350–500 (`Rp 125.000` / aktivasi)
    - **Product E**: ≥ 501 (`Rp 175.000` / aktivasi)
  - **Bonus FWA / PXGY (Terpisah)**:
    - **FWA 50 Mbps**: `+Rp 100.000` / aktivasi
    - **FWA 100 Mbps**: `+Rp 200.000` / aktivasi (atau bonus 100k di rincian bulanan)
    - **FWA 200 Mbps**: `+Rp 75.000` / aktivasi

---

### C. Pilar Insentif Tambahan (Net Add, Quarter, Survival, Booster)

Referensi `Contoh` memiliki 4 pilar insentif terstruktur yang belum ada di versi kita saat ini:

#### 1. Net Add
- **Dropdown Klasifikasi**:
  - **Klasifikasi A**: 80–99 unit (× `Rp 50.000` / unit)
  - **Klasifikasi B**: 100–199 unit (× `Rp 100.000` / unit)
  - **Klasifikasi C**: ≥ 200 unit (× `Rp 150.000` / unit)
- **Input**: Jumlah Unit Net Add.

#### 2. Quarter Bonus
- **Rumus Tier Capaian**:
  - 1–29 aktivasi: `Rp 0` (Tidak ada bonus / belum mencapai min. 30)
  - 30–44 aktivasi: `Rp 2.000.000`
  - 45–59 aktivasi: `Rp 15.000.000`
  - ≥ 60 aktivasi: `Rp 20.000.000` + `(N - 60) × Rp 10.000`

#### 3. Survival Rate
- **Aktivasi M3**: `Aktivasi M3 × Rp 90.000 / aktivasi` (Syarat minimum 6 aktivasi).
- **Aktivasi M6**: `Aktivasi M6 × Rp 90.000 / aktivasi` (Syarat minimum 6 aktivasi).

#### 4. Booster
- **Skema Aktivasi Bulanan**:
  - `< 7`: `Rp 0`
  - `7–11`: `Rp 500.000`
  - `12–17`: `Rp 1.100.000`
  - `≥ 18`: `Rp 1.800.000`

---

### D. Tabel Tier Produktivitas (Progressive Multiplier)
Pada referensi `Contoh` (contoh posisi **Elite**):
Tabel menghitung akumulasi progresif berdasarkan total aktivasi:

| Tier | Rate / Aktivasi | Multiplier | Rumus Subtotal Progressive | Act. Fee |
| :--- | :--- | :--- | :--- | :--- |
| **1 – 4 akt** | Rp 80.000/akt | × 0 | 4 × Rp 80.000 = Rp 320.000 | — |
| **5 – 7 akt** | Rp 125.000/akt | × 1 | 3 × Rp 125.000 = Rp 375.000 | — |
| **8 – 10 akt** | Rp 150.000/akt | × 2 | 3 × Rp 150.000 = Rp 450.000 | — |
| **11 – 16 akt** | Rp 185.000/akt | × 3.75 | 6 × Rp 185.000 = Rp 1.110.000 | — |
| **≥ 17 akt** | Rp 200.000/akt | × 4.25 | 4 × Rp 200.000 = Rp 800.000 | Rp 3.055.000 |
| **Total (20 akt)** | | | | **Rp 3.055.000** |

*Catatan*: Selain **Activation Fee** kumulatif (Rp 3.055.000), terdapat **Productivity Incentive**:
$$\text{Productivity Incentive} = \text{Rp 2.000.000} \times \text{Multiplier Tier} \ (\text{misal } 4.25 = \text{Rp 8.500.000})$$

---

### E. Rumus Grand Total Penghasilan

Pada referensi `Contoh`, rumus total akhir adalah:

$$\mathbf{Total \ Penghasilan} = \mathbf{Subtotal \ Bulanan} + \mathbf{Survival \ Rate} + \mathbf{Quarter \ Bonus} + \mathbf{Net \ Add}$$

Di mana:
$$\mathbf{Subtotal \ Bulanan} = \text{Basic Fee} + \text{Activation Fee} + \text{Bonus FWA} + \text{Productivity Incentive} + \text{Booster}$$

---

## 3. Rencana Langkah Integrasi ke Proyek Kita

Jika Anda ingin mengadopsi elemen-elemen dari referensi `Contoh`, kita dapat membaginya menjadi beberapa tahap yang rapi:

1. **Langkah 1: Pembaruan Engine Perhitungan (`calculator_engine.dart`)**
   - Mendukung 4 role: `OJT`, `Pro`, `Elite`, `SPV`.
   - Mengintegrasikan parameter: `Basic Fee`, `Product A–E`, `FWA Speed`, `Net Add`, `Quarter Bonus`, `Survival Rate M3/M6`, dan `Booster`.
   - Menghasilkan rincian berjenjang (per tier dan per subtotal).

2. **Langkah 2: Model & Database (`incentive_record.dart` & `database_helper.dart`)**
   - Menyesuaikan field histori agar menyimpan rincian baru (role, basic fee, quarter, survival, net add, grand total).

3. **Langkah 3: Desain UI Kalkulator (`calculator_screen.dart` & `result_card.dart`)**
   - **Header**: Tab Selector Role (`OJT`, `Pro`, `Elite`, `SPV`) dengan ikon modern.
   - **Section Wilayah**: Dropdown Kota/Kabupaten & display Basic Fee.
   - **Section Input Produk & FWA**: Input number bersih dan informatif.
   - **Section Tambahan (Collapsible / Accordion)**: Net Add, Quarter, Survival, Booster agar tampilan tetap ringkas dan tidak membebani layar.
   - **Section Hasil**: 
     - Tabel Tier Produktivitas interaktif.
     - Card rincian breakdown per kategori.
     - Banner Grand Total gradasi modern di bagian paling bawah.

---

> [!NOTE]
> File ini tersimpan di root proyek sebagai [KOMPARASI_DAN_ANALISIS_CONTOH.md](file:///c:/DevApp/dsa_incentive_tracker/KOMPARASI_DAN_ANALISIS_CONTOH.md). Anda dapat membuka dan membacanya langsung dengan leluasa di editor tab.
