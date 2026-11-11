-- =========================================================================
-- FASE 13A: Layer "Pelanggan Terpasang" di Peta Coverage (customer_map_points)
-- Idempotent migration (dapat dijalankan berulang kali dengan aman)
-- =========================================================================

-- Titik pelanggan terpasang untuk peta. Boleh dibaca semua anggota yang disetujui.
create table if not exists public.customer_map_points (
  customer_id text primary key,
  latitude double precision not null,
  longitude double precision not null,
  install_date date,
  address text not null default '',
  package_name text not null default '',
  sales_name text not null default '',
  spv_name text not null default '',
  tsc_name text not null default '',
  updated_at timestamptz not null default now()
);
create index if not exists customer_map_points_sales_idx on public.customer_map_points (sales_name);
create index if not exists customer_map_points_install_idx on public.customer_map_points (install_date);

alter table public.customer_map_points enable row level security;
revoke all on public.customer_map_points from anon;
revoke insert, update, delete on public.customer_map_points from authenticated;
grant select on public.customer_map_points to authenticated;

drop policy if exists "map points select" on public.customer_map_points;
create policy "map points select" on public.customer_map_points for select to authenticated
  using (public.is_approved_member() or public.can_view_all());

-- Sinkron otomatis dari customer_master (insert/update/delete).
create or replace function public.sync_customer_map_point()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    delete from public.customer_map_points where customer_id = old.customer_id;
    return old;
  end if;
  if new.latitude is null or new.longitude is null
     or new.latitude = 0 or new.longitude = 0 then
    delete from public.customer_map_points where customer_id = new.customer_id;
    return new;
  end if;
  insert into public.customer_map_points
    (customer_id, latitude, longitude, install_date, address, package_name,
     sales_name, spv_name, tsc_name, updated_at)
  values
    (new.customer_id, new.latitude, new.longitude, new.install_date, new.address,
     new.package_name, new.sales_name, new.spv_name, new.tsc_name, now())
  on conflict (customer_id) do update set
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    install_date = excluded.install_date,
    address = excluded.address,
    package_name = excluded.package_name,
    sales_name = excluded.sales_name,
    spv_name = excluded.spv_name,
    tsc_name = excluded.tsc_name,
    updated_at = now();
  return new;
end; $$;
revoke execute on function public.sync_customer_map_point() from public, anon, authenticated;

drop trigger if exists trg_customer_map_point_upsert on public.customer_master;
create trigger trg_customer_map_point_upsert
  after insert or update on public.customer_master
  for each row execute function public.sync_customer_map_point();

drop trigger if exists trg_customer_map_point_delete on public.customer_master;
create trigger trg_customer_map_point_delete
  after delete on public.customer_master
  for each row execute function public.sync_customer_map_point();

-- Isi awal dari data yang sudah diimpor.
insert into public.customer_map_points
  (customer_id, latitude, longitude, install_date, address, package_name,
   sales_name, spv_name, tsc_name, updated_at)
select customer_id, latitude, longitude, install_date, address, package_name,
       sales_name, spv_name, tsc_name, now()
from public.customer_master
where latitude is not null and longitude is not null
  and latitude <> 0 and longitude <> 0
on conflict (customer_id) do update set
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  install_date = excluded.install_date,
  address = excluded.address,
  package_name = excluded.package_name,
  sales_name = excluded.sales_name,
  spv_name = excluded.spv_name,
  tsc_name = excluded.tsc_name,
  updated_at = now();
