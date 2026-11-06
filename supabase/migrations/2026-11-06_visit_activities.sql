-- =========================================================================
-- MIGRASI FASE 1: Skema Supabase untuk Aktivitas Harian Visit
-- (Role baru spv/tsc, tabel visit_activities, RLS, dan RPC)
-- =========================================================================

-- 1. Role baru: spv dan tsc (member tetap dipakai sebagai role sales)
-- Verifikasi nama constraint: select conname from pg_constraint where conrelid = 'public.team_members'::regclass;
alter table public.team_members drop constraint if exists team_members_role_check;
alter table public.team_members add constraint team_members_role_check
  check (role in ('member','admin','superadmin','spv','tsc'));

-- 2. Helper: lihat-semua (read-only), TERPISAH dari is_superadmin()
create or replace function public.can_view_all(check_user_id uuid default auth.uid())
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.team_members
    where user_id = check_user_id and status = 'approved'
      and role in ('spv','tsc','admin','superadmin')
  );
$$;

create or replace function public.is_approved_member(check_user_id uuid default auth.uid())
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1 from public.team_members
    where user_id = check_user_id and status = 'approved'
  );
$$;

revoke execute on function public.can_view_all(uuid) from public, anon;
revoke execute on function public.is_approved_member(uuid) from public, anon;
grant execute on function public.can_view_all(uuid) to authenticated;
grant execute on function public.is_approved_member(uuid) to authenticated;

-- 3. Tabel aktivitas visit
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

-- 4. RLS
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

-- 5. RPC: ubah role (HANYA role 'superadmin' persis, bukan 'admin')
create or replace function public.admin_update_member_role(target_user_id uuid, new_role text)
returns text language plpgsql security definer set search_path = public as $$
declare caller_role text;
begin
  select role into caller_role from public.team_members
   where user_id = auth.uid() and status = 'approved';
  if caller_role is distinct from 'superadmin' then return 'unauthorized'; end if;
  if new_role not in ('member','spv','tsc','admin','superadmin') then return 'invalid_role'; end if;
  if target_user_id = auth.uid() then return 'cannot_change_self'; end if;
  update public.team_members set role = new_role where user_id = target_user_id;
  if not found then return 'not_found'; end if;
  return 'success';
end; $$;
revoke execute on function public.admin_update_member_role(uuid, text) from public, anon;
grant execute on function public.admin_update_member_role(uuid, text) to authenticated;

-- 6. RPC: rekap per sales (khusus can_view_all)
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
