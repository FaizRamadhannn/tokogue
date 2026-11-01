import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import { readFileSync } from 'node:fs';

const dir = process.argv[2];
const db = new PGlite({ extensions: { pgcrypto } });

// Tiruan bagian khusus Supabase
await db.exec(`
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users (
  instance_id uuid, id uuid primary key, aud text, role text, email text unique,
  encrypted_password text, email_confirmed_at timestamptz,
  raw_app_meta_data jsonb, raw_user_meta_data jsonb,
  created_at timestamptz, updated_at timestamptz,
  confirmation_token text, recovery_token text, email_change_token_new text, email_change text
);
create table auth.identities (
  id uuid primary key, user_id uuid, provider_id text, identity_data jsonb, provider text,
  last_sign_in_at timestamptz, created_at timestamptz, updated_at timestamptz
);
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create schema storage;
create table storage.buckets (id text primary key, name text, public boolean);
create table storage.objects (id uuid default gen_random_uuid(), bucket_id text, name text, owner uuid);
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language sql immutable as
  $$ select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1] $$;
grant usage on schema auth, storage to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
`);

const mig = readFileSync(`${dir}/supabase/migrations/0001_init.sql`, 'utf8');
await db.exec(mig);
console.log('✓ migrasi jalan');
await db.exec(`
grant usage on schema public to authenticated, anon;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant select, insert on storage.objects to authenticated;
`);
await db.exec(readFileSync(`${dir}/supabase/seed_demo.sql`, 'utf8'));
await db.exec(readFileSync(`${dir}/supabase/seed_demo.sql`, 'utf8')); // harus aman dijalankan 2x
console.log('✓ seed jalan (2x)');

// waktu lokal dibuat tetap supaya tes tidak tergantung jam
await db.exec(`create or replace function public.local_now() returns timestamp language sql stable as $$ select '2026-10-29 08:12'::timestamp $$;`);

const ids = Object.fromEntries((await db.query(`select phone, id from public.profiles`)).rows.map((r) => [r.phone, r.id]));
const BUDI = ids['081200000004'], SARI = ids['081200000005'], DIMAS = ids['081200000002'], NADIA = ids['081200000003'], HENDRA = ids['081200000001'];

let failed = 0;
async function as(uid, sql, params = []) {
  await db.exec(`reset role; select set_config('request.jwt.claim.sub', '${uid}', false); set role authenticated;`);
  try {
    return await db.query(sql, params);
  } finally {
    await db.exec('reset role;');
  }
}
async function ok(name, uid, sql, params) {
  try {
    const r = await as(uid, sql, params);
    console.log('✓', name);
    return r;
  } catch (e) {
    failed++;
    console.log('✗', name, '→', e.message);
  }
}
async function err(name, uid, sql, expect, params) {
  try {
    await as(uid, sql, params);
    failed++;
    console.log('✗', name, '→ seharusnya error');
  } catch (e) {
    if (expect && !e.message.includes(expect)) {
      failed++;
      console.log('✗', name, '→ error lain:', e.message);
    } else console.log('✓', name, `(${e.message})`);
  }
}
function eq(name, a, b) {
  if (JSON.stringify(a) === JSON.stringify(b)) console.log('✓', name);
  else { failed++; console.log('✗', name, '→', a, '!=', b); }
}

// koordinat default toko di settings
const [LAT, LNG] = [-6.175392, 106.827153];
const FAR = [-6.18, 106.83];

// --- Absensi
await err('absen di luar radius ditolak', BUDI, `select public.clock_in($1,$2,'x/s.jpg')`, 'luar radius', FAR);
await err('absen tanpa selfie ditolak', BUDI, `select public.clock_in($1,$2,'')`, 'selfie', [LAT, LNG]);
const ci = await ok('absen masuk 08.12', BUDI, `select * from public.clock_in($1,$2,'${BUDI}/in.jpg')`, [LAT, LNG]);
eq('telat 12 menit, potongan 10.000', [ci?.rows[0].late_minutes, ci?.rows[0].penalty], [12, 10000]);
await err('absen masuk 2x ditolak', BUDI, `select public.clock_in($1,$2,'a')`, 'sudah absen', [LAT, LNG]);
await err('shift malam belum buka jam 08.12', SARI, `select public.clock_in($1,$2,'a')`, 'baru bisa mulai', [LAT, LNG]);
await ok('absen pulang', BUDI, `select public.clock_out($1,$2,'${BUDI}/out.jpg')`, [LAT, LNG]);
eq('Dimas dapat notif absen Budi', (await as(DIMAS, `select count(*)::int c from public.notifications where kind='attendance'`)).rows[0].c, 1);
eq('Sari tidak bisa lihat absen Budi', (await as(SARI, `select count(*)::int c from public.attendance`)).rows[0].c, 0);
eq('Dimas lihat absen tim', (await as(DIMAS, `select count(*)::int c from public.attendance`)).rows[0].c, 1);
eq('HR lihat semua absen', (await as(NADIA, `select count(*)::int c from public.attendance`)).rows[0].c, 1);
const upd = await as(BUDI, `update public.attendance set penalty = 0`);
eq('update langsung tidak mengubah apa pun', upd.affectedRows ?? 0, 0);

