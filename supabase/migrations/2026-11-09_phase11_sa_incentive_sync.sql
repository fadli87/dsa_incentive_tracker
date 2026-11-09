-- =========================================================================
-- FASE 11A: Sinkron Data SA (Pelanggan) + Riwayat Insentif ke Supabase
-- Idempotent migration (dapat dijalankan berulang kali dengan aman)
-- =========================================================================

-- 1. Data SA (pelanggan yang diisi sales)
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

-- 2. Riwayat insentif
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

-- 3. updated_at otomatis
create or replace function public.touch_updated_at_generic()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;
drop trigger if exists sa_customers_touch on public.sa_customers;
create trigger sa_customers_touch before update on public.sa_customers
  for each row execute function public.touch_updated_at_generic();
drop trigger if exists incentive_records_touch on public.incentive_records;
create trigger incentive_records_touch before update on public.incentive_records
  for each row execute function public.touch_updated_at_generic();

-- 3b. Helper: superadmin PERSIS (bukan admin). HARUS dibuat sebelum policy di bawah.
create or replace function public.is_superadmin_exact(check_user_id uuid default auth.uid())
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.team_members
                 where user_id = check_user_id and status = 'approved' and role = 'superadmin');
$$;
revoke execute on function public.is_superadmin_exact(uuid) from public, anon;
grant execute on function public.is_superadmin_exact(uuid) to authenticated;

-- 4. RLS
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

-- 5. RPC: daftar Data SA seluruh tim (untuk SPV/TSC/admin/superadmin), dengan nama sales
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

-- 6. RPC: ringkasan pencapaian tim bulan tertentu (TANPA nominal rupiah)
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

