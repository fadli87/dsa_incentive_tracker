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
  role text not null default 'member' check (role in ('member','admin','superadmin','spv','tsc')),
  created_at timestamptz not null default now(),
  approved_at timestamptz
);

-- Tambahkan kolom role jika tabel sudah ada dari versi sebelumnya
alter table public.team_members 
  add column if not exists role text not null default 'member' check (role in ('member','admin','superadmin','spv','tsc'));

-- Pastikan constraint role memuat role baru (spv dan tsc)
alter table public.team_members drop constraint if exists team_members_role_check;
alter table public.team_members add constraint team_members_role_check
  check (role in ('member','admin','superadmin','spv','tsc'));

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

revoke execute on function public.make_superadmin(text) from public, anon, authenticated;

-- =========================================================================
-- FITUR AKTIVITAS HARIAN VISIT (RVAI / Dismantle / Unpaid)
-- =========================================================================

-- 10. Helper: lihat-semua (read-only), TERPISAH dari is_superadmin()
create or replace function public.can_view_all(check_user_id uuid default auth.uid())
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.team_members target_tm
    where target_tm.user_id = check_user_id
      and target_tm.status = 'approved'
      and target_tm.role in ('spv','tsc','admin','superadmin')
      and (
        check_user_id = auth.uid()
        or exists (
          select 1 from public.team_members caller_tm
          where caller_tm.user_id = auth.uid()
            and caller_tm.status = 'approved'
            and caller_tm.role in ('spv','tsc','admin','superadmin')
        )
      )
  );
$$;

create or replace function public.is_approved_member(check_user_id uuid default auth.uid())
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.team_members target_tm
    where target_tm.user_id = check_user_id
      and target_tm.status = 'approved'
      and (
        check_user_id = auth.uid()
        or exists (
          select 1 from public.team_members caller_tm
          where caller_tm.user_id = auth.uid()
            and caller_tm.status = 'approved'
            and caller_tm.role in ('spv','tsc','admin','superadmin')
        )
      )
  );
$$;

revoke execute on function public.can_view_all(uuid) from public, anon;
revoke execute on function public.is_approved_member(uuid) from public, anon;
grant execute on function public.can_view_all(uuid) to authenticated;
grant execute on function public.is_approved_member(uuid) to authenticated;

-- 11. Tabel aktivitas visit
create table if not exists public.visit_activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid not null,
  customer_id text not null,
  customer_name text not null default '',
  category text not null check (category in ('rvai','dismantle','unpaid')),
  status text not null default 'belum' check (status in ('belum','sudah_visit','follow_up')),
  address text not null default '',
  package_name text not null default '',
  latitude double precision,
  longitude double precision,
  planned_date date not null,
  visited_at timestamptz,
  note text not null default '',
  form_submitted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (user_id, client_id)
);

create index if not exists visit_activities_user_date_idx
  on public.visit_activities (user_id, planned_date);
create index if not exists visit_activities_cat_status_idx
  on public.visit_activities (category, status, planned_date);

create or replace function public.touch_visit_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists visit_activities_touch on public.visit_activities;
create trigger visit_activities_touch before update on public.visit_activities
  for each row execute function public.touch_visit_updated_at();

-- 12. RLS untuk visit_activities
alter table public.visit_activities enable row level security;
revoke all on public.visit_activities from anon;

drop policy if exists "visit select" on public.visit_activities;
create policy "visit select" on public.visit_activities for select to authenticated
  using ((user_id = auth.uid() and public.is_approved_member()) or public.can_view_all());

drop policy if exists "visit insert own" on public.visit_activities;
create policy "visit insert own" on public.visit_activities for insert to authenticated
  with check (user_id = auth.uid() and public.is_approved_member());

drop policy if exists "visit update own" on public.visit_activities;
create policy "visit update own" on public.visit_activities for update to authenticated
  using (user_id = auth.uid() and public.is_approved_member())
  with check (user_id = auth.uid() and public.is_approved_member());
-- Tidak ada policy DELETE: penghapusan = soft delete (isi deleted_at lewat UPDATE).
-- SPV/TSC tidak punya policy tulis sama sekali (read-only).

