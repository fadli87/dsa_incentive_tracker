# BRIEF — Perbaikan Kalkulasi, Serving Tower, dan AccessGate (Ver.1.0.9 → 1.0.10)

Untuk dieksekusi Antigravity pada branch terpisah (mis. `fix/scheme-sept-2026`). Dasar: audit `AUDIT_PERBEDAAN_PERHITUNGAN_SEPT2026.md` dan review lib.zip 10 Okt 2026.
Sumber kebenaran: PDF "New Incentive DSA Sept 2026", PDF "New Incentive Scheme SPV Sept 2026", Excel kalkulator Sept 2026. Jika Excel dan PDF berbeda, **PDF menang**.

## Aturan keras
1. Kerjakan per FASE, satu commit per fase. Jalankan `flutter analyze` dan `flutter test` di akhir tiap fase; jangan lanjut jika merah.
2. Jangan ubah hal di luar daftar. Jangan menyentuh rumus yang sudah benar (lihat bagian "Jangan diubah").
3. Jangan mengarang aturan. Jika ada hal yang tidak tercantum di brief atau PDF, berhenti dan tanya.
4. Semua angka test di bawah berasal dari file resmi. Test harus gagal jika rumus salah.

---

## FASE 1 — Bersihkan sisa aturan lama "Progresif HILANG"
Rumus di `calculator_engine.dart` sudah benar: `progInc` = jumlah semua tier, `multBonus = pmBase × multRate`. Yang tersisa hanya teks dan UI.

1. `lib/ui/screens/guide_screen.dart` baris ~281–293: hapus kalimat "Insentif Progresif SA akan HILANG…" dan semua "(Progresif Hilang)" di tabel. Ganti penjelasan menjadi: *"Pro/Elite menerima DUA komponen: (1) insentif progresif per SA dan (2) Multiplier × Product Mix Base (tanpa Special Incentive). Keduanya dibayarkan."*
2. `lib/ui/widgets/result_card.dart` baris ~101–112: subtitle progresif jangan lagi "Hilang karena…", cukup `'Tier Pro/Elite kumulatif $totalSa aktivasi'`. Hapus badge `'Diganti Booster'`; badge selalu `'$totalSa aktivasi'`.
3. `lib/ui/widgets/tier_productivity_table.dart`: hapus blok `if (tier.multiplierBonus > 0) …` (dead code) dan, jika tidak dipakai di tempat lain, field `multiplierBonus` di `TierRow` (`calculator_models.dart`). Pastikan label ringkasan menampilkan: Subtotal Progresif, Booster Multiplier (`{multRate}x × PM Base`), dan Total Insentif Produktivitas = progInc + multBonus.
4. `lib/ui/screens/update_notes_screen.dart`: tambahkan catatan versi 1.0.10 — "Perbaikan rumus Pro/Elite: progresif tetap dibayar + multiplier × Product Mix; perbaikan Net Add".
5. Naikkan versi ke `1.0.10` di `app_constants.dart` dan semua literal `Ver.1.0.9` (grep `1.0.9`).

## FASE 2 — Net Add (`calculateDsaNetAdd`)
Aturan resmi (PDF DSA poin 10 + simulasi + Excel `E30`):
- **Tarif ditentukan oleh Ending Active Subs bulan ini** (`currentActiveSubs`): `>=200 → 150.000`, `>=100 → 100.000`, `>=80 → 50.000`, selain itu `0` (tidak eligible).
- **Incremental** = `currentActiveSubs − baselineActiveSubs`, minimal 0, **maksimal 10**. `baselineActiveSubs` = pencapaian tertinggi sejak Maret 2026 (input user, tidak diubah).
- Total = incremental × tarif.
- OJT tetap `DsaNetAddDetail.empty`.

Ubah penentuan `ratePerSa` dari `baselineActiveSubs` menjadi `currentActiveSubs`. Pastikan UI (`calculator_screen.dart` sekitar baris 709) menampilkan tarif yang benar dan teks bantuan menyebut "tarif mengikuti Active Subs bulan ini".

Test (`test/engine/netadd_test.dart`), format `(baseline, current) → total`:
- (85, 86) → 50.000
- (90, 95) → 250.000
- (95, 106) → 1.000.000 (incremental 11 di-cap 10, tarif 100k)
- (106, 110) → 400.000
- (110, 150) → 1.000.000
- (150, 200) → 1.500.000 (tarif 150k karena current ≥ 200)
- (120, 119) → 0
- (80, 79) → 0 (current < 80, tidak eligible)

## FASE 3 — Gate survival memakai bilangan bulat
Saat ini `rate >= 0.8999 / 0.7999` meloloskan 89,99%. Ganti dengan helper di engine:
```dart
static bool meetsGate(int surv, int base, int percent) =>
    base > 0 && surv * 100 >= base * percent;
```
Pakai di: DSA M3 (90), DSA M5 (80), Quarterly DSA (90), SPV M3 (90), SPV M5 (80), SPV Quarterly (80).
`calculateDsaQuarterly` dan `calculateSpvQuarterly` saat ini menerima `double rate`; boleh dipertahankan, tetapi gate dihitung dari rate dengan toleransi epsilon `1e-9` (`rate + 1e-9 >= 0.90`), bukan 0.8999. Pilih salah satu pendekatan dan terapkan konsisten.

