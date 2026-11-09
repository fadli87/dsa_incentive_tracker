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
-- FASE 9A: JAWABAN GOOGLE FORM OTOMATIS MASUK SUPABASE (visit_form_responses)
-- =========================================================================

-- 24. Alias email Form per akun (diatur superadmin)
alter table public.team_members add column if not exists form_email text;

create or replace function public.admin_set_member_form_email(target_user_id uuid, p_form_email text)
returns text language plpgsql security definer set search_path = public as $$
declare caller_role text; v_email text := lower(trim(coalesce(p_form_email,'')));
begin
  select role into caller_role from public.team_members where user_id = auth.uid() and status = 'approved';
  if caller_role is distinct from 'superadmin' then return 'unauthorized'; end if;
  if v_email <> '' and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then return 'invalid_email'; end if;
  if v_email <> '' and exists (
       select 1 from public.team_members
       where user_id <> target_user_id and (lower(email) = v_email or lower(coalesce(form_email,'')) = v_email)
     ) then return 'already_used'; end if;
  update public.team_members set form_email = nullif(v_email,'') where user_id = target_user_id;
  if not found then return 'not_found'; end if;
  return 'success';
end; $$;
revoke execute on function public.admin_set_member_form_email(uuid, text) from public, anon;
grant execute on function public.admin_set_member_form_email(uuid, text) to authenticated;

