import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_state.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final canApprove = me.role != Role.karyawan;
    final approvals = state.approvalsForMe();

    final mine = _MyRequests(state: state);
    if (!canApprove) {
      return Scaffold(appBar: AppBar(title: const Text('Cuti & Izin')), body: mine, floatingActionButton: const _NewButton());
    }
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cuti & Izin'),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [const Tab(text: 'Pengajuan saya'), Tab(text: 'Perlu approval (${approvals.length})')],
          ),
        ),
        floatingActionButton: const _NewButton(),
        body: TabBarView(children: [
          mine,
          approvals.isEmpty
              ? ListView(children: const [EmptyState(icon: Icons.task_alt_rounded, title: 'Semua pengajuan sudah diproses')])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: approvals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _RequestCard(r: approvals[i], approve: true),
                ),
        ]),
      ),
    );
  }
}

class _NewButton extends StatelessWidget {
  const _NewButton();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LeaveFormScreen())),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Ajukan', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _MyRequests extends StatelessWidget {
  const _MyRequests({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final me = state.me!;
    final list = state.myRequests();
    final left = state.leaveLeft(me.id);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
      FadeSlideIn(child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.hero,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sisa cuti tahunan', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text('$left hari', style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
              const SizedBox(height: 4),
              Text('dari ${state.annualLeave} hari · terpakai ${state.leaveUsed(me.id)} hari',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5)),
            ]),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: left / (state.annualLeave == 0 ? 1 : state.annualLeave)),
            duration: const Duration(milliseconds: 900),
            curve: Motion.curve,
            builder: (_, v, _) => SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                value: v.clamp(0, 1).toDouble(),
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                color: AppColors.gold,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ]),
      )),
      const SectionTitle('Riwayat pengajuan'),
      if (list.isEmpty)
        const EmptyState(icon: Icons.event_note_rounded, title: 'Belum ada pengajuan')
      else
        for (final r in list)
          Padding(padding: const EdgeInsets.only(bottom: 12), child: _RequestCard(r: r, approve: false)),
    ]);
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.r, required this.approve});
  final LeaveRequest r;
  final bool approve;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final emp = state.byId(r.employeeId);
    final range = r.days > 1 ? '${fmtDayMonth(r.start)} – ${fmtDate(r.end)} · ${r.days} hari' : fmtDate(r.start);
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: AppColors.orangeSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(r.type.icon, color: AppColors.orange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(approve ? '${emp.name} · ${r.type.label}' : r.type.label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(range, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
          if (!approve) Pill(r.status.label, color: r.status.color, background: r.status.soft),
        ]),
        const SizedBox(height: 10),
        Text(r.reason, style: const TextStyle(fontSize: 14, height: 1.4)),
        if (r.attachment)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Pill('Ada lampiran', color: AppColors.blue, background: AppColors.blueSoft, icon: Icons.attach_file_rounded),
          ),
        if (approve) ...[
          if (r.type.needsHr)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                r.status == RequestStatus.menungguHr ? 'Sudah disetujui atasan, menunggu HR.' : 'Setelah kamu setujui, lanjut ke HR.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red, width: 1.5),
                ),
                onPressed: () => runAction(context, state.decide(r, false), success: 'Pengajuan ${emp.firstName} ditolak.'),
                child: const Text('Tolak'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () => runAction(context, state.decide(r, true), success: 'Pengajuan ${emp.firstName} disetujui.'),
                child: const Text('Setujui'),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class LeaveFormScreen extends StatefulWidget {
  const LeaveFormScreen({super.key, this.initialType = RequestType.cutiTahunan});
  final RequestType initialType;

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  late RequestType _type = widget.initialType;
  late DateTime _start;
  late DateTime _end;
  final _reason = TextEditingController();
  bool _attachment = false;
  XFile? _file;
  bool get _hasAttachment => _attachment || _file != null;
  bool _busy = false;

  Future<void> _toggleAttachment() async {
    if (!AppScope.read(context).isLive) {
      setState(() => _attachment = !_attachment);
      return;
    }
    if (_file != null) {
      setState(() => _file = null);
      return;
    }
    final picked = await FilePicker.pickFile();
    if (picked != null && mounted) setState(() => _file = picked.xFile);
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final first = switch (widget.initialType) {
      RequestType.koreksiAbsen => base.subtract(const Duration(days: 1)),
      RequestType.lembur => base.add(const Duration(days: 1)),
      _ => base.add(const Duration(days: 1)),
    };
    _start = first;
    _end = first;
  }

  bool get _singleDay => _type == RequestType.lembur || _type == RequestType.koreksiAbsen;

  Future<void> _pick(bool start) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: now.subtract(const Duration(days: 60)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      if (start) {
        _start = d;
        if (_end.isBefore(d) || _singleDay) _end = d;
      } else {
        _end = d;
      }
    });
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      AppScope.read(context).submitRequest(
        type: _type,
        start: _start,
        end: _singleDay ? _start : _end,
        reason: _reason.text,
        attachment: _attachment,
        attachmentFile: _file,
      ),
      success: '${_type.label} terkirim ke atasan.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final days = _end.difference(_start).inDays + 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan pengajuan')),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: SafeArea(top: false, child: FilledButton(onPressed: _busy ? null : _submit, child: const Text('Kirim pengajuan'))),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Jenis', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            for (final t in RequestType.values)
              InkWell(
                onTap: () => setState(() {
                  _type = t;
                  if (_singleDay) _end = _start;
                }),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: _type == t ? AppColors.primarySoft : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _type == t ? AppColors.primary : AppColors.line, width: _type == t ? 1.5 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(t.icon, color: _type == t ? AppColors.primary : AppColors.muted),
                    const SizedBox(height: 6),
                    Text(t.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _type == t ? AppColors.primaryDark : AppColors.ink)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _DateBox(label: _singleDay ? 'Tanggal' : 'Mulai', date: _start, onTap: () => _pick(true))),
          if (!_singleDay) ...[
            const SizedBox(width: 12),
            Expanded(child: _DateBox(label: 'Selesai', date: _end, onTap: () => _pick(false))),
          ],
        ]),
        const SizedBox(height: 8),
        if (_type == RequestType.cutiTahunan)
          Text('$days hari · sisa cuti kamu ${state.leaveLeft(state.me!.id)} hari', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        if (_type == RequestType.lembur)
          const Text('Lembur wajib diajukan paling lambat H-1.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        if (_type == RequestType.koreksiAbsen)
          const Text('Untuk lupa absen atau gagal absen karena sinyal/GPS. Wajib di-approve atasan.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        if (_type.needsHr)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Alur approval: atasan → HR.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
        const SizedBox(height: 18),
        const Text('Alasan', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(controller: _reason, maxLines: 3, decoration: const InputDecoration(hintText: 'Tulis alasan singkat')),
        const SizedBox(height: 16),
        CardBox(
          onTap: _toggleAttachment,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(_hasAttachment ? Icons.check_circle_rounded : Icons.attach_file_rounded, color: _hasAttachment ? AppColors.green : AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _hasAttachment ? (_file?.name ?? 'Lampiran ditambahkan') : (_type == RequestType.sakit ? 'Lampirkan surat dokter' : 'Tambah lampiran (opsional)'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.label, required this.date, required this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.event_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(fmtDate(date), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}
