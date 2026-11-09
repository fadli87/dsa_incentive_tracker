-- =========================================================================
-- FASE 12A: Impor Master Pelanggan KCLP dari Dalam Aplikasi (Khusus SuperAdmin)
-- Idempotent migration (dapat dijalankan berulang kali dengan aman)
-- =========================================================================

-- Impor master pelanggan oleh superadmin murni. Upsert per customer_id. Tidak menghapus data lama.
create or replace function public.admin_import_customer_master(p_batch_id text, p_rows jsonb)
returns table (inserted_count integer, updated_count integer, rejected_count integer)
language plpgsql security definer set search_path = public as $$
declare
  v_total integer;
  v_ins integer;
  v_proc integer;
begin
  if not public.is_superadmin_exact() then
    raise exception 'unauthorized';
  end if;
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    raise exception 'invalid_payload';
  end if;
  v_total := jsonb_array_length(p_rows);
  if v_total = 0 then
    return query select 0, 0, 0;
    return;
  end if;
  if v_total > 500 then
    raise exception 'batch_too_large';
  end if;
  if coalesce(trim(p_batch_id), '') = '' or length(p_batch_id) > 64 then
    raise exception 'invalid_batch_id';
  end if;

  -- Hanya kolom whitelist yang dibaca; kolom lain di JSON diabaikan otomatis.
  with cleaned as (
    select
      left(trim(r.customer_id), 64) as customer_id,
      upper(trim(r.city_code)) as city_code,
      r.install_date,
      left(regexp_replace(coalesce(r.address, ''), '\s+', ' ', 'g'), 500) as address,
      left(regexp_replace(coalesce(r.package_name, ''), '\s+', ' ', 'g'), 200) as package_name,
      case when r.latitude between -90 and 90 and r.latitude <> 0 then r.latitude end as latitude,
      case when r.longitude between -180 and 180 and r.longitude <> 0 then r.longitude end as longitude,
      upper(regexp_replace(trim(coalesce(r.sales_name, '')), '\s+', ' ', 'g')) as sales_name,
      upper(regexp_replace(trim(coalesce(r.spv_name, '')), '\s+', ' ', 'g')) as spv_name,
      upper(regexp_replace(trim(coalesce(r.tsc_name, '')), '\s+', ' ', 'g')) as tsc_name
    from jsonb_to_recordset(p_rows) as r(
      customer_id text, city_code text, install_date date, address text, package_name text,
      latitude double precision, longitude double precision,
      sales_name text, spv_name text, tsc_name text
    )
    where coalesce(trim(r.customer_id), '') <> ''
      and upper(trim(coalesce(r.city_code, ''))) = 'KCLP'
  ),
  dedup as (
    select distinct on (customer_id) *
    from cleaned
    order by customer_id, install_date desc nulls last
  ),
  up as (
    insert into public.customer_master as m
      (customer_id, city_code, install_date, address, package_name, latitude, longitude,
       sales_name, spv_name, tsc_name, batch_id, imported_at)
    select customer_id, city_code, install_date, address, package_name, latitude, longitude,
           sales_name, spv_name, tsc_name, p_batch_id, now()
    from dedup
    on conflict (customer_id) do update set
      city_code = excluded.city_code,
      install_date = excluded.install_date,
      address = excluded.address,
      package_name = excluded.package_name,
      latitude = excluded.latitude,
      longitude = excluded.longitude,
      sales_name = excluded.sales_name,
      spv_name = excluded.spv_name,
      tsc_name = excluded.tsc_name,
      batch_id = excluded.batch_id,
      imported_at = now()
    returning (xmax = 0) as is_insert
  )
  select count(*) filter (where is_insert), count(*) into v_ins, v_proc from up;

  return query select v_ins, v_proc - v_ins, v_total - v_proc;
end; $$;
revoke execute on function public.admin_import_customer_master(text, jsonb) from public, anon;
grant execute on function public.admin_import_customer_master(text, jsonb) to authenticated;