-- 25. Tabel jawaban Form
create table if not exists public.visit_form_responses (
  id uuid primary key default gen_random_uuid(),
  response_key text not null unique,            -- ID respons Google Form (idempotensi)
  submitted_at timestamptz not null default now(),
  responder_email text not null default '',
  visit_date date,
  sales_name text not null default '',
  spv_name text not null default '',
  tsc_name text not null default '',
  customer_id text not null,
  category text check (category in ('rvai','dismantle','unpaid')),
  visit_status text not null default '',
  result text not null default '',
  obstacles text[] not null default '{}',
  note text not null default '',
  latitude double precision,
  longitude double precision,
  follow_up text not null default '',
  follow_up_date date,
  photo_urls text[] not null default '{}',
  matched_user_id uuid references auth.users(id) on delete set null,
  matched_visit_id uuid references public.visit_activities(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists vfr_customer_idx on public.visit_form_responses (customer_id);
create index if not exists vfr_user_date_idx on public.visit_form_responses (matched_user_id, visit_date);
create index if not exists vfr_unmatched_idx on public.visit_form_responses (created_at) where matched_user_id is null;

alter table public.visit_form_responses enable row level security;
revoke all on public.visit_form_responses from anon;
revoke insert, update, delete on public.visit_form_responses from authenticated;

drop policy if exists "vfr select" on public.visit_form_responses;
create policy "vfr select" on public.visit_form_responses for select to authenticated
  using (public.can_view_all() or (matched_user_id = auth.uid() and public.is_approved_member()));

-- 26. form_submitted bersifat monoton (tidak boleh kembali false dari app)
create or replace function public.visit_keep_form_submitted()
returns trigger language plpgsql as $$
begin
  if old.form_submitted and not new.form_submitted then new.form_submitted := true; end if;
  return new;
end; $$;
drop trigger if exists visit_activities_keep_form on public.visit_activities;
create trigger visit_activities_keep_form before update on public.visit_activities
  for each row execute function public.visit_keep_form_submitted();

-- 27. Pencocokan otomatis saat jawaban masuk
create or replace function public.match_visit_form_response()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_user uuid; v_visit uuid;
begin
  select tm.user_id into v_user from public.team_members tm
   where tm.status = 'approved'
     and (lower(tm.email) = lower(new.responder_email) or lower(coalesce(tm.form_email,'')) = lower(new.responder_email))
   order by (lower(tm.email) = lower(new.responder_email)) desc limit 1;
  new.matched_user_id := v_user;

  if v_user is not null and new.category is not null and new.visit_date is not null then
    select v.id into v_visit from public.visit_activities v
     where v.user_id = v_user and v.customer_id = new.customer_id and v.category = new.category
       and v.deleted_at is null and v.planned_date between new.visit_date - 3 and new.visit_date + 3
     order by abs(v.planned_date - new.visit_date), v.created_at limit 1;
    new.matched_visit_id := v_visit;
  end if;
  return new;
end; $$;
drop trigger if exists vfr_match_before on public.visit_form_responses;
create trigger vfr_match_before before insert on public.visit_form_responses
  for each row execute function public.match_visit_form_response();

create or replace function public.apply_visit_form_response()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.matched_visit_id is not null then
    update public.visit_activities v
       set form_submitted = true,
           status = case when v.status = 'belum' then 'sudah_visit' else v.status end,
           visited_at = coalesce(v.visited_at, new.submitted_at)
     where v.id = new.matched_visit_id;
  end if;
  return new;
end; $$;
drop trigger if exists vfr_apply_after on public.visit_form_responses;
create trigger vfr_apply_after after insert on public.visit_form_responses
  for each row execute function public.apply_visit_form_response();

-- 28. RPC: jawaban Form untuk sebuah visit (pemilik visit atau can_view_all, lewat RLS)
create or replace function public.get_form_response_for_visit(p_visit_id uuid)
returns setof public.visit_form_responses
language sql security invoker set search_path = public stable as $$
  select * from public.visit_form_responses where matched_visit_id = p_visit_id order by submitted_at desc limit 1;
$$;
revoke execute on function public.get_form_response_for_visit(uuid) from public, anon;
grant execute on function public.get_form_response_for_visit(uuid) to authenticated;

-- 29. RPC: jawaban tanpa pasangan (khusus superadmin) untuk kartu di panel
create or replace function public.get_unmatched_form_responses(p_limit int default 50)
returns table (id uuid, submitted_at timestamptz, responder_email text, customer_id text, category text, visit_date date, reason text)
language plpgsql security definer set search_path = public stable as $$
declare caller_role text;
begin
  select role into caller_role from public.team_members where user_id = auth.uid() and status = 'approved';
  if caller_role is distinct from 'superadmin' then raise exception 'unauthorized'; end if;
  return query
    select r.id, r.submitted_at, r.responder_email, r.customer_id, r.category, r.visit_date,
           case when r.matched_user_id is null then 'email_tidak_cocok' else 'visit_tidak_ditemukan' end
    from public.visit_form_responses r
    where r.matched_visit_id is null
    order by r.submitted_at desc limit least(coalesce(p_limit, 50), 200);
end; $$;
revoke execute on function public.get_unmatched_form_responses(int) from public, anon;
grant execute on function public.get_unmatched_form_responses(int) to authenticated;

-- =========================================================================
-- FASE 11: SINKRON DATA SA (PELANGGAN) + RIWAYAT INSENTIF KE SUPABASE
-- =========================================================================

-- 30. Data SA (pelanggan yang diisi sales)
create table if not exists public.sa_customers (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid not null,
  id_pelanggan text not null,
  nama text not null,
  no_hp_utama text not null default '',
  no_hp_alternatif text not null default '',
  alamat text not null default '',
  latitude double precision,
  longitude double precision,
  paket text not null default '',
  tanggal_pasang date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (user_id, client_id)
);
create index if not exists sa_customers_user_idx on public.sa_customers (user_id, tanggal_pasang);
create index if not exists sa_customers_idpel_idx on public.sa_customers (id_pelanggan);

-- 31. Riwayat insentif
create table if not exists public.incentive_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  client_id uuid not null,
  periode text not null,
  period_month date,                       -- tanggal 1 bulan periode; null bila tak bisa ditentukan
  "position" text not null default '',
  city text not null default '',
  basic_fee double precision not null default 0,
  total_sa integer not null default 0,
  pm_base double precision not null default 0,
  mult_rate double precision not null default 0,
  mult_bonus double precision not null default 0,
  prog_inc double precision not null default 0,
  special_inc double precision not null default 0,
  monthly_subtotal double precision not null default 0,
  grand_total double precision not null default 0,
  f0 integer not null default 0, f50 integer not null default 0, f100 integer not null default 0,
  f125 integer not null default 0, f200 integer not null default 0, fwa integer not null default 0,
  p35 integer not null default 0, p6 integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (user_id, client_id)
);
create index if not exists incentive_user_month_idx on public.incentive_records (user_id, period_month);

-- 32. updated_at otomatis
create or replace function public.touch_updated_at_generic()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;
drop trigger if exists sa_customers_touch on public.sa_customers;
create trigger sa_customers_touch before update on public.sa_customers
  for each row execute function public.touch_updated_at_generic();
drop trigger if exists incentive_records_touch on public.incentive_records;
create trigger incentive_records_touch before update on public.incentive_records
  for each row execute function public.touch_updated_at_generic();

-- 32b. Helper: superadmin PERSIS (bukan admin). HARUS dibuat sebelum policy di bawah.
create or replace function public.is_superadmin_exact(check_user_id uuid default auth.uid())
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.team_members
                 where user_id = check_user_id and status = 'approved' and role = 'superadmin');
$$;
revoke execute on function public.is_superadmin_exact(uuid) from public, anon;
grant execute on function public.is_superadmin_exact(uuid) to authenticated;