Test: M3 base 100 surv 89 → gate gagal; surv 90 → lolos; base 10000 surv 8999 → gagal.

## FASE 4 — Special Incentive hanya untuk leads dari DTD
PDF DSA poin 5: Special Incentive PXGY hanya dibayar bila leads berasal dari DTD.
- Tambahkan parameter `bool leadsFromDtd = true` pada `calculateDetailed`.
- `specialInc = leadsFromDtd ? (p35*125000 + p6*150000) : 0`.
- `pmBase` (yang dikali multiplier) **tetap** memasukkan acquisition 125k/150k untuk PXGY. Special Incentive tidak ikut basis multiplier.
- UI: tambahkan Switch "Leads dari DTD" (default aktif) di kalkulator DSA, hanya tampil jika p35 + p6 > 0. Teruskan lewat `calculator_provider.dart`. Simpan di history hanya jika model sudah punya kolom yang cocok; **jangan migrasi DB** untuk ini, cukup state kalkulator.

Test: FWA 9 + PXGY(3–5) 5, Pro, `leadsFromDtd=true` → insentif tanpa basic = **7.830.000**; `false` → 7.830.000 − 625.000 = **7.205.000**.

## FASE 5 — Unit test dengan angka resmi
Buat/perbarui `test/engine/calculator_engine_test.dart`. Nilai "insentif" di bawah **belum termasuk Basic Fee**; bandingkan `monthlySubtotal − basicFee`.

Pro/Elite (semua dengan `leadsFromDtd=true`):
| Skenario (f0,f50,f100,f125,f200,fwa,p35,p6) | Insentif |
|---|---:|
| (0,0,5,0,0,0,0,0) 5 SA | 900.000 |
| (0,0,7,0,0,0,0,0) 7 SA | 2.380.000 |
| (0,2,4,2,0,2,0,0) 10 SA | 3.655.000 |
| (0,0,0,0,0,9,5,0) 14 SA | 7.830.000 |
| (0,0,20,0,0,0,0,0) 20 SA | 13.030.000 |
| (0,0,50,0,0,0,0,0) 50 SA | 38.105.000 |

Urutan parameter: f0, f50, f100, f125, f200, fwa, p35, p6. Baris 1–2 dan 5–6 memakai f100; baris 3 = f50 2, f100 4, f125 2, fwa 2; baris 4 = fwa 9 + p35 5.

OJT (tanpa multiplier, tanpa basic):
- 3 SA FWA (150.000 PM) → progresif 260.000 + lump sum **325.000** + PM 150.000 = **735.000** (Excel menulis 760.000 karena memakai 350.000; PDF = 325.000, ikuti PDF).
- 7 SA → lump sum 600.000.

SPV (contoh PDF): 
- Product Mix 4.085.000, participation 1,25× = 5.106.250, MoB>3, 14 agent aktif, 2 OJT (14%) → KPI multiplier 120% → KPI Bonus **11.029.500**.
- Contoh PDF kecil: PM 850.000 + participation 850.000 (multiplier 1,00), 15 agent, 10 OJT (67%) → ×105% = **1.785.000**.
- MoB ≤ 3: PM 850.000 → KPI Bonus **850.000** (tanpa participation).
- Survival SPV M5: 27 dari 28 (96%) → 27×25.000 + 2.000.000 = **2.675.000**; M3 80% → 0.
- Quarterly SPV 510 SA, survival ≥80% → 12.000.000 + 10×30.000 = **12.300.000**.
- Quarterly DSA 65 SA, survival ≥90% → 20.000.000 + 5×10.000 = **20.050.000**.

Jika ada test lama yang bertentangan dengan angka di atas, **ubah test-nya** (angka lama berasal dari aturan yang salah) dan sebutkan di ringkasan commit.

## FASE 6 — Serving Tower (maps)
File acuan dari Claude: `serving_fix/serving_tower_matcher.dart`, `coverage_map_provider.dart`, `serving_tower_matcher_test.dart` (jika tersedia, gabungkan; jika tidak, implementasikan sesuai spesifikasi berikut). Fokus: `lib/maps/providers/coverage_map_provider.dart` dan `network/models/cell_signal_info.dart`.

