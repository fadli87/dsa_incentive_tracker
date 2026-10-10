# BRIEF UNTUK AGY — Coach v2 (Offline, Deterministik) untuk DSA Tracker

Repo: `dsa_incentive_tracker` (Flutter + Riverpod + sqflite). Brief ini berdasarkan pembacaan `lib/` versi 1.0.7+8.

## 0. Cara kerja (ikuti urutan ini)

1. **Fase 0 — Rencana dulu, jangan langsung coding.** Balas dengan: daftar file yang akan dibuat/diubah, signature semua class publik, dan pertanyaan yang belum jelas. Tunggu review sebelum menulis kode.
2. Kerjakan per fase (1 → 2). Satu fase = satu commit terpisah. Jalankan `flutter analyze` dan `flutter test` sebelum melapor selesai.
3. Setiap fase, lapor: file yang berubah, hasil test, dan hal yang menyimpang dari brief beserta alasannya.

## 1. Aturan keras

- **Tanpa jaringan dan tanpa API key.** Coach v2 100% offline. Jangan tambah dependency baru kecuali disebut di brief ini.
- **Jangan mengubah rumus di `CalculatorEngine`.** Coach hanya memanggilnya. Kalau perlu helper baru, tambahkan tanpa menyentuh logika yang ada.
- **Tidak boleh ada literal angka insentif, harga, atau promo di file coach.** Semua angka berasal dari `CalculatorEngine`, `PackageCatalog`, `RfAnalyzer`, atau data maps.
- **Data pelanggan (KTP, alamat, nama dari `sa_record`) tidak boleh dibaca atau ditampilkan coach.**
- **Jangan mengarang klaim pemasaran.** Klaim seperti "hemat 40%" atau "gratis biaya pasang" hanya boleh muncul kalau berasal dari field katalog (`installation`, `isFreeInstall`, `speedUpgrade`, dll.) dan promonya belum kedaluwarsa.
- Bahasa jawaban: Indonesia santai ala lapangan, singkat, angka diformat `Rp 1.250.000`.

## 2. Masalah yang harus hilang (bug nyata di kode sekarang)

`lib/ai/engine/sales_ai_coach.dart` memakai `contains()` berurutan dan first-match-wins. Akibatnya:

| Input (quick reply / kalimat) | Sekarang | Harusnya |
|---|---|---|
| "Daftar Paket FWA" | analisis sinyal (kena `fwa`) | daftar paket FWA |
| "Script Closing FWA" | analisis sinyal | script closing FWA |
| "Perbedaan FWA vs FTTH" | analisis sinyal | penjelasan perbedaan |
| "Hitung Insentif 15 SA" | teks skema umum | hasil hitung dari engine |
| "Hitung Insentif 30 SA" | teks skema umum | hasil hitung dari engine |
| "Cara Capai 30 SA Sebulan" | menu bantuan umum | rencana kejar target |
| "Cara Cek ODP Fiber" | menu bantuan umum | panduan / buka peta cakupan |
| "Cek Speed Test" | menu bantuan umum | buka layar speed test |
| "Handling: Sudah Ada WiFi Lain" | menu bantuan umum | script objection |
| "Script Usaha/Warkop" | script rumah tangga | script UMKM/warkop |
| "Simulasi Insentif Paket Ini" | teks skema umum | hitung dengan paket dari konteks |

Selain itu:
- `_handleIncentiveQuery` menulis tier "1–10 SA Rp 50.000 / 11–25 Rp 75.000 / 26+ Rp 100.000". Ini **tidak sama** dengan engine (engine menghitung per bucket produk + progresif + multiplier + lump sum, dan OJT punya skema sendiri).
- `_handleProductQuery` menulis paket "Smart/Family/Super User/Ultimate/FWA Lite/FWA Prime". Katalog asli ada di `product_catalog_screen.dart` (mis. "Tactical FTTH 20 Mbps" Rp 185.000, "FWA Hero 100 Mbps" Rp 219.000).
- Substring `kos` ikut cocok dengan kata seperti "kosong"; `hai` bisa cocok di tengah kata.

## 3. Struktur target

