import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Absen tim hari ini (atasan) + rekap bulanan per karyawan (atasan & HR).
class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final now = DateTime.now();
    final people = me.role == Role.hr
        ? state.employees.where((e) => e.id != me.id).toList()
        : state.myTeam;

    final present = people.where((e) => state.todayRecord(e.id)?.checkIn != null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(me.role == Role.hr ? 'Rekap absen' : 'Absen tim'),
        actions: [
          if (me.role == Role.hr)
            IconButton(
              tooltip: 'Export Excel',
              onPressed: () => showSnack(context, 'Export Excel/PDF butuh server — dikerjakan setelah backend siap.'),
              icon: const Icon(Icons.file_download_outlined),
            ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          _Box(label: 'Sudah absen hari ini', value: '$present', color: AppColors.primary, soft: AppColors.primarySoft),
          const SizedBox(width: 12),
          _Box(label: 'Belum absen', value: '${people.length - present}', color: AppColors.orange, soft: AppColors.orangeSoft),
        ]),
        SectionTitle('Hari ini', subtitle: fmtLongDate(now)),
        for (final e in people)
          Builder(builder: (_) {
            final r = state.todayRecord(e.id);
            final status = r?.checkIn == null
                ? const Pill('Belum absen', color: AppColors.orange, background: AppColors.orangeSoft)
                : r!.lateMinutes > 0
                    ? Pill('Telat ${r.lateMinutes} mnt', color: AppColors.red, background: AppColors.redSoft)
                    : const Pill('Hadir', color: AppColors.green, background: AppColors.greenSoft);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(e),
              title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${e.shift.label}${r?.checkIn != null ? ' · masuk ${fmtTime(r!.checkIn!)}' : ''}'),
              trailing: status,
            );
          }),
        SectionTitle('Rekap ${fmtMonthYear(now)}'),
        Container(
          decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Expanded(flex: 3, child: Text('Nama', style: TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Hadir', textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Telat', textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text('Potongan', textAlign: TextAlign.right, style: TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600))),
              ]),
            ),
            for (final e in people) ...[
              const Divider(),
              Builder(builder: (_) {
                final m = state.historyOf(e.id).where((r) => r.date.month == now.month && r.date.year == now.year).toList();
                final late = m.where((r) => r.lateMinutes > 0).length;
                final pen = m.fold<int>(0, (s, r) => s + r.penalty);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(e.firstName, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Expanded(flex: 2, child: Text('${m.length}', textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('$late', textAlign: TextAlign.right, style: TextStyle(color: late > 0 ? AppColors.red : AppColors.ink))),
                    Expanded(flex: 3, child: Text(fmtRupiah(pen), textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, color: pen > 0 ? AppColors.red : AppColors.ink))),
                  ]),
                );
              }),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        const Text('Potongan: Rp5.000 untuk setiap 5 menit telat.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
      ]),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.label, required this.value, required this.color, required this.soft});
  final String label;
  final String value;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 26)),
        ]),
      ),
    );
  }
}

class AccountApprovalScreen extends StatelessWidget {
  const AccountApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final list = state.pendingAccounts;
    return Scaffold(
      appBar: AppBar(title: const Text('Akun baru')),
      body: list.isEmpty
          ? ListView(children: const [
              EmptyState(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Tidak ada akun yang menunggu',
                body: 'Karyawan yang daftar sendiri akan muncul di sini untuk kamu approve.',
              ),
            ])
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final p = list[i];
                return CardBox(
                  child: Column(children: [
                    Row(children: [
                      Avatar(p),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${p.position} · ${p.phone}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42), foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red, width: 1.5)),
                          onPressed: () => runAction(context, state.approveAccount(p, false), success: 'Pendaftaran ${p.firstName} ditolak.'),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                          onPressed: () => runAction(context, state.approveAccount(p, true), success: 'Akun ${p.firstName} aktif.'),
                          child: const Text('Aktifkan'),
                        ),
                      ),
                    ]),
                  ]),
                );
              },
            ),
    );
  }
}
