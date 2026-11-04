-- Loyalty Card — dipasang di project Supabase tokogue
-- File: supabase/loyalty.sql (halaman pelanggan & kasir: web/kartu/)
-- Jalankan di Supabase Dashboard → SQL Editor → New query → paste → Run.
-- Aman dijalankan ulang. Semua tabel & fungsi pakai awalan loyalty_
-- jadi tidak menyentuh tabel tokogue.
--
-- Akses:
--   • Pelanggan (tanpa login): daftar & lihat kartunya sendiri.
--   • Atasan tokogue (aplikasi → Kartu Member & Pelanggan): scan QR, kasih stempel, tukar hadiah,
--     lihat database pelanggan & laporan, atur menu & aturan program, atur siapa yang boleh kasih stempel.
--   • Karyawan yang diizinkan atasan (mis. kasir): cuma scan, kasih stempel, tukar hadiah.
--     Tidak bisa lihat nomor HP, daftar pelanggan, laporan, atau pengaturan.
--   • Karyawan lain & HR: tidak punya akses ke data member.

-- =========================================================
-- Tabel
-- =========================================================

create table if not exists public.loyalty_settings (
  id     int  primary key default 1 check (id = 1),
  store  text not null default 'Ayam Garing Juara' check (char_length(store) between 1 and 60),
  target int  not null default 10 check (target between 3 and 15),
  reward text not null default '1 Paket Ayam Geprek + Es Teh' check (char_length(reward) between 1 and 120)
);
insert into public.loyalty_settings (id) values (1) on conflict (id) do nothing;
-- Anti-curang: jeda minimal (menit) antar stempel untuk member yang sama. 0 = tanpa jeda.
alter table public.loyalty_settings add column if not exists stamp_cooldown_min int not null default 30;
do $$ begin
  alter table public.loyalty_settings add constraint loyalty_settings_cooldown_chk check (stamp_cooldown_min between 0 and 240);
exception when duplicate_object then null; end $$;

-- `id` = token rahasia di link kartu pelanggan, `code` = ID yang dicetak di kartu & QR.
create table if not exists public.loyalty_members (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,
  name       text not null check (char_length(name) between 1 and 60),
  phone      text not null unique check (phone ~ '^[0-9]{9,15}$'),
  stamps     int  not null default 0 check (stamps >= 0),
  redeemed   int  not null default 0 check (redeemed >= 0),
  last_visit timestamptz not null default now(),
  created_at timestamptz not null default now()
);
-- Kapan pelanggan setuju data (nama + nomor HP) disimpan (UU PDP)
alter table public.loyalty_members add column if not exists consented_at timestamptz;

create table if not exists public.loyalty_activity (
  id         bigint generated always as identity primary key,
  member_id  uuid references public.loyalty_members (id) on delete cascade,
  kind       text not null check (kind in ('join', 'stamp', 'redeem')),
  note       text not null,
  created_at timestamptz not null default now()
);
create index if not exists loyalty_activity_created_at_idx on public.loyalty_activity (created_at desc);
create index if not exists loyalty_activity_member_id_idx on public.loyalty_activity (member_id);

