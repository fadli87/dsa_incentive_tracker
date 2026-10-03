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
4. **Offline-First & Keamanan Data**:
   - Penyimpanan data SA 100% lokal terenkripsi di perangkat (tanpa KTP demi privasi).
   - Akses tim berbasis Supabase dengan masa tenggang offline (*grace period*) 7 hari.

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
