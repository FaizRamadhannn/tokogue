-- tokogue · skema awal
-- Jalankan sekali di Supabase: Dashboard → SQL Editor → paste file ini → Run.
-- Semua aturan bisnis (radius, jam shift, potongan telat, alur approval)
-- dicek di server lewat fungsi RPC, jadi tidak bisa diakali dari aplikasi.

create extension if not exists pgcrypto;

-- ============================================================
-- Tipe
-- ============================================================
create type public.role_t as enum ('karyawan', 'atasan', 'hr');
create type public.shift_t as enum ('pagi', 'malam');
create type public.account_status as enum ('pending', 'active', 'rejected');
create type public.task_status as enum ('baru', 'dikerjakan', 'review', 'revisi', 'selesai');
create type public.priority_t as enum ('rendah', 'sedang', 'tinggi');
create type public.recurrence_t as enum ('sekali', 'harian', 'mingguan');
create type public.request_type as enum ('cutiTahunan', 'izin', 'sakit', 'dinasLuar', 'lembur', 'koreksiAbsen');
create type public.request_status as enum ('menungguAtasan', 'menungguHr', 'disetujui', 'ditolak');

-- ============================================================
-- Pengaturan toko (satu baris)
-- ============================================================
create table public.settings (
  id int primary key default 1 check (id = 1),
  store_name text not null default 'tokogue · Toko Pusat',
  office_lat double precision not null default -6.175392,   -- GANTI ke koordinat toko
  office_lng double precision not null default 106.827153,  -- GANTI ke koordinat toko
  radius_m int not null default 100,
  penalty_per_5min int not null default 5000,
  annual_leave_days int not null default 12,
  timezone text not null default 'Asia/Jakarta'
);
insert into public.settings (id) values (1);

-- ============================================================
-- Karyawan
-- ============================================================
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null,
  nik text not null default '-',
  position text not null default '-',
  division text not null default 'Operasional',
  phone text not null unique,
  role public.role_t not null default 'karyawan',
  shift public.shift_t not null default 'pagi',
  manager_id uuid references public.profiles (id) on delete set null,
  joined_at date not null default current_date,
  status public.account_status not null default 'pending',
  device_id text,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Absensi
-- ============================================================
create table public.attendance (
  id bigint generated always as identity primary key,
  employee_id uuid not null references public.profiles (id) on delete cascade,
  work_date date not null,
  shift public.shift_t not null,
  check_in timestamptz,
  check_out timestamptz,
  distance_in int,
  distance_out int,
  selfie_in text,
  selfie_out text,
  late_minutes int not null default 0,
  penalty int not null default 0,
  is_correction boolean not null default false,
  created_at timestamptz not null default now(),
  unique (employee_id, work_date)
);
create index attendance_date_idx on public.attendance (work_date desc);

-- ============================================================
-- Tugas
-- ============================================================
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  assigner_id uuid not null references public.profiles (id) on delete cascade,
  deadline timestamptz not null,
  priority public.priority_t not null default 'sedang',
  status public.task_status not null default 'baru',
  recurrence public.recurrence_t not null default 'sekali',
  proof_note text,
  reminded boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.task_assignees (
  task_id uuid not null references public.tasks (id) on delete cascade,
  employee_id uuid not null references public.profiles (id) on delete cascade,
  primary key (task_id, employee_id)
);
create index task_assignees_emp_idx on public.task_assignees (employee_id);

