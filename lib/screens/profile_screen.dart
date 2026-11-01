import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final manager = me.managerId == null ? null : state.byId(me.managerId!);
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        FadeSlideIn(child: Container(
          margin: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 0),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.hero,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.gold,
              child: Text(me.initials, style: const TextStyle(color: AppColors.hero, fontWeight: FontWeight.w800, fontSize: 22)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                const SizedBox(height: 2),
                Text('${me.position} · ${me.division}', style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(me.role.label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ]),
        )),
        const SizedBox(height: 12),
        _Group(children: [
          _Row(icon: Icons.badge_outlined, label: 'NIK', value: me.nik),
          _Row(icon: Icons.phone_iphone_rounded, label: 'No. HP', value: me.phone),
          _Row(icon: Icons.schedule_rounded, label: 'Jadwal', value: '${me.shift.label} (${me.shift.hours})'),
          if (manager != null) _Row(icon: Icons.supervisor_account_outlined, label: 'Atasan langsung', value: manager.name),
          _Row(icon: Icons.event_available_rounded, label: 'Tanggal masuk', value: fmtDate(me.joinedAt)),
          if (me.role != Role.hr && state.myTeam.isNotEmpty)
            _Row(icon: Icons.groups_outlined, label: 'Anggota tim', value: '${state.myTeam.length} orang'),
        ]),
        const SizedBox(height: 12),
        _Group(children: [
          _Action(icon: Icons.lock_reset_rounded, label: 'Ganti password', onTap: () => _changePassword(context)),
          _Action(icon: Icons.phonelink_lock_rounded, label: 'Perangkat terdaftar', trailing: '1 HP', onTap: () => showSnack(context, '1 akun hanya bisa login di 1 HP.')),
          _Action(icon: Icons.help_outline_rounded, label: 'Bantuan', onTap: () => showSnack(context, 'Hubungi HR untuk bantuan.')),
        ]),
        const SizedBox(height: 12),
        _Group(children: [
          _Action(icon: Icons.logout_rounded, label: 'Keluar', color: AppColors.red, onTap: () => state.logout()),
        ]),
        const SizedBox(height: 24),
        Center(child: Text('tokogue v0.2 · ${state.isLive ? 'terhubung ke server' : 'mode demo'}', style: const TextStyle(color: AppColors.muted, fontSize: 12))),
        const SizedBox(height: 24),
      ]),
    );
  }

  void _changePassword(BuildContext context) {
    final a = TextEditingController();
    final b = TextEditingController();
    showAppSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Ganti password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: a, obscureText: true, decoration: const InputDecoration(labelText: 'Password baru')),
          const SizedBox(height: 10),
          TextField(controller: b, obscureText: true, decoration: const InputDecoration(labelText: 'Ulangi password baru')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              if (a.text != b.text) {
                showSnack(context, 'Password tidak sama.', error: true);
                return;
              }
              final state = AppScope.read(context);
              final nav = Navigator.of(context);
              final ok = await runAction(context, state.changePassword(a.text),
                  success: state.isLive ? 'Password berhasil diganti.' : 'Password diganti (mode demo, tidak tersimpan).');
              if (ok) nav.pop();
            },
            child: const Text('Simpan'),
          ),
        ]),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const Divider(indent: 52),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Icon(icon, color: AppColors.muted, size: 22),
        const SizedBox(width: 14),
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.color, this.trailing});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: color ?? AppColors.ink, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color ?? AppColors.ink))),
          if (trailing != null) Text(trailing!, style: const TextStyle(color: AppColors.muted)),
          if (color == null) const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ]),
      ),
    );
  }
}
