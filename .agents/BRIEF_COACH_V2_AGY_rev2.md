# BRIEF UNTUK AGY — Coach v2 (Offline, Deterministik) — REVISI 2

Repo: `dsa_incentive_tracker` (Flutter + Riverpod + sqflite). Revisi ini menggantikan `BRIEF_COACH_V2_AGY.md`. Dasar: `lib/` Ver.1.0.9 (zip 10 Okt 2026), rencana Fase 0 revisi final dari Agy, dan audit skema Sept 2026.

## 0. Status dan urutan kerja

- **Fase 0 (rencana Agy) dinyatakan DISETUJUI** dengan perubahan di bagian 1 ("Keputusan dari review"). Tidak perlu mengirim rencana ulang. Jika ada hal yang tidak cocok dengan kode, hentikan dan tanya.
- **Prasyarat:** kerjakan setelah `BRIEF_FIX_KALKULASI_MAPS_LOGIN_AGY.md` Fase 1–5 selesai dan ter-merge (rumus Pro/Elite, Net Add, gate survival, toggle DTD). Alasannya: rumus berubah, jadi test paritas coach harus memakai engine yang sudah benar. Jangan membuat test paritas dengan angka dari engine lama.
- Kerjakan per fase (1 → 2), satu fase = satu commit/PR. Sebelum lapor: `flutter analyze` bersih dan `flutter test` hijau.
- Lapor tiap fase: file yang berubah, hasil test, dan hal yang menyimpang dari brief beserta alasannya.

## 1. Keputusan dari review rencana Agy

| # | Keputusan |
|---|---|
| 1 | **Pakai `enum PackageType`** dan `tab` bertipe `String`/enum (usulan Agy), bukan `String type` bebas seperti file `package_catalog.dart` yang ada sekarang. |
| 2 | **Bucket PXGY ditentukan `tenureMonths`, bukan harga** (usulan Agy, benar). FTTH/FWA ditentukan harga bulanan **Exc. PPN**. |
| 3 | Tambahkan field Agy: `isAmortizedPrice`, `totalAdvance`, `normalAdvance`, `recurringLabel`, `recurringPrice`, `tenureMonths`. **Tambahkan juga `validUntil` (nullable)** agar promo kedaluwarsa bisa disaring. |
| 4 | **Navigasi lewat `enum CoachDestination`**, bukan route/screen langsung; `lib/ai/` tidak boleh mengimpor widget layar. `Navigator.push` dilakukan di `ai_coach_chat_sheet.dart`. |
| 5 | `target_gap` ditangani **minimal di Fase 1** (hitung via engine + penjelasan jujur), versi lengkap di Fase 2. |
| 6 | **`scripts.json` hanya di `assets/coach/scripts.json`** (aset Flutter, daftarkan di `pubspec.yaml`). Hapus `lib/ai/data/scripts.json` dari struktur, tidak bisa dibaca sebagai aset dari `lib/`. |
| 7 | **Nomor versi DB tidak ditulis mati.** Versi `DatabaseHelper` saat ini **5**. Naikkan **satu angka dari versi yang ditemukan saat merge** (brief lain, mis. backup cloud, juga akan menaikkan versi). Test migrasi dari versi sebelumnya ke versi baru. |

## 2. Aturan keras