-- 33. RLS
alter table public.sa_customers enable row level security;
alter table public.incentive_records enable row level security;
revoke all on public.sa_customers from anon;
revoke all on public.incentive_records from anon;
revoke delete on public.sa_customers from authenticated;
revoke delete on public.incentive_records from authenticated;

-- Data SA: milik sendiri; spv/tsc/admin/superadmin lihat semua (read-only)
drop policy if exists "sa select" on public.sa_customers;
create policy "sa select" on public.sa_customers for select to authenticated
  using ((user_id = auth.uid() and public.is_approved_member()) or public.can_view_all());
drop policy if exists "sa insert own" on public.sa_customers;
create policy "sa insert own" on public.sa_customers for insert to authenticated
  with check (user_id = auth.uid() and public.is_approved_member());
drop policy if exists "sa update own" on public.sa_customers;
create policy "sa update own" on public.sa_customers for update to authenticated
  using (user_id = auth.uid() and public.is_approved_member())
  with check (user_id = auth.uid() and public.is_approved_member());

-- Insentif: milik sendiri + HANYA superadmin yang melihat semua (nominal)
drop policy if exists "inc select" on public.incentive_records;
create policy "inc select" on public.incentive_records for select to authenticated
  using (
    (user_id = auth.uid() and public.is_approved_member())
    or public.is_superadmin_exact()
  );
drop policy if exists "inc insert own" on public.incentive_records;
create policy "inc insert own" on public.incentive_records for insert to authenticated
  with check (user_id = auth.uid() and public.is_approved_member());
drop policy if exists "inc update own" on public.incentive_records;
create policy "inc update own" on public.incentive_records for update to authenticated
  using (user_id = auth.uid() and public.is_approved_member())
  with check (user_id = auth.uid() and public.is_approved_member());

-- 34. RPC: daftar Data SA seluruh tim (untuk SPV/TSC/admin/superadmin), dengan nama sales
create or replace function public.list_sa_customers(
  p_search text default '', p_user uuid default null, p_limit int default 50, p_offset int default 0)
returns table (id uuid, user_id uuid, member_name text, id_pelanggan text, nama text,
               no_hp_utama text, no_hp_alternatif text, alamat text, latitude double precision,
               longitude double precision, paket text, tanggal_pasang date)
language plpgsql security definer set search_path = public stable as $$
begin
  if not public.can_view_all() then raise exception 'unauthorized'; end if;
  return query
    select c.id, c.user_id, coalesce(tm.name, tm.email, ''), c.id_pelanggan, c.nama,
           c.no_hp_utama, c.no_hp_alternatif, c.alamat, c.latitude, c.longitude, c.paket, c.tanggal_pasang
    from public.sa_customers c
    left join public.team_members tm on tm.user_id = c.user_id
    where c.deleted_at is null
      and (p_user is null or c.user_id = p_user)
      and (coalesce(p_search,'') = '' or c.nama ilike '%'||p_search||'%'
           or c.id_pelanggan ilike '%'||p_search||'%' or c.no_hp_utama ilike '%'||p_search||'%')
    order by c.updated_at desc
    limit least(coalesce(p_limit,50),200) offset greatest(coalesce(p_offset,0),0);
end; $$;
revoke execute on function public.list_sa_customers(text, uuid, int, int) from public, anon;
grant execute on function public.list_sa_customers(text, uuid, int, int) to authenticated;

-- 35. RPC: ringkasan pencapaian tim bulan tertentu (TANPA nominal rupiah)
drop function if exists public.get_incentive_team_summary(date);
create or replace function public.get_incentive_team_summary(p_month date)
returns table (member_id uuid, member_name text, member_position text, total_sa integer,
               f0 integer, f50 integer, f100 integer, f125 integer, f200 integer,
               fwa integer, p35 integer, p6 integer, updated_at timestamptz)
language plpgsql security definer set search_path = public stable as $$
begin
  if not public.can_view_all() then raise exception 'unauthorized'; end if;
  return query
    select distinct on (r.user_id) r.user_id, coalesce(tm.name, tm.email, ''), r."position", r.total_sa,
           r.f0, r.f50, r.f100, r.f125, r.f200, r.fwa, r.p35, r.p6, r.updated_at
    from public.incentive_records r
    left join public.team_members tm on tm.user_id = r.user_id
    where r.deleted_at is null and r.period_month = date_trunc('month', p_month)::date
    order by r.user_id, r.updated_at desc;
end; $$;
revoke execute on function public.get_incentive_team_summary(date) from public, anon;
grant execute on function public.get_incentive_team_summary(date) to authenticated;

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
