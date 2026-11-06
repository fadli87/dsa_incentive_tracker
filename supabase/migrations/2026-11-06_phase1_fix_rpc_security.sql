-- =========================================================================
-- MIGRASI LANJUTAN FASE 1: Perbaikan Keamanan Helper RLS & Pembatasan Role RPC
-- (Menindaklanjuti Review Prioritas 5 & 6 tanpa mengubah migrasi lama)
-- =========================================================================

-- 1. Prioritas 5: Cegah user biasa mengecek status/role UUID milik user lain
--    Pemeriksaan hanya diizinkan untuk diri sendiri (check_user_id = auth.uid())
--    atau jika pemanggil memiliki hak lihat-semua (spv/tsc/admin/superadmin).
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

-- 2. Prioritas 6: Batasi admin_update_member_role hanya ke ('member','spv','tsc')
--    agar selaras dengan UI Panel SuperAdmin (promosi superadmin tetap eksklusif
--    lewat SQL Editor menggunakan make_superadmin).
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