- **Tanpa jaringan dan tanpa API key.** 100% offline. Jangan tambah dependency baru.
- **Jangan mengubah rumus `CalculatorEngine`.** Coach hanya memanggilnya. Helper baru boleh, tanpa menyentuh logika yang ada.
- **Tidak ada literal angka insentif/harga/promo di `lib/ai/`.** Semua angka dari `CalculatorEngine`, `PackageCatalog`, `RfAnalyzer`, atau data maps. Konstanta bernama non-uang (`fwaReadyScore = 60`, `homepassRadiusMeters = 100.0`) boleh.
- **Setiap harga yang ditampilkan wajib berlabel basisnya**: "(Exc. PPN)". Harga paket Advance Pay yang diamortisasi harus diberi keterangan "rata-rata per bulan".
- **Privasi:** coach tidak membaca atau menampilkan data pelanggan (KTP, alamat, nama dari `sa_record`) dan **tidak membaca data login/akun tim** (email, Sales Code, status `team_members`). `coach_log` tidak boleh menyimpan teks mentah, dan **tidak ikut** backup cloud mana pun.
- **Jangan mengarang klaim pemasaran.** "Hemat 40%", "gratis biaya pasang", dan sejenisnya hanya boleh muncul bila berasal dari field katalog dan `validUntil` belum lewat.
- **Special Incentive PXGY hanya berlaku bila leads dari DTD** (PDF DSA Sept 2026, poin 5). Setiap jawaban coach yang menyebut insentif PXGY harus menyebut syarat ini dan memakai parameter `leadsFromDtd` di engine (default `true`, tanyakan jika konteks tidak jelas).
- Bahasa jawaban: Indonesia santai ala lapangan, singkat, angka diformat `Rp 1.250.000`.

## 3. Bug nyata yang harus hilang (tidak berubah)

`lib/ai/engine/sales_ai_coach.dart` memakai `contains()` berurutan, first-match-wins.

| Input | Sekarang | Harusnya |
|---|---|---|
| "Daftar Paket FWA" | analisis sinyal | daftar paket FWA |
| "Script Closing FWA" | analisis sinyal | script closing FWA |
| "Perbedaan FWA vs FTTH" | analisis sinyal | penjelasan perbedaan |
| "Hitung Insentif 15 SA" | teks skema umum | hasil hitung dari engine |
| "Hitung Insentif 30 SA" | teks skema umum | hasil hitung dari engine |
| "Cara Capai 30 SA Sebulan" | menu bantuan | rencana kejar target |
| "Cara Cek ODP Fiber" | menu bantuan | buka peta cakupan |
| "Cek Speed Test" | menu bantuan | buka speed test |
| "Handling: Sudah Ada WiFi Lain" | menu bantuan | script objection |
| "Script Usaha/Warkop" | script rumah tangga | script UMKM/warkop |
| "Simulasi Insentif Paket Ini" | teks skema umum | hitung dengan paket dari konteks |

Selain itu: `_handleIncentiveQuery` menulis tier karangan ("1–10 SA Rp 50.000 …") yang tidak sama dengan engine; `_handleProductQuery` menyebut paket yang tidak ada di katalog asli (Smart/Family/Super User/Ultimate/FWA Lite/FWA Prime); substring `kos` cocok dengan "kosong" dan `hai` cocok di tengah kata.

## 4. Struktur target

```
assets/coach/scripts.json                 # Fase 2, daftarkan di pubspec.yaml
lib/core/catalog/package_catalog.dart     # sumber tunggal data paket
lib/core/engine/incentive_bucket.dart     # paket -> bucket (f0/f50/f100/f125/f200/fwa/p35/p6)
lib/ai/
  core/  text_normalizer.dart, intent_router.dart, entity_extractor.dart,
         coach_session.dart, coach_engine.dart
  intents/ incentive_handlers.dart, package_handlers.dart,
           signal_coverage_handlers.dart, script_handlers.dart, navigation_handlers.dart
  models/ ai_message.dart (tambah actions), quick_action.dart (+ enum CoachDestination)
  engine/sales_ai_coach.dart              # facade tipis, @Deprecated, delegasi ke CoachEngine
test/ai/..., test/core/...
```

## 5. FASE 1 — Fondasi

### 5.1 `PackageCatalog` (KONDISI SAAT INI: SETENGAH JADI)
Ditemukan: `lib/core/catalog/package_catalog.dart` sudah ada tetapi **belum dipakai** layar mana pun, hanya berisi **16 paket** (layar punya **20**), `type` masih String bebas, dan satu paket combo berisi `price: 0 // akan dilengkapi nanti`. Perlakukan file itu sebagai draf, bukan sumber kebenaran.

