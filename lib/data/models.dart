import 'package:flutter/material.dart';

import '../theme.dart';

enum Role { karyawan, atasan, hr }

extension RoleLabel on Role {
  String get label => switch (this) {
        Role.karyawan => 'Karyawan',
        Role.atasan => 'Atasan',
        Role.hr => 'HR',
      };
}

class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.nik,
    required this.position,
    required this.division,
    required this.phone,
    required this.role,
    required this.shift,
    required this.joinedAt,
    this.managerId,
  });

  final String id;
  final String name;
  final String nik;
  final String position;
  final String division;
  final String phone;
  final Role role;
  final Shift shift;
  final DateTime joinedAt;
  final String? managerId;

  String get firstName => name.split(' ').first;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

enum Shift { pagi, malam }

extension ShiftInfo on Shift {
  String get label => this == Shift.pagi ? 'Shift Pagi' : 'Shift Malam';
  int get startHour => this == Shift.pagi ? 8 : 16;
  int get endHour => this == Shift.pagi ? 16 : 24;
  String get hours => this == Shift.pagi ? '08.00 – 16.00' : '16.00 – 24.00';
}

// ---------- Tugas ----------

enum TaskStatus { baru, dikerjakan, review, revisi, selesai }

extension TaskStatusInfo on TaskStatus {
  String get label => switch (this) {
        TaskStatus.baru => 'Baru',
        TaskStatus.dikerjakan => 'Dikerjakan',
        TaskStatus.review => 'Menunggu review',
        TaskStatus.revisi => 'Revisi',
        TaskStatus.selesai => 'Selesai',
      };

  Color get color => switch (this) {
        TaskStatus.baru => AppColors.blue,
        TaskStatus.dikerjakan => AppColors.orange,
        TaskStatus.review => AppColors.purple,
        TaskStatus.revisi => AppColors.red,
        TaskStatus.selesai => AppColors.green,
      };

  Color get soft => switch (this) {
        TaskStatus.baru => AppColors.blueSoft,
        TaskStatus.dikerjakan => AppColors.orangeSoft,
        TaskStatus.review => AppColors.purpleSoft,
        TaskStatus.revisi => AppColors.redSoft,
        TaskStatus.selesai => AppColors.greenSoft,
      };
}

enum Priority { rendah, sedang, tinggi }

extension PriorityInfo on Priority {
  String get label => switch (this) {
        Priority.rendah => 'Rendah',
        Priority.sedang => 'Sedang',
        Priority.tinggi => 'Tinggi',
      };
  Color get color => switch (this) {
        Priority.rendah => AppColors.muted,
        Priority.sedang => AppColors.orange,
        Priority.tinggi => AppColors.red,
      };
}

enum Recurrence { sekali, harian, mingguan }

extension RecurrenceLabel on Recurrence {
  String get label => switch (this) {
        Recurrence.sekali => 'Sekali',
        Recurrence.harian => 'Harian',
        Recurrence.mingguan => 'Mingguan',
      };
}

class TaskComment {
  TaskComment({required this.authorId, required this.text, required this.time});
  final String authorId;
  final String text;
  final DateTime time;
}

class TaskItem {
  TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.assignerId,
    required this.assigneeIds,
    required this.deadline,
    required this.createdAt,
    this.priority = Priority.sedang,
    this.status = TaskStatus.baru,
    this.recurrence = Recurrence.sekali,
    this.proofPhotos = 0,
    this.proofFiles = 0,
    this.proofNote,
    List<TaskComment>? comments,
    List<String>? proofNames,
  })  : comments = comments ?? [],
        proofNames = proofNames ?? [];

  final String id;
  String title;
  String description;
  final String assignerId;
  final List<String> assigneeIds;
  DateTime deadline;
  final DateTime createdAt;
  Priority priority;
  TaskStatus status;
  Recurrence recurrence;
  int proofPhotos;
  int proofFiles;
  String? proofNote;
  final List<TaskComment> comments;

  /// Nama file bukti yang sudah diupload (mode live).
  final List<String> proofNames;

  bool get hasProof => proofPhotos > 0 && proofFiles > 0;
  bool get isOpen => status != TaskStatus.selesai;
}

// ---------- Absensi ----------

class AttendanceRecord {
  AttendanceRecord({
    required this.employeeId,
    required this.date,
    required this.shift,
    this.checkIn,
    this.checkOut,
    this.distanceIn,
    this.isCorrection = false,
    this.serverLate,
    this.serverPenalty,
  });