Masalah di versi sekarang:
1. `state.copyWith(matchedServingTower: null)` **tidak mengosongkan** karena `copyWith` memakai `??`. Tower lama tetap tampil walau sinyal hilang atau tidak ada kecocokan. **Perbaikan:** tambahkan parameter `bool clearServingTower = false` pada `copyWith` (`matchedServingTower: clearServingTower ? null : (matchedServingTower ?? this.matchedServingTower)`) dan pakai di semua tempat yang ingin mengosongkan.
2. Pencocokan eksak berdasarkan Node ID **hanya valid untuk LTE** (`cellType == 'LTE'`, `eNodeB = ECI >> 8`). Untuk NR dan WCDMA database tower tidak berisi gNodeB/RNC, jadi **jangan** cocokkan eksak; langsung ke estimasi terdekat. Hapus kecocokan `t.towerId == enodebId` kecuali sudah dipastikan kolom itu memuat eNodeB.
3. Tambahkan `servingMatchSource` di state: `none`, `enodebExact`, `nearestEstimate`. UI (kartu serving tower di `coverage_map_screen.dart`) harus memberi label **"Perkiraan (tower terdekat)"** bila `nearestEstimate`, dan label biasa bila `enodebExact`.
4. Batas jarak: bila eNodeB cocok eksak tetapi jarak ke user > **15 km**, jangan dipakai sebagai eksak (turunkan ke estimasi). Radius fallback estimasi tetap 8–10 km.
5. Bila beberapa tower memiliki eNodeB sama, pilih yang terdekat dari lokasi user; bila lokasi user belum ada, ambil pertama dan tandai `enodebExact`.
6. Pindahkan logika pencocokan ke kelas murni `ServingTowerMatcher` agar bisa di-unit-test tanpa Riverpod.

Test (tanpa Android): LTE ECI 0x0A1B2C03 → eNodeB 0x0A1B2C → cocok; NR tidak pernah `enodebExact`; hilangnya sinyal mengosongkan `matchedServingTower`; dua tower ber-eNodeB sama memilih yang terdekat; jarak > 15 km → `nearestEstimate`.

## FASE 7 — AccessGate: keamanan dan stabilitas
File: `lib/auth/widgets/access_gate.dart`, `lib/auth/providers/auth_providers.dart`, `lib/auth/supabase_client.dart`.

1. **Bypass hanya di debug.** Saat ini jika kredensial kosong atau `Supabase.initialize` gagal, gate menyetel `approved` untuk semua orang. Ubah: bypass hanya bila `kDebugMode`. Di release, tampilkan layar "Konfigurasi aplikasi belum lengkap, hubungi admin" (tanpa akses ke `child`).
2. **Jangan membongkar layar saat refresh token.** Setiap event `onAuthStateChange` (termasuk `tokenRefreshed`, sekitar tiap 1 jam) memanggil `_checkAccess`, yang menyetel `checkingAccess` dan membuang `MainNavigation`. Perbaikan: di `_checkAccess`, bila state saat ini sudah `approved`, **jangan** setel `checkingAccess`; lakukan cek di latar belakang dan hanya ganti state bila hasilnya berubah. Abaikan event `tokenRefreshed`/`userUpdated` untuk pengecekan layar kecuali status server berubah.
3. **Hindari dua pemanggilan beruntun saat startup** (`onAuthStateChange` awal + `checkAccess` manual): buat satu jalur saja.
4. Kegagalan koneksi **tidak boleh** memanggil `signOut()` (sudah benar, pertahankan). Masa tenggang offline 7 hari dipertahankan.
5. Test: widget test `AccessGate` — (a) release tanpa config → layar konfigurasi, (b) state approved + event token refresh → `child` tidak ter-rebuild/dispose (pakai `GlobalKey`/counter `initState`).

## FASE 8 (BERIKUTNYA, jangan dikerjakan sebelum konfirmasi) — Ganti kode bersama menjadi Sales Code per orang
Manajemen meminta Sales Code unik per sales. Implementasi saat ini masih memakai `redeem_access_code` (satu kode tim). Spesifikasi lengkap ada di `BRIEF_TEAM_LOGIN_AGY.md` (versi Sales Code) — gunakan RPC `claim_sales_code`, daftar `sales_codes`, dan jalankan SQL pembersihan 4.0 + skema 4.1 di Supabase terlebih dahulu. **Tunggu konfirmasi dari pemilik** (butuh daftar Sales Code resmi dan status SQL lama).

---

## Jangan diubah (sudah diverifikasi benar)
Tarif Product Mix FTTH/FWA/PXGY; tier dan lump sum OJT (325k/600k); tier progresif dan nilai multiplier Pro/Elite; survival DSA (M3 100k gate 90%, M5 80k gate 80%); tier Quarterly DSA/SPV beserta tambahan 10k/30k; seluruh rumus SPV (Product Mix, Participation, KPI multiplier, Survival 25k+2jt, Graduation, Monthly Performance).

## Pertanyaan terbuka (jangan diputuskan sendiri, catat sebagai TODO)
- SPV dengan MoB ≤ 3: Excel menghitung hanya Basic + Product Mix + Graduation, sedangkan app juga menambah Survival, Monthly Performance, dan Quarterly. Tunggu konfirmasi tim Channel; sementara **jangan ubah**.
- Basic Fee Cilacap (OJT 1.900.000, Pro 2.600.000, Elite 2.773.184, SPV 4.500.000) berbeda dari Excel Greater YK City; tidak diubah.

## Hasil yang diharapkan
Ringkasan per fase: file yang diubah, hasil `flutter analyze`, hasil `flutter test` (jumlah test lulus), dan daftar test lama yang diubah beserta alasannya.