-- Daftar menu (dipilih kasir tiap kunjungan)
create table if not exists public.loyalty_menu (
  id         bigint generated always as identity primary key,
  name       text not null unique check (char_length(name) between 1 and 60),
  active     boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.loyalty_menu (name) values
  ('Ayam Geprek'), ('Ayam Goreng Original'), ('Ayam Crispy'), ('Nasi Putih'), ('Es Teh'), ('Es Jeruk')
on conflict (name) do nothing;

-- 1 stempel = 1 kunjungan, beserta menu yang dipesan
create table if not exists public.loyalty_visits (
  id         bigint generated always as identity primary key,
  member_id  uuid not null references public.loyalty_members (id) on delete cascade,
  staff_id   uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists loyalty_visits_member_idx  on public.loyalty_visits (member_id, created_at desc);
create index if not exists loyalty_visits_created_idx on public.loyalty_visits (created_at);
create index if not exists loyalty_visits_staff_idx   on public.loyalty_visits (staff_id);

create table if not exists public.loyalty_visit_items (
  visit_id bigint not null references public.loyalty_visits (id) on delete cascade,
  menu_id  bigint not null references public.loyalty_menu (id) on delete restrict,
  qty      int    not null check (qty between 1 and 50),
  primary key (visit_id, menu_id)
);
create index if not exists loyalty_visit_items_menu_idx on public.loyalty_visit_items (menu_id);

-- =========================================================
-- Siapa staf / atasan (pakai akun tokogue)
-- =========================================================

-- Karyawan yang diizinkan atasan untuk scan & kasih stempel (mis. kasir).
create table if not exists public.loyalty_staff (
  profile_id uuid primary key references public.profiles (id) on delete cascade,
  granted_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);
-- siapa yang menukar hadiah (untuk laporan per staf)
alter table public.loyalty_activity add column if not exists staff_id uuid references auth.users (id) on delete set null;

drop function if exists public.loyalty_is_admin();

-- Yang boleh scan & kasih stempel (aplikasi tokogue → Kartu Member):
-- atasan aktif, atau karyawan aktif yang diizinkan atasan (tabel loyalty_staff).
create or replace function public.loyalty_is_staff()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.status = 'active'
      and (p.role = 'atasan' or exists (select 1 from public.loyalty_staff s where s.profile_id = p.id))
  );
$$;

create or replace function public.loyalty_is_manager()
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and status = 'active' and role = 'atasan'
  );
$$;

-- =========================================================
-- Keamanan (RLS)
-- =========================================================
alter table public.loyalty_settings    enable row level security;
alter table public.loyalty_members     enable row level security;
alter table public.loyalty_activity    enable row level security;
alter table public.loyalty_menu        enable row level security;
alter table public.loyalty_visits      enable row level security;
alter table public.loyalty_visit_items enable row level security;
alter table public.loyalty_staff       enable row level security;
-- izin staf cuma diubah lewat fungsi loyalty_set_staff (atasan)
revoke all on public.loyalty_staff from anon, authenticated;

revoke all on public.loyalty_members, public.loyalty_activity, public.loyalty_menu,
              public.loyalty_visits, public.loyalty_visit_items from anon;
revoke insert, delete on public.loyalty_settings from anon, authenticated;
-- Stempel, kunjungan & log cuma bisa diubah lewat fungsi (biar selalu konsisten)
revoke insert, update, delete on public.loyalty_members, public.loyalty_activity,
              public.loyalty_visits, public.loyalty_visit_items from authenticated;
revoke delete on public.loyalty_menu from authenticated;

-- settings
drop policy if exists "loyalty settings: semua baca" on public.loyalty_settings;
create policy "loyalty settings: semua baca" on public.loyalty_settings
  for select to anon, authenticated using (true);
drop policy if exists "loyalty settings: HR ubah" on public.loyalty_settings;
drop policy if exists "loyalty settings: atasan ubah" on public.loyalty_settings;
create policy "loyalty settings: atasan ubah" on public.loyalty_settings
  for update to authenticated
  using ((select public.loyalty_is_manager())) with check ((select public.loyalty_is_manager()));

-- members & activity: cuma atasan
drop policy if exists "loyalty members: staf baca" on public.loyalty_members;
drop policy if exists "loyalty members: atasan baca" on public.loyalty_members;
create policy "loyalty members: atasan baca" on public.loyalty_members
  for select to authenticated using ((select public.loyalty_is_manager()));

drop policy if exists "loyalty activity: staf baca" on public.loyalty_activity;
drop policy if exists "loyalty activity: atasan baca" on public.loyalty_activity;
create policy "loyalty activity: atasan baca" on public.loyalty_activity
  for select to authenticated using ((select public.loyalty_is_manager()));

-- menu: staf baca, atasan tambah/ubah
drop policy if exists "loyalty menu: staf baca" on public.loyalty_menu;
create policy "loyalty menu: staf baca" on public.loyalty_menu
  for select to authenticated using ((select public.loyalty_is_staff()));
drop policy if exists "loyalty menu: atasan tambah" on public.loyalty_menu;
create policy "loyalty menu: atasan tambah" on public.loyalty_menu
  for insert to authenticated with check ((select public.loyalty_is_manager()));
