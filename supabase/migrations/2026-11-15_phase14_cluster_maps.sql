-- =========================================================================
-- FASE 14: Fitur Peta Cluster (cluster_maps & Storage bucket cluster-maps)
-- Idempotent migration (dapat dijalankan berulang kali dengan aman)
-- =========================================================================

-- 1. Tabel cluster_maps untuk katalog cluster FTTH
create table if not exists public.cluster_maps (
  cluster_code text primary key,
  name text not null,
  kelurahan text,
  rw text,
  kmz_path text not null,
  pdf_path text,
  kmz_size int,
  updated_at timestamptz not null default now()
);

create index if not exists cluster_maps_name_idx on public.cluster_maps (name);
create index if not exists cluster_maps_kelurahan_idx on public.cluster_maps (kelurahan);
create index if not exists cluster_maps_updated_at_idx on public.cluster_maps (updated_at desc);

-- 2. RLS tabel cluster_maps
alter table public.cluster_maps enable row level security;
revoke all on public.cluster_maps from anon;
revoke insert, update, delete on public.cluster_maps from authenticated;
grant select on public.cluster_maps to authenticated;

drop policy if exists "cluster_maps select approved" on public.cluster_maps;
create policy "cluster_maps select approved" on public.cluster_maps for select to authenticated
  using (public.is_approved_member() or public.can_view_all());

drop policy if exists "cluster_maps superadmin modify" on public.cluster_maps;
create policy "cluster_maps superadmin modify" on public.cluster_maps for all to authenticated
  using (public.is_superadmin_exact())
  with check (public.is_superadmin_exact());

-- 3. Storage Bucket: cluster-maps (privat)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'cluster-maps',
  'cluster-maps',
  false,
  52428800, -- 50 MB limit
  array['application/vnd.google-earth.kmz', 'application/zip', 'application/pdf', 'application/octet-stream']
)
on conflict (id) do update set
  public = false,
  file_size_limit = 52428800;

-- 4. Storage Policies untuk bucket cluster-maps
-- Read: Hanya anggota tim berstatus approved
drop policy if exists "cluster_maps storage read approved" on storage.objects;
create policy "cluster_maps storage read approved" on storage.objects for select to authenticated
  using (
    bucket_id = 'cluster-maps'
    and (public.is_approved_member(auth.uid()) or public.can_view_all(auth.uid()))
  );

-- Insert/Update/Delete: Hanya superadmin (atau service role)
drop policy if exists "cluster_maps storage superadmin insert" on storage.objects;
create policy "cluster_maps storage superadmin insert" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'cluster-maps'
    and public.is_superadmin_exact(auth.uid())
  );

drop policy if exists "cluster_maps storage superadmin update" on storage.objects;
create policy "cluster_maps storage superadmin update" on storage.objects for update to authenticated
  using (
    bucket_id = 'cluster-maps'
    and public.is_superadmin_exact(auth.uid())
  );

drop policy if exists "cluster_maps storage superadmin delete" on storage.objects;
create policy "cluster_maps storage superadmin delete" on storage.objects for delete to authenticated
  using (
    bucket_id = 'cluster-maps'
    and public.is_superadmin_exact(auth.uid())
  );

