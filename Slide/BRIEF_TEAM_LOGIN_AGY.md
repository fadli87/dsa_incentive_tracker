# BRIEF UNTUK AGY — Team Login / Access Gate (Supabase, dengan Kode Akses)

Repo: `dsa_incentive_tracker`. Fitur baru: gerbang login supaya hanya anggota tim yang punya **kode akses** yang bisa membuka app. **Scope: hanya akses masuk.** Data (kalkulator, history, Data SA) tetap 100% lokal di SQLite seperti sekarang — fitur ini tidak mengubah penyimpanan data sama sekali.

## 0. Cara kerja
1. **Fase 0 — Rencana dulu.** Balas dengan daftar file yang dibuat/diubah, signature class publik, dan pertanyaan yang belum jelas (termasuk proyek Supabase mana yang dipakai — lihat bagian 1). Tunggu review.
2. Satu fase = satu commit. `flutter analyze` dan `flutter test` sebelum lapor selesai.

## 1. Alur approval (revisi): kode akses, bukan approve manual per user
- User daftar (email, password, nama, **kode akses tim**) → kalau kode benar, **langsung approved otomatis**, tanpa owner harus buka dashboard.
- Owner tetap bisa **revoke manual** lewat Supabase Dashboard saat ada sales yang keluar.
- **Trade-off yang harus dipahami user (sudah dikonfirmasi):** kode akses dipakai bersama oleh semua anggota. Kalau satu orang keluar dan direvoke tapi masih tahu kodenya, dia bisa daftar ulang pakai email baru + kode yang sama dan otomatis approved lagi. Supaya revoke efektif, SOP saat ada yang keluar harus **dua langkah**:
  1. Revoke `user_id` orang itu (lihat bagian 3) — ini memblokir akun lamanya.
  2. **Putar/ganti kode akses** (update satu baris di tabel `app_config`), lalu sebarkan kode baru ke anggota yang masih aktif.
- Tulis SOP dua langkah ini di README atau komentar kode, supaya tidak terlupa di kemudian hari.

## 2. Keputusan yang perlu dikonfirmasi dulu ke user (jangan ditebak)
- Proyek Supabase: pakai salah satu proyek yang sudah ada milik user atau buat proyek baru khusus app ini? (Perlu URL + anon key.)
- Nilai masa tenggang offline (default usulan: **7 hari**). Lihat bagian 5.
- Kode akses awal: minta user menentukan nilainya sendiri (jangan dibuatkan oleh Agy), supaya hanya user yang tahu.
- Apakah perlu verifikasi email saat daftar (default Supabase: ya, email confirmation aktif).

## 3. Aturan keras
- **Tidak mengubah apa pun di penyimpanan lokal yang sudah ada** (`DatabaseHelper`, `IncentiveRecord`, `UserProfile`, dll). Fitur ini murni lapisan di depan `MainNavigation`.
- **Tidak ada layar admin approve di dalam app.** Revoke dilakukan owner lewat Supabase Table Editor/SQL Editor (lihat skema bagian 4). Rotasi kode akses juga lewat SQL Editor. Jangan membangun fitur admin di app.
- **Kode akses tidak boleh bisa dibaca langsung oleh client.** Disimpan ter-hash (bcrypt via `pgcrypto`) di tabel yang tidak punya policy SELECT sama sekali untuk role `authenticated`/`anon`. Verifikasi hanya lewat RPC `security definer` (bagian 4) — jangan taruh perbandingan kode di kode Dart atau di tabel yang bisa dibaca client.
- **Client tidak boleh bisa langsung meng-UPDATE kolom `status` dirinya sendiri.** Satu-satunya jalan status berubah dari `pending`→`approved` adalah lewat RPC `redeem_access_code`. INSERT awal hanya lewat trigger `security definer`.
- **App harus tetap bisa dipakai offline** untuk fungsi inti (kalkulator, dsb) selama masih dalam masa tenggang akses. Jangan menambah syarat online di luar proses login/verifikasi gate ini.
- Tidak menyimpan password di local storage. Sesi ditangani oleh `supabase_flutter` sendiri (sudah persist otomatis).
- **Jangan pernah memanggil `signOut()` secara otomatis hanya karena pengecekan ke Supabase gagal/timeout (offline).** `signOut()` hanya dipanggil kalau: (a) status dari server eksplisit `revoked`, atau (b) user menekan tombol "Keluar" sendiri. Kegagalan jaringan harus jatuh ke jalur cache lokal di `resolveAccess`, bukan ke logout. Ini mencegah sales kehilangan akses hanya karena tidak ada sinyal.
- **Login ulang (tab "Masuk") TIDAK PERNAH meminta kode akses.** Kode akses hanya dipakai sekali saat pendaftaran pertama (`redeem_access_code`). Kalau sesi hilang karena app di-uninstall, cache dibersihkan, atau ganti HP, user cukup login ulang dengan email+password yang sama — statusnya sudah tersimpan di server (`team_members.status`), bukan di HP. Pemulihan ini **butuh koneksi internet saat itu juga**; kalau user offline total saat sesinya hilang, dia harus menunggu sinyal dulu sebelum bisa login ulang — ini batas yang wajar dan harus disampaikan ke user, bukan sesuatu yang perlu "diakali".