```
lib/core/catalog/
  package_catalog.dart        # data class + daftar paket (satu-satunya sumber)
lib/core/engine/
  incentive_bucket.dart       # helper: harga paket -> bucket (f0/f50/...)  [lihat 4.1]
lib/ai/
  core/
    text_normalizer.dart
    intent_router.dart
    entity_extractor.dart
    coach_session.dart        # konteks percakapan
    coach_engine.dart         # orkestrasi: normalize -> route -> extract -> handler
  intents/                    # satu file per kelompok handler
    incentive_handlers.dart
    package_handlers.dart
    signal_coverage_handlers.dart
    script_handlers.dart
    navigation_handlers.dart
  models/
    ai_message.dart           # tambah field actions
    quick_action.dart
  data/
    scripts.json              # perpustakaan script (aset)
lib/ai/engine/sales_ai_coach.dart   # jadikan tipis: delegasi ke CoachEngine, tandai @Deprecated
test/ai/...
```

Tambahkan `assets/coach/` ke `pubspec.yaml` (sekarang aset terdaftar: `assets/images/`, `assets/map_data/...`).

## 4. FASE 1 — Fondasi (hilangkan bug, satu sumber kebenaran)

### 4.1 Ekstrak `PackageCatalog`
- Pindahkan data paket dari `_buildInternetOnlyTab`, `_buildFmcTab`, `_buildAdvancePayTab`, `_buildComboTvTab` (`product_catalog_screen.dart`) ke `PackageCatalog`. Saat ini datanya berupa literal `Map` (`title, speed, type, tag, speedUpgrade, price, installation, isFreeInstall, features`) yang tersebar di dalam widget.
- Model: `CatalogPackage { id, tab, title, speedMbps (int), speedLabel, type (ftth/fwaOutdoor/fwaIndoor/fmc/pxgy/comboTv), price, installation, isFreeInstall, speedUpgrade, features, hpQuotaGb? }`. `id` stabil (slug), bukan indeks.
- `product_catalog_screen.dart` diubah untuk membaca dari `PackageCatalog`. **Tampilan layar tidak boleh berubah** (bandingkan sebelum dan sesudah).
- Ada beberapa paket dengan speed berbentuk "50 Mbps ➔ 75 Mbps" dan "(Booster 75 Mbps 6 bln) + 10 GB HP". Parse ke `speedMbps` (kecepatan dasar) dan simpan teks aslinya di `speedLabel`.
- Test: `id` unik, `price > 0`, setiap paket punya `type` dan `speedMbps`.

### 4.2 Helper bucket insentif (tanpa mengubah rumus)
Di `calculator_screen.dart`, label input FTTH menunjukkan bucket berdasarkan **harga paket**:

| Kode | Label UI |
|---|---|
| `f0` | FTTH < 229 (Rp 0) |
| `f50` | FTTH 229–299 |
| `f100` | FTTH 300–399 |
| `f125` | FTTH 400–599 |
| `f200` | FTTH ≥ 600 |
| `fwa` | FWA ≥ 219 (+Rp 50.000) |
| `p35` | PXGY 3–5 Bln |
| `p6` | PXGY ≥ 6 Bln |

Buat `IncentiveBucket.forPackage(CatalogPackage) -> String? (kode)` yang memakai ambang harga di atas. **Verifikasi ambang dengan kode di engine dan label UI**; kalau ada beda, laporkan dulu, jangan menebak. Satuan harga yang dimaksud label ("229", "300") — konfirmasi apakah ribuan rupiah dan apakah mengacu ke harga paket bulanan; tanyakan kalau tidak jelas dari kode.
Tujuan: coach bisa bilang "paket ini masuk bucket X, insentif Rp Y".

### 4.3 `QuickAction` menggantikan quick reply berupa teks
```dart
class QuickAction {
  final String label;      // teks di chip
  final String intent;     // id intent, mis. 'package_list'
  final Map<String, dynamic> args;  // mis. {'type': 'fwa'}
}
```
`AiMessage.quickReplies` (`List<String>`) diganti `actions` (`List<QuickAction>`). Ubah `ai_coach_chat_sheet.dart` (`_sendMessage`) agar chip memanggil `coachNotifier.runAction(action)`, **bukan** mengirim ulang teks label. Ini menghilangkan seluruh kelas bug pada tabel bagian 2.
Tambahkan juga `NavAction` (buka layar): speed test, peta cakupan, katalog, kalkulator. Pakai mekanisme navigasi yang sudah ada di app.

