-- =========================================================================
-- FASE 9A: JAWABAN GOOGLE FORM OTOMATIS MASUK SUPABASE (visit_form_responses)
-- Idempotent migration: aman dijalankan berulang kali di Supabase SQL Editor.
-- =========================================================================

-- 1. Alias email Form per akun (diatur superadmin)
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

-- 2. Tabel jawaban Form
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

-- 3. form_submitted bersifat monoton (tidak boleh kembali false dari app)
create or replace function public.visit_keep_form_submitted()
returns trigger language plpgsql as $$
begin
  if old.form_submitted and not new.form_submitted then new.form_submitted := true; end if;
  return new;
end; $$;
drop trigger if exists visit_activities_keep_form on public.visit_activities;
create trigger visit_activities_keep_form before update on public.visit_activities
  for each row execute function public.visit_keep_form_submitted();

-- 4. Pencocokan otomatis saat jawaban masuk
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

-- 5. RPC: jawaban Form untuk sebuah visit (pemilik visit atau can_view_all, lewat RLS)
create or replace function public.get_form_response_for_visit(p_visit_id uuid)
returns setof public.visit_form_responses
language sql security invoker set search_path = public stable as $$
  select * from public.visit_form_responses where matched_visit_id = p_visit_id order by submitted_at desc limit 1;
$$;
revoke execute on function public.get_form_response_for_visit(uuid) from public, anon;
grant execute on function public.get_form_response_for_visit(uuid) to authenticated;

-- 6. RPC: jawaban tanpa pasangan (khusus superadmin) untuk kartu di panel
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

