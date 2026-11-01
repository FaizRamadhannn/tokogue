import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme.dart';
import 'backend.dart';
import 'format.dart';
import 'models.dart';

/// Pusat data app.
///
/// - Mode demo (`backend == null`): data contoh di memori, reset tiap app dibuka.
/// - Mode live: data dari Supabase; aturan bisnis dicek di server.
///
/// Semua aksi mengembalikan pesan error (String) atau null kalau berhasil.
class AppState extends ChangeNotifier {
  AppState({this.backend}) {
    if (backend == null) _seed();
  }

  final Backend? backend;
  bool get isLive => backend != null;

  // Pengaturan toko (di mode live diambil dari tabel settings)
  String storeName = 'tokogue · Toko Pusat';
  double officeLat = -6.175392;
  double officeLng = 106.827153;
  int radius = 100; // meter, sesuai PRD
  int annualLeave = 12; // hari per tahun

  final List<Employee> employees = [];
  final List<TaskItem> tasks = [];
  final List<AttendanceRecord> attendance = [];
  final List<LeaveRequest> requests = [];
  final List<StockItem> stock = [];
  final List<Announcement> announcements = [];
  final List<AppNotification> notifications = [];
  final List<Employee> pendingAccounts = [];

  Employee? me;
  bool loading = false;
  int _seq = 100;
  String _id(String p) => '$p${_seq++}';

  // ---------- Mode live: muat ulang & bungkus aksi ----------

  Future<void> refresh() async {
    final b = backend;
    if (b == null) return;
    final s = await b.load();
    storeName = s.storeName;
    officeLat = s.officeLat;
    officeLng = s.officeLng;
    radius = s.radius;
    annualLeave = s.annualLeave;
    _replace(employees, s.employees);
    _replace(pendingAccounts, s.pending);
    _replace(attendance, s.attendance);
    _replace(tasks, s.tasks);
    _replace(requests, s.requests);
    _replace(stock, s.stock);
    _replace(announcements, s.announcements);
    _replace(notifications, s.notifications);
    if (s.meRow != null) me = Backend.employeeFrom(s.meRow!);
    notifyListeners();
  }

  static void _replace<T>(List<T> target, List<T> source) => target
    ..clear()
    ..addAll(source);