Langkah wajib berurutan:
1. **Snapshot dulu.** Sebelum memindahkan data, tulis test yang membaca daftar paket literal yang ada di `_buildInternetOnlyTab`, `_buildFmcTab`, `_buildAdvancePayTab`, `_buildComboTvTab` (jumlah, judul, harga, instalasi) sebagai acuan.
2. Lengkapi `PackageCatalog` menjadi **semua 20 paket** (7 Internet Only, 4 FMC, 3 Advance Pay, 6 Combo TV/OTT), tanpa harga 0 dan tanpa data yang dikarang. Jika ada angka yang tidak ada di layar, **berhenti dan tanya**, jangan mengisi.
3. Ubah layar agar membaca dari `PackageCatalog`. **Tampilan harus identik** (bandingkan screenshot sebelum/sesudah).
4. Test: `id` unik; `price >= 0` dan hanya paket tanpa harga resmi yang boleh 0 (daftar eksplisit di test); jumlah = 20; setiap paket punya `type`, `speedMbps`; paket Advance Pay punya `tenureMonths`, `totalAdvance`, `recurringPrice`; kecocokan dengan snapshot langkah 1.
5. Speed berbentuk "50 Mbps ➔ 75 Mbps" dan "(Booster 75 Mbps 6 bln) + 10 GB HP": parse `speedMbps` = kecepatan dasar, simpan teks asli di `speedLabel`.

### 5.2 `IncentiveBucket`
`IncentiveBucket.forPackage(CatalogPackage) -> IncentiveBucketCode?` (fungsi murni):
- FTTH, harga bulanan Exc. PPN: `<229.000 → f0`, `229.000–299.999 → f50`, `300.000–399.999 → f100`, `400.000–599.999 → f125`, `≥600.000 → f200`.
- FWA `≥219.000 → fwa`.
- PXGY: `tenureMonths` 3–5 → `p35`, `≥6 → p6`, selain itu `null`. (Contoh: "Pay 3 Get 4" = 4 bulan → `p35`.)
- Paket FMC dan Combo TV: **jangan menebak**. Cek label dan engine; bila tidak jelas, kembalikan `null` dan laporkan ke pemilik. Coach untuk paket tanpa bucket cukup menjawab "bucket insentif belum dipastikan".
- Verifikasi ambang terhadap label UI di `calculator_screen.dart` dan kode engine; jika ada beda, laporkan dulu.
- Catatan batas: "229.000" dan "299.999" mengacu pada rentang resmi PDF DSA (0–228.999, 229.000–299.999, dst.). Uji batas persis di test (228.999, 229.000, 299.999, 300.000, dst.).

### 5.3 `QuickAction` dan `CoachDestination`
```dart
enum CoachDestination { speedTest, coverageMap, catalog, calculator, signalTab }
class QuickAction {
  final String label;
  final String intent;
  final Map<String, dynamic> args;
  final CoachDestination? destination;
  const QuickAction({required this.label, required this.intent,
      this.args = const {}, this.destination});
  bool get isNavAction => destination != null;
}
```
`AiMessage.quickReplies` (`List<String>`) diganti `actions` (`List<QuickAction>`). Chip memanggil `coachNotifier.runAction(action)`, **bukan** mengirim ulang teks label. Chat sheet menerjemahkan `CoachDestination` menjadi navigasi nyata.

### 5.4 `TextNormalizer`
Huruf kecil, hapus emoji/tanda baca berlebih, rapikan spasi; singkatan/slang (`brp→berapa`, `gmn→bagaimana`, `yg→yang`, `sdh→sudah`, `utk→untuk`, `tdk/gk/ga/nggak→tidak`, `rb/ribu`, `jt→juta`, dst.); kata bilangan Indonesia 0–100 → angka; variasi `ftth/fiber/kabel`, `fwa/wireless/router`, `insentif/bonus/komisi`, `sa/aktivasi/closing` (waspada: "closing" juga intent script, selesaikan dengan skor/konteks).

