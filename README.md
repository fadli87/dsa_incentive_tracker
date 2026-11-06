# DSA XL Satu Handbook & Incentive Tracker

Aplikasi komprehensif untuk Direct Sales Agency (DSA) XL Satu — mencakup kalkulator simulasi skema insentif terbaru (September 2026), pemetaan GIS coverage & BTS Tower, AURA AI Coach & RF Diagnostic, pencatatan SA lokal, serta gerbang akses tim (*Team Access Gate*) berbasis Supabase.

---

## 🚀 Fitur Utama

1. **Simulasi Skema Insentif September 2026**:
   - Skema DSA: OJT, Pro, dan Elite (Basic Fee, Tier Progresif SA, Multiplier, Survival Rate M3/M5, Quarterly Bonus, Net Add Incentive).
   - Skema SPV: Basic Fee, Multiplier Tim, MoB Support <= 3 bulan, dan Quarterly Bonus Tim.
2. **Peta GIS Coverage & BTS Tower**:
   - 24 distrik pemetaan Kabupaten Cilacap & Banyumas.
   - Deteksi Homepass 3 warna (Ungu: FTTH, Hijau: FWA Indoor/Outdoor, Orange: FWA Outdoor).
   - Perhitungan jarak tower BTS terdekat & parsir koordinat WhatsApp Shareloc / Google Maps.
3. **AURA AI Coach & Diagnostik Jaringan**:
   - RF Diagnostic & eNodeB / Cell ID separator.
   - Panduan pitching & objection handling penjualan XL Satu.
4. **Aktivitas Harian Visit (RVAI / Dismantle / Unpaid)**:
   - Pencatatan target kunjungan harian (**RVAI** hijau, **Dismantle** merah, **Unpaid** kuning) 100% *offline-first* (SQLite v7) dengan sinkronisasi otomatis ke Supabase saat terhubung internet.
   - Input titik koordinat via GPS saat ini, tempel tautan Google Maps / Shareloc WhatsApp, atau input manual.
   - Peta Visit 3 Layer (`flutter_map`), navigasi 1-tap ke Google Maps, prefill otomatis Google Form pelaporan, serta **Ekspor CSV per kategori** untuk Google My Maps.
   - Layar **Rekap Tim (Read-Only)** khusus untuk role **SPV**, **TSC**, **Admin**, dan **Superadmin**.
5. **Offline-First & Keamanan Data**:
   - Penyimpanan data SA & Visit lokal di perangkat (tanpa menyimpan nomor seri perangkat/ONT/SIM maupun NIK/KTP demi privasi pelanggan).
   - Akses tim berbasis Supabase dengan masa tenggang offline (*grace period*) 7 hari.

---

## 👥 Matriks Role & Hak Akses Tim

| Role | Nilai DB | Kelola Visit Sendiri | Lihat Rekap Visit Seluruh Tim (`Rekap Tim`) | Ubah / Hapus Visit Sales Lain | Akses Panel SuperAdmin | Ubah Role Anggota Tim |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **Sales** | `member` | Ya | Tidak | Tidak | Tidak | Tidak |
| **Supervisor** | `spv` | Ya | **Ya (Read-Only)** | Tidak | Tidak | Tidak |
| **TSC** | `tsc` | Ya | **Ya (Read-Only)** | Tidak | Tidak | Tidak |
| **Admin** | `admin` | Ya | **Ya (Read-Only)** | Tidak | Ya (Approve/Revoke) | Tidak |
| **Superadmin** | `superadmin` | Ya | **Ya (Read-Only)** | Tidak | Ya (Penuh) | **Ya** (`member`/`spv`/`tsc`) |

### SOP Promosi Role SPV / TSC Lewat Panel SuperAdmin
1. Login ke aplikasi menggunakan akun ber-role **Superadmin**.
2. Buka **Info Pengguna** (ketuk avatar profil di pojok kanan atas Dashboard) ➔ pilih **Panel Kontrol Superadmin**.
3. Pastikan anggota yang ingin dipromosikan sudah berstatus **Aktif (Approved)**.
4. Pada kartu anggota tersebut, ketuk tombol menu **`Ubah Role`** lalu pilih **`Jadikan SPV`**, **`Jadikan TSC`**, atau **`Jadikan Sales (Member)`**.
5. Saat perangkat SPV/TSC tersebut melakukan verifikasi akses online berikutnya, kartu menu **Rekap Tim** akan otomatis muncul di Dashboard mereka.