## 4. Supabase — schema, hash kode akses, & RPC

```sql
create extension if not exists pgcrypto;

create table public.team_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  name text,
  status text not null default 'pending' check (status in ('pending','approved','revoked')),
  created_at timestamptz not null default now(),
  approved_at timestamptz
);

alter table public.team_members enable row level security;

create policy "select own row" on public.team_members
  for select using (auth.uid() = user_id);
-- SENGAJA tidak ada policy insert/update/delete untuk role 'authenticated'.
-- Dengan RLS aktif dan tanpa policy tsb, operasi itu otomatis ditolak untuk client.

create or replace function public.handle_new_team_member()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.team_members (user_id, email) values (new.id, new.email);
  return new;
end; $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_team_member();

-- Tabel kode akses: TIDAK ADA policy sama sekali -> tidak bisa dibaca/ditulis client sama sekali,
-- hanya bisa diisi/diubah owner lewat SQL Editor (pakai role postgres, bukan anon/authenticated).
create table public.app_config (
  key text primary key,
  value text not null
);
alter table public.app_config enable row level security;
-- Owner mengisi baris awal lewat SQL Editor, MISALNYA (ganti 'KODE-RAHASIA-TIM' dengan kode pilihan user):
-- insert into app_config (key, value) values ('access_code_hash', crypt('KODE-RAHASIA-TIM', gen_salt('bf')));
-- Untuk rotasi kode nanti, jalankan UPDATE dengan kode baru:
-- update app_config set value = crypt('KODE-BARU', gen_salt('bf')) where key = 'access_code_hash';

create or replace function public.redeem_access_code(input_code text)
returns text  -- 'approved' | 'invalid_code' | 'not_authenticated' | 'already_revoked' | 'config_missing'
language plpgsql
security definer
set search_path = public
as $$
declare
  stored_hash text;
  uid uuid := auth.uid();
  current_status text;
begin
  if uid is null then
    return 'not_authenticated';
  end if;

  select value into stored_hash from app_config where key = 'access_code_hash';
  if stored_hash is null then
    return 'config_missing';
  end if;

  if crypt(input_code, stored_hash) <> stored_hash then
    return 'invalid_code';
  end if;

  select status into current_status from team_members where user_id = uid;
  if current_status = 'revoked' then
    return 'already_revoked'; -- jangan pernah timpa status revoked meski kode benar
  end if;

  update team_members set status = 'approved', approved_at = now() where user_id = uid;
  return 'approved';
end;
$$;

grant execute on function public.redeem_access_code(text) to authenticated;
```

**Cara owner revoke** (saat sales keluar): Table Editor → `team_members` → ubah `status` baris user jadi `revoked`. **Cara owner rotate kode**: jalankan `update app_config ...` di atas dengan kode baru, lalu sebarkan manual ke anggota aktif (WA/dsb — di luar scope app).

## 5. Struktur baru di `lib/`

```
lib/auth/
  supabase_client.dart         # init Supabase.initialize(...), expose SupabaseClient
  models/
    member_status.dart         # enum MemberStatus { pending, approved, revoked, unknown }
    access_cache.dart          # model: status, checkedAt, validUntil
  services/
    team_access_service.dart   # cek status ke Supabase + baca/tulis cache lokal + redeem kode
  providers/
    auth_providers.dart        # authStateProvider, accessGateProvider (Riverpod)
  screens/
    login_screen.dart          # form email+password, tombol daftar/masuk, lupa password
    access_code_screen.dart    # input kode akses (dipakai saat daftar, dan sebagai retry kalau kode sempat salah)
    change_password_screen.dart # ubah password (perlu login + re-auth password lama)
    access_revoked_screen.dart
    offline_verification_required_screen.dart
  widgets/
    access_gate.dart           # widget pembungkus: root app memanggil AccessGate(child: MainNavigation())
```

