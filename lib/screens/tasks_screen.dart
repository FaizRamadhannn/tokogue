import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final all = state.tasksForMe();
    final active = all.where((t) => t.status == TaskStatus.baru || t.status == TaskStatus.dikerjakan || t.status == TaskStatus.revisi).toList();
    final review = all.where((t) => t.status == TaskStatus.review).toList();
    final done = all.where((t) => t.status == TaskStatus.selesai).toList();
    final canAssign = me.role == Role.atasan;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tugas'),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Aktif (${active.length})'),
              Tab(text: 'Review (${review.length})'),
              Tab(text: 'Selesai (${done.length})'),
            ],
          ),
        ),
        floatingActionButton: canAssign
            ? FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskFormScreen())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Buat tugas', style: TextStyle(fontWeight: FontWeight.w700)),
              )
            : null,
        body: TabBarView(children: [
          _TaskList(tasks: active, empty: 'Tidak ada tugas aktif'),
          _TaskList(tasks: review, empty: canAssign ? 'Belum ada tugas yang perlu kamu review' : 'Belum ada tugas yang menunggu review'),
          _TaskList(tasks: done, empty: 'Belum ada tugas selesai'),
        ]),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.tasks, required this.empty});
  final List<TaskItem> tasks;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return ListView(children: [EmptyState(icon: Icons.assignment_turned_in_rounded, title: empty)]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => TaskCard(task: tasks[i]),
    );
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final overdue = task.isOpen && task.deadline.isBefore(now);
    final me = state.me!;
    final assigner = state.byId(task.assignerId);
    final assignees = task.assigneeIds.map(state.byId).toList();
    final fromMe = task.assignerId == me.id;

    return CardBox(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(task.status.label, color: task.status.color, background: task.status.soft),
          const SizedBox(width: 6),
          if (task.recurrence != Recurrence.sekali)
            Pill(task.recurrence.label, color: AppColors.teal, background: AppColors.tealSoft, icon: Icons.repeat_rounded),
          const Spacer(),
          Icon(Icons.flag_rounded, size: 16, color: task.priority.color),
          const SizedBox(width: 2),
          Text(task.priority.label, style: TextStyle(color: task.priority.color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Text(task.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        const SizedBox(height: 4),
        Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35)),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(
            width: 24.0 + (assignees.length - 1) * 16,
            height: 24,
            child: Stack(children: [
              for (var i = 0; i < assignees.length; i++)
                Positioned(
                  left: i * 16.0,
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: Avatar(assignees[i], size: 22),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              fromMe ? 'Untuk ${assignees.map((e) => e.firstName).join(', ')}' : 'Dari ${assigner.firstName}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
          Icon(Icons.access_time_rounded, size: 15, color: overdue ? AppColors.red : AppColors.muted),
          const SizedBox(width: 4),
          Text(task.isOpen ? fmtDeadline(task.deadline, now) : fmtDate(task.deadline),
              style: TextStyle(fontSize: 12.5, color: overdue ? AppColors.red : AppColors.muted, fontWeight: overdue ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ]),
    );
  }
}
