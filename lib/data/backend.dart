import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../theme.dart';
import 'models.dart';

/// Semua komunikasi dengan Supabase ada di sini.
class Backend {
  Backend(this.db);
  final SupabaseClient db;

  String? get uid => db.auth.currentUser?.id;
  RealtimeChannel? _channel;

  // ---------- Akun ----------

  Future<void> signIn(String phone, String password) =>
      db.auth.signInWithPassword(email: phoneToEmail(phone), password: password);

  Future<void> signUp({
    required String name,
    required String phone,
    required String position,
    required String password,
  }) async {
    await db.auth.signUp(
      email: phoneToEmail(phone),
      password: password,
      data: {'name': name, 'phone': phone, 'position': position},
    );
    // Akun baru belum aktif sampai di-approve HR.
    await db.auth.signOut();
  }

  Future<void> signOut() async {
    await _channel?.unsubscribe();
    _channel = null;
    await db.auth.signOut();
  }

  Future<void> changePassword(String password) =>
      db.auth.updateUser(UserAttributes(password: password));

  /// Satu ID acak per perangkat, disimpan di HP/browser.
  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await prefs.setString('device_id', id);
    }
    return id;
  }

  Future<void> bindDevice() async => rpc('bind_device', {'p_device': await deviceId()});

  // ---------- Fungsi server ----------

  Future<dynamic> rpc(String fn, [Map<String, dynamic>? params]) => db.rpc(fn, params: params);

  Future<String> upload(String bucket, XFile file) async {
    final bytes = await file.readAsBytes();
    final safe = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}-$safe';
    await db.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: file.mimeType, upsert: false),
        );
    return path;
  }

  Future<String> signedUrl(String bucket, String path) =>
      db.storage.from(bucket).createSignedUrl(path, 600);

  Future<void> insert(String table, Map<String, dynamic> row) => db.from(table).insert(row);

  Future<void> update(String table, Map<String, dynamic> values, String column, Object value) =>
      db.from(table).update(values).eq(column, value);

  /// Dengarkan notifikasi baru untuk user ini; tiap ada yang masuk, data dimuat ulang.
  void listen(VoidCallback onChange) {
    if (_channel != null || uid == null) return;
    _channel = db
        .channel('notif-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'to_id', value: uid),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  // ---------- Ambil data ----------

  Future<Snapshot> load() async {
    final since = DateTime.now().subtract(const Duration(days: 62)).toIso8601String().substring(0, 10);
    final results = await Future.wait<dynamic>([
      db.from('settings').select().maybeSingle(),
      db.from('profiles').select(),
      db.from('attendance').select().gte('work_date', since).order('work_date', ascending: false),
      db.from('tasks').select('*, task_assignees(employee_id), task_proofs(kind, file_name, path), task_comments(author_id, body, created_at)'),
      db.from('requests').select().order('created_at', ascending: false),
      db.from('stock_items').select('*, stock_logs(by_id, delta, note, created_at)'),
      db.from('announcements').select('*, announcement_reads(employee_id)').order('created_at', ascending: false),
      db.from('notifications').select().order('created_at', ascending: false).limit(100),
    ]);

    final settings = results[0] as Map<String, dynamic>?;
    final profiles = (results[1] as List).cast<Map<String, dynamic>>();
    return Snapshot(
      storeName: settings?['store_name'] as String? ?? 'tokogue',
      officeLat: (settings?['office_lat'] as num?)?.toDouble() ?? 0,
      officeLng: (settings?['office_lng'] as num?)?.toDouble() ?? 0,
      radius: settings?['radius_m'] as int? ?? 100,
      annualLeave: settings?['annual_leave_days'] as int? ?? 12,
      employees: profiles.where((p) => p['status'] == 'active').map(_employee).toList(),
      pending: profiles.where((p) => p['status'] == 'pending').map(_employee).toList(),
      meRow: profiles.where((p) => p['id'] == uid).firstOrNull,
      attendance: (results[2] as List).cast<Map<String, dynamic>>().map(_attendance).toList(),
      tasks: (results[3] as List).cast<Map<String, dynamic>>().map(_task).toList(),
      requests: (results[4] as List).cast<Map<String, dynamic>>().map(_request).toList(),
      stock: (results[5] as List).cast<Map<String, dynamic>>().map(_stock).toList(),
      announcements: (results[6] as List).cast<Map<String, dynamic>>().map(_announcement).toList(),
      notifications: (results[7] as List).cast<Map<String, dynamic>>().map(_notification).toList(),
    );
  }

  static DateTime _time(Object? v) => DateTime.parse(v as String).toLocal();
  static DateTime _date(Object? v) => DateTime.parse(v as String);

  static Employee employeeFrom(Map<String, dynamic> r) => _employee(r);

  static Employee _employee(Map<String, dynamic> r) => Employee(
        id: r['id'] as String,
        name: r['name'] as String,
        nik: r['nik'] as String? ?? '-',
        position: r['position'] as String? ?? '-',
        division: r['division'] as String? ?? '-',
        phone: r['phone'] as String? ?? '-',
        role: Role.values.byName(r['role'] as String),
        shift: Shift.values.byName(r['shift'] as String),
        joinedAt: _date(r['joined_at']),
        managerId: r['manager_id'] as String?,
      );

  static AttendanceRecord _attendance(Map<String, dynamic> r) => AttendanceRecord(
        employeeId: r['employee_id'] as String,
        date: _date(r['work_date']),
        shift: Shift.values.byName(r['shift'] as String),
        checkIn: r['check_in'] == null ? null : _time(r['check_in']),
        checkOut: r['check_out'] == null ? null : _time(r['check_out']),
        distanceIn: r['distance_in'] as int?,
        isCorrection: r['is_correction'] as bool? ?? false,
        serverLate: r['late_minutes'] as int?,
        serverPenalty: r['penalty'] as int?,
      );

  static TaskItem _task(Map<String, dynamic> r) {
    final proofs = (r['task_proofs'] as List? ?? []).cast<Map<String, dynamic>>();
    final comments = (r['task_comments'] as List? ?? []).cast<Map<String, dynamic>>()
        .map((c) => TaskComment(authorId: c['author_id'] as String, text: c['body'] as String, time: _time(c['created_at'])))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return TaskItem(
      id: r['id'] as String,
      title: r['title'] as String,
      description: r['description'] as String? ?? '',
      assignerId: r['assigner_id'] as String,
      assigneeIds: (r['task_assignees'] as List? ?? []).map((a) => a['employee_id'] as String).toList(),
      deadline: _time(r['deadline']),
      createdAt: _time(r['created_at']),
      priority: Priority.values.byName(r['priority'] as String),
      status: TaskStatus.values.byName(r['status'] as String),
      recurrence: Recurrence.values.byName(r['recurrence'] as String),
      proofPhotos: proofs.where((p) => p['kind'] == 'foto').length,
      proofFiles: proofs.where((p) => p['kind'] == 'file').length,
      proofNames: proofs.map((p) => (p['file_name'] ?? p['path']) as String).toList(),
      proofNote: r['proof_note'] as String?,
      comments: comments,
    );
  }

  static LeaveRequest _request(Map<String, dynamic> r) => LeaveRequest(
        id: r['id'] as String,
        employeeId: r['employee_id'] as String,
        type: RequestType.values.byName(r['type'] as String),
        start: _date(r['start_date']),
        end: _date(r['end_date']),
        reason: r['reason'] as String,
        createdAt: _time(r['created_at']),
        status: RequestStatus.values.byName(r['status'] as String),
        attachment: r['attachment'] != null,
      );

  static StockItem _stock(Map<String, dynamic> r) => StockItem(
        id: r['id'] as String,
        name: r['name'] as String,
        unit: r['unit'] as String,
        qty: (r['qty'] as num).toDouble(),
        min: (r['min_qty'] as num).toDouble(),
        logs: (r['stock_logs'] as List? ?? [])
            .cast<Map<String, dynamic>>()
            .map((l) => StockLog(
                  byId: l['by_id'] as String,
                  delta: (l['delta'] as num).toDouble(),
                  time: _time(l['created_at']),
                  note: l['note'] as String? ?? '',
                ))
            .toList()
          ..sort((a, b) => b.time.compareTo(a.time)),
      );

  static const _colors = {
    'green': AppColors.green,
    'blue': AppColors.blue,
    'orange': AppColors.orange,
    'purple': AppColors.purple,
    'red': AppColors.red,
    'teal': AppColors.teal,
    'pink': AppColors.pink,
  };

  static Announcement _announcement(Map<String, dynamic> r) => Announcement(
        id: r['id'] as String,
        title: r['title'] as String,
        body: r['body'] as String,
        date: _time(r['created_at']),
        authorId: r['author_id'] as String,
        pinned: r['pinned'] as bool? ?? false,
        color: _colors[r['color']] ?? AppColors.blue,
        readBy: (r['announcement_reads'] as List? ?? []).map((x) => x['employee_id'] as String).toSet(),
      );

  static const _kinds = <String, (IconData, Color)>{
    'task': (Icons.assignment_rounded, AppColors.blue),
    'review': (Icons.fact_check_rounded, AppColors.purple),
    'approved': (Icons.check_circle_rounded, AppColors.green),
    'revision': (Icons.replay_rounded, AppColors.red),
    'rejected': (Icons.cancel_rounded, AppColors.red),
    'request': (Icons.event_note_rounded, AppColors.orange),
    'attendance': (Icons.login_rounded, AppColors.green),
    'stock': (Icons.inventory_2_rounded, AppColors.red),
    'announcement': (Icons.campaign_rounded, AppColors.blue),
    'account': (Icons.person_add_alt_1_rounded, AppColors.teal),
  };

  static AppNotification _notification(Map<String, dynamic> r) {
    final k = _kinds[r['kind']] ?? (Icons.notifications_rounded, AppColors.green);
    return AppNotification(
      id: r['id'] as int,
      toId: r['to_id'] as String,
      title: r['title'] as String,
      body: r['body'] as String,
      time: _time(r['created_at']),
      icon: k.$1,
      color: k.$2,
      read: r['read'] as bool? ?? false,
    );
  }
}

class Snapshot {
  Snapshot({
    required this.storeName,
    required this.officeLat,
    required this.officeLng,
    required this.radius,
    required this.annualLeave,
    required this.employees,
    required this.pending,
    required this.meRow,
    required this.attendance,
    required this.tasks,
    required this.requests,
    required this.stock,
    required this.announcements,
    required this.notifications,
  });

  final String storeName;
  final double officeLat;
  final double officeLng;
  final int radius;
  final int annualLeave;
  final List<Employee> employees;
  final List<Employee> pending;
  final Map<String, dynamic>? meRow;
  final List<AttendanceRecord> attendance;
  final List<TaskItem> tasks;
  final List<LeaveRequest> requests;
  final List<StockItem> stock;
  final List<Announcement> announcements;
  final List<AppNotification> notifications;
}

/// Pesan error dari server dibuat ramah dibaca.
String friendlyError(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid api key')) return 'Kunci server (SUPABASE_KEY) salah. Hubungi admin aplikasi.';
    if (m.contains('invalid login')) return 'Nomor HP atau password salah.';
    if (m.contains('email logins are disabled') || m.contains('email signups are disabled')) {
      return 'Login belum diaktifkan di server. Admin: nyalakan provider Email di Supabase.';
    }
    if (m.contains('rate limit')) {
      return 'Server sedang membatasi pendaftaran. Admin: matikan "Confirm email" di Supabase, lalu coba lagi.';
    }
    if (m.contains('email not confirmed')) return 'Akun belum dikonfirmasi. Admin: matikan "Confirm email" di Supabase.';
    if (m.contains('already registered')) return 'Nomor HP ini sudah terdaftar.';
    if (m.contains('password')) return 'Password minimal 6 karakter.';
    return e.message;
  }
  if (e is StorageException) return 'Upload gagal: ${e.message}';
  return 'Gagal terhubung ke server. Cek internet lalu coba lagi.';
}
