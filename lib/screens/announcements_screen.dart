import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/format.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = state.me!;
    final list = [...state.announcements]..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.date.compareTo(a.date);
      });
    final canPost = me.role == Role.hr || me.role == Role.atasan;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _post(context),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Tulis', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final a = list[i];
          final unread = !a.readBy.contains(me.id);
          return CardBox(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnnouncementDetailScreen(a: a))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: a.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(a.pinned ? Icons.push_pin_rounded : Icons.campaign_rounded, color: a.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                    if (unread)
                      Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
                  ]),
                  const SizedBox(height: 4),
                  Text(a.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 6),
                  Text('${state.byId(a.authorId).firstName} · ${fmtDate(a.date)}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  void _post(BuildContext context) {
    final title = TextEditingController();
    final body = TextEditingController();
    showAppSheet(
      context,
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Pengumuman baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Dikirim ke semua karyawan.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Judul')),
          const SizedBox(height: 10),
          TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Isi pengumuman')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty || body.text.trim().isEmpty) return;
              final nav = Navigator.of(context);
              final ok = await runAction(context, AppScope.read(context).postAnnouncement(title.text.trim(), body.text.trim()),
                  success: 'Pengumuman terkirim.');
              if (ok) nav.pop();
            },
            child: const Text('Kirim ke semua'),
          ),
        ]),
      ),
    );
  }
}

class AnnouncementDetailScreen extends StatefulWidget {
  const AnnouncementDetailScreen({super.key, required this.a});
  final Announcement a;

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.read(context).markRead(widget.a);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final a = widget.a;
    final author = state.byId(a.authorId);
    final isAuthor = a.authorId == state.me!.id;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        FadeSlideIn(
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: a.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.campaign_rounded, size: 28, color: a.color),
          ),
        ),
        const SizedBox(height: 20),
        FadeSlideIn(child: Text(a.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.6))),
        const SizedBox(height: 10),
        Row(children: [
          Avatar(author, size: 28),
          const SizedBox(width: 8),
          Text('${author.name} · ${fmtDate(a.date)}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ]),
        const SizedBox(height: 18),
        FadeSlideIn(child: Text(a.body, style: const TextStyle(fontSize: 15.5, height: 1.6))),
        const SizedBox(height: 24),
        if (isAuthor || state.me!.role == Role.hr)
          Pill('Sudah dibaca ${a.readBy.length} dari ${state.employees.length} orang',
              color: AppColors.primary, background: AppColors.primarySoft, icon: Icons.done_all_rounded),
      ]),
    );
  }
}