### 5.1 `TeamAccessService` (inti logic)
```dart
class AccessCache {
  final MemberStatus status;
  final DateTime checkedAt;
  final DateTime validUntil; // checkedAt + grace period, hanya relevan utk status approved
}

class TeamAccessService {
  static const graceDuration = Duration(days: 7); // KONSTANTA BERNAMA, bukan literal tersebar

  /// Dipanggil saat app start & saat resume dari background (kalau >1 jam sejak cek terakhir).
  Future<AccessCache> resolveAccess(String userId) async {
    // 1. Coba query Supabase team_members by user_id, dengan timeout singkat (mis. 6 detik).
    // 2. Kalau berhasil: simpan cache baru (status, checkedAt=now, validUntil=now+graceDuration
    //    HANYA jika status == approved), tulis ke secure storage, return cache ini.
    // 3. Kalau gagal/timeout (offline): baca cache lokal.
    //    - Tidak ada cache sama sekali -> return status unknown (anggap belum pernah approved -> block).
    //    - Cache ada & status terakhir approved & now <= validUntil -> return cache apa adanya (tetap approved).
    //    - Cache ada tapi now > validUntil -> return status unknown dengan flag "butuh online".
  }

  /// Dipanggil dari AccessCodeScreen.
  Future<String> redeemAccessCode(String code) async {
    // panggil supabase.rpc('redeem_access_code', params: {'input_code': code})
    // kalau hasil 'approved' -> panggil resolveAccess ulang supaya cache ikut terupdate, lalu return hasilnya
  }
}
```
- Simpan cache dengan `flutter_secure_storage` (tambahkan dependency ini; belum ada di `pubspec.yaml`).
- **Jangan percaya status `approved` dari cache tanpa batas waktu** — itulah fungsi `validUntil`. Status `revoked` dari hasil online terakhir juga disimpan supaya kalau app dibuka ulang offline setelah revoke diketahui, tetap diblokir (tidak "reset" ke unknown).

### 5.2 `AccessGate` widget
- Bungkus root widget (`MaterialApp.home` atau sejenis — cek struktur `main.dart` saat ini sebelum mengubah).
- State machine: `loading → noSession (ke LoginScreen) → checkingAccess → approved (render child/MainNavigation) → needsAccessCode (AccessCodeScreen, untuk status pending) → revoked (AccessRevokedScreen, tombol logout) → needsOnlineVerification (OfflineVerificationRequiredScreen, tombol retry & logout)`.
- Logout: `supabase.auth.signOut()` + hapus cache lokal di `flutter_secure_storage`.

### 5.3 `LoginScreen` & `AccessCodeScreen`
- Tab/toggle Masuk / Daftar.
- Daftar: email, password, nama, **kode akses** (satu form, langsung submit semuanya). Setelah `signUp()` sukses (status pending otomatis dari trigger), langsung panggil `redeemAccessCode`.
  - Hasil `approved` → langsung masuk app.
  - Hasil `invalid_code` → tetap di layar yang sama (jangan logout), tampilkan pesan "Kode akses salah, hubungi admin tim" + tombol coba lagi (tanpa perlu daftar ulang — akun sudah dibuat, tinggal redeem ulang).
  - Hasil `already_revoked` → ke `AccessRevokedScreen` (kasus langka: akun lama yang di-revoke mendaftar ulang dengan email sama — biasanya tidak mungkin karena email sudah terpakai, tapi tetap ditangani).
- `AccessCodeScreen` dipakai juga sebagai layar retry kalau user menutup app sebelum berhasil redeem (status masih pending saat `resolveAccess` dipanggil ulang).
- **Lupa password (Fase 1, scope MVP): TIDAK dibangun self-service di app.** Kalau user lupa password, alurnya: hubungi owner → owner reset manual lewat Supabase Dashboard (Authentication → Users → "Send password recovery" atau set password baru langsung). Tidak perlu kode/dependency tambahan untuk ini. (Self-service reset via email deep link butuh dependency `app_links`/`uni_links` + konfigurasi Android/iOS — ini di luar cakupan sekarang, lihat bagian "Di luar cakupan".)
- Validasi email format & password minimal 6 karakter (minimum Supabase).