-- 13. RPC: ubah role (HANYA role 'superadmin' persis, bukan 'admin'; dibatasi ke member/spv/tsc)
create or replace function public.admin_update_member_role(target_user_id uuid, new_role text)
returns text language plpgsql security definer set search_path = public as $$
declare caller_role text;
begin
  select role into caller_role from public.team_members
   where user_id = auth.uid() and status = 'approved';
  if caller_role is distinct from 'superadmin' then return 'unauthorized'; end if;
  if new_role not in ('member','spv','tsc') then return 'invalid_role'; end if;
  if target_user_id = auth.uid() then return 'cannot_change_self'; end if;
  update public.team_members set role = new_role where user_id = target_user_id;
  if not found then return 'not_found'; end if;
  return 'success';
end; $$;
revoke execute on function public.admin_update_member_role(uuid, text) from public, anon;
grant execute on function public.admin_update_member_role(uuid, text) to authenticated;

-- 14. RPC: rekap per sales (khusus can_view_all)
create or replace function public.get_visit_summary(from_date date, to_date date)
returns table (member_id uuid, member_name text, member_email text,
               category text, status text, total bigint)
language plpgsql security definer set search_path = public stable as $$
begin
  if not public.can_view_all() then raise exception 'unauthorized'; end if;
  return query
    select v.user_id, coalesce(tm.name,''), coalesce(tm.email,''),
           v.category, v.status, count(*)
    from public.visit_activities v
    left join public.team_members tm on tm.user_id = v.user_id
    where v.deleted_at is null and v.planned_date between from_date and to_date
    group by v.user_id, tm.name, tm.email, v.category, v.status;
end; $$;
revoke execute on function public.get_visit_summary(date, date) from public, anon;
grant execute on function public.get_visit_summary(date, date) to authenticated;

-- =========================================================================
-- FITUR MASTER PELANGGAN KCLP ("Pelanggan Saya") + SARAN & KEPATUHAN RVAI
-- =========================================================================

-- 15. Master pelanggan (hanya kolom yang diizinkan; TANPA serial/WO/SO/SIM)
create table if not exists public.customer_master (
  customer_id text primary key,
  city_code text not null,
  install_date date,
  address text not null default '',
  package_name text not null default '',
  latitude double precision,
  longitude double precision,
  sales_name text not null default '',      -- dinormalisasi: trim, spasi ganda -> 1, UPPERCASE
  spv_name text not null default '',
  tsc_name text not null default '',
  batch_id text not null default '',
  imported_at timestamptz not null default now()
);
create index if not exists customer_master_sales_idx on public.customer_master (sales_name);
create index if not exists customer_master_install_idx on public.customer_master (install_date);

-- 16. Nama sales per akun (untuk memetakan akun app -> Sales Name di KMZ)
alter table public.team_members add column if not exists sales_name text;

-- 17. Helper: nama sales milik pemanggil
create or replace function public.my_sales_name()
returns text language sql security definer set search_path = public stable as $$
  select nullif(tm.sales_name, '') from public.team_members tm
  where tm.user_id = auth.uid() and tm.status = 'approved';
$$;
revoke execute on function public.my_sales_name() from public, anon;
grant execute on function public.my_sales_name() to authenticated;

-- 18. RLS: tidak ada policy tulis untuk client. Tulis hanya lewat service role (skrip impor) / SQL Editor.
alter table public.customer_master enable row level security;
revoke all on public.customer_master from anon;
revoke insert, update, delete on public.customer_master from authenticated;

drop policy if exists "master select" on public.customer_master;
create policy "master select" on public.customer_master for select to authenticated
  using (
    public.can_view_all()
    or (public.is_approved_member() and sales_name <> '' and sales_name = public.my_sales_name())
  );

-- 19. Daftar nama sales untuk dipilih saat klaim (hanya nama, tanpa data pelanggan)
create or replace function public.list_master_sales_names()
returns table (sales_name text, spv_name text, total bigint)
language plpgsql security definer set search_path = public stable as $$
begin
  if not public.is_approved_member() then raise exception 'unauthorized'; end if;
  return query
    select m.sales_name, max(m.spv_name), count(*)
    from public.customer_master m
    where m.sales_name <> ''
    group by m.sales_name order by m.sales_name;
end; $$;
revoke execute on function public.list_master_sales_names() from public, anon;
grant execute on function public.list_master_sales_names() to authenticated;