---

## 📝 Konfigurasi Integrasi Google Form Visit (`--dart-define` / `.env`)

Tombol **Isi Google Form** pada detail Aktivitas Harian membaca tiga variabel environment saat build (`--dart-define` atau `--dart-define-from-file=.env`):

```dotenv
VISIT_FORM_URL=https://docs.google.com/forms/d/e/<FORM_ID>/viewform
VISIT_FORM_CUSTOMER_ENTRY=entry.<ID_PERTANYAAN_CUSTOMER_ID>
VISIT_FORM_CATEGORY_ENTRY=entry.<ID_PERTANYAAN_KATEGORI>
```

- Bila `VISIT_FORM_URL` dikosongkan, tombol Google Form otomatis tampil nonaktif beserta penjelasannya (aplikasi tetap berfungsi normal).
- Saat dikonfigurasi, aplikasi membuka URL prefill dengan format:
  `<VISIT_FORM_URL>?usp=pp_url&<CUSTOMER_ENTRY>=<customer_id>&<CATEGORY_ENTRY>=<label>`
  di mana label kategori dikirim secara presisi: `VISIT RVAI`, `DISMANTLE`, atau `UNPAID`.

### Cara Mengambil ID `entry.xxxx` dari Google Form
1. Buka Google Form di mode editor (Google Forms ➔ klik ikon titik tiga **⋮** di kanan atas ➔ pilih **Dapatkan link yang sudah terisi / Get pre-filled link**).
2. Isi contoh nilai pada kolom **Customer ID** (misal `12345`) dan pilih salah satu opsi pada pertanyaan **Kategori**, lalu klik **Dapatkan link / Get link** ➔ **Salin link**.
3. Tempel link yang disalin ke teks editor; perhatikan parameter query seperti `...&entry.111111=12345&entry.222222=VISIT+RVAI`.
4. Masukkan `entry.111111` ke `VISIT_FORM_CUSTOMER_ENTRY` dan `entry.222222` ke `VISIT_FORM_CATEGORY_ENTRY` pada file `.env` lokal atau GitHub Actions Repository Variables (`vars`). *(Jangan pernah meng-commit nilai URL/entry asli ke dalam repositori publik).*

---

## 🔐 Sistem Login Tim & Gerbang Akses (*Team Access Gate*)

Aplikasi menggunakan pola **Access Gate** dengan Supabase backend dan enkripsi lokal `flutter_secure_storage`.
- **Daftar/Masuk Mandiri**: Sales mendaftar akun menggunakan email, password, dan memasukkan **Kode Akses Tim**.
- **Mode Offline 7 Hari**: Sales yang sudah disetujui (*approved*) dapat bekerja di lapangan tanpa koneksi internet hingga 7 hari berturut-turut.
- **Perlindungan Sesi**: Kegagalan koneksi offline tidak pernah membatalkan sesi login user (*anti-auto-signout*).
- **Superadmin pertama**: akun pertama yang mendaftar di database kosong otomatis menjadi `superadmin` dan langsung `approved`.

> **Sales Code** di halaman Info Pengguna hanya label profil untuk ditampilkan di kalkulator dan dashboard. Sales Code tidak dipakai untuk login maupun persetujuan akses.

---

## 📋 SOP Pengelolaan Anggota Tim (Untuk Superadmin)

Anggota dan kode akses tim dikelola langsung dari **Panel SuperAdmin** di dalam aplikasi (Info Pengguna ➔ Panel Kontrol Superadmin), tanpa perlu membuka Supabase Dashboard.

- **Tab Anggota Tim**: cari nama/email, filter status (Semua, Menunggu, Disetujui, Dicabut), lalu **Setujui**, **Cabut Akses**, atau **Pulihkan Akses**. Ubah role lewat menu **Ubah Role** (lihat SOP di atas).
- **Tab Kode Akses Tim**: ubah kode akses tim (minimal 6 karakter). Kode disimpan sebagai hash bcrypt di tabel `app_config`.