### 5.3b `ChangePasswordScreen` (menu/pengaturan, hanya untuk user yang sudah login)
- Form: password lama, password baru, konfirmasi password baru.
- **Wajib re-autentikasi dulu** sebelum mengubah: panggil `supabase.auth.signInWithPassword(email, oldPassword)` untuk verifikasi password lama benar (mencegah orang lain mengganti password hanya karena menemukan HP dalam keadaan masih login).
- Kalau verifikasi sukses → `supabase.auth.updateUser(UserAttributes(password: newPassword))`.
- Tidak perlu dependency baru, tidak perlu deep link.

### 5.4 Layar status
- `AccessCodeScreen`: input kode akses, tombol submit, pesan error kalau salah.
- `AccessRevokedScreen`: pesan akses dicabut, tombol "Keluar".
- `OfflineVerificationRequiredScreen`: pesan perlu koneksi internet untuk verifikasi ulang (masa tenggang habis), tombol "Coba Lagi" dan "Keluar".

## 6. Perubahan `pubspec.yaml`
Tambahkan: `supabase_flutter`, `flutter_secure_storage`. **Jangan tambah dependency lain** tanpa melapor dulu.

## 7. Android/iOS
- Pastikan `INTERNET` permission ada di `AndroidManifest.xml` (laporkan kalau belum ada, lalu tambahkan).
- `flutter_secure_storage` butuh `minSdkVersion` tertentu — cek dan laporkan kalau perlu dinaikkan (`flutter_launcher_icons` config punya `min_sdk_android: 21` — verifikasi apakah ini cukup).

## 8. Test wajib
- `test/auth/team_access_service_test.dart`: mock Supabase client/response untuk kasus — approved online, pending online, revoked online, offline dengan cache valid, offline dengan cache kedaluwarsa, offline tanpa cache sama sekali, online tapi timeout, redeem kode benar, redeem kode salah, redeem pada akun revoked.
- `test/auth/access_gate_widget_test.dart`: tiap state machine merender layar yang benar.
- Pastikan tidak ada test yang benar-benar memanggil Supabase asli (pakai fake/mock client).
- **Test regresi khusus:** pastikan tidak ada pemanggilan `signOut()` di jalur manapun selain status `revoked` eksplisit dan aksi tombol "Keluar" — misalnya dengan mock yang melempar exception/timeout pada query status, lalu assert `signOut` tidak pernah terpanggil dan cache lokal (kalau masih valid) tetap dipakai.

## 9. Definition of Done
- [ ] User baru dengan kode akses benar bisa langsung masuk app tanpa menunggu owner.
- [ ] User dengan kode akses salah tetap di `AccessCodeScreen` dengan pesan jelas, bisa coba lagi tanpa daftar ulang.
- [ ] Setelah owner mengubah status ke `revoked` di Dashboard, user yang online langsung terblokir; user yang offline tetap terblokir maksimal `graceDuration` setelah pengecekan online terakhir.
- [ ] Akun yang sudah `revoked` tidak bisa kembali `approved` lewat `redeem_access_code` meski kodenya benar.
- [ ] Kode akses tidak pernah terbaca langsung oleh client (tidak ada cara query `app_config` dari app, tidak ada kode tertulis di Dart).
- [ ] Semua fitur inti app (kalkulator, history, Data SA, AI Coach, dll) tidak berubah perilakunya sama sekali, hanya dibungkus `AccessGate`.
- [ ] `flutter analyze` bersih, semua test hijau.
- [ ] Tidak ada API key/password tertulis di kode (anon key Supabase boleh ada di kode sesuai praktik umum `supabase_flutter`, tapi **service role key tidak boleh pernah masuk ke app**).
- [ ] SOP "revoke + rotate kode saat sales keluar" tertulis di README.
- [ ] Kalau sesi hilang dari HP (uninstall/clear data/ganti HP), user yang statusnya masih `approved` di server bisa pulih hanya dengan email+password (tanpa kode akses) selama online saat itu.
- [ ] Kegagalan jaringan/offline tidak pernah memicu `signOut()` otomatis — dibuktikan oleh test regresi di bagian 8.
- [ ] User yang sudah login bisa ubah password sendiri lewat `ChangePasswordScreen`, dengan re-autentikasi password lama sebagai syarat.

## 10. Di luar cakupan (jangan dikerjakan sekarang)
- Pemisahan data per tim/branch.
- Config berbeda (skema insentif/katalog) per tim.
- Layar admin approve/rotate di dalam app (semua lewat Supabase Dashboard).
- Role-based permission selain approved/pending/revoked.
- Rate-limiting percobaan kode salah (opsional, bisa menyusul kalau diperlukan).
- Lupa password self-service di dalam app (reset via email deep link). Untuk sekarang, lupa password ditangani manual oleh owner lewat Supabase Dashboard.