### 5.5 `IntentRouter` berbasis skor
`keywords` (bobot 1), `phrases` (3), `negatives` (−2), boost entitas (+3, mis. angka + "sa" → `incentive_calc`). Cocok per **token utuh**; fuzzy Damerau-Levenshtein ≤1 untuk token ≥5 huruf, ≤2 untuk ≥8. Skor tertinggi menang; bila selisih kecil atau di bawah ambang, tampilkan **3 tebakan teratas** sebagai chip, jangan menebak. Pesan lanjutan ("yang 100 mbps?", "kalau 20 SA?") memakai `CoachSession.lastIntent`/`lastEntities`. Bobot dan ambang jadi konstanta bernama di satu tempat.

### 5.6 `EntityExtractor`
Jumlah per produk (`5 fwa`, `2 f100`, `3 pxgy 6 bulan`, `12 sa`), posisi (`ojt|pro|elite|spv`), kecepatan, budget (`250rb`, `1,2jt`), wilayah (fuzzy dari `GeoJsonService.loadDistricts()`), segmen (rumah, kos, warkop/warung, umkm, kantor), keberatan (mahal, sudah ada wifi, mikir dulu, ribet, kontrak). Alias bucket dan kata natural disusun dari **label asli di `calculator_screen.dart`**, jangan mengarang.

### 5.7 Daftar intent per fase
- **Fase 1:** `greet`, `help`, `incentive_calc`, `incentive_scheme_info`, `rf_analyze`, `package_list`, `package_detail`, `package_search`, `package_compare`, `fwa_vs_ftth`, `script_get`, `target_gap` (versi minimal), `nav_speedtest`, `nav_coverage_map`, `nav_catalog`, `nav_calculator`, `unknown`.
- **Fase 2:** `target_gap` (lengkap), `best_product_mix`, `pace`, `history_summary`, `coverage_check`, `wa_draft`.
Seed test (bagian 8) hanya boleh memuat intent yang aktif di fase tersebut; baris Fase 2 ditandai.

### 5.8 Handler Fase 1
- **`incentive_calc`**: ambil input dari entitas; yang kurang diambil dari `calculatorProvider` dan **sebutkan sumbernya**. Panggil `CalculatorEngine.calculateDetailed(...)`; tampilkan `grandTotal`, dan komponen: Product Mix (`pmBase`), progresif (`progInc`), multiplier (`multBonus`), Special Incentive (`specialInc`, dengan catatan DTD), `lumpSumBonus` (OJT). Posisi **SPV** di luar cakupan coach Fase 1: jawab dan arahkan ke kalkulator SPV (`CoachDestination.calculator`). Survival, Quarterly, Net Add hanya dijelaskan di `incentive_scheme_info` dan hanya dihitung bila pengguna memberi inputnya secara eksplisit.
- **`incentive_scheme_info`**: dari output engine/label bucket, bukan teks hardcode.
- **`rf_analyze`**: `rfAnalysisProvider`/`cellSignalProvider` + `RfAnalyzer.evaluate`. Jika data kosong, beri panduan dan chip `CoachDestination.signalTab`. Ambang 60 jadi `fwaReadyScore`, nilai tidak berubah.
- **`package_*`**: dari `PackageCatalog`, termasuk bucket insentif dan label "(Exc. PPN)".
- **`script_get`**: boleh masih dari kode, tanpa klaim tanpa sumber.
- **`fwa_vs_ftth`**: perbandingan singkat dengan contoh paket dari katalog.
- **`target_gap` (minimal)**: hitung total insentif untuk jumlah SA yang diminta lewat engine, tampilkan tabel tier, dan katakan bahwa simulasi laju harian ada di Fase 2.

