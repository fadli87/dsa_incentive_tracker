-- =========================================================================
-- MIGRASI FASE 0: Pengamanan fungsi public.make_superadmin(text)
-- Mencabut hak eksekusi dari public, anon, dan authenticated agar fungsi
-- hanya dapat dijalankan langsung dari Supabase SQL Editor oleh owner.
-- =========================================================================

revoke execute on function public.make_superadmin(text) from public, anon, authenticated;

