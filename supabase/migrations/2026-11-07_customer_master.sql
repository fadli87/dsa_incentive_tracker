-- =========================================================================
-- FASE 10A & 10E: Master Pelanggan KCLP ("Pelanggan Saya") + Saran & Kepatuhan RVAI
-- Tanggal: 2026-11-07
-- =========================================================================

-- 1. Master pelanggan (hanya kolom yang diizinkan; TANPA serial/WO/SO/SIM)
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

-- 2. Nama sales per akun (untuk memetakan akun app -> Sales Name di KMZ)
alter table public.team_members add column if not exists sales_name text;

-- 3. Helper: nama sales milik pemanggil
create or replace function public.my_sales_name()
returns text language sql security definer set search_path = public stable as $$
  select nullif(tm.sales_name, '') from public.team_members tm
  where tm.user_id = auth.uid() and tm.status = 'approved';
$$;
revoke execute on function public.my_sales_name() from public, anon;
grant execute on function public.my_sales_name() to authenticated;

-- 4. RLS: tidak ada policy tulis untuk client. Tulis hanya lewat service role (skrip impor) / SQL Editor.
alter table public.customer_master enable row level security;
revoke all on public.customer_master from anon;
revoke insert, update, delete on public.customer_master from authenticated;

drop policy if exists "master select" on public.customer_master;
create policy "master select" on public.customer_master for select to authenticated
  using (
    public.can_view_all()
    or (public.is_approved_member() and sales_name <> '' and sales_name = public.my_sales_name())
  );

-- 5. Daftar nama sales untuk dipilih saat klaim (hanya nama, tanpa data pelanggan)
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

-- 6. Klaim nama sales oleh akun sendiri (sekali; tidak boleh merebut nama akun lain)
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

-- 7. Superadmin mengubah/mereset nama sales anggota (kosong = reset)
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

-- 8. Status impor terakhir (untuk kartu di Panel SuperAdmin)
create or replace function public.get_master_status()
returns table (total bigint, last_import timestamptz, last_batch text, with_sales bigint)
language plpgsql security definer set search_path = public stable as $$
begin
  if not public.can_view_all() then raise exception 'unauthorized'; end if;
  return query select count(*), max(imported_at), max(batch_id), count(*) filter (where sales_name <> '') from public.customer_master;
end; $$;
revoke execute on function public.get_master_status() from public, anon;
grant execute on function public.get_master_status() to authenticated;

-- 9. Rekap kepatuhan RVAI per sales (khusus can_view_all, hanya baca)
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