### 4.4 `TextNormalizer`
- huruf kecil, hapus emoji/tanda baca berlebih, rapikan spasi.
- tabel singkatan dan slang: `brp→berapa`, `gmn→bagaimana`, `yg→yang`, `sdh→sudah`, `utk→untuk`, `tdk→tidak`, `gk/ga/nggak→tidak`, `wifi/wi-fi→wifi`, `rb/ribu→ribu`, `jt→juta`, dll. (bisa ditambah).
- kata bilangan Indonesia 0–100 ke angka ("lima belas" → 15, "dua puluh lima" → 25).
- ejaan varian: `ftth/fiber/kabel`, `fwa/wireless/router`, `insentif/bonus/komisi`, `sa/aktivasi/closing` (jaga agar tidak salah: "closing" juga muncul di intent script; pakai konteks/skor).

### 4.5 `IntentRouter` berbasis skor
- Setiap intent punya: `keywords` (bobot 1), `phrases` (bobot 3), `negatives` (bobot −2), dan boost dari entitas (mis. ada angka + "sa" → `incentive_calc` +3).
- Cocokkan per **token utuh** (bukan substring). Fuzzy: jarak Damerau-Levenshtein ≤1 untuk token ≥5 huruf, ≤2 untuk ≥8 huruf.
- Skor tertinggi menang; kalau selisih dengan runner-up kecil atau skor < ambang, jangan menebak: tampilkan **3 tebakan teratas** sebagai chip ("Maksud kamu: …?").
- Konteks: kalau pesan pendek/lanjutan ("yang 100 mbps?", "kalau 20 SA?"), pakai `CoachSession.lastIntent` dan entitas terakhir.
- Ambang dan bobot ditaruh sebagai konstanta bernama di satu tempat.

### 4.6 `EntityExtractor` (regex)
Ekstrak: 
- **jumlah per produk**: pola seperti `5 fwa`, `2 f100`, `3 pxgy 6 bulan`, `12 sa` (total tanpa rincian).
- **posisi**: `ojt|pro|elite|spv` → `PositionType`.
- **kecepatan**: `100 mbps`, `1 gb`, `1 giga`.
- **budget**: `250rb`, `250 ribu`, `1,2jt` → rupiah.
- **wilayah**: cocokkan fuzzy dengan nama dari `GeoJsonService.loadDistricts()` (`DistrictInfo.name`).
- **segmen**: rumah, kos, warkop/warung, umkm, kantor.
- **keberatan**: mahal, sudah ada wifi, mikir dulu/nanti, ribet, kontrak/lama.
Alias kode produk (`f50`, `f100`, ...) dan kata natural ("ftth 300 sampai 399") harus bisa dipakai. **Baca label sebenarnya di `calculator_screen.dart`** untuk menyusun alias; jangan mengarang.

### 4.7 Daftar intent (id) untuk Fase 1
`greet`, `help`, `incentive_calc`, `incentive_scheme_info`, `rf_analyze`, `package_list`, `package_detail`, `package_search`, `package_compare`, `fwa_vs_ftth`, `script_get`, `nav_speedtest`, `nav_coverage_map`, `nav_catalog`, `nav_calculator`, `unknown`.

Handler yang wajib benar di Fase 1:
- `incentive_calc`: ambil input dari entitas; kalau kurang, pakai `calculatorProvider` (state kalkulator saat ini) sebagai default dan **katakan sumbernya**. Panggil `CalculatorEngine.calculateDetailed(...)` dan tampilkan `grandTotal`, komponen (`pmBase`, `progInc`, `multBonus`, `specialInc`, `lumpSumBonus`), serta `tierRows`. Tanpa angka buatan sendiri.
- `incentive_scheme_info`: jelaskan skema dari **output engine** (mis. `tierRows` untuk contoh total SA) dan label bucket UI, bukan teks hardcode.
- `rf_analyze`: pakai `rfAnalysisProvider` / `cellSignalProvider` + `RfAnalyzer.evaluate` (sudah ada). Kalau belum ada data sinyal, beri panduan dan chip `NavAction` ke tab sinyal. **Ambang skor FWA-ready (sekarang 60, hardcode di `_handleRfQuery`) jadikan konstanta bernama** dan jangan diubah nilainya.
- `package_*`: semua dari `PackageCatalog` (filter type/speed/budget, detail, banding dua paket, tampilkan bucket insentif dari 4.2).
- `script_get`: untuk Fase 1 boleh masih dari kode, tapi **buang klaim tanpa sumber** (lihat aturan keras). Perpustakaan berbasis data ada di Fase 2.
- `fwa_vs_ftth`: perbandingan singkat yang mengambil contoh paket dari katalog.