create table public.task_proofs (
  id bigint generated always as identity primary key,
  task_id uuid not null references public.tasks (id) on delete cascade,
  kind text not null check (kind in ('foto', 'file')),
  path text not null,
  file_name text,
  uploaded_by uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.task_comments (
  id bigint generated always as identity primary key,
  task_id uuid not null references public.tasks (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

-- ============================================================
-- Cuti, izin, lembur, koreksi absen
-- ============================================================
create table public.requests (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.profiles (id) on delete cascade,
  type public.request_type not null,
  start_date date not null,
  end_date date not null,
  reason text not null,
  attachment text,
  status public.request_status not null default 'menungguAtasan',
  manager_decided_by uuid references public.profiles (id),
  hr_decided_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  check (end_date >= start_date)
);

-- ============================================================
-- Stok bahan
-- ============================================================
create table public.stock_items (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  unit text not null,
  qty numeric not null default 0 check (qty >= 0),
  min_qty numeric not null default 0,
  created_at timestamptz not null default now()
);

create table public.stock_logs (
  id bigint generated always as identity primary key,
  item_id uuid not null references public.stock_items (id) on delete cascade,
  by_id uuid not null references public.profiles (id) on delete cascade,
  delta numeric not null,
  note text not null default '',
  created_at timestamptz not null default now()
);

-- ============================================================
-- Pengumuman & notifikasi
-- ============================================================
create table public.announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  author_id uuid not null references public.profiles (id) on delete cascade,
  pinned boolean not null default false,
  color text not null default 'blue',
  created_at timestamptz not null default now()
);

create table public.announcement_reads (
  announcement_id uuid not null references public.announcements (id) on delete cascade,
  employee_id uuid not null references public.profiles (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (announcement_id, employee_id)
);

create table public.notifications (
  id bigint generated always as identity primary key,
  to_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  body text not null,
  kind text not null default 'info',
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index notifications_to_idx on public.notifications (to_id, created_at desc);

-- ============================================================
-- Fungsi bantu (dipakai di aturan akses)
-- ============================================================
create function public.my_role() returns public.role_t
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and status = 'active'
$$;

create function public.is_active() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and status = 'active')
$$;

create function public.is_manager_of(emp uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = emp and manager_id = auth.uid())
$$;

create function public.can_see_task(t uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select public.my_role() = 'hr'
      or exists (select 1 from public.tasks where id = t and assigner_id = auth.uid())
      or exists (select 1 from public.task_assignees where task_id = t and employee_id = auth.uid())
$$;

create function public.local_now() returns timestamp
language sql stable as $$
  select now() at time zone (select timezone from public.settings where id = 1)
$$;

create function public.notify(p_to uuid, p_title text, p_body text, p_kind text)
returns void language sql security definer set search_path = public as $$
  insert into public.notifications (to_id, title, body, kind) values (p_to, p_title, p_body, p_kind)
$$;

-- jarak dua titik GPS dalam meter (haversine)
create function public.distance_m(lat1 double precision, lng1 double precision,
                                  lat2 double precision, lng2 double precision)
returns int language sql immutable as $$
  select round(6371000 * 2 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) * power(sin(radians(lng2 - lng1) / 2), 2)
  )))::int
$$;

create function public.require_active() returns public.profiles
language plpgsql stable security definer set search_path = public as $$
declare me public.profiles;
begin
  select * into me from public.profiles where id = auth.uid();
  if me.id is null then raise exception 'Kamu belum login.'; end if;
  if me.status = 'pending' then raise exception 'Akun kamu masih menunggu approval HR.'; end if;
  if me.status = 'rejected' then raise exception 'Pendaftaran akun kamu ditolak HR.'; end if;
  return me;
end $$;

-- ============================================================
-- Daftar akun: profil dibuat otomatis saat sign up (status pending)
-- ============================================================
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  m jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  hr record;
begin
  insert into public.profiles (id, name, phone, position, status)
  values (
    new.id,
    coalesce(nullif(m ->> 'name', ''), 'Tanpa nama'),
    coalesce(nullif(m ->> 'phone', ''), new.id::text),
    coalesce(nullif(m ->> 'position', ''), '-'),
    'pending'
  );
  for hr in select id from public.profiles where role = 'hr' and status = 'active' loop
    perform public.notify(hr.id, 'Akun baru menunggu approval',
      coalesce(m ->> 'name', 'Seseorang') || ' mendaftar sebagai ' || coalesce(m ->> 'position', '-') || '.', 'account');
  end loop;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.approve_account(p_user uuid, p_ok boolean)
returns void language plpgsql security definer set search_path = public as $$
declare me public.profiles := public.require_active();
begin
  if me.role <> 'hr' then raise exception 'Hanya HR yang bisa approve akun.'; end if;
  update public.profiles
     set status = case when p_ok then 'active'::public.account_status else 'rejected' end,
         manager_id = coalesce(manager_id, (select id from public.profiles where role = 'atasan' and status = 'active' and manager_id is not null order by created_at limit 1))
   where id = p_user and status = 'pending';
  if not found then raise exception 'Akun tidak ditemukan atau sudah diproses.'; end if;
end $$;

-- 1 akun hanya untuk 1 HP: perangkat pertama yang login dikunci.
create function public.bind_device(p_device text)
returns void language plpgsql security definer set search_path = public as $$
declare me public.profiles := public.require_active();
begin
  if me.device_id is null then
    update public.profiles set device_id = p_device where id = me.id;
  elsif me.device_id <> p_device then
    raise exception 'Akun ini sudah terdaftar di HP lain. Minta HR untuk reset perangkat.';
  end if;
end $$;

create function public.reset_device(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me public.profiles := public.require_active();
begin
  if me.role <> 'hr' then raise exception 'Hanya HR yang bisa reset perangkat.'; end if;
  update public.profiles set device_id = null where id = p_user;
end $$;

-- ============================================================
-- Absensi
-- ============================================================
create function public.clock_in(p_lat double precision, p_lng double precision, p_selfie text)
returns public.attendance language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.require_active();
  s public.settings;
  t timestamp := public.local_now();
  d date := t::date;
  start_h int;
  end_h int;
  dist int;
  late int;
  rec public.attendance;
begin
  select * into s from public.settings where id = 1;
  if coalesce(trim(p_selfie), '') = '' then raise exception 'Ambil selfie dulu sebelum absen.'; end if;
  dist := public.distance_m(p_lat, p_lng, s.office_lat, s.office_lng);
  if dist > s.radius_m then
    raise exception 'Kamu di luar radius toko (% m dari % m).', dist, s.radius_m;
  end if;
  start_h := case me.shift when 'pagi' then 8 else 16 end;
  end_h := case me.shift when 'pagi' then 16 else 24 end;
  if t < d + make_interval(hours => start_h - 1) then
    raise exception 'Absen masuk baru bisa mulai %.00 (1 jam sebelum shift).', lpad((start_h - 1)::text, 2, '0');
  end if;
  if t >= d + make_interval(hours => end_h) then
    raise exception 'Shift kamu sudah selesai. Ajukan koreksi absen kalau kamu tadi masuk.';
  end if;
  if exists (select 1 from public.attendance where employee_id = me.id and work_date = d and check_in is not null) then
    raise exception 'Kamu sudah absen masuk hari ini.';
  end if;
  late := greatest(0, floor(extract(epoch from (t - (d + make_interval(hours => start_h)))) / 60))::int;
  insert into public.attendance (employee_id, work_date, shift, check_in, distance_in, selfie_in, late_minutes, penalty)
  values (me.id, d, me.shift, now(), dist, p_selfie, late, (late / 5) * s.penalty_per_5min)
  on conflict (employee_id, work_date) do update
    set check_in = excluded.check_in, distance_in = excluded.distance_in, selfie_in = excluded.selfie_in,
        late_minutes = excluded.late_minutes, penalty = excluded.penalty
  returning * into rec;
  if me.manager_id is not null then
    perform public.notify(me.manager_id, split_part(me.name, ' ', 1) || ' absen masuk',
      to_char(t, 'HH24.MI') || case when late > 0 then ' · telat ' || late || ' menit' else ' · tepat waktu' end, 'attendance');
  end if;
  return rec;
end $$;

create function public.clock_out(p_lat double precision, p_lng double precision, p_selfie text)
returns public.attendance language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.require_active();
  s public.settings;
  d date := public.local_now()::date;
  dist int;
  rec public.attendance;
begin
  select * into s from public.settings where id = 1;
  if coalesce(trim(p_selfie), '') = '' then raise exception 'Ambil selfie dulu sebelum absen.'; end if;
  dist := public.distance_m(p_lat, p_lng, s.office_lat, s.office_lng);
  if dist > s.radius_m then
    raise exception 'Kamu di luar radius toko (% m dari % m).', dist, s.radius_m;
  end if;
  select * into rec from public.attendance where employee_id = me.id and work_date = d;
  if rec.id is null or rec.check_in is null then raise exception 'Kamu belum absen masuk hari ini.'; end if;
  if rec.check_out is not null then raise exception 'Kamu sudah absen pulang hari ini.'; end if;
  update public.attendance set check_out = now(), distance_out = dist, selfie_out = p_selfie
   where id = rec.id returning * into rec;
  return rec;
end $$;

-- ============================================================
-- Tugas
-- ============================================================
create function public.create_task(p_title text, p_description text, p_assignees uuid[],
                                   p_deadline timestamptz, p_priority public.priority_t,
                                   p_recurrence public.recurrence_t)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.require_active();
  new_id uuid;
  a uuid;
begin
  if me.role <> 'atasan' then raise exception 'Hanya atasan yang bisa memberi tugas.'; end if;
  if coalesce(trim(p_title), '') = '' then raise exception 'Isi judul tugas dulu.'; end if;
  if coalesce(array_length(p_assignees, 1), 0) = 0 then raise exception 'Pilih minimal 1 penerima tugas.'; end if;
  foreach a in array p_assignees loop
    if not exists (select 1 from public.profiles where id = a and manager_id = me.id and status = 'active') then
      raise exception 'Tugas hanya bisa diberikan ke bawahan langsung.';
    end if;
  end loop;
  insert into public.tasks (title, description, assigner_id, deadline, priority, recurrence)
  values (trim(p_title), coalesce(p_description, ''), me.id, p_deadline, p_priority, p_recurrence)
  returning id into new_id;
  foreach a in array p_assignees loop
    insert into public.task_assignees values (new_id, a) on conflict do nothing;
    perform public.notify(a, 'Tugas baru dari ' || split_part(me.name, ' ', 1), trim(p_title), 'task');
  end loop;
  return new_id;
end $$;

create function public.start_task(p_task uuid)
returns void language plpgsql security definer set search_path = public as $$
declare me public.profiles := public.require_active();
begin
  if not exists (select 1 from public.task_assignees where task_id = p_task and employee_id = me.id) then
    raise exception 'Tugas ini bukan untuk kamu.';
  end if;
  update public.tasks set status = 'dikerjakan' where id = p_task and status = 'baru';
end $$;

create function public.submit_task(p_task uuid, p_note text)
returns void language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.require_active();
  t public.tasks;
begin
  select * into t from public.tasks where id = p_task;
  if not exists (select 1 from public.task_assignees where task_id = p_task and employee_id = me.id) then
    raise exception 'Tugas ini bukan untuk kamu.';
  end if;
  if t.status not in ('dikerjakan', 'revisi') then raise exception 'Tugas ini tidak sedang dikerjakan.'; end if;
  if not exists (select 1 from public.task_proofs where task_id = p_task and kind = 'foto')
     or not exists (select 1 from public.task_proofs where task_id = p_task and kind = 'file') then
    raise exception 'Upload minimal 1 foto dan 1 file bukti dulu.';
  end if;
  update public.tasks set status = 'review', proof_note = nullif(trim(coalesce(p_note, '')), '') where id = p_task;
  perform public.notify(t.assigner_id, 'Tugas menunggu review',
    split_part(me.name, ' ', 1) || ' menyelesaikan "' || t.title || '".', 'review');
end $$;

create function public.review_task(p_task uuid, p_approve boolean, p_note text)
returns void language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.require_active();
  t public.tasks;
  a uuid;
begin
  select * into t from public.tasks where id = p_task;
  if t.assigner_id is distinct from me.id then raise exception 'Hanya pemberi tugas yang bisa review.'; end if;
  if t.status <> 'review' then raise exception 'Tugas ini tidak sedang menunggu review.'; end if;
  if not p_approve and coalesce(trim(p_note), '') = '' then raise exception 'Tulis apa yang perlu direvisi.'; end if;
  update public.tasks set status = case when p_approve then 'selesai'::public.task_status else 'revisi' end where id = p_task;
  if coalesce(trim(p_note), '') <> '' then
    insert into public.task_comments (task_id, author_id, body) values (p_task, me.id, trim(p_note));
  end if;
  for a in select employee_id from public.task_assignees where task_id = p_task loop
    perform public.notify(a,
      case when p_approve then 'Tugas disetujui' else 'Tugas perlu revisi' end,
      case when p_approve then '"' || t.title || '" sudah selesai.' else '"' || t.title || '": ' || trim(p_note) end,
      case when p_approve then 'approved' else 'revision' end);
  end loop;
end $$;

-- ============================================================
-- Cuti, izin, lembur, koreksi absen
-- ============================================================
create function public.leave_used(p_emp uuid) returns int
language sql stable security definer set search_path = public as $$
  select coalesce(sum(end_date - start_date + 1), 0)::int
    from public.requests
   where employee_id = p_emp and type = 'cutiTahunan' and status <> 'ditolak'
     and extract(year from start_date) = extract(year from public.local_now())
$$;

create function public.submit_request(p_type public.request_type, p_start date, p_end date,
                                      p_reason text, p_attachment text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.require_active();
  s public.settings;
  today date := public.local_now()::date;
  days int := p_end - p_start + 1;
  new_id uuid;
begin
  select * into s from public.settings where id = 1;
  if p_end < p_start then raise exception 'Tanggal selesai harus setelah tanggal mulai.'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'Isi alasannya dulu.'; end if;
  if p_type = 'lembur' and p_start < today + 1 then
    raise exception 'Lembur harus diajukan paling lambat H-1.';
  end if;
  if p_type = 'koreksiAbsen' and p_start > today then
    raise exception 'Koreksi absen hanya untuk hari ini atau sebelumnya.';
  end if;
  if p_type = 'cutiTahunan' and days > s.annual_leave_days - public.leave_used(me.id) then
    raise exception 'Sisa cuti kamu tinggal % hari.', s.annual_leave_days - public.leave_used(me.id);
  end if;
  insert into public.requests (employee_id, type, start_date, end_date, reason, attachment)
  values (me.id, p_type, p_start,
          case when p_type in ('lembur', 'koreksiAbsen') then p_start else p_end end,
          trim(p_reason), nullif(p_attachment, ''))
  returning id into new_id;
  if me.manager_id is not null then
    perform public.notify(me.manager_id, 'Pengajuan baru',
      split_part(me.name, ' ', 1) || ' · ' || p_type::text || ' · ' || to_char(p_start, 'DD/MM'), 'request');
  end if;
  return new_id;
end $$;

create function public.decide_request(p_id uuid, p_ok boolean)
returns void language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.require_active();
  r public.requests;
  emp public.profiles;
  hr record;
begin
  select * into r from public.requests where id = p_id for update;
  if r.id is null then raise exception 'Pengajuan tidak ditemukan.'; end if;
  select * into emp from public.profiles where id = r.employee_id;

  if r.status = 'menungguAtasan' then
    if emp.manager_id is distinct from me.id then raise exception 'Hanya atasan langsung yang bisa memutuskan.'; end if;
    if not p_ok then
      update public.requests set status = 'ditolak', manager_decided_by = me.id where id = p_id;
    elsif r.type in ('cutiTahunan', 'sakit') then
      update public.requests set status = 'menungguHr', manager_decided_by = me.id where id = p_id;
      for hr in select id from public.profiles where role = 'hr' and status = 'active' loop
        perform public.notify(hr.id, 'Pengajuan perlu approval HR', split_part(emp.name, ' ', 1) || ' · ' || r.type::text, 'request');
      end loop;
      return;
    else
      update public.requests set status = 'disetujui', manager_decided_by = me.id where id = p_id;
    end if;
  elsif r.status = 'menungguHr' then
    if me.role <> 'hr' then raise exception 'Pengajuan ini menunggu keputusan HR.'; end if;
    update public.requests
       set status = case when p_ok then 'disetujui'::public.request_status else 'ditolak' end,
           hr_decided_by = me.id
     where id = p_id;
  else
    raise exception 'Pengajuan ini sudah diproses.';
  end if;

  -- koreksi absen yang disetujui → isi absen hari itu sesuai jam shift
  if p_ok and r.type = 'koreksiAbsen' then
    insert into public.attendance (employee_id, work_date, shift, check_in, check_out, is_correction)
    values (emp.id, r.start_date, emp.shift,
            (r.start_date + make_interval(hours => case emp.shift when 'pagi' then 8 else 16 end))
              at time zone (select timezone from public.settings where id = 1),
            (r.start_date + make_interval(hours => case emp.shift when 'pagi' then 16 else 24 end))
              at time zone (select timezone from public.settings where id = 1),
            true)
    on conflict (employee_id, work_date) do update
      set check_in = coalesce(public.attendance.check_in, excluded.check_in),
          check_out = coalesce(public.attendance.check_out, excluded.check_out),
          is_correction = true;
  end if;

  perform public.notify(r.employee_id,
    case when p_ok then 'Pengajuan disetujui' else 'Pengajuan ditolak' end,
    r.type::text || ' ' || to_char(r.start_date, 'DD/MM'),
    case when p_ok then 'approved' else 'rejected' end);
end $$;

-- ============================================================
-- Stok bahan
-- ============================================================
create function public.adjust_stock(p_item uuid, p_delta numeric, p_note text)
returns public.stock_items language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.require_active();
  it public.stock_items;
  boss record;
begin
  if me.role <> 'atasan' then raise exception 'Hanya atasan yang bisa update stok.'; end if;
  if p_delta = 0 then raise exception 'Isi jumlah yang valid.'; end if;
  update public.stock_items set qty = greatest(0, qty + p_delta) where id = p_item returning * into it;
  if it.id is null then raise exception 'Bahan tidak ditemukan.'; end if;
  insert into public.stock_logs (item_id, by_id, delta, note) values (p_item, me.id, p_delta, coalesce(p_note, ''));
  if it.qty <= it.min_qty then
    for boss in select id from public.profiles where role = 'atasan' and status = 'active' loop
      perform public.notify(boss.id, 'Stok ' || it.name || ' menipis',
        'Sisa ' || trim(to_char(it.qty, 'FM999990.##')) || ' ' || it.unit || ' (minimum ' || trim(to_char(it.min_qty, 'FM999990.##')) || ')', 'stock');
    end loop;
  end if;
  return it;
end $$;

create function public.add_stock_item(p_name text, p_unit text, p_qty numeric, p_min numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.require_active();
  new_id uuid;
begin
  if me.role <> 'atasan' then raise exception 'Hanya atasan yang bisa menambah bahan.'; end if;
  insert into public.stock_items (name, unit, qty, min_qty) values (trim(p_name), trim(p_unit), p_qty, p_min)
  returning id into new_id;
  insert into public.stock_logs (item_id, by_id, delta, note) values (new_id, me.id, p_qty, 'Stok awal');
  return new_id;
end $$;

-- ============================================================
-- Pengumuman & notifikasi
-- ============================================================
create function public.post_announcement(p_title text, p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  me public.profiles := public.require_active();
  new_id uuid;
  e record;
begin
  if me.role not in ('hr', 'atasan') then raise exception 'Hanya HR atau atasan yang bisa membuat pengumuman.'; end if;
  insert into public.announcements (title, body, author_id) values (trim(p_title), trim(p_body), me.id)
  returning id into new_id;
  insert into public.announcement_reads (announcement_id, employee_id) values (new_id, me.id);
  for e in select id from public.profiles where status = 'active' and id <> me.id loop
    perform public.notify(e.id, 'Pengumuman baru', trim(p_title), 'announcement');
  end loop;
  return new_id;
end $$;

-- Pengingat deadline 10 jam sebelumnya. Jadwalkan tiap 15 menit lewat
-- Supabase → Integrations → Cron: select public.send_deadline_reminders();
create function public.send_deadline_reminders()
returns int language plpgsql security definer set search_path = public as $$
declare
  t record;
  n int := 0;
begin
  for t in
    select * from public.tasks
     where status in ('baru', 'dikerjakan', 'revisi') and not reminded
       and deadline <= now() + interval '10 hours' and deadline > now()
  loop
    perform public.notify(a.employee_id, 'Deadline 10 jam lagi', t.title, 'task')
      from public.task_assignees a where a.task_id = t.id;
    update public.tasks set reminded = true where id = t.id;
    n := n + 1;
  end loop;
  return n;
end $$;

-- ============================================================
-- Aturan akses (Row Level Security)
-- Tulis data penting hanya lewat fungsi di atas.
-- ============================================================
alter table public.settings enable row level security;
alter table public.profiles enable row level security;
alter table public.attendance enable row level security;
alter table public.tasks enable row level security;
alter table public.task_assignees enable row level security;
alter table public.task_proofs enable row level security;
alter table public.task_comments enable row level security;
alter table public.requests enable row level security;
alter table public.stock_items enable row level security;
alter table public.stock_logs enable row level security;
alter table public.announcements enable row level security;
alter table public.announcement_reads enable row level security;
alter table public.notifications enable row level security;

create policy "settings dibaca semua karyawan" on public.settings
  for select to authenticated using (public.is_active());
create policy "HR ubah settings" on public.settings
  for update to authenticated using (public.my_role() = 'hr') with check (public.my_role() = 'hr');

create policy "lihat profil sendiri" on public.profiles
  for select to authenticated using (id = auth.uid());
create policy "karyawan aktif saling lihat" on public.profiles
  for select to authenticated using (public.is_active() and status = 'active');
create policy "HR lihat semua profil" on public.profiles
  for select to authenticated using (public.my_role() = 'hr');
create policy "HR ubah profil" on public.profiles
  for update to authenticated using (public.my_role() = 'hr') with check (public.my_role() = 'hr');

create policy "lihat absen sendiri, tim, atau HR" on public.attendance
  for select to authenticated
  using (employee_id = auth.uid() or public.is_manager_of(employee_id) or public.my_role() = 'hr');

create policy "lihat tugas terkait" on public.tasks
  for select to authenticated using (public.can_see_task(id));
create policy "lihat penerima tugas" on public.task_assignees
  for select to authenticated using (public.can_see_task(task_id));
create policy "lihat bukti tugas" on public.task_proofs
  for select to authenticated using (public.can_see_task(task_id));
create policy "penerima upload bukti" on public.task_proofs
  for insert to authenticated
  with check (
    uploaded_by = auth.uid()
    and exists (select 1 from public.task_assignees a join public.tasks t on t.id = a.task_id
                 where a.task_id = task_proofs.task_id and a.employee_id = auth.uid()
                   and t.status in ('dikerjakan', 'revisi'))
  );
create policy "lihat komentar" on public.task_comments
  for select to authenticated using (public.can_see_task(task_id));
create policy "tulis komentar" on public.task_comments
  for insert to authenticated with check (author_id = auth.uid() and public.can_see_task(task_id));

create policy "lihat pengajuan sendiri, tim, atau HR" on public.requests
  for select to authenticated
  using (employee_id = auth.uid() or public.is_manager_of(employee_id) or public.my_role() = 'hr');

create policy "lihat stok" on public.stock_items
  for select to authenticated using (public.is_active());
create policy "lihat riwayat stok" on public.stock_logs
  for select to authenticated using (public.is_active());

create policy "lihat pengumuman" on public.announcements
  for select to authenticated using (public.is_active());
create policy "lihat status baca" on public.announcement_reads
  for select to authenticated
  using (employee_id = auth.uid() or public.my_role() in ('hr', 'atasan'));
create policy "tandai dibaca" on public.announcement_reads
  for insert to authenticated with check (employee_id = auth.uid() and public.is_active());

create policy "lihat notifikasi sendiri" on public.notifications
  for select to authenticated using (to_id = auth.uid());
create policy "tandai notifikasi dibaca" on public.notifications
  for update to authenticated using (to_id = auth.uid()) with check (to_id = auth.uid());

-- Fungsi bantu tidak boleh dipanggil dari luar
revoke execute on function public.notify(uuid, text, text, text) from public, anon, authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.send_deadline_reminders() from public, anon, authenticated;

-- ============================================================
-- Penyimpanan file: selfie, bukti tugas, lampiran
-- File disimpan di folder <id user>/...
-- ============================================================
insert into storage.buckets (id, name, public) values
  ('selfies', 'selfies', false),
  ('task-proofs', 'task-proofs', false),
  ('attachments', 'attachments', false)
on conflict (id) do nothing;

create policy "upload ke folder sendiri" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('selfies', 'task-proofs', 'attachments')
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.is_active()
  );

create policy "lihat file sendiri atau sebagai atasan/HR" on storage.objects
  for select to authenticated
  using (
    bucket_id in ('selfies', 'task-proofs', 'attachments')
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.my_role() in ('atasan', 'hr')
    )
  );

-- ============================================================
-- Realtime: app langsung refresh saat ada notifikasi baru
-- ============================================================
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