  /// Jalankan aksi di server, lalu muat ulang data. Error jadi pesan yang bisa dibaca.
  Future<String?> _live(Future<void> Function(Backend b) action) async {
    try {
      await action(backend!);
      await refresh();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  // ---------- Akun ----------

  static const demoPassword = 'demo123';

  /// Pulihkan sesi login yang tersimpan (mode live).
  Future<void> restoreSession() async {
    final b = backend;
    if (b == null || b.uid == null) return;
    loading = true;
    notifyListeners();
    try {
      await refresh();
      if (me != null) b.listen(() => refresh());
    } catch (_) {
      // sesi kedaluwarsa / offline: tampilkan layar login
      me = null;
    }
    loading = false;
    notifyListeners();
  }

  Future<String?> login(String phone, String password) async {
    final b = backend;
    if (b == null) {
      if (password != demoPassword) return 'Nomor HP atau password salah.';
      final clean = phone.replaceAll(RegExp(r'\D'), '');
      for (final e in employees) {
        if (e.phone.replaceAll(RegExp(r'\D'), '') == clean) {
          loginAs(e);
          return null;
        }
      }
      return 'Nomor HP atau password salah.';
    }
    try {
      await b.signIn(phone, password);
      await b.bindDevice();
      await refresh();
      if (me == null) throw StateError('profil tidak ada');
      b.listen(() => refresh());
      return null;
    } catch (e) {
      final msg = e is StateError ? 'Profil kamu belum dibuat. Hubungi HR.' : friendlyError(e);
      me = null;
      await b.signOut().catchError((_) {});
      notifyListeners();
      return msg;
    }
  }

  void loginAs(Employee e) {
    me = e;
    notifyListeners();
  }

  Future<void> logout() async {
    await backend?.signOut().catchError((_) {});
    me = null;
    notifyListeners();
  }

  Future<String?> register({
    required String name,
    required String phone,
    required String position,
    required String password,
  }) async {
    final b = backend;
    if (b != null) {
      try {
        await b.signUp(name: name, phone: phone, position: position, password: password);
        return null;
      } catch (e) {
        return friendlyError(e);
      }
    }
    pendingAccounts.add(Employee(
      id: _id('p'),
      name: name,
      nik: '-',
      position: position,
      division: 'Operasional',
      phone: phone,
      role: Role.karyawan,
      shift: Shift.pagi,
      joinedAt: DateTime.now(),
      managerId: 'm1',
    ));
    for (final hr in employees.where((e) => e.role == Role.hr)) {
      _notify(hr.id, 'Akun baru menunggu approval', '$name mendaftar sebagai $position.',
          Icons.person_add_alt_1_rounded, AppColors.blue);
    }
    notifyListeners();
    return null;
  }

  Future<String?> approveAccount(Employee p, bool ok) async {
    if (isLive) return _live((b) => b.rpc('approve_account', {'p_user': p.id, 'p_ok': ok}));
    pendingAccounts.remove(p);
    if (ok) employees.add(p);
    notifyListeners();
    return null;
  }

  Future<String?> changePassword(String password) async {
    if (password.length < 6) return 'Password minimal 6 karakter.';
    final b = backend;
    if (b == null) return null;
    try {
      await b.changePassword(password);
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  Employee byId(String id) => employees.firstWhere((e) => e.id == id,
      orElse: () => Employee(
            id: id,
            name: 'Tidak dikenal',
            nik: '-',
            position: '-',
            division: '-',
            phone: '-',
            role: Role.karyawan,
            shift: Shift.pagi,
            joinedAt: DateTime(2024),
          ));

  List<Employee> get myTeam =>
      employees.where((e) => e.managerId == me?.id).toList();

  // ---------- Absensi ----------

  AttendanceRecord? todayRecord(String employeeId) {
    final now = DateTime.now();
    for (final r in attendance) {
      if (r.employeeId == employeeId && sameDay(r.date, now)) return r;
    }
    return null;
  }

  List<AttendanceRecord> historyOf(String employeeId) {
    final list = attendance.where((r) => r.employeeId == employeeId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Absen di mode live: upload selfie, server cek radius, jam shift, dan hitung telat.
  Future<String?> clockLive({
    required bool isIn,
    required double lat,
    required double lng,
    required XFile selfie,
  }) =>
      _live((b) async {
        final path = await b.upload('selfies', selfie);
        await b.rpc(isIn ? 'clock_in' : 'clock_out', {'p_lat': lat, 'p_lng': lng, 'p_selfie': path});
      });

  /// Absen di mode demo (lokasi & selfie disimulasikan).
  String? clockIn({required int distance, required bool selfie, DateTime? at}) {
    final e = me!;
    final now = at ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final opens = day.add(Duration(hours: e.shift.startHour - 1));
    final closes = day.add(Duration(hours: e.shift.endHour));
    if (now.isBefore(opens)) {
      return 'Absen masuk baru bisa mulai ${fmtTime(opens)} (1 jam sebelum ${e.shift.label.toLowerCase()}).';
    }
    if (!now.isBefore(closes)) {
      return '${e.shift.label} (${e.shift.hours}) sudah selesai. Ajukan koreksi absen kalau kamu tadi masuk.';
    }
    if (!selfie) return 'Ambil selfie dulu sebelum absen.';
    if (distance > radius) {
      return 'Kamu di luar radius toko ($distance m dari $radius m).';
    }
    final existing = todayRecord(e.id);
    if (existing?.checkIn != null) return 'Kamu sudah absen masuk hari ini.';
    final r = AttendanceRecord(
      employeeId: e.id,
      date: DateTime(now.year, now.month, now.day),
      shift: e.shift,
      checkIn: now,
      distanceIn: distance,
    );
    attendance.add(r);
    if (e.managerId != null) {
      _notify(e.managerId!, '${e.firstName} absen masuk',
          '${fmtTime(now)} · ${r.lateMinutes > 0 ? 'telat ${r.lateMinutes} menit' : 'tepat waktu'}',
          Icons.login_rounded, AppColors.green);
    }
    notifyListeners();
    return null;
  }

  String? clockOut({required int distance, required bool selfie}) {
    final e = me!;
    if (!selfie) return 'Ambil selfie dulu sebelum absen.';
    if (distance > radius) {
      return 'Kamu di luar radius toko ($distance m dari $radius m).';
    }
    final r = todayRecord(e.id);
    if (r == null || r.checkIn == null) return 'Kamu belum absen masuk hari ini.';
    if (r.checkOut != null) return 'Kamu sudah absen pulang hari ini.';
    r.checkOut = DateTime.now();
    notifyListeners();
    return null;
  }

  // ---------- Tugas ----------

  List<TaskItem> tasksForMe() {
    final e = me!;
    final list = tasks
        .where((t) => e.role == Role.karyawan
            ? t.assigneeIds.contains(e.id)
            : t.assignerId == e.id || t.assigneeIds.contains(e.id))
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));
    return list;
  }

  Future<String?> createTask({
    required String title,
    required String description,
    required List<String> assigneeIds,
    required DateTime deadline,
    required Priority priority,
    required Recurrence recurrence,
  }) async {
    if (isLive) {
      return _live((b) => b.rpc('create_task', {
            'p_title': title,
            'p_description': description,
            'p_assignees': assigneeIds,
            'p_deadline': deadline.toUtc().toIso8601String(),
            'p_priority': priority.name,
            'p_recurrence': recurrence.name,
          }));
    }
    final t = TaskItem(
      id: _id('t'),
      title: title,
      description: description,
      assignerId: me!.id,
      assigneeIds: assigneeIds,
      deadline: deadline,
      createdAt: DateTime.now(),
      priority: priority,
      recurrence: recurrence,
    );
    tasks.add(t);
    for (final id in assigneeIds) {
      _notify(id, 'Tugas baru dari ${me!.firstName}', title,
          Icons.assignment_rounded, AppColors.blue);
    }
    notifyListeners();
    return null;
  }

  Future<String?> startTask(TaskItem t) async {
    if (isLive) return _live((b) => b.rpc('start_task', {'p_task': t.id}));
    t.status = TaskStatus.dikerjakan;
    notifyListeners();
    return null;
  }

  /// [file] wajib di mode live (foto dari kamera/galeri atau dokumen).
  Future<String?> addProof(TaskItem t, {required bool photo, XFile? file}) async {
    if (isLive) {
      if (file == null) return null;
      return _live((b) async {
        final path = await b.upload('task-proofs', file);
        await b.insert('task_proofs', {
          'task_id': t.id,
          'kind': photo ? 'foto' : 'file',
          'path': path,
          'file_name': file.name,
          'uploaded_by': b.uid,
        });
      });
    }
    if (photo) {
      t.proofPhotos++;
    } else {
      t.proofFiles++;
    }
    notifyListeners();
    return null;
  }

  Future<String?> submitTask(TaskItem t, String note) async {
    if (isLive) return _live((b) => b.rpc('submit_task', {'p_task': t.id, 'p_note': note}));
    if (!t.hasProof) return 'Upload minimal 1 foto dan 1 file bukti dulu.';
    t.proofNote = note.trim().isEmpty ? null : note.trim();
    t.status = TaskStatus.review;
    _notify(t.assignerId, 'Tugas menunggu review', '${me!.firstName} menyelesaikan "${t.title}".',
        Icons.fact_check_rounded, AppColors.purple);
    notifyListeners();
    return null;
  }

  Future<String?> reviewTask(TaskItem t, {required bool approve, String note = ''}) async {
    if (isLive) {
      return _live((b) => b.rpc('review_task', {'p_task': t.id, 'p_approve': approve, 'p_note': note}));
    }
    t.status = approve ? TaskStatus.selesai : TaskStatus.revisi;
    if (note.trim().isNotEmpty) {
      t.comments.add(TaskComment(authorId: me!.id, text: note.trim(), time: DateTime.now()));
    }
    for (final id in t.assigneeIds) {
      _notify(
          id,
          approve ? 'Tugas disetujui' : 'Tugas perlu revisi',
          approve ? '"${t.title}" sudah selesai.' : '"${t.title}": ${note.isEmpty ? 'cek catatan atasan.' : note}',
          approve ? Icons.check_circle_rounded : Icons.replay_rounded,
          approve ? AppColors.green : AppColors.red);
    }
    notifyListeners();
    return null;
  }

  Future<String?> addComment(TaskItem t, String text) async {
    if (isLive) {
      return _live((b) => b.insert('task_comments', {'task_id': t.id, 'author_id': b.uid, 'body': text}));
    }
    t.comments.add(TaskComment(authorId: me!.id, text: text, time: DateTime.now()));
    notifyListeners();
    return null;
  }

  // ---------- Cuti, izin, lembur ----------

  int leaveUsed(String employeeId) => requests
      .where((r) =>
          r.employeeId == employeeId &&
          r.type == RequestType.cutiTahunan &&
          r.status != RequestStatus.ditolak &&
          r.start.year == DateTime.now().year)
      .fold(0, (sum, r) => sum + r.days);

  int leaveLeft(String employeeId) => annualLeave - leaveUsed(employeeId);

  List<LeaveRequest> myRequests() =>
      requests.where((r) => r.employeeId == me!.id).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Pengajuan yang menunggu keputusan user yang sedang login.
  List<LeaveRequest> approvalsForMe() {
    final e = me!;
    return requests.where((r) {
      if (e.role == Role.hr) return r.status == RequestStatus.menungguHr;
      if (e.role == Role.atasan) {
        return r.status == RequestStatus.menungguAtasan &&
            byId(r.employeeId).managerId == e.id;
      }
      return false;
    }).toList();
  }

  static String _day(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

  Future<String?> submitRequest({
    required RequestType type,
    required DateTime start,
    required DateTime end,
    required String reason,
    bool attachment = false,
    XFile? attachmentFile,
  }) async {
    if (isLive) {
      return _live((b) async {
        final path = attachmentFile == null ? null : await b.upload('attachments', attachmentFile);
        await b.rpc('submit_request', {
          'p_type': type.name,
          'p_start': _day(start),
          'p_end': _day(end),
          'p_reason': reason,
          'p_attachment': path ?? '',
        });
      });
    }
    final e = me!;
    if (end.isBefore(start)) return 'Tanggal selesai harus setelah tanggal mulai.';
    if (reason.trim().isEmpty) return 'Isi alasannya dulu.';
    if (type == RequestType.lembur) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final minDay = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      if (start.isBefore(minDay)) return 'Lembur harus diajukan paling lambat H-1.';
    }
    if (type == RequestType.cutiTahunan) {
      final days = end.difference(start).inDays + 1;
      if (days > leaveLeft(e.id)) return 'Sisa cuti kamu tinggal ${leaveLeft(e.id)} hari.';
    }
    final r = LeaveRequest(
      id: _id('r'),
      employeeId: e.id,
      type: type,
      start: start,
      end: end,
      reason: reason.trim(),
      createdAt: DateTime.now(),
      attachment: attachment || attachmentFile != null,
    );
    requests.add(r);
    if (e.managerId != null) {
      _notify(e.managerId!, 'Pengajuan ${type.label.toLowerCase()}',
          '${e.firstName} · ${fmtDayMonth(start)}${r.days > 1 ? ' – ${fmtDayMonth(end)}' : ''}',
          type.icon, AppColors.orange);
    }
    notifyListeners();
    return null;
  }

  Future<String?> decide(LeaveRequest r, bool ok) async {
    if (isLive) return _live((b) => b.rpc('decide_request', {'p_id': r.id, 'p_ok': ok}));
    final e = me!;
    if (!ok) {
      r.status = RequestStatus.ditolak;
    } else if (e.role == Role.atasan && r.type.needsHr) {
      r.status = RequestStatus.menungguHr;
      for (final hr in employees.where((x) => x.role == Role.hr)) {
        _notify(hr.id, 'Pengajuan perlu approval HR',
            '${byId(r.employeeId).firstName} · ${r.type.label}', r.type.icon, AppColors.purple);
      }
    } else {
      r.status = RequestStatus.disetujui;
      if (r.type == RequestType.koreksiAbsen) _applyCorrection(r);
    }
    if (r.status != RequestStatus.menungguHr) {
      _notify(r.employeeId, ok ? 'Pengajuan disetujui' : 'Pengajuan ditolak',
          '${r.type.label} ${fmtDayMonth(r.start)}',
          ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
          ok ? AppColors.green : AppColors.red);
    }
    notifyListeners();
    return null;
  }

  void _applyCorrection(LeaveRequest r) {
    final emp = byId(r.employeeId);
    final d = DateTime(r.start.year, r.start.month, r.start.day);
    final exists = attendance.any((a) => a.employeeId == emp.id && sameDay(a.date, d));
    if (exists) return;
    attendance.add(AttendanceRecord(
      employeeId: emp.id,
      date: d,
      shift: emp.shift,
      checkIn: DateTime(d.year, d.month, d.day, emp.shift.startHour),
      checkOut: DateTime(d.year, d.month, d.day, emp.shift.endHour == 24 ? 23 : emp.shift.endHour, emp.shift.endHour == 24 ? 59 : 0),
      isCorrection: true,
    ));
  }

  // ---------- Stok ----------

  Future<String?> adjustStock(StockItem s, double delta, String note) async {
    if (isLive) {
      return _live((b) => b.rpc('adjust_stock', {'p_item': s.id, 'p_delta': delta, 'p_note': note}));
    }
    s.qty = (s.qty + delta).clamp(0, 99999).toDouble();
    s.logs.insert(0, StockLog(byId: me!.id, delta: delta, time: DateTime.now(), note: note));
    if (s.isLow) {
      for (final boss in employees.where((x) => x.role == Role.atasan)) {
        _notify(boss.id, 'Stok ${s.name} menipis',
            'Sisa ${fmtQty(s.qty)} ${s.unit} (minimum ${fmtQty(s.min)})',
            Icons.inventory_2_rounded, AppColors.red);
      }
    }
    notifyListeners();
    return null;
  }

  Future<String?> addStockItem(String name, String unit, double qty, double min) async {
    if (isLive) {
      return _live((b) => b.rpc('add_stock_item', {'p_name': name, 'p_unit': unit, 'p_qty': qty, 'p_min': min}));
    }
    stock.add(StockItem(id: _id('s'), name: name, unit: unit, qty: qty, min: min));
    notifyListeners();
    return null;
  }

  // ---------- Pengumuman & notifikasi ----------

  Future<String?> postAnnouncement(String title, String body) async {
    if (isLive) return _live((b) => b.rpc('post_announcement', {'p_title': title, 'p_body': body}));
    announcements.insert(
        0,
        Announcement(
          id: _id('a'),
          title: title,
          body: body,
          date: DateTime.now(),
          authorId: me!.id,
          color: AppColors.blue,
        ));
    for (final e in employees.where((x) => x.id != me!.id)) {
      _notify(e.id, 'Pengumuman baru', title, Icons.campaign_rounded, AppColors.blue);
    }
    notifyListeners();
    return null;
  }

  Future<void> markRead(Announcement a) async {
    if (!a.readBy.add(me!.id)) return;
    notifyListeners();
    await backend
        ?.insert('announcement_reads', {'announcement_id': a.id, 'employee_id': me!.id})
        .catchError((_) {});
  }

  List<AppNotification> myNotifications() =>
      notifications.where((n) => n.toId == me?.id).toList()
        ..sort((a, b) => b.time.compareTo(a.time));

  int get unreadCount => myNotifications().where((n) => !n.read).length;

  Future<void> markNotificationRead(AppNotification n) async {
    if (n.read) return;
    n.read = true;
    notifyListeners();
    if (n.id != null) {
      await backend?.update('notifications', {'read': true}, 'id', n.id!).catchError((_) {});
    }
  }

  Future<void> readAllNotifications() async {
    for (final n in myNotifications()) {
      n.read = true;
    }
    notifyListeners();
    final uid = me?.id;
    if (uid != null) {
      await backend?.update('notifications', {'read': true}, 'to_id', uid).catchError((_) {});
    }
  }

  void _notify(String toId, String title, String body, IconData icon, Color color) {
    notifications.add(AppNotification(
      toId: toId,
      title: title,
      body: body,
      time: DateTime.now(),
      icon: icon,
      color: color,
    ));
  }

  // ---------- Data contoh ----------

  void _seed() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    employees.addAll([
      Employee(id: 'c1', name: 'Hendra Wijaya', nik: '3201000001', position: 'Owner / CEO', division: 'Manajemen', phone: '081200000001', role: Role.atasan, shift: Shift.pagi, joinedAt: DateTime(2021, 1, 4)),
      Employee(id: 'm1', name: 'Dimas Aditya', nik: '3201000002', position: 'Manager Toko', division: 'Operasional', phone: '081200000002', role: Role.atasan, shift: Shift.pagi, joinedAt: DateTime(2022, 3, 1), managerId: 'c1'),
      Employee(id: 'h1', name: 'Nadia Putri', nik: '3201000003', position: 'Staf HR', division: 'HR', phone: '081200000003', role: Role.hr, shift: Shift.pagi, joinedAt: DateTime(2022, 7, 11), managerId: 'c1'),
      Employee(id: 'e1', name: 'Budi Santoso', nik: '3201000004', position: 'Barista', division: 'Operasional', phone: '081200000004', role: Role.karyawan, shift: Shift.pagi, joinedAt: DateTime(2023, 2, 6), managerId: 'm1'),
      Employee(id: 'e2', name: 'Sari Wulandari', nik: '3201000005', position: 'Kasir', division: 'Operasional', phone: '081200000005', role: Role.karyawan, shift: Shift.malam, joinedAt: DateTime(2023, 9, 18), managerId: 'm1'),
      Employee(id: 'e3', name: 'Rizky Pratama', nik: '3201000006', position: 'Staf Lapangan', division: 'Operasional', phone: '081200000006', role: Role.karyawan, shift: Shift.pagi, joinedAt: DateTime(2024, 5, 2), managerId: 'm1'),
    ]);

    // Riwayat absen 14 hari terakhir (pola telat dibuat tetap supaya mudah dicek).
    const lates = [0, 3, 0, 12, 0, 0, 7, 0, 0, 22, 0, 4, 0, 0];
    for (final e in employees) {
      for (var i = 1; i <= 14; i++) {
        final d = today.subtract(Duration(days: i));
        if (d.weekday == DateTime.sunday) continue;
        final late = lates[(i + e.id.hashCode.abs()) % lates.length];
        final inAt = DateTime(d.year, d.month, d.day, e.shift.startHour).add(Duration(minutes: late - 5 + (late == 0 ? 0 : 5)));
        final outAt = DateTime(d.year, d.month, d.day, e.shift.endHour == 24 ? 23 : e.shift.endHour, e.shift.endHour == 24 ? 58 : 4);
        attendance.add(AttendanceRecord(employeeId: e.id, date: d, shift: e.shift, checkIn: inAt, checkOut: outAt, distanceIn: 20 + (i * 7) % 60));
      }
    }

    tasks.addAll([
      TaskItem(id: 't1', title: 'Cek kebersihan mesin espresso', description: 'Bersihkan group head dan steam wand, lalu foto hasilnya sebelum toko buka.', assignerId: 'm1', assigneeIds: ['e1'], deadline: DateTime(now.year, now.month, now.day, 10), createdAt: today, priority: Priority.tinggi, recurrence: Recurrence.harian),
      TaskItem(id: 't2', title: 'Rekap penjualan shift malam', description: 'Rekap total transaksi tunai dan QRIS, cocokkan dengan laporan kasir. Upload file rekapnya.', assignerId: 'm1', assigneeIds: ['e2'], deadline: today.add(const Duration(days: 1, hours: 9)), createdAt: today.subtract(const Duration(days: 1)), status: TaskStatus.dikerjakan),
      TaskItem(id: 't3', title: 'Ambil kiriman biji kopi di supplier', description: 'Ambil 10 kg biji kopi arabika di supplier, cek berat dan tanggal roasting. Foto nota.', assignerId: 'm1', assigneeIds: ['e3'], deadline: today.add(const Duration(days: 1, hours: 13)), createdAt: today, priority: Priority.tinggi),
      TaskItem(id: 't4', title: 'Susun ulang display etalase', description: 'Pindahkan produk baru ke rak depan sesuai planogram yang dikirim di grup.', assignerId: 'm1', assigneeIds: ['e1', 'e3'], deadline: today.subtract(const Duration(hours: 2)), createdAt: today.subtract(const Duration(days: 2)), status: TaskStatus.review, proofPhotos: 2, proofFiles: 1, proofNote: 'Sudah dipindah, foto sebelum & sesudah terlampir.'),
      TaskItem(id: 't5', title: 'Stock opname bahan mingguan', description: 'Hitung semua bahan di gudang dan update angka stok di app.', assignerId: 'm1', assigneeIds: ['e1'], deadline: today.add(const Duration(days: 3, hours: 15)), createdAt: today.subtract(const Duration(days: 1)), recurrence: Recurrence.mingguan, priority: Priority.rendah),
      TaskItem(id: 't6', title: 'Training SOP kasir baru', description: 'Ikuti training SOP kasir di ruang belakang.', assignerId: 'm1', assigneeIds: ['e2'], deadline: today.subtract(const Duration(days: 3)), createdAt: today.subtract(const Duration(days: 6)), status: TaskStatus.selesai, proofPhotos: 1, proofFiles: 1),
      TaskItem(id: 't7', title: 'Laporan mingguan toko', description: 'Kirim ringkasan penjualan, stok, dan absensi minggu ini.', assignerId: 'c1', assigneeIds: ['m1'], deadline: today.add(const Duration(days: 2, hours: 17)), createdAt: today.subtract(const Duration(days: 1)), priority: Priority.sedang),
    ]);
    tasks[1].comments.add(TaskComment(authorId: 'e2', text: 'QRIS kemarin ada selisih Rp15.000, saya cek dulu ya pak.', time: now.subtract(const Duration(hours: 3))));
    tasks[1].comments.add(TaskComment(authorId: 'm1', text: 'Oke, tulis penyebabnya di catatan.', time: now.subtract(const Duration(hours: 2))));

    requests.addAll([
      LeaveRequest(id: 'r1', employeeId: 'e1', type: RequestType.cutiTahunan, start: today.add(const Duration(days: 10)), end: today.add(const Duration(days: 11)), reason: 'Acara keluarga di Bandung', createdAt: now.subtract(const Duration(hours: 5))),
      LeaveRequest(id: 'r2', employeeId: 'e2', type: RequestType.sakit, start: today.subtract(const Duration(days: 4)), end: today.subtract(const Duration(days: 4)), reason: 'Demam', createdAt: today.subtract(const Duration(days: 4)), status: RequestStatus.disetujui, attachment: true),
      LeaveRequest(id: 'r3', employeeId: 'e3', type: RequestType.lembur, start: today.add(const Duration(days: 2)), end: today.add(const Duration(days: 2)), reason: 'Bantu bongkar muat stok akhir bulan', createdAt: now.subtract(const Duration(hours: 1))),
      LeaveRequest(id: 'r4', employeeId: 'e1', type: RequestType.cutiTahunan, start: today.subtract(const Duration(days: 30)), end: today.subtract(const Duration(days: 28)), reason: 'Pulang kampung', createdAt: today.subtract(const Duration(days: 40)), status: RequestStatus.disetujui),
      LeaveRequest(id: 'r5', employeeId: 'e2', type: RequestType.cutiTahunan, start: today.add(const Duration(days: 20)), end: today.add(const Duration(days: 20)), reason: 'Urus dokumen', createdAt: today.subtract(const Duration(days: 1)), status: RequestStatus.menungguHr),
    ]);

    stock.addAll([
      StockItem(id: 's1', name: 'Biji kopi arabika', unit: 'kg', qty: 3.5, min: 5),
      StockItem(id: 's2', name: 'Susu UHT', unit: 'liter', qty: 42, min: 20),
      StockItem(id: 's3', name: 'Gula aren cair', unit: 'liter', qty: 6, min: 4),
      StockItem(id: 's4', name: 'Cup plastik 16 oz', unit: 'pcs', qty: 180, min: 200),
      StockItem(id: 's5', name: 'Es batu kristal', unit: 'kg', qty: 25, min: 10),
      StockItem(id: 's6', name: 'Sirup vanila', unit: 'botol', qty: 4, min: 2),
    ]);
    stock[0].logs.add(StockLog(byId: 'm1', delta: -1.5, time: now.subtract(const Duration(hours: 4)), note: 'Pemakaian shift pagi'));
    stock[3].logs.add(StockLog(byId: 'm1', delta: -70, time: now.subtract(const Duration(hours: 6)), note: 'Pemakaian kemarin'));

    announcements.addAll([
      Announcement(id: 'a1', title: 'Jadwal libur Natal & Tahun Baru', body: 'Toko tetap buka 24–26 Desember dengan jam operasional 10.00–20.00. Pembagian shift akan dikirim HR minggu depan.', date: today.subtract(const Duration(days: 1)), authorId: 'h1', pinned: true, color: AppColors.green),
      Announcement(id: 'a2', title: 'Absen sekarang lewat aplikasi', body: 'Mulai 1 November, absen lewat grup WA tidak dipakai lagi. Absen masuk dan pulang wajib lewat aplikasi dengan selfie di area toko (radius 100 m).', date: today.subtract(const Duration(days: 2)), authorId: 'h1', color: AppColors.blue),
      Announcement(id: 'a3', title: 'Menu baru: Es Kopi Pandan', body: 'Resep dan takaran sudah ada di folder SOP. Semua barista wajib coba bikin sebelum Sabtu.', date: today.subtract(const Duration(days: 5)), authorId: 'm1', color: AppColors.orange),
    ]);

    _notify('e1', 'Tugas baru dari Dimas', 'Cek kebersihan mesin espresso', Icons.assignment_rounded, AppColors.blue);
    _notify('e1', 'Pengumuman baru', 'Jadwal libur Natal & Tahun Baru', Icons.campaign_rounded, AppColors.green);
    _notify('m1', 'Tugas menunggu review', 'Budi & Rizky menyelesaikan "Susun ulang display etalase".', Icons.fact_check_rounded, AppColors.purple);
    _notify('m1', 'Stok Biji kopi arabika menipis', 'Sisa 3.5 kg (minimum 5)', Icons.inventory_2_rounded, AppColors.red);
    _notify('h1', 'Pengajuan perlu approval HR', 'Sari · Cuti tahunan', Icons.beach_access_rounded, AppColors.purple);
  }
}

/// Akses AppState dari widget mana pun: `AppScope.of(context)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