  final String employeeId;
  final DateTime date;
  final Shift shift;
  DateTime? checkIn;
  DateTime? checkOut;
  int? distanceIn;
  bool isCorrection;

  /// Nilai dari server (mode live). Kalau ada, dipakai apa adanya.
  final int? serverLate;
  final int? serverPenalty;

  int get lateMinutes {
    if (serverLate != null) return serverLate!;
    if (checkIn == null) return 0;
    final start = DateTime(date.year, date.month, date.day, shift.startHour);
    final diff = checkIn!.difference(start).inMinutes;
    return diff > 0 ? diff : 0;
  }

  /// Rp5.000 untuk setiap 5 menit telat (dibulatkan ke bawah).
  int get penalty => serverPenalty ?? (lateMinutes ~/ 5) * 5000;
}

// ---------- Cuti, izin, lembur ----------

enum RequestType { cutiTahunan, izin, sakit, dinasLuar, lembur, koreksiAbsen }

extension RequestTypeInfo on RequestType {
  String get label => switch (this) {
        RequestType.cutiTahunan => 'Cuti tahunan',
        RequestType.izin => 'Izin',
        RequestType.sakit => 'Sakit',
        RequestType.dinasLuar => 'Dinas luar',
        RequestType.lembur => 'Lembur',
        RequestType.koreksiAbsen => 'Koreksi absen',
      };
  IconData get icon => switch (this) {
        RequestType.cutiTahunan => Icons.beach_access_rounded,
        RequestType.izin => Icons.event_busy_rounded,
        RequestType.sakit => Icons.medical_services_rounded,
        RequestType.dinasLuar => Icons.directions_car_rounded,
        RequestType.lembur => Icons.more_time_rounded,
        RequestType.koreksiAbsen => Icons.edit_calendar_rounded,
      };

  /// Cuti & sakit perlu approve HR setelah atasan; sisanya cukup atasan.
  bool get needsHr =>
      this == RequestType.cutiTahunan || this == RequestType.sakit;
}

enum RequestStatus { menungguAtasan, menungguHr, disetujui, ditolak }

extension RequestStatusInfo on RequestStatus {
  String get label => switch (this) {
        RequestStatus.menungguAtasan => 'Menunggu atasan',
        RequestStatus.menungguHr => 'Menunggu HR',
        RequestStatus.disetujui => 'Disetujui',
        RequestStatus.ditolak => 'Ditolak',
      };
  Color get color => switch (this) {
        RequestStatus.menungguAtasan => AppColors.orange,
        RequestStatus.menungguHr => AppColors.purple,
        RequestStatus.disetujui => AppColors.green,
        RequestStatus.ditolak => AppColors.red,
      };
  Color get soft => switch (this) {
        RequestStatus.menungguAtasan => AppColors.orangeSoft,
        RequestStatus.menungguHr => AppColors.purpleSoft,
        RequestStatus.disetujui => AppColors.greenSoft,
        RequestStatus.ditolak => AppColors.redSoft,
      };
}

class LeaveRequest {
  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.start,
    required this.end,
    required this.reason,
    required this.createdAt,
    this.status = RequestStatus.menungguAtasan,
    this.attachment = false,
  });

  final String id;
  final String employeeId;
  final RequestType type;
  final DateTime start;
  final DateTime end;
  final String reason;
  final DateTime createdAt;
  RequestStatus status;
  bool attachment;

  int get days => end.difference(start).inDays + 1;
}

// ---------- Stok bahan ----------

class StockLog {
  StockLog({required this.byId, required this.delta, required this.time, this.note = ''});
  final String byId;
  final double delta;
  final DateTime time;
  final String note;
}

class StockItem {
  StockItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.qty,
    required this.min,
    List<StockLog>? logs,
  }) : logs = logs ?? [];

  final String id;
  final String name;
  final String unit;
  double qty;
  double min;
  final List<StockLog> logs;

  bool get isLow => qty <= min;
}

// ---------- Pengumuman & notifikasi ----------

class Announcement {
  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.authorId,
    this.pinned = false,
    this.color = AppColors.green,
    Set<String>? readBy,
  }) : readBy = readBy ?? {};

  final String id;
  final String title;
  final String body;
  final DateTime date;
  final String authorId;
  bool pinned;
  final Color color;
  final Set<String> readBy;
}

class AppNotification {
  AppNotification({
    this.id,
    required this.toId,
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.color,
    this.read = false,
  });

  final int? id;
  final String toId;
  final String title;
  final String body;
  final DateTime time;
  final IconData icon;
  final Color color;
  bool read;
}