### 4.8 Test wajib Fase 1
- `test/ai/intent_router_test.dart`: tabel query → intent (lihat bagian 6). Minimal 60 baris sebagai awal, target 100.
- `test/ai/engine_parity_test.dart`: untuk beberapa kombinasi input dan tiap `PositionType`, angka yang ditampilkan coach **sama persis** dengan `CalculatorEngine.calculateDetailed`.
- `test/ai/no_hardcoded_numbers_test.dart` (sederhana): pastikan file di `lib/ai/intents/` tidak berisi pola `Rp\s?\d` literal.
- `test/core/package_catalog_test.dart`.
- Regresi untuk 11 kasus di tabel bagian 2.

## 5. FASE 2 — Fitur yang berguna di lapangan

### 5.1 Target coach (semua dihitung engine dengan loop, tanpa AI)
- `target_gap`: dari state saat ini, cari jumlah aktivasi tambahan minimum yang membuat `progInc` naik tier atau `lumpSumBonus` naik (loop 0..N memanggil `calculateDetailed`). Tampilkan tabel "kalau +1 / +2 / +3 / +5" dengan selisih `grandTotal`.
- `best_product_mix`: untuk tiap bucket, hitung ΔgrandTotal marginal untuk +1 aktivasi dari state sekarang; urutkan. Beri catatan bahwa ini murni insentif, bukan kemudahan menjual.
- `pace`: dari `historyProvider` dan tanggal hari ini, hitung sisa hari dan laju harian yang dibutuhkan. Format `periode` di app adalah `DateFormat('MMM yyyy')` (lihat `calculator_screen.dart`); tentukan definisi periode dan laporkan asumsi yang dipakai.
- `history_summary`: ringkasan dari `historyProvider` (total, tren, periode terbaik).

### 5.2 Kartu keputusan lokasi
Input: posisi GPS (`liveGpsProvider` atau `Geolocator`), `rfAnalysisProvider`, dan data cakupan (`GeoJsonService`: `loadDistrictHomepass`, `findNearestTower`, `CoverageMapState.matchedServingTower`).
Logika keputusan (tabel, ditulis sebagai fungsi murni agar bisa dites):
1. Homepass **FTTH** terdekat dalam radius R → rekomendasikan FTTH.
2. Homepass **FWA** (`displayTechnologyLabel`) dalam radius R → FWA; gating dengan skor RF (konstanta `fwaReadyScore`).
3. Tidak ada homepass dalam radius → "belum tercover / cek manual".
`R` = konstanta bernama yang bisa diubah (usulan awal 100 m; **tampilkan jarak aktual** ke titik terdekat agar sales bisa menilai sendiri). Kartu berisi alasan, 1–3 paket dari katalog yang cocok (dengan bucket insentif), script, dan tombol "Salin/Kirim WA".
Perhatikan status `HomepassPoint.isExistingCustomer` dan `isNonPriority` agar hasilnya tidak menyesatkan.

### 5.3 Perpustakaan script berbasis data
`assets/coach/scripts.json`, skema:
```json
{
  "id": "obj_mahal_rumah_01",
  "type": "objection|opening|closing",
  "segment": ["rumah","kos","warkop","umkm","kantor","any"],
  "objection": "mahal",
  "text": "…{paket} … {harga} …",
  "requires": ["harga"],
  "validUntil": null
}
```
- Placeholder: `{paket}`, `{harga}`, `{speed}`, `{instalasi}`, `{promo}` diisi dari `PackageCatalog`. Kalau placeholder tidak bisa diisi, **buang kalimat itu**, jangan tampilkan `{...}` mentah (ada test untuk ini).
- Kalau `validUntil` lewat, script tidak dipakai.
- Kombinasi objection × segmen minimal: mahal, sudah ada wifi, mikir dulu, takut ribet, takut kontrak; × rumah, kos, warkop, umkm.
- Pindahkan 4 script yang ada sekarang ke sini dan bersihkan klaim tanpa sumber.

### 5.4 Draf pesan WA
Template pesan follow-up/penawaran dari paket katalog. Pakai `Clipboard` untuk salin; `LauncherHelper.openWhatsApp` sudah ada di `core/utils/launcher_helper.dart` untuk membuka WA. Tidak menyimpan nomor pelanggan.