drop policy if exists "loyalty menu: atasan ubah" on public.loyalty_menu;
create policy "loyalty menu: atasan ubah" on public.loyalty_menu
  for update to authenticated
  using ((select public.loyalty_is_manager())) with check ((select public.loyalty_is_manager()));

-- visits: cuma atasan yang baca
drop policy if exists "loyalty visits: atasan baca" on public.loyalty_visits;
create policy "loyalty visits: atasan baca" on public.loyalty_visits
  for select to authenticated using ((select public.loyalty_is_manager()));
drop policy if exists "loyalty visit items: atasan baca" on public.loyalty_visit_items;
create policy "loyalty visit items: atasan baca" on public.loyalty_visit_items
  for select to authenticated using ((select public.loyalty_is_manager()));

-- =========================================================
-- Fungsi
-- =========================================================

create or replace function public.loyalty_gen_code()
returns text
language plpgsql
set search_path = ''
as $$
declare
  alphabet constant text := '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
  c text;
begin
  loop
    c := 'LC-';
    for i in 1..5 loop
      c := c || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.loyalty_members where code = c);
  end loop;
  return c;
end;
$$;

-- Data kartu yang aman ditampilkan (tanpa nomor HP)
create or replace function public.loyalty_card_json(m public.loyalty_members)
returns json
language sql stable
set search_path = ''
as $$
  select json_build_object(
    'token', m.id, 'code', m.code, 'name', m.name,
    'stamps', m.stamps, 'redeemed', m.redeemed,
    'store', s.store, 'target', s.target, 'reward', s.reward
  )
  from public.loyalty_settings s where s.id = 1;
$$;

-- Pelanggan daftar → dapat kartu + bonus 1 stempel. Wajib centang persetujuan.
drop function if exists public.loyalty_join(text, text);
create or replace function public.loyalty_join(p_name text, p_phone text, p_consent boolean default null)
returns json
language plpgsql security definer
set search_path = ''
as $$
declare
  v_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_name  text := btrim(coalesce(p_name, ''));
  m public.loyalty_members;
begin
  if p_consent is not true then raise exception 'consent_required'; end if;
  if v_phone like '62%' then v_phone := '0' || substr(v_phone, 3); end if;
  if char_length(v_name) not between 1 and 60 then raise exception 'invalid_name'; end if;
  if v_phone !~ '^[0-9]{9,15}$' then raise exception 'invalid_phone'; end if;
  if exists (select 1 from public.loyalty_members where phone = v_phone) then raise exception 'phone_taken'; end if;

  insert into public.loyalty_members (code, name, phone, stamps, consented_at)
  values (public.loyalty_gen_code(), v_name, v_phone, 1, now())
  returning * into m;

  insert into public.loyalty_activity (member_id, kind, note)
  values (m.id, 'join', m.name || ' daftar jadi member (bonus 1 stempel)');

  return public.loyalty_card_json(m);
end;
$$;

-- Pelanggan buka kartunya pakai token dari link
create or replace function public.loyalty_get_card(p_token uuid)
returns json
language sql stable security definer
set search_path = ''
as $$
  select public.loyalty_card_json(m) from public.loyalty_members m where m.id = p_token;
$$;

-- Pelanggan hapus kartu & semua datanya sendiri (hak hapus data, UU PDP).
-- Butuh token rahasia dari link kartu, jadi cuma pemilik kartu yang bisa.
create or replace function public.loyalty_delete_me(p_token uuid)
returns boolean
language plpgsql security definer
set search_path = ''
as $$
begin
  delete from public.loyalty_members where id = p_token;
  return found;
end;
$$;

-- Kasir: cari member dari ID di kartu / QR (tanpa nomor HP)
create or replace function public.loyalty_lookup(p_code text)
returns json
language plpgsql stable security definer
set search_path = ''
as $$
declare
  m public.loyalty_members;
begin
  if not public.loyalty_is_staff() then raise exception 'not_staff'; end if;
  select * into m from public.loyalty_members
   where code = upper(btrim(regexp_replace(coalesce(p_code, ''), '^LOYALTY:', '', 'i')));
  if m.id is null then return null; end if;
  return public.loyalty_card_json(m);
end;
$$;

