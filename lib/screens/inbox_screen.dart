import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/format.dart';
import '../theme.dart';
import '../widgets/common.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final list = state.myNotifications();
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => state.readAllNotifications(),
              child: const Text('Tandai dibaca', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: list.isEmpty
          ? ListView(children: const [EmptyState(icon: Icons.notifications_none_rounded, title: 'Belum ada notifikasi')])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = list[i];
                return FadeSlideIn(child: Pressable(scale: 0.98, child: AnimatedContainer(
                  duration: Motion.medium,
                  decoration: BoxDecoration(
                    color: n.read ? Colors.white : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: n.read ? AppColors.line : Colors.transparent),
                  ),
                  child: Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: n.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                      child: Icon(n.icon, color: n.color, size: 22),
                    ),
                    title: Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800, fontSize: 14.5)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(n.body, style: const TextStyle(fontSize: 13, height: 1.35)),
                    ),
                    trailing: Text(fmtAgo(n.time, now), style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                    onTap: () => state.markNotificationRead(n),
                  ),
                ))));
              },
            ),
    );
  }
}
