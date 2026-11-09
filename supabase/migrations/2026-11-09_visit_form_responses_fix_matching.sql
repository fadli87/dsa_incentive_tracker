-- =========================================================================
-- FASE 9 (FIX MATCHING): Pencocokan Dua Arah Jawaban Google Form <-> Visit
-- Idempotent migration: aman dijalankan berulang kali di Supabase SQL Editor.
-- =========================================================================
-- Menangani 3 skenario pencocokan secara otomatis:
-- 1. Jawaban Google Form masuk/di-upsert (INSERT atau UPDATE) -> cari visit_activities
--    milik sales (berdasarkan email atau form_email alias, customer_id, category,
--    tanggal ±7 hari, fallback ke tanggal submit WIB bila visit_date kosong),
--    lalu tandai visit_activities.form_submitted = true & status = 'sudah_visit'.
-- 2. Sales menambah/menyinkronkan visit_activities SETELAH mengisi Google Form ->
--    trigger di visit_activities otomatis mencari jawaban Form yang belum berpasangan
--    dan langsung menandai form_submitted = true serta menautkan matched_visit_id.
-- 3. SuperAdmin mengatur form_email alias atau menyetujui akun di team_members ->
--    trigger di team_members otomatis mencocokkan ulang semua jawaban Form lama
--    dari email tersebut yang belum memiliki pasangan.
-- =========================================================================

-- 1. Fungsi BEFORE INSERT OR UPDATE pada visit_form_responses:
--    Mencari matched_user_id dan matched_visit_id.
create or replace function public.match_visit_form_response()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_user uuid;
  v_visit uuid;
  v_effective_date date;
begin
  -- Cari akun sales yang approved berdasarkan email utama atau form_email alias
  select tm.user_id into v_user
    from public.team_members tm
   where tm.status = 'approved'
     and (
       lower(trim(tm.email)) = lower(trim(new.responder_email))
       or lower(trim(coalesce(tm.form_email, ''))) = lower(trim(new.responder_email))
     )
   order by (lower(trim(tm.email)) = lower(trim(new.responder_email))) desc
   limit 1;

  new.matched_user_id := v_user;

  -- Gunakan visit_date dari Form, atau fallback ke tanggal submitted_at (WIB) bila kosong
  v_effective_date := coalesce(
    new.visit_date,
    (coalesce(new.submitted_at, now()) at time zone 'Asia/Jakarta')::date
  );

  if v_user is not null and new.category is not null then
    select v.id into v_visit
      from public.visit_activities v
     where v.user_id = v_user
       and trim(v.customer_id) = trim(new.customer_id)
       and v.category = new.category
       and v.deleted_at is null
       and v.planned_date between (v_effective_date - 7) and (v_effective_date + 7)
     order by abs(v.planned_date - v_effective_date), v.created_at desc
     limit 1;

    new.matched_visit_id := v_visit;
  else
    new.matched_visit_id := null;
  end if;

  return new;
end; $$;

drop trigger if exists vfr_match_before on public.visit_form_responses;
drop trigger if exists trg_match_form_response_on_upsert on public.visit_form_responses;
create trigger vfr_match_before
  before insert or update on public.visit_form_responses
  for each row execute function public.match_visit_form_response();

-- 2. Fungsi AFTER INSERT OR UPDATE pada visit_form_responses:
--    Memperbarui baris visit_activities yang cocok (form_submitted = true, status = 'sudah_visit').
create or replace function public.apply_visit_form_response()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.matched_visit_id is not null then
    update public.visit_activities v
       set form_submitted = true,
           status = case when v.status = 'belum' then 'sudah_visit' else v.status end,
           visited_at = coalesce(v.visited_at, new.submitted_at)
     where v.id = new.matched_visit_id
       and (
         v.form_submitted is distinct from true
         or v.status = 'belum'
         or v.visited_at is null
       );
  end if;
  return new;
end; $$;

drop trigger if exists vfr_apply_after on public.visit_form_responses;
create trigger vfr_apply_after
  after insert or update on public.visit_form_responses
  for each row execute function public.apply_visit_form_response();