### 5.9 Test wajib Fase 1
- `test/ai/intent_router_test.dart` (tabel bagian 8, minimal 60, target 100).
- `test/ai/engine_parity_test.dart`: tiap `PositionType` selain SPV, beberapa kombinasi input → angka coach **sama persis** dengan engine. Sertakan: Pro 14 SA (FWA 9 + PXGY 3–5 × 5) → insentif tanpa Basic Fee Rp 7.830.000; OJT 3 SA FWA → Rp 735.000.
- `test/ai/no_hardcoded_numbers_test.dart`: tak ada `Rp\s?\d` di `lib/ai/intents/`.
- `test/ai/no_ui_imports_test.dart`: `lib/ai/` tidak mengimpor `ui/screens`.
- `test/core/package_catalog_test.dart`, `test/core/incentive_bucket_test.dart`.
- Regresi 11 kasus bagian 3.

## 6. FASE 2 — Fitur lapangan

### 6.1 Target coach (semua dihitung engine dengan loop)
- **`target_gap`**: cari jumlah aktivasi tambahan minimum yang menaikkan `grandTotal` secara berarti. **Lompatan terbesar ada di batas multiplier, bukan di progresif**: pada Pro/Elite multiplier menyala di 7, 10, 14, 30, 40, dan 50 SA dan berlaku untuk seluruh Product Mix. Coach harus menonjolkan "kurang X SA lagi ke tier berikutnya" dan selisih `grandTotal` untuk +1/+2/+3/+5. Untuk OJT: batas lump sum di 3 dan 7 SA.
- **`best_product_mix`**: untuk tiap bucket hitung Δ`grandTotal` marginal untuk +1 aktivasi dari state sekarang, urutkan; catat bahwa ini murni insentif, bukan kemudahan menjual.
- **`pace`**: dari `historyProvider` dan tanggal hari ini; format periode di app `DateFormat('MMM yyyy')`. Definisikan periode dan laporkan asumsinya. Catatan skema baru: populasi SA yang dihitung adalah SA bulan-1 full (bukan SA Paid/SO), jadi coach tidak boleh mengaitkan laju dengan "SA Paid".
- **`history_summary`**: ringkasan dari `historyProvider`.

### 6.2 Kartu keputusan lokasi
Input: GPS (`liveGpsProvider`/`Geolocator`), `rfAnalysisProvider`, data cakupan (`GeoJsonService`, `CoverageMapState.matchedServingTower`).
Fungsi murni:
1. Homepass **FTTH** dalam radius R → FTTH.
2. Homepass **FWA** dalam radius R → FWA, dengan gating `fwaReadyScore`.
3. Tidak ada → "belum tercover / cek manual".
`R = homepassRadiusMeters` (awal 100 m) dan **tampilkan jarak aktual**. Perhatikan `isExistingCustomer` dan `isNonPriority`. Jika serving tower berasal dari **perkiraan** (bukan cocok eNodeB eksak; lihat brief fix Fase 6), kartu harus menyebut "perkiraan", jangan menyajikannya sebagai data pasti. Kartu berisi alasan, 1–3 paket cocok (bucket + Exc. PPN), script, dan tombol Salin/Kirim WA.

### 6.3 Perpustakaan script (data)
`assets/coach/scripts.json`:
```json
{ "id": "obj_mahal_rumah_01", "type": "objection|opening|closing",
  "segment": ["rumah","kos","warkop","umkm","kantor","any"],
  "objection": "mahal", "text": "…{paket} … {harga} …",
  "requires": ["harga"], "validUntil": null }
```
Placeholder `{paket}`, `{harga}`, `{speed}`, `{instalasi}`, `{promo}` diisi dari `PackageCatalog`; bila tidak bisa, **buang kalimatnya** (jangan tampilkan `{...}`). `validUntil` lewat → tidak dipakai. Minimal kombinasi objection (mahal, sudah ada wifi, mikir dulu, takut ribet, takut kontrak) × segmen (rumah, kos, warkop, umkm). Pindahkan 4 script lama dan bersihkan klaim tanpa sumber.

