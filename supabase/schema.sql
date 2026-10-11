-- =========================================================================
-- SUPABASE SCHEMA & SECURITY CONFIGURATION
-- Fitur: DSA XL Satu Handbook — Team Login, Access Gate & Superadmin
-- =========================================================================

-- 1. Pastikan ekstensi pgcrypto aktif untuk hashing bcrypt kode akses
create extension if not exists pgcrypto;

-- 2. Tabel anggota tim (team_members) dengan kolom role
create table if not exists public.team_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  name text,
  status text not null default 'pending' check (status in ('pending','approved','revoked')),
  role text not null default 'member' check (role in ('member','admin','superadmin')),
  created_at timestamptz not null default now(),
  approved_at timestamptz
);

-- Tambahkan kolom role jika tabel sudah ada dari versi sebelumnya
alter table public.team_members 
  add column if not exists role text not null default 'member' check (role in ('member','admin','superadmin'));

-- Aktifkan Row Level Security (RLS)
alter table public.team_members enable row level security;

-- 3. Fungsi Helper Security Definer untuk cek status Superadmin tanpa rekursi RLS
create or replace function public.is_superadmin(check_user_id uuid default auth.uid())
returns boolean 
language sql 
security definer 
set search_path = public 
as $$
  select exists (
    select 1 from public.team_members
    where user_id = check_user_id 
      and role in ('admin', 'superadmin') 
      and status = 'approved'
  );
$$;

-- Policy SELECT: User biasa hanya membaca baris dirinya sendiri; Superadmin membaca SEMUA baris
drop policy if exists "select own row" on public.team_members;
drop policy if exists "select team_members" on public.team_members;

create policy "select team_members" on public.team_members
  for select using (
    auth.uid() = user_id 
    or public.is_superadmin()
  );

-- CATATAN: Mutasi langsung dari client tetap diblokir. Mutasi hanya lewat RPC & Trigger.

-- 4. Trigger otomatis saat user baru mendaftar di Supabase Auth
create or replace function public.handle_new_team_member()
returns trigger 
language plpgsql 
security definer 
set search_path = public 
as $$
declare
  is_first_user boolean;
begin
  -- Cek apakah ini akun pertama yang mendaftar di sistem
  select not exists (select 1 from public.team_members) into is_first_user;

  if is_first_user then
    -- Akun pertama otomatis menjadi Superadmin dan langsung Approved!
    insert into public.team_members (user_id, email, name, status, role, approved_at)
    values (
      new.id, 
      new.email, 
      coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
      'approved',
      'superadmin',
      now()
    );
  else
    -- Akun berikutnya terdaftar sebagai member biasa dengan status pending
    insert into public.team_members (user_id, email, name, status, role)
    values (
      new.id, 
      new.email, 
      coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
      'pending',
      'member'
    );
  end if;

  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_team_member();

-- 5. Tabel konfigurasi rahasia (app_config)
create table if not exists public.app_config (
  key text primary key,
  value text not null
);

alter table public.app_config enable row level security;
-- RLS aktif tanpa policy -> hanya bisa diakses lewat security definer RPC atau SQL Editor

-- Inisialisasi Kode Akses Tim Default
insert into public.app_config (key, value)
values ('access_code_hash', crypt('XLSATU2026', gen_salt('bf')))
on conflict (key) do nothing;

-- 6. RPC Function: Redeem Kode Akses Tim untuk Sales Baru
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
    return 'already_revoked';
  end if;

  update team_members 
  set status = 'approved', approved_at = now() 
  where user_id = uid;

  return 'approved';
end;
$$;

grant execute on function public.redeem_access_code(text) to authenticated;

-- =========================================================================
-- FITUR SUPERADMIN RPC (Hanya bisa dijalankan oleh Superadmin)
-- =========================================================================

-- 7. RPC Function: Superadmin mengubah status anggota tim (Approve / Revoke)
create or replace function public.admin_update_member_status(target_user_id uuid, new_status text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
begin
  -- Verifikasi pemanggil adalah Superadmin
  is_admin := public.is_superadmin(auth.uid());
  if not is_admin then
    return 'unauthorized';
  end if;

  if new_status not in ('approved', 'pending', 'revoked') then
    return 'invalid_status';
  end if;

  update public.team_members
  set status = new_status,
      approved_at = case when new_status = 'approved' then coalesce(approved_at, now()) else approved_at end
  where user_id = target_user_id;

  return 'success';
end;
$$;

grant execute on function public.admin_update_member_status(uuid, text) to authenticated;

-- 8. RPC Function: Superadmin merotasi / memperbarui Kode Akses Tim
create or replace function public.admin_update_access_code(new_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  is_admin boolean;
begin
  -- Verifikasi pemanggil adalah Superadmin
  is_admin := public.is_superadmin(auth.uid());
  if not is_admin then
    return 'unauthorized';
  end if;

  if length(trim(new_code)) < 6 then
    return 'code_too_short';
  end if;

  update public.app_config
  set value = crypt(trim(new_code), gen_salt('bf'))
  where key = 'access_code_hash';

  return 'success';
end;
$$;

grant execute on function public.admin_update_access_code(text) to authenticated;

-- 9. Helper Function: Promosikan Akun Tertentu Menjadi Superadmin Secara Instan
create or replace function public.make_superadmin(target_email text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  row_count int;
begin
  update public.team_members
  set role = 'superadmin',
      status = 'approved',
      approved_at = coalesce(approved_at, now())
  where lower(email) = lower(trim(target_email));

  get diagnostics row_count = row_count;

  if row_count > 0 then
    return 'SUKSES: Akun ' || target_email || ' berhasil dipromosikan menjadi Superadmin!';
  else
    return 'PERINGATAN: Email ' || target_email || ' belum terdaftar di team_members. Daftarkan akun terlebih dahulu di aplikasi.';
  end if;
end;
$$;

-- =========================================================================
-- CARA MENGGUNAKAN UNTUK MEMBUAT SUPERADMIN PERTAMA:
-- 1. Jalankan seluruh skrip SQL ini di SQL Editor Supabase.
-- 2. Daftar di aplikasi dengan email Anda.
--    (Jika Anda adalah akun pertama, Anda OTOMATIS menjadi Superadmin!).
-- 3. Jika Anda sudah mendaftar sebelumnya, cukup jalankan perintah berikut di SQL Editor:
--    SELECT public.make_superadmin('email_anda@gmail.com');
-- =========================================================================