-- Kasir: +1 stempel, sekalian catat menu yang dipesan.
-- p_items = [{"menu_id": 1, "qty": 2}, ...]
drop function if exists public.loyalty_add_stamp(uuid);
create or replace function public.loyalty_add_stamp(p_member uuid, p_items jsonb default '[]'::jsonb)
returns json
language plpgsql security definer
set search_path = ''
as $$
declare
  v_target   int;
  v_cooldown int;
  v_last     timestamptz;
  v_visit    bigint;
  v_bad      int;
  m public.loyalty_members;
begin
  if not public.loyalty_is_staff() then raise exception 'not_staff'; end if;
  if jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' or jsonb_array_length(coalesce(p_items, '[]'::jsonb)) > 30 then
    raise exception 'invalid_items';
  end if;

  -- semua menu harus ada, aktif, dan qty 1..50
  select count(*) into v_bad
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
    left join public.loyalty_menu mn on mn.id = (e ->> 'menu_id')::bigint and mn.active
   where mn.id is null
      or coalesce((e ->> 'qty')::int, 0) not between 1 and 50;
  if v_bad > 0 then raise exception 'invalid_items'; end if;
  -- kalau toko punya menu aktif, minimal 1 menu wajib dipilih (biar laporan menu akurat)
  if jsonb_array_length(coalesce(p_items, '[]'::jsonb)) = 0 and exists (select 1 from public.loyalty_menu where active) then
    raise exception 'items_required';
  end if;

  select target, stamp_cooldown_min into v_target, v_cooldown from public.loyalty_settings where id = 1;

  -- kunci baris member dulu supaya dua kasir tidak bisa memberi stempel bersamaan
  perform 1 from public.loyalty_members where id = p_member for update;
  select max(created_at) into v_last from public.loyalty_visits where member_id = p_member;
  if v_cooldown > 0 and v_last is not null and v_last > now() - make_interval(mins => v_cooldown) then
    raise exception 'too_soon:%', ceil(extract(epoch from (v_last + make_interval(mins => v_cooldown) - now())) / 60)::int;
  end if;

  update public.loyalty_members
     set stamps = stamps + 1, last_visit = now()
   where id = p_member and stamps < v_target
  returning * into m;
  if m.id is null then raise exception 'card_full_or_missing'; end if;

  insert into public.loyalty_visits (member_id, staff_id)
  values (m.id, (select auth.uid()))
  returning id into v_visit;

  insert into public.loyalty_visit_items (visit_id, menu_id, qty)
  select v_visit, (e ->> 'menu_id')::bigint, sum((e ->> 'qty')::int)
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
   group by (e ->> 'menu_id')::bigint;

  insert into public.loyalty_activity (member_id, kind, note, staff_id)
  values (m.id, 'stamp', m.name || ' dapat stempel ke-' || m.stamps, (select auth.uid()));
  return public.loyalty_card_json(m);
end;
$$;

-- Kasir: tukar hadiah (kartu balik ke 0)
drop function if exists public.loyalty_redeem(uuid);
create or replace function public.loyalty_redeem(p_member uuid)
returns json
language plpgsql security definer
set search_path = ''
as $$
declare
  s public.loyalty_settings;
  m public.loyalty_members;
begin
  if not public.loyalty_is_staff() then raise exception 'not_staff'; end if;
  select * into s from public.loyalty_settings where id = 1;

  update public.loyalty_members
     set stamps = 0, redeemed = redeemed + 1, last_visit = now()
   where id = p_member and stamps >= s.target
  returning * into m;
  if m.id is null then raise exception 'not_ready'; end if;

  insert into public.loyalty_activity (member_id, kind, note, staff_id)
  values (m.id, 'redeem', m.name || ' tukar hadiah: ' || s.reward, (select auth.uid()));
  return public.loyalty_card_json(m);
end;
$$;

-- Atasan: laporan pelanggan per bulan (zona waktu Asia/Jakarta)
create or replace function public.loyalty_report(p_month date)
returns json
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_from timestamptz := date_trunc('month', p_month)::timestamp at time zone 'Asia/Jakarta';
  v_to   timestamptz := (date_trunc('month', p_month) + interval '1 month')::timestamp at time zone 'Asia/Jakarta';
  r json;