-- 20. Klaim nama sales oleh akun sendiri (sekali; tidak boleh merebut nama akun lain)
create or replace function public.claim_sales_name(p_sales_name text)
returns text language plpgsql security definer set search_path = public as $$
declare v_name text := upper(regexp_replace(trim(coalesce(p_sales_name,'')), '\s+', ' ', 'g'));
begin
  if not public.is_approved_member() then return 'unauthorized'; end if;
  if v_name = '' then return 'invalid_name'; end if;
  if not exists (select 1 from public.customer_master where sales_name = v_name) then return 'not_found'; end if;
  if exists (select 1 from public.team_members where sales_name = v_name and user_id <> auth.uid() and status = 'approved')
    then return 'already_claimed'; end if;
  if exists (select 1 from public.team_members where user_id = auth.uid() and coalesce(sales_name,'') <> '')
    then return 'already_set'; end if;          -- perubahan hanya lewat superadmin (RPC di bawah)
  update public.team_members set sales_name = v_name where user_id = auth.uid();
  return 'success';
end; $$;
revoke execute on function public.claim_sales_name(text) from public, anon;
grant execute on function public.claim_sales_name(text) to authenticated;

-- 21. Superadmin mengubah/mereset nama sales anggota (kosong = reset)
create or replace function public.admin_set_member_sales_name(target_user_id uuid, p_sales_name text)
returns text language plpgsql security definer set search_path = public as $$
declare caller_role text; v_name text := upper(regexp_replace(trim(coalesce(p_sales_name,'')), '\s+', ' ', 'g'));
begin
  select role into caller_role from public.team_members where user_id = auth.uid() and status = 'approved';
  if caller_role is distinct from 'superadmin' then return 'unauthorized'; end if;
  if v_name <> '' and exists (select 1 from public.team_members where sales_name = v_name and user_id <> target_user_id and status = 'approved')
    then return 'already_claimed'; end if;
  update public.team_members set sales_name = nullif(v_name,'') where user_id = target_user_id;
  if not found then return 'not_found'; end if;
  return 'success';
end; $$;
revoke execute on function public.admin_set_member_sales_name(uuid, text) from public, anon;
grant execute on function public.admin_set_member_sales_name(uuid, text) to authenticated;

-- 22. Status impor terakhir (untuk kartu di Panel SuperAdmin)
create or replace function public.get_master_status()
returns table (total bigint, last_import timestamptz, last_batch text, with_sales bigint)
language plpgsql security definer set search_path = public stable as $$
begin
  if not public.can_view_all() then raise exception 'unauthorized'; end if;
  return query select count(*), max(imported_at), max(batch_id), count(*) filter (where sales_name <> '') from public.customer_master;
end; $$;
revoke execute on function public.get_master_status() from public, anon;
grant execute on function public.get_master_status() to authenticated;

-- 23. Rekap kepatuhan RVAI per sales (khusus can_view_all, hanya baca)
create or replace function public.get_rvai_compliance(from_date date, to_date date)
returns table (sales_name text, spv_name text, tsc_name text, due_total bigint, visited_total bigint)
language plpgsql security definer set search_path = public stable as $$
begin
  if not public.can_view_all() then raise exception 'unauthorized'; end if;
  return query
    select m.sales_name,
           max(m.spv_name) as spv_name,
           max(m.tsc_name) as tsc_name,
           count(*) as due_total,
           count(*) filter (
             where exists (
               select 1 from public.visit_activities v
               where v.customer_id = m.customer_id
                 and v.category = 'rvai'
                 and v.deleted_at is null
                 and v.status = 'sudah_visit'
             )
           ) as visited_total
    from public.customer_master m
    where m.sales_name <> ''
      and m.install_date is not null
      and (m.install_date + 7) between from_date and to_date
    group by m.sales_name
    order by m.sales_name;
end; $$;
revoke execute on function public.get_rvai_compliance(date, date) from public, anon;
grant execute on function public.get_rvai_compliance(date, date) to authenticated;

-- =========================================================================
-- CARA MENGGUNAKAN UNTUK MEMBUAT SUPERADMIN PERTAMA:
-- CATATAN KEAMANAN: Fungsi public.make_superadmin(text) telah di-revoke dari
-- public, anon, dan authenticated, sehingga HANYA bisa dipanggil langsung dari
-- Supabase SQL Editor oleh owner project (tidak bisa dipanggil lewat RPC client).
-- 1. Jalankan seluruh skrip SQL ini di SQL Editor Supabase.
-- 2. Daftar di aplikasi dengan email Anda.
--    (Jika Anda adalah akun pertama, Anda OTOMATIS menjadi Superadmin!).
-- 3. Jika Anda sudah mendaftar sebelumnya, cukup jalankan perintah berikut
--    langsung di Supabase SQL Editor (hanya oleh owner):
--    SELECT public.make_superadmin('email_anda@gmail.com');
-- =========================================================================
