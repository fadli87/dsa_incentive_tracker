# Panduan Integrasi Google Form ➔ Supabase (`visit_form_to_supabase.gs`)

Skrip Google Apps Script di [`visit_form_to_supabase.gs`](visit_form_to_supabase.gs) mengirimkan setiap jawaban Google Form pelaporan visit secara *real-time* ke Supabase Edge Function (`visit-form-webhook`) menggunakan trigger **`On form submit`**.

---

## ⚠️ Peringatan Keamanan: Pengumpulan Email "Terverifikasi"

Agar pencocokan akun sales (`responder_email` ➔ `team_members.email` / `form_email`) tidak dapat dipalsukan:
1. Buka Google Form pelaporan visit di mode Editor.
2. Masuk ke tab **Setelan (Settings)** ➔ **Respons (Responses)**.
3. Pada bagian **Kumpulkan alamat email (Collect email addresses)**, pastikan dipilih **`Terverifikasi` (`Verified`)**, **BUKAN** *"Input responden" ("Responder input")*.
   - Dengan opsi *Input responden*, siapa saja dapat mengetik email rekan sales lain dan menandai visit orang lain sebagai selesai.
   - Jika Anda menggunakan skrip generator Google Form milik manajemen, pastikan memanggil:
     ```javascript
     form.setEmailCollectionType(FormApp.EmailCollectionType.VERIFIED);
     ```

---

## Daftar Judul Pertanyaan Google Form (Harus Sama Persis)

Skrip membaca jawaban berdasarkan judul pertanyaan (`item.getTitle()`). Pastikan ke-14 judul berikut sama persis di Google Form Anda:
1. `Tanggal Visit`
2. `Nama Sales`
3. `Nama SPV`
4. `TSC`
5. `Customer ID`
6. `Kategori Visit` (pilihan: `VISIT RVAI`, `DISMANTLE`, `UNPAID`)
7. `Status Visit`
8. `Hasil Kunjungan`
9. `Kendala Utama (jika ada)`
10. `Catatan / Detail Kunjungan`
11. `Koordinat Lokasi Visit (opsional)`
12. `Tindak Lanjut`
13. `Tanggal Tindak Lanjut (jika ada)`
14. `Foto Bukti Visit` *(pertanyaan Upload File)*

---

## Langkah Pemasangan oleh Owner

1. Buka [script.google.com](https://script.google.com) (atau dari Google Form klik menu titik tiga **⋮** ➔ **Editor skrip / Script editor**).
2. Salin seluruh isi [`visit_form_to_supabase.gs`](visit_form_to_supabase.gs) ke editor.
3. Buka menu **Setelan Proyek (Project Settings ⚙)** di bilah kiri ➔ gulir ke bagian **Properti Skrip (Script Properties)**, lalu tambahkan 3 properti berikut:
   - `FORM_ID` : ID Google Form dari URL editor (`/forms/d/<FORM_ID>/edit`)
   - `WEBHOOK_URL` : `https://<PROJECT_REF>.supabase.co/functions/v1/visit-form-webhook`
   - `WEBHOOK_SECRET` : Nilai secret yang sama persis dengan `VISIT_FORM_WEBHOOK_SECRET` di Supabase Secrets.
4. Kembali ke menu **Editor (`< >`)**, pilih fungsi **`installTrigger`** pada dropdown di bagian atas, lalu klik **Jalankan (Run)** sekali dan setujui izin akses (*Review permissions*).
5. **Uji Coba**:
   - Isi 1 respons pada Google Form (atau jalankan fungsi **`sendLatestAsTest`** di Apps Script).
   - Periksa tabel `public.visit_form_responses` di Supabase.
6. **Sinkronisasi Ulang Jawaban Lama (Opsional)**:
   - Jalankan fungsi **`resyncAll`**. Fungsi ini idempoten (aman dijalankan berulang kali karena memakai `response_key`) dan otomatis menyimpan posisi di `RESYNC_CURSOR_INDEX` bila jumlah respons sangat banyak.
7. **Berbagi Akses Foto ke SPV & TSC**:
   - Buka folder Google Drive tempat file pertanyaan **`Foto Bukti Visit`** disimpan, lalu bagikan akses *Viewer (elihat saja)* kepada akun Google SPV dan TSC agar mereka dapat membuka foto bukti langsung dari aplikasi.

