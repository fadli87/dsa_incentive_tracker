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

---

## 📋 SOP Pengelolaan Anggota Tim (Untuk Admin / Supervisor)

Semua pengelolaan anggota dan kode akses tim dilakukan melalui **Supabase Dashboard** tanpa perlu modifikasi kode aplikasi:

### 1. Prosedur Saat Sales Keluar / Berhenti
Karena kode akses tim dipakai bersama oleh seluruh sales aktif, lakukan **2 langkah wajib** berikut saat ada sales yang berhenti:

- **Langkah 1: Cabut Akses Akun (Revoke)**
  1. Buka **Supabase Dashboard** ➔ **Table Editor** ➔ Tabel `team_members`.
  2. Cari baris sales yang bersangkutan, ubah nilai kolom `status` dari `approved` menjadi `revoked`.
  3. Akun tersebut langsung diblokir di server. Ketika perangkat sales terhubung internet, aplikasi akan menampilkan layar **Akses Dicabut**. Akun tidak akan bisa masuk lagi meskipun mendaftar ulang dengan kode yang sama.

- **Langkah 2: Rotasi Kode Akses Tim (Rotate)**
  1. Buka **Supabase Dashboard** ➔ **SQL Editor**.
  2. Jalankan query berikut untuk memperbarui kode akses tim baru:
     ```sql
     update public.app_config 
     set value = crypt('KODE-BARU-ANDA', gen_salt('bf')) 
     where key = 'access_code_hash';
     ```
  3. Bagikan kode akses baru hanya kepada anggota tim aktif yang tersisa.

---

## 🛠️ Panduan Setup Supabase Backend

1. **Jalankan Skema Database**:
   - Buka SQL Editor di project Supabase Anda.
   - Salin dan jalankan seluruh isi file [`supabase/schema.sql`](file:///l:/dev_app/dsa_incentive_tracker/supabase/schema.sql).
   - Skema ini membuat tabel `team_members`, `app_config`, trigger pendaftaran akun, dan RPC security definer `redeem_access_code`.

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
   Isi URL & Anon Key di [`lib/core/config/supabase_config.dart`](file:///l:/dev_app/dsa_incentive_tracker/lib/core/config/supabase_config.dart), atau lewat `--dart-define`:
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=ey...
   ```

---

## 🧪 Menjalankan Pengujian Otomatis (*Automated Tests*)

Seluruh logika bisnis, kalkulasi insentif, dan autentikasi dilindungi oleh automated test suite lengkap:

```bash
# Menjalankan static analysis
flutter analyze

# Menjalankan seluruh test suite (45 tests)
flutter test
```