### Prosedur Saat Sales Keluar / Berhenti
Karena kode akses tim dipakai bersama oleh seluruh sales aktif, lakukan **2 langkah wajib** berikut:

1. **Cabut akses akun**: Panel SuperAdmin ➔ tab **Anggota Tim** ➔ cari sales ➔ **Cabut Akses**. Saat perangkat sales terhubung internet, aplikasi menampilkan layar **Akses Dicabut**, dan akun tidak bisa masuk lagi meskipun mendaftar ulang dengan kode yang sama.
2. **Ganti kode akses tim**: tab **Kode Akses Tim** ➔ simpan kode baru, lalu bagikan hanya kepada anggota aktif yang tersisa.

### Menjadikan Akun Tertentu Superadmin
Untuk akun yang sudah terdaftar, jalankan di Supabase SQL Editor (fungsi ini sengaja tidak bisa dipanggil dari aplikasi):

```sql
select public.make_superadmin('email_anda@gmail.com');
```

---

## 🛠️ Panduan Setup Supabase Backend

1. **Jalankan Skema Database**:
   - **Project baru**: buka SQL Editor di project Supabase Anda, lalu salin dan jalankan seluruh isi file [`supabase/schema.sql`](supabase/schema.sql). File ini sudah memuat semua perbaikan.
   - **Project yang sudah berjalan**: jalankan file di [`supabase/migrations/`](supabase/migrations) **berurutan**: `2026-11-06_phase0_harden_make_superadmin.sql`, `2026-11-06_visit_activities.sql`, lalu `2026-11-06_phase1_fix_rpc_security.sql`. Sebelumnya, pastikan constraint role lama bernama `team_members_role_check` (`select conname from pg_constraint where conrelid = 'public.team_members'::regclass;`), kalau tidak, role `spv`/`tsc` masih ditolak.
   - Skema membuat tabel `team_members`, `app_config`, dan `visit_activities`, trigger pendaftaran akun, fungsi `is_superadmin`, `can_view_all`, `is_approved_member`, serta RPC `redeem_access_code`, `admin_update_member_status`, `admin_update_member_role`, `admin_update_access_code`, `get_visit_summary`, dan `make_superadmin`.

2. **Atur Kode Akses Tim Awal**:
   Jalankan query di SQL Editor Supabase:
   ```sql
   insert into public.app_config (key, value)
   values ('access_code_hash', crypt('KODE-AKSES-TIM-ANDA', gen_salt('bf')))
   on conflict (key) do update 
   set value = crypt('KODE-AKSES-TIM-ANDA', gen_salt('bf'));
   ```

3. **Nonaktifkan Konfirmasi Email** (Sesuai Konfirmasi):
   - Masuk ke **Authentication** ➔ **Providers** ➔ **Email**.
   - Matikan pilihan *Confirm email* agar pendaftar baru bisa langsung login dan beraktivitas seketika.

4. **Koneksikan ke Aplikasi**:
   Kredensial tidak ditulis di kode ([`lib/core/config/supabase_config.dart`](lib/core/config/supabase_config.dart) hanya membacanya dari `--dart-define`). Salin [`.env.example`](.env.example) menjadi `.env` (sudah di `.gitignore`), isi nilainya, lalu jalankan:
   ```bash
   flutter run --dart-define-from-file=.env
   ```
   atau langsung:
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=ey...
   ```
   Untuk build rilis lewat GitHub Actions, isi `SUPABASE_URL` dan `SUPABASE_ANON_KEY` sebagai secret, serta variabel `VISIT_FORM_*` di bagian Google Form di atas.

---

## 🧪 Menjalankan Pengujian Otomatis (*Automated Tests*)

Logika bisnis, kalkulasi insentif, peta coverage, AI Coach, autentikasi, dan fitur Aktivitas Harian Visit dicakup oleh test suite di folder [`test/`](test):

```bash
# Menjalankan static analysis
flutter analyze

# Menjalankan seluruh test suite
flutter test
```
