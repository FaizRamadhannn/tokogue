-- tokogue · data demo (opsional)
-- Jalankan SETELAH 0001_init.sql. Membuat 6 akun dengan password demo123.
-- Login di app pakai nomor HP. Di belakang layar, nomor HP diubah jadi email
-- <nomor>@tokogue.app karena Supabase butuh email untuk login password.
-- Ganti password akun-akun ini (atau hapus) sebelum dipakai sungguhan.

do $$
declare
  u record;
  uid uuid;
begin
  for u in
    select * from (values
      ('c1', 'Hendra Wijaya',  '081200000001', 'Owner / CEO',   'Manajemen',   'atasan'::public.role_t,   'pagi'::public.shift_t,  date '2021-01-04', '3201000001'),
      ('m1', 'Dimas Aditya',   '081200000002', 'Manager Toko',  'Operasional', 'atasan'::public.role_t,   'pagi'::public.shift_t,  date '2022-03-01', '3201000002'),
      ('h1', 'Nadia Putri',    '081200000003', 'Staf HR',       'HR',          'hr'::public.role_t,       'pagi'::public.shift_t,  date '2022-07-11', '3201000003'),
      ('e1', 'Budi Santoso',   '081200000004', 'Barista',       'Operasional', 'karyawan'::public.role_t, 'pagi'::public.shift_t,  date '2023-02-06', '3201000004'),
      ('e2', 'Sari Wulandari', '081200000005', 'Kasir',         'Operasional', 'karyawan'::public.role_t, 'malam'::public.shift_t, date '2023-09-18', '3201000005'),
      ('e3', 'Rizky Pratama',  '081200000006', 'Staf Lapangan', 'Operasional', 'karyawan'::public.role_t, 'pagi'::public.shift_t,  date '2024-05-02', '3201000006')
    ) as t(code, name, phone, position, division, role, shift, joined, nik)
  loop
    if exists (select 1 from auth.users where email = u.phone || '@tokogue.app') then
      continue;
    end if;
    uid := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
      u.phone || '@tokogue.app', crypt('demo123', gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('name', u.name, 'phone', u.phone, 'position', u.position),
      now(), now(), '', '', '', ''
    );
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), uid, uid::text,
            jsonb_build_object('sub', uid::text, 'email', u.phone || '@tokogue.app', 'email_verified', true),
            'email', now(), now(), now());
    update public.profiles
       set role = u.role, shift = u.shift, division = u.division, nik = u.nik,
           joined_at = u.joined, status = 'active'
     where id = uid;
  end loop;

  -- struktur atasan
  update public.profiles set manager_id = (select id from public.profiles where phone = '081200000001')
   where phone in ('081200000002', '081200000003');
  update public.profiles set manager_id = (select id from public.profiles where phone = '081200000002')
   where phone in ('081200000004', '081200000005', '081200000006');
end $$;

-- notifikasi "akun baru" dari trigger tidak perlu untuk akun demo
delete from public.notifications where kind = 'account';

insert into public.stock_items (name, unit, qty, min_qty) values
  ('Biji kopi arabika', 'kg', 3.5, 5),
  ('Susu UHT', 'liter', 42, 20),
  ('Gula aren cair', 'liter', 6, 4),
  ('Cup plastik 16 oz', 'pcs', 180, 200),
  ('Es batu kristal', 'kg', 25, 10),
  ('Sirup vanila', 'botol', 4, 2)
on conflict (name) do nothing;

insert into public.announcements (title, body, author_id, pinned, color)
select 'Absen sekarang lewat aplikasi',
       'Mulai hari ini absen lewat grup WA tidak dipakai lagi. Absen masuk dan pulang wajib lewat aplikasi dengan selfie di area toko (radius 100 m).',
       id, true, 'green'
  from public.profiles where phone = '081200000003'
   and not exists (select 1 from public.announcements);

insert into public.tasks (title, description, assigner_id, deadline, priority, recurrence)
select 'Stock opname bahan mingguan',
       'Hitung semua bahan di gudang dan laporkan angkanya. Upload foto rak dan file rekap.',
       id, now() + interval '3 days', 'sedang', 'mingguan'
  from public.profiles where phone = '081200000002'
   and not exists (select 1 from public.tasks);

insert into public.task_assignees (task_id, employee_id)
select t.id, p.id from public.tasks t, public.profiles p
 where t.title = 'Stock opname bahan mingguan' and p.phone = '081200000004'
on conflict do nothing;