-- 3. Trigger arah sebaliknya pada visit_activities (saat visit disinkronkan SETELAH Form diisi):
create or replace function public.match_form_on_visit_upsert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_form_id uuid;
  v_submitted_at timestamptz;
begin
  if new.deleted_at is not null then
    return new;
  end if;

  -- Cari jawaban Form milik user ini (atau emailnya cocok) untuk customer_id & category yang sama dalam ±7 hari
  select r.id, r.submitted_at
    into v_form_id, v_submitted_at
    from public.visit_form_responses r
   where trim(r.customer_id) = trim(new.customer_id)
     and r.category = new.category
     and (r.matched_visit_id is null or r.matched_visit_id = new.id)
     and (
       r.matched_user_id = new.user_id
       or exists (
         select 1 from public.team_members tm
          where tm.user_id = new.user_id
            and tm.status = 'approved'
            and (
              lower(trim(tm.email)) = lower(trim(r.responder_email))
              or lower(trim(coalesce(tm.form_email, ''))) = lower(trim(r.responder_email))
            )
       )
     )
     and coalesce(
       r.visit_date,
       (coalesce(r.submitted_at, now()) at time zone 'Asia/Jakarta')::date
     ) between (new.planned_date - 7) and (new.planned_date + 7)
   order by r.submitted_at desc
   limit 1;

  if v_form_id is not null then
    new.form_submitted := true;
    if new.status = 'belum' then
      new.status := 'sudah_visit';
    end if;
    new.visited_at := coalesce(new.visited_at, v_submitted_at);
  end if;

  return new;
end; $$;

drop trigger if exists trg_match_visit_before_upsert on public.visit_activities;
create trigger trg_match_visit_before_upsert
  before insert or update on public.visit_activities
  for each row execute function public.match_form_on_visit_upsert();

create or replace function public.link_form_after_visit_upsert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.deleted_at is null and new.form_submitted = true then
    update public.visit_form_responses r
       set matched_user_id = new.user_id,
           matched_visit_id = new.id
     where r.matched_visit_id is null
       and trim(r.customer_id) = trim(new.customer_id)
       and r.category = new.category
       and (
         r.matched_user_id = new.user_id
         or exists (
           select 1 from public.team_members tm
            where tm.user_id = new.user_id
              and tm.status = 'approved'
              and (
                lower(trim(tm.email)) = lower(trim(r.responder_email))
                or lower(trim(coalesce(tm.form_email, ''))) = lower(trim(r.responder_email))
              )
         )
       )
       and coalesce(
         r.visit_date,
         (coalesce(r.submitted_at, now()) at time zone 'Asia/Jakarta')::date
       ) between (new.planned_date - 7) and (new.planned_date + 7);
  end if;
  return new;
end; $$;

drop trigger if exists trg_match_visit_on_insert_or_update on public.visit_activities;
create trigger trg_match_visit_on_insert_or_update
  after insert or update on public.visit_activities
  for each row execute function public.link_form_after_visit_upsert();

-- 4. Trigger pada team_members: saat form_email diatur atau status menjadi approved,
--    cocokkan ulang jawaban Form lama yang belum memiliki pasangan.
create or replace function public.rematch_forms_on_team_member_change()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'approved' then
    update public.visit_form_responses r
       set responder_email = r.responder_email
     where r.matched_visit_id is null
       and (
         lower(trim(r.responder_email)) = lower(trim(new.email))
         or (
           coalesce(trim(new.form_email), '') <> ''
           and lower(trim(r.responder_email)) = lower(trim(new.form_email))
         )
       );
  end if;
  return new;
end; $$;

drop trigger if exists trg_rematch_forms_on_team_member_email_update on public.team_members;
create trigger trg_rematch_forms_on_team_member_email_update
  after insert or update of email, form_email, status on public.team_members
  for each row execute function public.rematch_forms_on_team_member_change();

-- 5. Backfill satu kali untuk mencocokkan jawaban Form yang sudah telanjur masuk tetapi belum terpasangkan
update public.visit_form_responses
   set responder_email = responder_email
 where matched_visit_id is null;