### 6.4 Draf pesan WA
Template dari paket katalog; `Clipboard` untuk salin, `LauncherHelper.openWhatsApp` untuk membuka WA. Tidak menyimpan nomor pelanggan.

### 6.5 Log belajar (lokal saja)
Tabel `coach_log`: `id, ts, query_norm, intent, score, matched, feedback`. Naikkan versi DB sesuai keputusan #7 dan tulis migrasi tanpa merusak tabel lain. **Masking** deretan angka ≥ 8 digit sebelum simpan; tidak menyimpan teks mentah. Tombol 👍/👎 mengisi `feedback`. Menu developer: 20 query `unknown` terbanyak, salin CSV.

### 6.6 Test Fase 2
Fungsi lokasi (FTTH dekat, FWA dekat + RF bagus/jelek, tak ada homepass, existing customer, serving "perkiraan"); `target_gap` sama dengan hitung manual via engine, termasuk kasus 6→7 SA dan 13→14 SA; script: tak ada placeholder mentah dan script kedaluwarsa tidak muncul; migrasi DB tidak menghapus `history`, `sa_history`, `user_profile`; masking angka panjang.

## 7. Definition of Done
- 11 kasus bagian 3 lulus; analyze bersih; seluruh test hijau.
- Tak ada literal harga/insentif di `lib/ai/`; tak ada impor `ui/screens` dari `lib/ai/`.
- Katalog: 20 paket, layar identik, tak ada harga 0 yang tidak disengaja.
- Tak ada request jaringan atau API key.
- Migrasi DB aman dari versi sebelumnya.
- Semua harga yang ditampilkan berlabel Exc. PPN.

## 8. Tabel seed test router
Format `query → intent`. Baris bertanda **[F2]** hanya berlaku mulai Fase 2.

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
simulasi insentif paket ini → incentive_calc (package_context)
gimana skema insentif → incentive_scheme_info
cara capai 30 sa sebulan → target_gap
butuh berapa lagi biar naik tier → target_gap
produk apa yang paling gede insentifnya → best_product_mix [F2]
sisa berapa hari target → pace [F2]
rekomendasi paket sinyal → rf_analyze
sinyal di sini bagus ga → rf_analyze
rsrp -95 sinr 8 cocok fwa ga → rf_analyze
cek speed test → nav_speedtest
cara cek odp fiber → nav_coverage_map
cek cakupan kroya → coverage_check (district=kroya) [F2]
di sini kena fiber ga → coverage_check [F2]
script closing fwa → script_get (type=closing)
script closing pelanggan rumah → script_get (segment=rumah)
script anak kos → script_get (segment=kos)
Script Usaha/Warkop → script_get (segment=warkop)
handling kemahalan → script_get (objection=mahal)
Handling: Sudah Ada WiFi Lain → script_get (objection=sudah_ada_wifi)
pelanggan bilang mikir dulu → script_get (objection=mikir)
takut ribet pasang → script_get (objection=ribet)
draf wa buat penawaran fwa → wa_draft [F2]
halo → greet
pagi kak → greet
apa yang bisa kamu lakukan → help
kosongin chat → (tidak boleh cocok script kos)
haiya → (tidak boleh cocok greet)
asdfgh → unknown
```
Tambahkan variasi slang/typo/angka-ejaan ("lima belas sa", "insentif gw brp") sampai ±100 baris.

## 9. Di luar cakupan
- LLM lokal atau cloud. Bila nanti ditambahkan, hanya sebagai pemeta kalimat bebas → intent + argumen (JSON terbatas) di atas router ini; kandidat: `flutter_gemma` dengan FunctionGemma 270M (±284 MB) atau Qwen3 0.6B (±586 MB), diunduh terpisah, tidak dibundel di APK.
- Coach untuk perhitungan SPV (arahkan ke kalkulator SPV), perubahan aturan insentif, desain ulang layar, sinkronisasi Supabase, Net Add/Survival/Quarterly sebagai simulasi otomatis (hanya penjelasan skema).
