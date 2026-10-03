-- =========================================================================
-- SUPABASE SCHEMA & SECURITY CONFIGURATION
-- Fitur: DSA XL Satu Handbook — Team Login & Access Gate
-- =========================================================================

-- 1. Pastikan ekstensi pgcrypto aktif untuk hashing bcrypt kode akses
create extension if not exists pgcrypto;

-- 2. Tabel anggota tim (team_members)
create table if not exists public.team_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  name text,
  status text not null default 'pending' check (status in ('pending','approved','revoked')),
  created_at timestamptz not null default now(),
  approved_at timestamptz
);

-- Aktifkan Row Level Security (RLS)
alter table public.team_members enable row level security;

-- Client authenticated hanya diizinkan membaca data miliknya sendiri
drop policy if exists "select own row" on public.team_members;
create policy "select own row" on public.team_members
  for select using (auth.uid() = user_id);

-- CATATAN: Sengaja TIDAK ADA policy insert/update/delete untuk authenticated/anon.
-- Operasi mutasi hanya dilakukan via server trigger dan RPC security definer.

-- 3. Trigger otomatis saat user baru mendaftar di Supabase Auth
create or replace function public.handle_new_team_member()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.team_members (user_id, email, name)
  values (
    new.id, 
    new.email, 
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1))
  );
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_team_member();

-- 4. Tabel konfigurasi rahasia (app_config)
create table if not exists public.app_config (
  key text primary key,
  value text not null
);

alter table public.app_config enable row level security;
-- DENGAN RLS AKTIF DAN TANPA POLICY, CLIENT TIDAK BISA SELECT MAUPUN MUTASI TABEL INI.

-- 5. Inisialisasi Kode Akses Tim Awal
-- Ganti 'XLSATU2026' di bawah ini dengan kode akses tim yang Anda tentukan:
insert into public.app_config (key, value)
values ('access_code_hash', crypt('XLSATU2026', gen_salt('bf')))
on conflict (key) do update set value = excluded.value;

-- 6. RPC Function Security Definer untuk validasi dan redeem kode akses
create or replace function public.redeem_access_code(input_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  stored_hash text;
  uid uuid := auth.uid();
  current_status text;
begin
  -- Pastikan user sedang login
  if uid is null then
    return 'not_authenticated';
  end if;

  -- Ambil hash kode akses dari konfigurasi server
  select value into stored_hash from app_config where key = 'access_code_hash';
  if stored_hash is null then
    return 'config_missing';
  end if;

  -- Verifikasi kecocokan bcrypt
  if crypt(input_code, stored_hash) <> stored_hash then
    return 'invalid_code';
  end if;

  -- Cek status user saat ini
  select status into current_status from team_members where user_id = uid;
  if current_status = 'revoked' then
    return 'already_revoked'; -- JANGAN PERNAH menimpa status revoked meski kode benar
  end if;

  -- Update status menjadi approved dan catat timestamp
  update team_members 
  set status = 'approved', approved_at = now() 
  where user_id = uid;

  return 'approved';
end;
$$;

-- Berikan izin eksekusi RPC kepada user terotentikasi
grant execute on function public.redeem_access_code(text) to authenticated;

-- =========================================================================
-- SOP ROTASI KODE AKSES TIM DI MASA DEPAN (JIKA SALES KELUAR):
-- Jalankan perintah berikut di SQL Editor dengan kode baru:
-- update public.app_config 
-- set value = crypt('KODE-BARU-ANDA', gen_salt('bf')) 
-- where key = 'access_code_hash';
-- =========================================================================