// --- Tugas
await err('karyawan tidak bisa buat tugas', BUDI, `select public.create_task('x','',array[$1]::uuid[], now()+interval '1 day','sedang','sekali')`, 'Hanya atasan', [SARI]);
await err('atasan tidak bisa kasih tugas ke bukan bawahan', HENDRA, `select public.create_task('x','',array[$1]::uuid[], now()+interval '1 day','sedang','sekali')`, 'bawahan langsung', [BUDI]);
const ct = await ok('Dimas buat tugas untuk Budi', DIMAS, `select public.create_task('Bersihkan mesin','Foto hasilnya',array[$1]::uuid[], now()+interval '5 hours','tinggi','harian') id`, [BUDI]);
const TASK = ct?.rows[0].id;
eq('Sari tidak lihat tugas Budi', (await as(SARI, `select count(*)::int c from public.tasks where id=$1`, [TASK])).rows[0].c, 0);
await ok('Budi mulai tugas', BUDI, `select public.start_task($1)`, [TASK]);
await err('kirim tanpa bukti ditolak', BUDI, `select public.submit_task($1,'')`, 'foto dan 1 file', [TASK]);
await err('Sari tidak bisa upload bukti tugas Budi', SARI, `insert into public.task_proofs (task_id, kind, path, uploaded_by) values ($1,'foto','x',$2)`, null, [TASK, SARI]);
await ok('Budi upload foto', BUDI, `insert into public.task_proofs (task_id, kind, path, uploaded_by) values ($1,'foto','${BUDI}/a.jpg',$2)`, [TASK, BUDI]);
await ok('Budi upload file', BUDI, `insert into public.task_proofs (task_id, kind, path, uploaded_by) values ($1,'file','${BUDI}/a.pdf',$2)`, [TASK, BUDI]);
await ok('Budi kirim hasil', BUDI, `select public.submit_task($1,'sudah')`, [TASK]);
await err('revisi tanpa catatan ditolak', DIMAS, `select public.review_task($1,false,'')`, 'perlu direvisi', [TASK]);
await ok('Dimas minta revisi', DIMAS, `select public.review_task($1,false,'kurang bersih')`, [TASK]);
await ok('Budi komentar', BUDI, `insert into public.task_comments (task_id, author_id, body) values ($1,$2,'oke pak')`, [TASK, BUDI]);
await ok('Budi kirim ulang', BUDI, `select public.submit_task($1,'sudah diulang')`, [TASK]);
await ok('Dimas setujui', DIMAS, `select public.review_task($1,true,'')`, [TASK]);
eq('status tugas selesai', (await db.query(`select status from public.tasks where id=$1`, [TASK])).rows[0].status, 'selesai');
const remind = await db.query(`select public.send_deadline_reminders() n`);
eq('pengingat deadline jalan', typeof remind.rows[0].n, 'number');

// --- Pengajuan
const today = '2026-10-29';
await err('lembur hari ini ditolak (H-1)', BUDI, `select public.submit_request('lembur',$1,$1,'bantu','')`, 'H-1', [today]);
await err('cuti 20 hari ditolak (kuota)', BUDI, `select public.submit_request('cutiTahunan','2026-11-01','2026-11-20','liburan','')`, 'Sisa cuti', []);
const rq = await ok('Budi ajukan cuti 2 hari', BUDI, `select public.submit_request('cutiTahunan','2026-11-08','2026-11-09','acara keluarga','') id`);
const REQ = rq?.rows[0].id;
await err('Sari tidak bisa approve', SARI, `select public.decide_request($1,true)`, 'atasan langsung', [REQ]);
await err('HR belum bisa approve sebelum atasan', NADIA, `select public.decide_request($1,true)`, 'atasan langsung', [REQ]);
await ok('Dimas setujui → ke HR', DIMAS, `select public.decide_request($1,true)`, [REQ]);
eq('status menunggu HR', (await db.query(`select status from public.requests where id=$1`, [REQ])).rows[0].status, 'menungguHr');
await err('Dimas tidak bisa approve tahap HR', DIMAS, `select public.decide_request($1,true)`, 'keputusan HR', [REQ]);
await ok('Nadia setujui', NADIA, `select public.decide_request($1,true)`, [REQ]);
eq('sisa cuti Budi 10', (await db.query(`select 12 - public.leave_used($1) s`, [BUDI])).rows[0].s, 10);
const kr = await ok('Sari ajukan koreksi absen kemarin', SARI, `select public.submit_request('koreksiAbsen','2026-10-28','2026-10-28','sinyal hilang','') id`);
await ok('Dimas setujui koreksi', DIMAS, `select public.decide_request($1,true)`, [kr?.rows[0].id]);
eq('absen Sari 28 Okt terisi koreksi', (await db.query(`select is_correction from public.attendance where employee_id=$1 and work_date='2026-10-28'`, [SARI])).rows[0]?.is_correction, true);

