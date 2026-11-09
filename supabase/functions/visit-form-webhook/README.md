# Supabase Edge Function: `visit-form-webhook`

Edge Function ini menerima kiriman jawaban Google Form dari Google Apps Script (`onFormSubmit`), memvalidasi header `x-webhook-secret` secara *constant-time*, memvalidasi isi payload secara ketat, lalu melakukan `upsert` idempoten (berdasarkan `response_key`) ke tabel `public.visit_form_responses`.

---

## Prasyarat

1. Migrasi SQL [`supabase/migrations/2026-11-09_visit_form_responses.sql`](../../migrations/2026-11-09_visit_form_responses.sql) sudah dijalankan di Supabase SQL Editor.
2. Supabase CLI sudah terpasang dan login ke project Anda (`supabase login` & `supabase link --project-ref <PROJECT_REF>`).

---

## Cara Mengatur Secret & Deploy

> **PENTING**: Jangan pernah menuliskan nilai `VISIT_FORM_WEBHOOK_SECRET` atau `SUPABASE_SERVICE_ROLE_KEY` di dalam kode repositori! `SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` disediakan otomatis oleh runtime Supabase Edge Functions.

1. Buat string acak minimal 32 karakter untuk secret webhook, lalu simpan ke Supabase Secrets:
   ```bash
   supabase secrets set VISIT_FORM_WEBHOOK_SECRET=<STRING_ACAK_MINIMAL_32_KARAKTER>
   ```

2. Deploy fungsi dengan flag `--no-verify-jwt` (karena Google Apps Script tidak mengirimkan token JWT Supabase, melainkan autentikasi menggunakan `x-webhook-secret`):
   ```bash
   supabase functions deploy visit-form-webhook --no-verify-jwt
   ```

3. Salin URL endpoint fungsi Anda:
   ```text
   https://<PROJECT_REF>.supabase.co/functions/v1/visit-form-webhook
   ```
   Masukkan URL tersebut beserta nilai `VISIT_FORM_WEBHOOK_SECRET` yang sama ke dalam **Script Properties** pada proyek Google Apps Script (`WEBHOOK_URL` dan `WEBHOOK_SECRET`).

---

## Menjalankan Unit Test Lokal (Deno)

```bash
deno test supabase/functions/visit-form-webhook/index_test.ts
```