begin
  if not public.loyalty_is_manager() then raise exception 'not_manager'; end if;

  with v as (
    select * from public.loyalty_visits where created_at >= v_from and created_at < v_to
  ), per as (
    select member_id, count(*)::int n from v group by member_id
  ), fav as (
    select distinct on (x.member_id) x.member_id, mn.name
      from public.loyalty_visit_items i
      join public.loyalty_visits x on x.id = i.visit_id
      join public.loyalty_menu mn on mn.id = i.menu_id
     group by x.member_id, mn.name
     order by x.member_id, sum(i.qty) desc, mn.name
  ), tot as (
    select member_id, count(*)::int n, max(created_at) last_at from public.loyalty_visits group by member_id
  )
  select json_build_object(
    'month', to_char(date_trunc('month', p_month), 'YYYY-MM-DD'),
    'members_total', (select count(*) from public.loyalty_members),
    'members_new', (select count(*) from public.loyalty_members where created_at >= v_from and created_at < v_to),
    'visits', (select count(*) from v),
    'active_customers', (select count(*) from per),
    'redeemed', (select count(*) from public.loyalty_activity where kind = 'redeem' and created_at >= v_from and created_at < v_to),
    'top_menu', coalesce((
      select json_agg(t) from (
        select mn.name, sum(i.qty)::int as qty, count(distinct v.member_id)::int as customers
          from v
          join public.loyalty_visit_items i on i.visit_id = v.id
          join public.loyalty_menu mn on mn.id = i.menu_id
         group by mn.name
         order by qty desc, mn.name
         limit 10
      ) t), '[]'::json),
    'staff', coalesce((
      select json_agg(st) from (
        select coalesce(p.name, '(akun dihapus)') as name,
               count(*) filter (where x.k = 'stamp')::int as stamps,
               count(*) filter (where x.k = 'redeem')::int as redeems
          from (
            select staff_id, 'stamp' as k from v
            union all
            select staff_id, 'redeem' from public.loyalty_activity
             where kind = 'redeem' and created_at >= v_from and created_at < v_to
          ) x
          left join public.profiles p on p.id = x.staff_id
         group by x.staff_id, p.name
         order by stamps desc, redeems desc, name
      ) st), '[]'::json),
    'customers', coalesce((
      select json_agg(c) from (
        select mb.id, mb.code, mb.name, mb.phone, mb.stamps, mb.redeemed, mb.created_at,
               coalesce(per.n, 0) as visits_month,
               coalesce(tot.n, 0) as visits_total,
               tot.last_at as last_visit,
               fav.name as favorite
          from public.loyalty_members mb
          left join per on per.member_id = mb.id
          left join tot on tot.member_id = mb.id
          left join fav on fav.member_id = mb.id
         order by coalesce(per.n, 0) desc, tot.last_at desc nulls last, mb.name
         limit 1000
      ) c), '[]'::json)
  ) into r;
  return r;
end;
$$;

-- Atasan: detail 1 pelanggan
create or replace function public.loyalty_customer(p_member uuid)
returns json
language plpgsql stable security definer
set search_path = ''
as $$
declare
  r json;
