import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_state.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({super.key, required this.task});
  final TaskItem task;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _comment = TextEditingController();

  // Ambil versi terbaru (di mode live data dimuat ulang jadi objek baru).
  TaskItem get t {
    final s = AppScope.read(context);
    return s.tasks.firstWhere((x) => x.id == widget.task.id, orElse: () => widget.task);
  }

  bool _busy = false;

  Future<void> _do(Future<String?> action, {String? success}) async {
    setState(() => _busy = true);
    await runAction(context, action, success: success);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _addProof(AppState state, bool photo) async {
    XFile? file;
    if (state.isLive) {
      if (photo) {
        file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 75);
      } else {
        final picked = await FilePicker.pickFile();
        file = picked?.xFile;
      }
      if (file == null || !mounted) return;
    }
    await _do(state.addProof(t, photo: photo, file: file), success: photo ? 'Foto bukti terupload.' : 'File bukti terupload.');
  }

  Future<String?> _askNote(String title, String hint, {bool required = false}) {
    final c = TextEditingController();
    return showAppSheet<String>(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: c, maxLines: 3, autofocus: true, decoration: InputDecoration(hintText: hint)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (required && c.text.trim().isEmpty) return;
              Navigator.pop(context, c.text);
            },
            child: const Text('Kirim'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final now = DateTime.now();
    final assigner = state.byId(t.assignerId);
    final isAssignee = t.assigneeIds.contains(me.id);
    final isAssigner = t.assignerId == me.id;
    final overdue = t.isOpen && t.deadline.isBefore(now);
    final canWork = isAssignee && (t.status == TaskStatus.dikerjakan || t.status == TaskStatus.revisi);

    Widget? bottom;
    if (isAssignee && t.status == TaskStatus.baru) {
      bottom = FilledButton(onPressed: _busy ? null : () => _do(state.startTask(t)), child: const Text('Mulai kerjakan'));
    } else if (canWork) {
      bottom = FilledButton(
        onPressed: _busy ? null : () async {
          if (!t.hasProof) {
            showSnack(context, 'Upload minimal 1 foto dan 1 file bukti dulu.', error: true);
            return;
          }
          final note = await _askNote('Kirim hasil ke atasan', 'Catatan untuk atasan (opsional)');
          if (note == null || !context.mounted) return;
          await _do(state.submitTask(t, note), success: 'Hasil terkirim, menunggu review ${assigner.firstName}.');
        },
        child: const Text('Kirim hasil'),
      );
    } else if (isAssigner && t.status == TaskStatus.review) {
      bottom = Row(children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.red, side: const BorderSide(color: AppColors.red, width: 1.5)),
            onPressed: () async {
              final note = await _askNote('Minta revisi', 'Apa yang perlu diperbaiki?', required: true);
              if (note == null || !context.mounted) return;
              await _do(state.reviewTask(t, approve: false, note: note), success: 'Revisi dikirim.');
            },
            child: const Text('Minta revisi'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _busy ? null : () => _do(state.reviewTask(t, approve: true), success: 'Tugas ditandai selesai.'),
            child: const Text('Setujui'),
          ),
        ),
      ]);
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Detail tugas')),
      bottomNavigationBar: bottom == null
          ? null
          : Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SafeArea(top: false, child: bottom),
            ),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              Pill(t.status.label, color: t.status.color, background: t.status.soft),
              Pill('Prioritas ${t.priority.label.toLowerCase()}', color: t.priority.color, background: t.priority.color.withValues(alpha: 0.1), icon: Icons.flag_rounded),
              if (t.recurrence != Recurrence.sekali)
                Pill(t.recurrence.label, color: AppColors.teal, background: AppColors.tealSoft, icon: Icons.repeat_rounded),
            ]),
            const SizedBox(height: 12),
            Text(t.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, height: 1.25)),
            const SizedBox(height: 10),
            Text(t.description, style: const TextStyle(fontSize: 14.5, height: 1.5, color: Color(0xFF3A3A3A))),
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.person_outline_rounded, label: 'Dari', value: '${assigner.name} · ${assigner.position}'),
            _InfoRow(icon: Icons.group_outlined, label: 'Untuk', value: t.assigneeIds.map((id) => state.byId(id).name).join(', ')),
            _InfoRow(
              icon: Icons.event_rounded,
              label: 'Deadline',
              value: '${fmtDate(t.deadline)}, ${fmtTime(t.deadline)}${overdue ? ' (terlambat)' : ''}',
              color: overdue ? AppColors.red : null,
            ),
            _InfoRow(icon: Icons.notifications_active_outlined, label: 'Pengingat', value: '10 jam sebelum deadline'),
          ]),
        ),
        const SizedBox(height: 10),
        _Progress(status: t.status),
        const SizedBox(height: 10),
        // Bukti
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bukti selesai', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Wajib foto + file sebelum dikirim ke atasan.', style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _ProofBox(
                  icon: Icons.photo_camera_rounded,
                  label: 'Foto',
                  count: t.proofPhotos,
                  onAdd: canWork && !_busy ? () => _addProof(state, true) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProofBox(
                  icon: Icons.attach_file_rounded,
                  label: 'File',
                  count: t.proofFiles,
                  onAdd: canWork && !_busy ? () => _addProof(state, false) : null,
                ),
              ),
            ]),
            if (t.proofNote != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12)),
                child: Text('Catatan: ${t.proofNote}', style: const TextStyle(fontSize: 13.5, height: 1.4)),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        // Komentar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Komentar (${t.comments.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            for (final c in t.comments)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Avatar(state.byId(c.authorId), size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(state.byId(c.authorId).firstName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(width: 6),
                        Text(fmtAgo(c.time, now), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
                      const SizedBox(height: 2),
                      Text(c.text, style: const TextStyle(fontSize: 14, height: 1.4)),
                    ]),
                  ),
                ]),
              ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _comment,
                  decoration: const InputDecoration(hintText: 'Tulis komentar…', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: _busy
                    ? null
                    : () async {
                        final text = _comment.text.trim();
                        if (text.isEmpty) return;
                        _comment.clear();
                        await _do(state.addComment(t, text));
                      },
                icon: const Icon(Icons.send_rounded, size: 20),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: AppColors.muted),
        const SizedBox(width: 10),
        SizedBox(width: 72, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13.5))),
        Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: color ?? AppColors.ink))),
      ]),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.status});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    const steps = ['Baru', 'Dikerjakan', 'Review', 'Selesai'];
    final idx = switch (status) {
      TaskStatus.baru => 0,
      TaskStatus.dikerjakan || TaskStatus.revisi => 1,
      TaskStatus.review => 2,
      TaskStatus.selesai => 3,
    };
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 0; i < steps.length; i++) ...[
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: i <= idx ? AppColors.primary : AppColors.line,
                shape: BoxShape.circle,
              ),
              child: i <= idx ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
            ),
            if (i < steps.length - 1)
              Expanded(child: Container(height: 3, color: i < idx ? AppColors.primary : AppColors.line)),
          ],
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < steps.length; i++)
            Text(steps[i], style: TextStyle(fontSize: 11.5, color: i <= idx ? AppColors.ink : AppColors.muted, fontWeight: i == idx ? FontWeight.w700 : FontWeight.w500)),
        ]),
        if (status == TaskStatus.revisi)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Pill('Dikembalikan untuk revisi — cek komentar atasan', color: AppColors.red, background: AppColors.redSoft, icon: Icons.replay_rounded),
          ),
      ]),
    );
  }
}

class _ProofBox extends StatelessWidget {
  const _ProofBox({required this.icon, required this.label, required this.count, this.onAdd});
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final has = count > 0;
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: has ? AppColors.primarySoft : AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: has ? AppColors.primary.withValues(alpha: 0.4) : AppColors.line),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(has ? Icons.check_circle_rounded : icon, color: has ? AppColors.green : AppColors.muted, size: 28),
          const SizedBox(height: 6),
          Text(has ? '$count $label' : (onAdd == null ? 'Belum ada ${label.toLowerCase()}' : '+ Tambah ${label.toLowerCase()}'),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: has ? AppColors.primary : AppColors.muted)),
        ]),
      ),
    );
  }
}