### 5.5 Log belajar (lokal)
- Tabel `coach_log` di `DatabaseHelper` (sekarang `version: 5`; naikkan ke 6 dan tulis migrasi di `_onUpgrade` tanpa merusak data lama): `id, ts, query_norm, intent, score, matched, feedback`.
- **Masking privasi:** sebelum disimpan, hapus deretan angka ≥ 8 digit (nomor HP/KTP) dan jangan simpan teks mentah.
- Tombol 👍/👎 di tiap jawaban coach mengisi `feedback`.
- Layar/menu developer sederhana: daftar 20 query `unknown` terbanyak dan tombol salin sebagai CSV. Tujuan: menambah intent dari kebutuhan nyata tim.

### 5.6 Test Fase 2
- Fungsi keputusan lokasi: tabel kasus (FTTH dekat, FWA dekat + RF bagus/jelek, tidak ada homepass, existing customer).
- `target_gap`: hasil harus sama dengan hitung manual via engine untuk beberapa kasus.
- Script: tidak ada placeholder mentah di output; script kedaluwarsa tidak muncul.
- Migrasi DB versi 5 → 6 tidak menghapus tabel `history`, `sa_history`, `user_profile`.

## 6. Tabel seed test router (perluas sampai ±100)

Format: `query → intent`.

```
daftar paket fwa → package_list (type=fwa)
Daftar Paket FTTH → package_list (type=ftth)
paket fwa yang 100 mbps → package_detail
ada paket 250rb ga → package_search (budget=250000)
paket paling murah → package_search
bandingin fwa hero sama tactical ftth → package_compare
Perbedaan FWA vs FTTH → fwa_vs_ftth
bedanya fwa sama fiber apa → fwa_vs_ftth
Hitung Insentif 15 SA → incentive_calc (total=15)
hitung insentif 5 fwa 2 f100 → incentive_calc
insentif elite kalo 12 sa berapa → incentive_calc (position=elite)
insentif ojt 8 sa → incentive_calc (position=ojt)
berapa bonus saya bulan ini → incentive_calc (state)
gimana skema insentif → incentive_scheme_info
cara capai 30 sa sebulan → target_gap
butuh berapa lagi biar naik tier → target_gap
produk apa yang paling gede insentifnya → best_product_mix
sisa berapa hari target → pace
rekomendasi paket sinyal → rf_analyze
sinyal di sini bagus ga → rf_analyze
rsrp -95 sinr 8 cocok fwa ga → rf_analyze
cek speed test → nav_speedtest
cara cek odp fiber → nav_coverage_map
cek cakupan kroya → coverage_check (district=kroya)
di sini kena fiber ga → coverage_check
script closing fwa → script_get (type=closing)
script closing pelanggan rumah → script_get (segment=rumah)
script anak kos → script_get (segment=kos)
Script Usaha/Warkop → script_get (segment=warkop)
handling kemahalan → script_get (objection=mahal)
Handling: Sudah Ada WiFi Lain → script_get (objection=sudah_ada_wifi)
pelanggan bilang mikir dulu → script_get (objection=mikir)
takut ribet pasang → script_get (objection=ribet)
draf wa buat penawaran fwa → wa_draft
halo → greet
pagi kak → greet
apa yang bisa kamu lakukan → help
kosongin chat → (tidak boleh cocok script kos)
haiya → (tidak boleh cocok greet)
asdfgh → unknown
```

## 7. Definition of Done

- Semua kasus pada bagian 2 lolos di test.
- `flutter analyze` bersih dan seluruh test hijau.
- Tidak ada literal harga/insentif di `lib/ai/`.
- Layar Katalog tampil identik dengan sebelumnya.
- Tidak ada request jaringan dan tidak ada API key di kode.
- Migrasi DB aman (uji upgrade dari database versi 5).

## 8. Di luar cakupan (JANGAN dikerjakan sekarang)

- Integrasi LLM lokal atau cloud. Kalau nanti ditambahkan, posisinya hanya sebagai **pemetaan kalimat bebas → intent + argumen** (keluaran JSON terbatas) di atas router ini, lalu handler yang sama menghitung jawabannya. Opsi yang bisa dikaji nanti: `flutter_gemma` dengan FunctionGemma 270M (±284 MB) atau Qwen3 0.6B (±586 MB), diunduh terpisah, bukan dibundel di APK.
- Perubahan aturan insentif, desain ulang layar, dan sinkronisasi Supabase.
