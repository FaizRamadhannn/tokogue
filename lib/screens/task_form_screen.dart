import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final Set<String> _assignees = {};
  late DateTime _deadline;
  Priority _priority = Priority.sedang;
  Recurrence _recurrence = Recurrence.sekali;

  @override
  void initState() {
    super.initState();
    final t = DateTime.now().add(const Duration(days: 1));
    _deadline = DateTime(t.year, t.month, t.day, 17);
  }

  Future<void> _pickDeadline() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_deadline));
    setState(() => _deadline = DateTime(d.year, d.month, d.day, t?.hour ?? 17, t?.minute ?? 0));
  }

  bool _busy = false;

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      showSnack(context, 'Isi judul tugas dulu.', error: true);
      return;
    }
    if (_assignees.isEmpty) {
      showSnack(context, 'Pilih minimal 1 penerima tugas.', error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await runAction(
      context,
      AppScope.read(context).createTask(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        assigneeIds: _assignees.toList(),
        deadline: _deadline,
        priority: _priority,
        recurrence: _recurrence,
      ),
      success: 'Tugas terkirim ke ${_assignees.length} orang.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final team = state.myTeam;
    return Scaffold(
      appBar: AppBar(title: const Text('Buat tugas')),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: SafeArea(top: false, child: FilledButton(onPressed: _busy ? null : _submit, child: const Text('Kirim tugas'))),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const _Label('Judul tugas'),
        TextField(controller: _title, decoration: const InputDecoration(hintText: 'Contoh: Bersihkan mesin espresso')),
        const SizedBox(height: 16),
        const _Label('Deskripsi'),
        TextField(controller: _desc, maxLines: 4, decoration: const InputDecoration(hintText: 'Jelaskan apa yang harus dikerjakan dan bukti yang diminta')),
        const SizedBox(height: 16),
        _Label('Penerima (${_assignees.length} dipilih)'),
        if (team.isEmpty)
          const Text('Belum ada anggota tim di bawah kamu.', style: TextStyle(color: AppColors.muted))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in team)
              FilterChip(
                avatar: Avatar(e, size: 24),
                label: Text(e.firstName),
                selected: _assignees.contains(e.id),
                showCheckmark: false,
                onSelected: (v) => setState(() => v ? _assignees.add(e.id) : _assignees.remove(e.id)),
              ),
          ]),
        const SizedBox(height: 16),
        const _Label('Deadline'),
        InkWell(
          onTap: _pickDeadline,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.event_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('${fmtLongDate(_deadline)}, ${fmtTime(_deadline)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.edit_rounded, size: 18, color: AppColors.muted),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        const Text('Penerima dapat pengingat 10 jam sebelum deadline.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 16),
        const _Label('Prioritas'),
        SegmentedButton<Priority>(
          segments: [for (final p in Priority.values) ButtonSegment(value: p, label: Text(p.label))],
          selected: {_priority},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _priority = s.first),
        ),
        const SizedBox(height: 16),
        const _Label('Ulangi tugas'),
        SegmentedButton<Recurrence>(
          segments: [for (final r in Recurrence.values) ButtonSegment(value: r, label: Text(r.label))],
          selected: {_recurrence},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _recurrence = s.first),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.blueSoft, borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: AppColors.blue, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('Penerima wajib upload foto dan file bukti sebelum tugas bisa dikirim ke kamu.',
                  style: TextStyle(color: AppColors.blue, fontSize: 13)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}