// --- Stok
const item = (await db.query(`select id from public.stock_items where name='Susu UHT'`)).rows[0].id;
await err('karyawan tidak bisa update stok', BUDI, `select public.adjust_stock($1,-5,'x')`, 'Hanya atasan', [item]);
await ok('Dimas pakai 25 liter susu', DIMAS, `select public.adjust_stock($1,-25,'shift pagi')`, [item]);
eq('stok susu 17 dan dapat notif menipis', [
  Number((await db.query(`select qty from public.stock_items where id=$1`, [item])).rows[0].qty),
  (await as(DIMAS, `select count(*)::int c from public.notifications where kind='stock'`)).rows[0].c,
], [17, 1]);
await ok('Dimas tambah bahan baru', DIMAS, `select public.add_stock_item('Teh melati','kg',2,1)`);

// --- Pengumuman & notifikasi
await err('karyawan tidak bisa bikin pengumuman', BUDI, `select public.post_announcement('a','b')`, 'Hanya HR');
await ok('Nadia bikin pengumuman', NADIA, `select public.post_announcement('Rapat Senin','Jam 9 pagi')`);
await ok('Budi tandai dibaca', BUDI, `insert into public.announcement_reads (announcement_id, employee_id) select id, $1 from public.announcements where title='Rapat Senin'`, [BUDI]);
await err('Budi tidak bisa tandai dibaca atas nama Sari', BUDI, `insert into public.announcement_reads (announcement_id, employee_id) select id, $1 from public.announcements where title='Rapat Senin'`, null, [SARI]);
eq('Budi cuma lihat notifikasinya sendiri', (await as(BUDI, `select count(*)::int c from public.notifications where to_id <> $1`, [BUDI])).rows[0].c, 0);
await ok('Budi tandai notif dibaca', BUDI, `update public.notifications set read = true where to_id = $1`, [BUDI]);

// --- Akun & profil
const upd2 = await as(BUDI, `update public.profiles set role='hr' where id=$1`, [BUDI]);
eq('karyawan tidak bisa ubah role sendiri', upd2.affectedRows ?? 0, 0);
await db.exec(`insert into auth.users (id, email, raw_user_meta_data) values ('11111111-1111-1111-1111-111111111111','081299990000@tokogue.app','{"name":"Andi Baru","phone":"081299990000","position":"Barista"}')`);
const NEWU = '11111111-1111-1111-1111-111111111111';
eq('daftar → profil pending', (await db.query(`select status from public.profiles where id=$1`, [NEWU])).rows[0].status, 'pending');
await err('akun pending tidak bisa absen', NEWU, `select public.clock_in($1,$2,'a')`, 'menunggu approval', [LAT, LNG]);
eq('akun pending tidak lihat karyawan lain', (await as(NEWU, `select count(*)::int c from public.profiles`)).rows[0].c, 1);
await err('karyawan tidak bisa approve akun', BUDI, `select public.approve_account($1,true)`, 'Hanya HR', [NEWU]);
await ok('HR aktifkan akun', NADIA, `select public.approve_account($1,true)`, [NEWU]);
eq('akun baru aktif + punya atasan', (await db.query(`select status, manager_id is not null m from public.profiles where id=$1`, [NEWU])).rows[0], { status: 'active', m: true });
await ok('kunci perangkat pertama', BUDI, `select public.bind_device('hp-1')`);
await ok('perangkat yang sama boleh', BUDI, `select public.bind_device('hp-1')`);
await err('HP lain ditolak', BUDI, `select public.bind_device('hp-2')`, 'HP lain');
await ok('HR reset perangkat', NADIA, `select public.reset_device($1)`, [BUDI]);
await err('fungsi notify tidak bisa dipanggil langsung', BUDI, `select public.notify($1,'x','y','z')`, 'permission', [BUDI]);

// --- Storage
await ok('upload selfie ke folder sendiri', BUDI, `insert into storage.objects (bucket_id, name) values ('selfies', $1)`, [`${BUDI}/2026-10-29-in.jpg`]);
await err('upload ke folder orang lain ditolak', BUDI, `insert into storage.objects (bucket_id, name) values ('selfies', $1)`, null, [`${SARI}/x.jpg`]);

console.log(failed ? `\n${failed} TES GAGAL` : '\nSEMUA TES SQL LOLOS');
process.exit(failed ? 1 : 0);