begin
  if not public.loyalty_is_manager() then raise exception 'not_manager'; end if;

  select json_build_object(
    'id', mb.id, 'code', mb.code, 'name', mb.name, 'phone', mb.phone,
    'stamps', mb.stamps, 'redeemed', mb.redeemed, 'created_at', mb.created_at,
    'favorites', coalesce((
      select json_agg(f) from (
        select mn.name, sum(i.qty)::int as qty, count(distinct x.id)::int as visits
          from public.loyalty_visits x
          join public.loyalty_visit_items i on i.visit_id = x.id
          join public.loyalty_menu mn on mn.id = i.menu_id
         where x.member_id = mb.id
         group by mn.name
         order by qty desc, mn.name
         limit 5
      ) f), '[]'::json),
    'monthly', coalesce((
      select json_agg(mo order by mo.month) from (
        select to_char(gs, 'YYYY-MM-DD') as month,
               (select count(*) from public.loyalty_visits x
                 where x.member_id = mb.id
                   and x.created_at >= (gs::timestamp at time zone 'Asia/Jakarta')
                   and x.created_at <  ((gs + interval '1 month')::timestamp at time zone 'Asia/Jakarta'))::int as visits
          from generate_series(
                 date_trunc('month', (now() at time zone 'Asia/Jakarta')) - interval '5 months',
                 date_trunc('month', (now() at time zone 'Asia/Jakarta')),
                 interval '1 month') gs
      ) mo), '[]'::json),
    'visits', coalesce((
      select json_agg(vv) from (
        select x.created_at,
               (select p.name from public.profiles p where p.id = x.staff_id) as staff,
               coalesce((select json_agg(json_build_object('name', mn.name, 'qty', i.qty) order by mn.name)
                           from public.loyalty_visit_items i
                           join public.loyalty_menu mn on mn.id = i.menu_id
                          where i.visit_id = x.id), '[]'::json) as items
          from public.loyalty_visits x
         where x.member_id = mb.id
         order by x.created_at desc
         limit 30
      ) vv), '[]'::json)
  ) into r
  from public.loyalty_members mb
  where mb.id = p_member;

  return r;
end;
$$;

-- Atasan: daftar karyawan aktif + apakah boleh kasih stempel
create or replace function public.loyalty_staff_list()
returns json
language plpgsql stable security definer
set search_path = ''
as $$
begin
  if not public.loyalty_is_manager() then raise exception 'not_manager'; end if;
  return coalesce((
    select json_agg(json_build_object(
             'id', p.id, 'name', p.name, 'position', p.position, 'role', p.role,
             'allowed', s.profile_id is not null) order by p.name)
      from public.profiles p
      left join public.loyalty_staff s on s.profile_id = p.id
     where p.status = 'active' and p.role <> 'atasan'
  ), '[]'::json);
end;
$$;

-- Atasan: izinkan / cabut izin kasih stempel untuk 1 karyawan
create or replace function public.loyalty_set_staff(p_profile uuid, p_allowed boolean)
returns boolean
language plpgsql security definer
set search_path = ''
as $$
begin
  if not public.loyalty_is_manager() then raise exception 'not_manager'; end if;
  if coalesce(p_allowed, false) then
    if not exists (select 1 from public.profiles where id = p_profile and status = 'active' and role <> 'atasan') then
      raise exception 'invalid_staff';
    end if;
    insert into public.loyalty_staff (profile_id, granted_by) values (p_profile, (select auth.uid()))
    on conflict (profile_id) do nothing;
  else
    delete from public.loyalty_staff where profile_id = p_profile;
  end if;
  return coalesce(p_allowed, false);
end;
$$;

-- Hak akses fungsi
revoke execute on function
  public.loyalty_is_staff(), public.loyalty_is_manager(), public.loyalty_gen_code(),
  public.loyalty_card_json(public.loyalty_members), public.loyalty_join(text, text, boolean),
  public.loyalty_delete_me(uuid),
  public.loyalty_get_card(uuid), public.loyalty_lookup(text),
  public.loyalty_add_stamp(uuid, jsonb), public.loyalty_redeem(uuid),
  public.loyalty_report(date), public.loyalty_customer(uuid),
  public.loyalty_staff_list(), public.loyalty_set_staff(uuid, boolean)
from public, anon, authenticated;
grant execute on function public.loyalty_join(text, text, boolean) to anon, authenticated;
grant execute on function public.loyalty_delete_me(uuid)           to anon, authenticated;
grant execute on function public.loyalty_get_card(uuid)            to anon, authenticated;
grant execute on function public.loyalty_is_staff()                to authenticated;
grant execute on function public.loyalty_is_manager()              to authenticated;
grant execute on function public.loyalty_lookup(text)              to authenticated;
grant execute on function public.loyalty_add_stamp(uuid, jsonb)    to authenticated;
grant execute on function public.loyalty_redeem(uuid)              to authenticated;
grant execute on function public.loyalty_report(date)              to authenticated;
grant execute on function public.loyalty_customer(uuid)            to authenticated;
grant execute on function public.loyalty_staff_list()             to authenticated;
grant execute on function public.loyalty_set_staff(uuid, boolean) to authenticated;
