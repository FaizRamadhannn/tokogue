import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'announcements_screen.dart';
import 'attendance_screen.dart';
import 'leave_screen.dart';
import 'recap_screen.dart';
import 'stock_screen.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenTab});
  final void Function(int) onOpenTab;

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final now = DateTime.now();
    final openTasks = state.tasksForMe().where((t) => t.isOpen).toList();
    final approvals = state.approvalsForMe().length;
    final reviewCount = state.tasks.where((t) => t.assignerId == me.id && t.status == TaskStatus.review).length;
    final lowStock = state.stock.where((s) => s.isLow).toList();

    final services = <ServiceTile>[
      ServiceTile(icon: Icons.fingerprint_rounded, label: 'Absen', color: AppColors.primary, soft: AppColors.primarySoft, onTap: () => _push(context, const AttendanceScreen())),
      ServiceTile(icon: Icons.assignment_rounded, label: 'Tugas', color: AppColors.blue, soft: AppColors.blueSoft, badge: me.role == Role.karyawan ? openTasks.length : reviewCount, onTap: () => onOpenTab(1)),
      if (me.role == Role.karyawan) ...[
        ServiceTile(icon: Icons.beach_access_rounded, label: 'Cuti & Izin', color: AppColors.orange, soft: AppColors.orangeSoft, onTap: () => _push(context, const LeaveScreen())),
        ServiceTile(icon: Icons.more_time_rounded, label: 'Lembur', color: AppColors.purple, soft: AppColors.purpleSoft, onTap: () => _push(context, const LeaveFormScreen(initialType: RequestType.lembur))),
        ServiceTile(icon: Icons.edit_calendar_rounded, label: 'Koreksi Absen', color: AppColors.pink, soft: AppColors.pinkSoft, onTap: () => _push(context, const LeaveFormScreen(initialType: RequestType.koreksiAbsen))),
        ServiceTile(icon: Icons.history_rounded, label: 'Riwayat Absen', color: AppColors.teal, soft: AppColors.tealSoft, onTap: () => _push(context, const AttendanceScreen(initialTab: 1))),
      ],
      if (me.role == Role.atasan) ...[
        ServiceTile(icon: Icons.add_task_rounded, label: 'Buat Tugas', color: AppColors.teal, soft: AppColors.tealSoft, onTap: () => _push(context, const TaskFormScreen())),
        ServiceTile(icon: Icons.how_to_reg_rounded, label: 'Approval', color: AppColors.orange, soft: AppColors.orangeSoft, badge: approvals, onTap: () => _push(context, const LeaveScreen(initialTab: 1))),
        ServiceTile(icon: Icons.inventory_2_rounded, label: 'Stok Bahan', color: AppColors.pink, soft: AppColors.pinkSoft, badge: lowStock.length, onTap: () => _push(context, const StockScreen())),
        ServiceTile(icon: Icons.groups_rounded, label: 'Absen Tim', color: AppColors.purple, soft: AppColors.purpleSoft, onTap: () => _push(context, const RecapScreen())),
      ],
      if (me.role == Role.hr) ...[
        ServiceTile(icon: Icons.how_to_reg_rounded, label: 'Approval', color: AppColors.orange, soft: AppColors.orangeSoft, badge: approvals, onTap: () => _push(context, const LeaveScreen(initialTab: 1))),
        ServiceTile(icon: Icons.table_chart_rounded, label: 'Rekap Absen', color: AppColors.purple, soft: AppColors.purpleSoft, onTap: () => _push(context, const RecapScreen())),
        ServiceTile(icon: Icons.person_add_alt_1_rounded, label: 'Akun Baru', color: AppColors.teal, soft: AppColors.tealSoft, badge: state.pendingAccounts.length, onTap: () => _push(context, const AccountApprovalScreen())),
        ServiceTile(icon: Icons.beach_access_rounded, label: 'Cuti & Izin', color: AppColors.pink, soft: AppColors.pinkSoft, onTap: () => _push(context, const LeaveScreen())),
      ],
      ServiceTile(icon: Icons.campaign_rounded, label: 'Pengumuman', color: AppColors.blue, soft: AppColors.blueSoft, badge: state.announcements.where((a) => !a.readBy.contains(me.id)).length, onTap: () => _push(context, const AnnouncementsScreen())),
      ServiceTile(icon: Icons.receipt_long_rounded, label: 'Slip Gaji', color: AppColors.muted, soft: AppColors.bg, onTap: () => showSnack(context, 'Slip gaji hadir di fase 2.')),
    ];

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(me: me, now: now, state: state, onOpen: () => _push(context, const AttendanceScreen())),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 0.8,
              children: services,
            ),
          ),
          if (me.role == Role.atasan && lowStock.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _AlertBanner(
                icon: Icons.warning_amber_rounded,
                text: '${lowStock.length} bahan di bawah stok minimum: ${lowStock.map((s) => s.name).take(2).join(', ')}${lowStock.length > 2 ? ', …' : ''}',
                onTap: () => _push(context, const StockScreen()),
              ),
            ),
          SectionTitle(
            me.role == Role.karyawan ? 'Tugas kamu' : 'Tugas tim',
            subtitle: openTasks.isEmpty ? 'Semua beres untuk sekarang' : '${openTasks.length} tugas belum selesai',
            action: 'Lihat semua',
            onAction: () => onOpenTab(1),
          ),
          SizedBox(
            height: 148,
            child: openTasks.isEmpty
                ? const Center(child: Text('Tidak ada tugas aktif', style: TextStyle(color: AppColors.muted)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: openTasks.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _TaskMiniCard(task: openTasks[i], now: now, onTap: () => _push(context, TaskDetailScreen(task: openTasks[i]))),
                  ),
          ),
          SectionTitle('Info dari kantor', action: 'Lihat semua', onAction: () => _push(context, const AnnouncementsScreen())),
          SizedBox(
            height: 148,
            child: state.announcements.isEmpty
                ? const Center(child: Text('Belum ada pengumuman', style: TextStyle(color: AppColors.muted)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: state.announcements.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final a = state.announcements[i];
                      return _PromoCard(a: a, onTap: () => _push(context, AnnouncementDetailScreen(a: a)));
                    },
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.me, required this.now, required this.state, required this.onOpen});
  final Employee me;
  final DateTime now;
  final AppState state;
  final VoidCallback onOpen;

  String get _greeting {
    final h = now.hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final rec = state.todayRecord(me.id);
    final inAt = rec?.checkIn;
    final outAt = rec?.checkOut;
    final label = inAt == null ? 'Absen Masuk' : (outAt == null ? 'Absen Pulang' : 'Sudah absen');
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FadeSlideIn(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtLongDate(now), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('$_greeting, ${me.firstName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
                ]),
              ),
              const SizedBox(width: 12),
              Avatar(me, size: 44),
            ]),
          ),
          const SizedBox(height: 20),
          // Kartu absen: satu-satunya blok gelap di beranda supaya langsung terlihat.
          FadeSlideIn(
            offset: 24,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.hero,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: inAt != null && outAt == null ? AppColors.goldLight : Colors.white38,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${me.shift.label} · ${me.shift.hours}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.goldLight, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    child: rec != null && rec.lateMinutes > 0
                        ? Pill('Telat ${rec.lateMinutes} mnt', key: const ValueKey('late'), color: const Color(0xFFFF8A8C), background: Colors.white10)
                        : inAt != null
                            ? const Pill('Tepat waktu', key: ValueKey('ok'), color: Color(0xFF5BE38C), background: Colors.white10)
                            : const SizedBox.shrink(),
                  ),
                ]),
                const SizedBox(height: 18),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _TimeBox(label: 'Masuk', time: inAt),
                  Container(width: 1, height: 34, margin: const EdgeInsets.symmetric(horizontal: 14), color: Colors.white12),
                  _TimeBox(label: 'Pulang', time: outAt),
                  const SizedBox(width: 12),
                  Expanded(child: Pressable(
                    enabled: outAt == null,
                    scale: 0.94,
                    child: FilledButton(
                      onPressed: outAt != null ? null : onOpen,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.hero,
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        disabledBackgroundColor: Colors.white10,
                        disabledForegroundColor: Colors.white54,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: AnimatedSwitcher(
                        duration: Motion.medium,
                        child: Text(label, key: ValueKey(label), maxLines: 1, style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  )),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.time});
  final String label;
  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    final text = time == null ? '--.--' : fmtTime(time!);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      const SizedBox(height: 2),
      AnimatedSwitcher(
        duration: Motion.slow,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a), child: child),
        ),
        child: Text(text,
            key: ValueKey(text),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5)),
      ),
    ]);
  }
}

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Pressable(
        child: Material(
          color: AppColors.redSoft,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(icon, color: AppColors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: const TextStyle(color: AppColors.red, fontWeight: FontWeight.w600, fontSize: 13))),
                const Icon(Icons.chevron_right_rounded, color: AppColors.red),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskMiniCard extends StatelessWidget {
  const _TaskMiniCard({required this.task, required this.now, required this.onTap});
  final TaskItem task;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final overdue = task.deadline.isBefore(now);
    return SizedBox(
      width: 236,
      child: CardBox(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Pill(task.status.label, color: task.status.color, background: task.status.soft),
            const Spacer(),
            if (task.priority == Priority.tinggi) const Icon(Icons.local_fire_department_rounded, color: AppColors.red, size: 18),
          ]),
          const SizedBox(height: 12),
          Text(task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, height: 1.3, letterSpacing: -0.2)),
          const Spacer(),
          Row(children: [
            Icon(Icons.schedule_rounded, size: 15, color: overdue ? AppColors.red : AppColors.muted),
            const SizedBox(width: 5),
            Text(fmtDeadline(task.deadline, now),
                style: TextStyle(fontSize: 12.5, color: overdue ? AppColors.red : AppColors.muted, fontWeight: overdue ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ]),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.a, required this.onTap});
  final Announcement a;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 268,
      child: CardBox(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: a.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.campaign_rounded, size: 17, color: a.color),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(fmtDate(a.date), style: const TextStyle(color: AppColors.muted, fontSize: 12))),
            if (a.pinned) const Icon(Icons.push_pin_rounded, size: 15, color: AppColors.muted),
          ]),
          const SizedBox(height: 12),
          Text(a.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2)),
          const SizedBox(height: 4),
          Expanded(
            child: Text(a.body,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
          ),
        ]),
      ),
    );
  }
}
