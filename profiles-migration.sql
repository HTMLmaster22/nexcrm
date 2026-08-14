-- ═══════ NexCRM: profiles table (fix hidden emails/names) ═══════
-- شغّله مرة واحدة في: Supabase → SQL Editor → New query → Run

-- 1) الجدول
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  created_at timestamptz default now()
);

-- 2) Trigger: أي يوزر جديد يتسجل → صف في profiles تلقائياً
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name',
             new.raw_user_meta_data->>'name',
             split_part(new.email,'@',1))
  )
  on conflict (id) do update
    set email = excluded.email,
        full_name = coalesce(public.profiles.full_name, excluded.full_name);
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update of email on auth.users
  for each row execute function public.handle_new_user();

-- 3) Backfill: اليوزرز التلاتة الموجودين حالياً
insert into public.profiles (id, email, full_name)
select id, email,
       coalesce(raw_user_meta_data->>'full_name',
                raw_user_meta_data->>'name',
                split_part(email,'@',1))
from auth.users
on conflict (id) do update
  set email = excluded.email,
      full_name = coalesce(public.profiles.full_name, excluded.full_name);

-- 4) RLS: كل واحد يشوف بروفايلات أعضاء نفس الـ org بس
create or replace function public.same_org(target uuid)
returns boolean
language sql security definer set search_path = public stable
as $$
  select exists (
    select 1
    from org_members me
    join org_members them on them.org_id = me.org_id
    where me.user_id = auth.uid()
      and them.user_id = target
  );
$$;

alter table public.profiles enable row level security;

drop policy if exists "read own or same-org profiles" on public.profiles;
create policy "read own or same-org profiles" on public.profiles
  for select using ( id = auth.uid() or public.same_org(id) );

drop policy if exists "update own profile" on public.profiles;
create policy "update own profile" on public.profiles
  for update using ( id = auth.uid() );

-- ✅ للتأكد بعد التشغيل:
-- select id, email, full_name from public.profiles;
