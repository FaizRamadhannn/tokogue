# tokogue

Aplikasi kerja karyawan: absensi (GPS + selfie), tugas dari atasan, cuti/izin/lembur,
koreksi absen, stok bahan, pengumuman, dan rekap absen untuk HR. Flutter + Supabase,
sesuai PRD v0.1.

App punya dua mode:

- **Live** (bawaan) — data tersimpan di Supabase, login asli, GPS & kamera asli.
- **Demo** — data contoh di memori (reset tiap dibuka), lokasi & selfie disimulasikan.
  Aktif kalau build dengan `--dart-define=DEMO=true`.

## Setup Supabase (sekali saja)

Project: `https://sinxdbpbmodmtxzphgyx.supabase.co`

1. **Buat tabel & aturan.** Dashboard → SQL Editor → paste isi
   `supabase/migrations/0001_init.sql` → Run.
2. **(Opsional) Isi akun demo.** Paste `supabase/seed_demo.sql` → Run. Membuat 6 akun
   dengan password `demo123` (lihat tabel di bawah). Ganti/hapus sebelum dipakai sungguhan.
3. **Nyalakan login Email, matikan konfirmasi.** Authentication → Sign In / Providers →
   Email → nyalakan **Enable Email provider**, lalu matikan **Confirm email**. Login pakai nomor HP yang diubah jadi email palsu
   `<nomor>@tokogue.app`, jadi email konfirmasi tidak akan pernah sampai.
4. **Set lokasi toko.** Di SQL Editor (ganti angka dengan koordinat toko dari Google Maps):
   ```sql
   update public.settings set office_lat = -6.2, office_lng = 106.8, store_name = 'tokogue · Toko Pusat' where id = 1;
   ```
5. **(Opsional) Pengingat deadline.** Integrations → Cron → job baru tiap 15 menit:
   `select public.send_deadline_reminders();`
6. Publishable key sudah tersimpan di `lib/config.dart`.

Akun demo (setelah langkah 2):

| Nama | Role | No. HP |
| --- | --- | --- |
| Hendra Wijaya | Owner (atasan Dimas & Nadia) | 081200000001 |
| Dimas Aditya | Atasan / Manager Toko | 081200000002 |
| Nadia Putri | HR | 081200000003 |
| Budi Santoso | Karyawan (shift pagi) | 081200000004 |
| Sari Wulandari | Karyawan (shift malam) | 081200000005 |
| Rizky Pratama | Karyawan (shift pagi) | 081200000006 |

## Menjalankan

Flutter ada di `~/development/flutter`:

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
```

Web, terhubung ke Supabase:

```bash
flutter build web && node tool/serve_web.mjs 8090
```

HP Android/iPhone (perlu Android Studio atau Xcode):

```bash
flutter run
```

Mode demo: tambahkan `--dart-define=DEMO=true`.

## Versi web untuk HP

Live di **https://tokogue-sigma.vercel.app** (project Vercel `tokogue`). Buka di Chrome HP →
menu ⋮ → **Tambahkan ke layar utama**.

Deploy otomatis: setiap push ke branch `main` di GitHub
(`FaizRamadhannn/tokogue`) langsung di-build dan di-deploy oleh Vercel. Cara build-nya
(pasang Flutter 3.47.8 lalu `flutter build web`) diatur di `vercel.json`.

```bash
git add -A && git commit -m "pesan perubahan" && git push
```

## Tes

```bash
flutter test
```

Tes database (jalan di Postgres lokal via PGlite, tidak menyentuh Supabase):

```bash
cd supabase/tests && npm install && npm test
```

## Aturan yang dicek di server

| Aturan | Fungsi |
| --- | --- |
| Absen hanya dalam radius toko (default 100 m), wajib selfie | `clock_in`, `clock_out` |
| Absen masuk mulai 1 jam sebelum shift sampai shift selesai | `clock_in` |
| Telat dihitung server, Rp5.000 per 5 menit | `clock_in` |
| 1 akun hanya di 1 HP (HR bisa reset) | `bind_device`, `reset_device` |
| Tugas hanya ke bawahan langsung; kirim hasil wajib foto + file | `create_task`, `submit_task` |
| Cuti & sakit: atasan lalu HR; lainnya cukup atasan | `decide_request` |
| Lembur paling lambat H-1; cuti tidak boleh lewat sisa kuota | `submit_request` |
| Koreksi absen yang disetujui otomatis mengisi absen hari itu | `decide_request` |
| Stok hanya diubah atasan; notifikasi saat di bawah minimum | `adjust_stock` |
| Akun daftar sendiri berstatus pending sampai di-approve HR | trigger + `approve_account` |

Semua tabel memakai Row Level Security: karyawan hanya melihat datanya sendiri, atasan
melihat timnya, HR melihat semua.

## Struktur

- `lib/config.dart` — URL & key Supabase
- `lib/data/backend.dart` — komunikasi dengan Supabase
- `lib/data/app_state.dart` — pusat data & aksi (mode demo + live)
- `lib/screens/` — semua layar
- `supabase/migrations/` — skema database
- `supabase/tests/` — tes SQL

## Belum dikerjakan

- Push notification ke HP (sekarang notifikasi muncul di Inbox, realtime saat app terbuka)
- Lihat foto selfie / bukti tugas langsung di app (file sudah tersimpan di Storage)
- Export rekap ke Excel/PDF
- Fase 2: chat, slip gaji, reimbursement
